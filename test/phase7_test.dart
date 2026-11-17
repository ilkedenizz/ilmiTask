import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/data/database_helper.dart';
import 'package:reminder_app/data/models/reminder_model.dart';
import 'package:reminder_app/data/repositories/reminder_repository.dart';
import 'package:reminder_app/l10n/app_strings.dart';
import 'package:reminder_app/main.dart';
import 'package:reminder_app/services/notification_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockNotificationService extends NotificationService {
  int cancelCount = 0;
  @override
  Future<void> scheduleReminderNotification(Reminder reminder) async {}
  @override
  Future<void> cancelReminderNotification(int reminderId) async {
    cancelCount++;
  }
}

Future<Database> _openTestDb() {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE ${DatabaseHelper.tableCategories} (
            ${DatabaseHelper.colCatId} INTEGER PRIMARY KEY AUTOINCREMENT,
            ${DatabaseHelper.colCatName} TEXT NOT NULL,
            ${DatabaseHelper.colCatColorHex} TEXT NOT NULL,
            ${DatabaseHelper.colCatIconCode} INTEGER NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE ${DatabaseHelper.tableReminders} (
            ${DatabaseHelper.colRemId} INTEGER PRIMARY KEY AUTOINCREMENT,
            ${DatabaseHelper.colRemTitle} TEXT NOT NULL,
            ${DatabaseHelper.colRemNotes} TEXT,
            ${DatabaseHelper.colRemCategoryId} INTEGER,
            ${DatabaseHelper.colRemDueDatetime} TEXT,
            ${DatabaseHelper.colRemEarlyAlertMinutes} INTEGER NOT NULL DEFAULT 0,
            ${DatabaseHelper.colRemRepeatRule} TEXT NOT NULL DEFAULT 'none',
            ${DatabaseHelper.colRemAlertSeverity} TEXT NOT NULL DEFAULT 'short',
            ${DatabaseHelper.colRemLocationLat} REAL,
            ${DatabaseHelper.colRemLocationLng} REAL,
            ${DatabaseHelper.colRemLocationRadius} REAL,
            ${DatabaseHelper.colRemLocationTriggerType} TEXT,
            ${DatabaseHelper.colRemImagePath} TEXT,
            ${DatabaseHelper.colRemIsPinned} INTEGER NOT NULL DEFAULT 0,
            ${DatabaseHelper.colRemIsCompleted} INTEGER NOT NULL DEFAULT 0,
            ${DatabaseHelper.colRemCreatedAt} TEXT NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE ${DatabaseHelper.tableSubtasks} (
            ${DatabaseHelper.colSubId} INTEGER PRIMARY KEY AUTOINCREMENT,
            ${DatabaseHelper.colSubReminderId} INTEGER NOT NULL,
            ${DatabaseHelper.colSubTitle} TEXT NOT NULL,
            ${DatabaseHelper.colSubIsDone} INTEGER NOT NULL DEFAULT 0
          );
        ''');
        await db.insert(DatabaseHelper.tableCategories, {
          'name': 'Work',
          'color_hex': '#FF9800',
          'icon_code': 0xe6f2,
        });
      },
    ),
  );
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Phase 7 — payload parsing', () {
    test('parses main, early and invalid payloads', () {
      expect(parseReminderIdFromPayload('reminder_42'), 42);
      expect(parseReminderIdFromPayload('early_reminder_7'), 7);
      expect(parseReminderIdFromPayload('immediate_test_3'), isNull);
      expect(parseReminderIdFromPayload('reminder_abc'), isNull);
    });
  });

  group('Phase 7 — localized agenda dates', () {
    test('Turkish and English month/day labels', () {
      final d = DateTime(2026, 11, 17); // Tuesday
      expect(const AppStrings('tr').agendaDate(d), '17 Kasım 2026, Salı');
      expect(const AppStrings('en').agendaDate(d),
          'Tuesday, November 17, 2026');
      expect(const AppStrings('tr').addForThisDay, 'Bu güne hatırlatıcı ekle');
    });
  });

  group('Phase 7 — notification actions', () {
    test('Complete action marks reminder done in SQLite', () async {
      final db = await _openTestDb();
      DatabaseHelper.instance.setDatabaseForTesting(db);
      final mock = _MockNotificationService();
      final repo = ReminderRepository(
        dbHelper: DatabaseHelper.instance,
        notificationService: mock,
      );
      final id = (await repo.insertReminder(Reminder(
        title: 'Pay invoice',
        dueDatetime: DateTime.now().add(const Duration(minutes: 1)),
        createdAt: DateTime.now(),
      ))).id!;

      await handleNotificationAction(
        NotificationService.actionComplete,
        'reminder_$id',
        repository: repo,
        notificationService: mock,
      );
      final r = await repo.getReminderById(id);
      expect(r!.isCompleted, isTrue);
      expect(mock.cancelCount, greaterThanOrEqualTo(1));

      await db.close();
      DatabaseHelper.instance.setDatabaseForTesting(null);
    });

    test('Snooze action (from early alert) moves due ~10 minutes ahead',
        () async {
      final db = await _openTestDb();
      DatabaseHelper.instance.setDatabaseForTesting(db);
      final repo = ReminderRepository(
        dbHelper: DatabaseHelper.instance,
        notificationService: _MockNotificationService(),
      );
      final id = (await repo.insertReminder(Reminder(
        title: 'Standup',
        dueDatetime: DateTime.now().subtract(const Duration(minutes: 1)),
        createdAt: DateTime.now(),
      ))).id!;

      final before = DateTime.now();
      await handleNotificationAction(
        NotificationService.actionSnooze,
        'early_reminder_$id',
        repository: repo,
      );
      final r = await repo.getReminderById(id);
      final diff = r!.dueDatetime!.difference(before).inSeconds;
      expect(diff, inInclusiveRange(590, 610));
      expect(r.isCompleted, isFalse);

      await db.close();
      DatabaseHelper.instance.setDatabaseForTesting(null);
    });
  });

  testWidgets('Agenda view shows cell snippets and empty-day shortcut',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      final db = await _openTestDb();
      DatabaseHelper.instance.setDatabaseForTesting(db);
      final repo = ReminderRepository(
        dbHelper: DatabaseHelper.instance,
        notificationService: _MockNotificationService(),
      );
      final now = DateTime.now();
      await repo.insertReminder(Reminder(
        title: 'Design Review',
        categoryId: 1,
        dueDatetime: DateTime(now.year, now.month, now.day, 23, 30),
        createdAt: now,
      ));

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;

      await tester.pumpWidget(SamsungReminderApp(repository: repo));
      await Future.delayed(const Duration(milliseconds: 150));
      await tester.pump();

      await tester.tap(find.text('AGENDA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Snippet in the calendar cell + full card in the agenda list
      expect(find.text('Design Review'), findsNWidgets(2));
      expect(find.text('23:30'), findsWidgets);

      // Jump to next month -> empty day shows shortcut
      await tester.tap(find.byKey(const Key('agenda_next_month')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final firstOfNext = DateTime(now.year, now.month + 1, 1);
      await tester.tap(find.byKey(ValueKey(
          'cal_cell_${firstOfNext.year}_${firstOfNext.month}_${firstOfNext.day}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Add reminder for this day'), findsWidgets);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await db.close();
      DatabaseHelper.instance.setDatabaseForTesting(null);
    });
  });
}
