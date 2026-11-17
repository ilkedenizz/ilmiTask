import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/data/database_helper.dart';
import 'package:reminder_app/data/models/category_model.dart';
import 'package:reminder_app/data/models/reminder_model.dart';
import 'package:reminder_app/data/repositories/reminder_repository.dart';
import 'package:reminder_app/main.dart';
import 'package:reminder_app/services/notification_service.dart';
import 'package:reminder_app/widgets/category_management_dialog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockNotificationService extends NotificationService {
  @override
  Future<void> scheduleReminderNotification(Reminder reminder) async {}
  @override
  Future<void> cancelReminderNotification(int reminderId) async {}
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

  group('Phase 8 — Swipe Gestures & Category Management', () {
    testWidgets('Swipe right on reminder card marks task as completed',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        final db = await _openTestDb();
        DatabaseHelper.instance.setDatabaseForTesting(db);
        final repo = ReminderRepository(
          dbHelper: DatabaseHelper.instance,
          notificationService: _MockNotificationService(),
        );

        final inserted = await repo.insertReminder(Reminder(
          title: 'Review PR #42',
          isPinned: true,
          createdAt: DateTime.now(),
        ));

        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.5;

        await tester.pumpWidget(SamsungReminderApp(repository: repo));
        await Future.delayed(const Duration(milliseconds: 150));
        await tester.pump();

        expect(find.text('Review PR #42'), findsOneWidget);

        // Fling right to trigger complete action on Dismissible
        final dismissibleFinder = find.byKey(Key('reminder_${inserted.id}'));
        expect(dismissibleFinder, findsOneWidget);
        await tester.fling(dismissibleFinder, const Offset(500, 0), 1000);
        await tester.pumpAndSettle();

        // Check SQLite updated to completed
        final r = await repo.getReminderById(inserted.id!);
        expect(r!.isCompleted, isTrue);

        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await db.close();
        DatabaseHelper.instance.setDatabaseForTesting(null);
      });
    });

    testWidgets('Swipe left on reminder card triggers delete with undo snackbar',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        final db = await _openTestDb();
        DatabaseHelper.instance.setDatabaseForTesting(db);
        final repo = ReminderRepository(
          dbHelper: DatabaseHelper.instance,
          notificationService: _MockNotificationService(),
        );

        final inserted = await repo.insertReminder(Reminder(
          title: 'Delete this task',
          isPinned: true,
          createdAt: DateTime.now(),
        ));

        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.5;

        await tester.pumpWidget(SamsungReminderApp(repository: repo));
        await Future.delayed(const Duration(milliseconds: 150));
        await tester.pump();

        expect(find.text('Delete this task'), findsOneWidget);

        // Fling left to trigger delete action on Dismissible
        final dismissibleFinder = find.byKey(Key('reminder_${inserted.id}'));
        expect(dismissibleFinder, findsOneWidget);
        await tester.fling(dismissibleFinder, const Offset(-800, 0), 2000);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pump();

        // Check task is deleted in SQLite
        final r = await repo.getReminderById(inserted.id!);
        expect(r, isNull);

        // Check Undo action
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);

        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await db.close();
        DatabaseHelper.instance.setDatabaseForTesting(null);
      });
    });

    testWidgets('CategoryManagementDialog allows editing existing category',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        final db = await _openTestDb();
        DatabaseHelper.instance.setDatabaseForTesting(db);
        final repo = ReminderRepository(
          dbHelper: DatabaseHelper.instance,
          notificationService: _MockNotificationService(),
        );

        final cat = CategoryModel(
          id: 1,
          name: 'Work',
          colorHex: '#FF9800',
          iconCode: 0xe6f2,
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: CategoryManagementDialog(
              repository: repo,
              initialCategoryToEdit: cat,
            ),
          ),
        ));
        await tester.pump();

        expect(find.text('EDIT: WORK'), findsOneWidget);
        expect(find.text('Work'), findsWidgets);

        // Edit category name
        final field = find.byType(TextField);
        await tester.enterText(field, 'Work & Projects');
        await tester.pump();

        // Tap Save button
        final saveBtn = find.byTooltip('Update Category');
        expect(saveBtn, findsOneWidget);
        await tester.tap(saveBtn);
        await Future.delayed(const Duration(milliseconds: 150));
        await tester.pump();

        // Verify updated category in SQLite
        final updated = await repo.getCategoryById(1);
        expect(updated!.name, 'Work & Projects');

        await db.close();
        DatabaseHelper.instance.setDatabaseForTesting(null);
      });
    });
  });
}
