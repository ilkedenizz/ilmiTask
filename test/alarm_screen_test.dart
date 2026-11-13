import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/data/database_helper.dart';
import 'package:reminder_app/data/models/reminder_model.dart';
import 'package:reminder_app/data/models/subtask_model.dart';
import 'package:reminder_app/data/repositories/reminder_repository.dart';
import 'package:reminder_app/main.dart';
import 'package:reminder_app/screens/alarm_ringing_screen.dart';
import 'package:reminder_app/services/notification_service.dart';
import 'package:reminder_app/widgets/system_shield_dialog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockNotificationService extends NotificationService {
  int? lastCancelledId;
  Reminder? lastScheduled;

  @override
  Future<void> scheduleReminderNotification(Reminder reminder) async {
    lastScheduled = reminder;
  }

  @override
  Future<void> cancelReminderNotification(int reminderId) async {
    lastCancelledId = reminderId;
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('AlarmRingingScreen Tests', () {
    testWidgets('Renders alarm title, notes, time, checklist, and action buttons',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final reminder = Reminder(
        id: 101,
        title: 'Emergency Standup',
        notes: 'Critical team coordination needed',
        dueDatetime: now,
        alertSeverity: ReminderAlertSeverity.strongFullscreen,
        createdAt: now,
        subtasks: const [
          Subtask(id: 1, title: 'Server logs check', isDone: false),
          Subtask(id: 2, title: 'Alert ops team', isDone: true),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AlarmRingingScreen(reminder: reminder),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Emergency Standup'), findsOneWidget);
      expect(find.text('Critical team coordination needed'), findsOneWidget);
      expect(find.text('CHECKLIST (1/2)'), findsOneWidget);
      expect(find.text('Server logs check'), findsOneWidget);
      expect(find.text('Alert ops team'), findsOneWidget);
      expect(find.text('Snooze (+10m)'), findsOneWidget);
      expect(find.text('Dismiss / Done'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Interactive subtask toggle updates state inside AlarmRingingScreen',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        final notifMock = MockNotificationService();
        NotificationService.instance = notifMock;

        final db = await databaseFactoryFfi.openDatabase(
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
            },
          ),
        );

        DatabaseHelper.instance.setDatabaseForTesting(db);
        final repo = ReminderRepository(
          dbHelper: DatabaseHelper.instance,
          notificationService: notifMock,
        );

        final inserted = await repo.insertReminder(
          Reminder(
            title: 'Critical Deployment',
            dueDatetime: DateTime.now(),
            alertSeverity: ReminderAlertSeverity.strongFullscreen,
            createdAt: DateTime.now(),
            subtasks: const [
              Subtask(title: 'Run smoke test suite'),
            ],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AlarmRingingScreen(
              reminder: inserted,
              repository: repo,
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        expect(find.text('Run smoke test suite'), findsOneWidget);
        expect(find.text('CHECKLIST (0/1)'), findsOneWidget);

        // Tap the subtask item to toggle it
        await tester.tap(find.text('Run smoke test suite'));
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Subtask should now be marked done (1/1)
        expect(find.text('CHECKLIST (1/1)'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await db.close();
        DatabaseHelper.instance.setDatabaseForTesting(null);
      });
    });

    testWidgets('Snooze button reschedules reminder for +10 minutes',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        final notifMock = MockNotificationService();
        NotificationService.instance = notifMock;

        final db = await databaseFactoryFfi.openDatabase(
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
            },
          ),
        );

        DatabaseHelper.instance.setDatabaseForTesting(db);
        final repo = ReminderRepository(
          dbHelper: DatabaseHelper.instance,
          notificationService: notifMock,
        );

        final inserted = await repo.insertReminder(
          Reminder(
            title: 'Alarm Task to Snooze',
            dueDatetime: DateTime.now(),
            alertSeverity: ReminderAlertSeverity.strongFullscreen,
            createdAt: DateTime.now(),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AlarmRingingScreen(
              reminder: inserted,
              repository: repo,
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        final snoozeFinder = find.text('Snooze (+10m)');
        expect(snoozeFinder, findsOneWidget);

        await tester.tap(snoozeFinder);
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Check that the reminder was updated with a future due datetime (~10 mins from now)
        final updated = await repo.getReminderById(inserted.id!);
        expect(updated, isNotNull);
        expect(
          updated!.dueDatetime!.isAfter(
            DateTime.now().add(const Duration(minutes: 8)),
          ),
          isTrue,
        );

        await tester.pumpWidget(const SizedBox());

        await db.close();
        DatabaseHelper.instance.setDatabaseForTesting(null);
      });
    });

    testWidgets('Notification Routing: ONLY strong_fullscreen reminder opens AlarmRingingScreen',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        final notifMock = MockNotificationService();
        NotificationService.instance = notifMock;

        final db = await databaseFactoryFfi.openDatabase(
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
            },
          ),
        );

        DatabaseHelper.instance.setDatabaseForTesting(db);
        final repo = ReminderRepository(
          dbHelper: DatabaseHelper.instance,
          notificationService: notifMock,
        );

        // 1. Insert strong_fullscreen reminder
        final strongReminder = await repo.insertReminder(
          Reminder(
            title: 'Critical Strong Alarm',
            dueDatetime: DateTime.now(),
            alertSeverity: ReminderAlertSeverity.strongFullscreen,
            createdAt: DateTime.now(),
          ),
        );

        // 2. Insert standard short reminder
        final shortReminder = await repo.insertReminder(
          Reminder(
            title: 'Standard Short Task',
            dueDatetime: DateTime.now(),
            earlyAlertMinutes: 15,
            alertSeverity: ReminderAlertSeverity.short,
            createdAt: DateTime.now(),
          ),
        );

        await tester.pumpWidget(SamsungReminderApp(repository: repo));
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Test payload for early_reminder: should NOT open AlarmRingingScreen
        await handleNotificationPayload(
          'early_reminder_${shortReminder.id}',
          repository: repo,
        );
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        expect(find.byType(AlarmRingingScreen), findsNothing);

        // Test payload for short reminder: should NOT open AlarmRingingScreen
        await handleNotificationPayload(
          'reminder_${shortReminder.id}',
          repository: repo,
        );
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        expect(find.byType(AlarmRingingScreen), findsNothing);

        // Test payload for strong_fullscreen main reminder: MUST open AlarmRingingScreen
        await handleNotificationPayload(
          'reminder_${strongReminder.id}',
          repository: repo,
        );
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        expect(find.byType(AlarmRingingScreen), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlarmRingingScreen),
            matching: find.text('Critical Strong Alarm'),
          ),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await db.close();
        DatabaseHelper.instance.setDatabaseForTesting(null);
      });
    });

    testWidgets('SystemShieldDialog renders and displays diagnostic items',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SystemShieldDialog(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('System Reliability Shield'), findsOneWidget);
      expect(find.text('System Notifications'), findsOneWidget);
      expect(find.text('Exact Alarm Scheduling'), findsOneWidget);
      expect(find.text('Battery Optimization Shield'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
