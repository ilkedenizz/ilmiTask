import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/data/database_helper.dart';
import 'package:reminder_app/data/models/reminder_model.dart';
import 'package:reminder_app/data/models/subtask_model.dart';
import 'package:reminder_app/data/repositories/reminder_repository.dart';
import 'package:reminder_app/main.dart';
import 'package:reminder_app/services/notification_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockNotificationService extends NotificationService {
  @override
  Future<void> scheduleReminderNotification(Reminder reminder) async {}
  @override
  Future<void> cancelReminderNotification(int reminderId) async {}
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('HomeScreen renders search, categories, reminders, and opens editor',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
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

            // Seed sample category
            await db.insert(DatabaseHelper.tableCategories, {
              'name': 'Work',
              'color_hex': '#FF9800',
              'icon_code': 0xe6f2,
            });
          },
        ),
      );

      DatabaseHelper.instance.setDatabaseForTesting(db);
      final repo = ReminderRepository(
        dbHelper: DatabaseHelper.instance,
        notificationService: MockNotificationService(),
      );

      // Insert a sample reminder with subtasks to verify rendering
      await repo.insertReminder(
        Reminder(
          title: 'Prepare Client Brief',
          notes: 'Cover financial scope and timeline',
          categoryId: 1,
          dueDatetime: DateTime.now().add(const Duration(hours: 2)),
          earlyAlertMinutes: 15,
          alertSeverity: ReminderAlertSeverity.strongFullscreen,
          isPinned: true,
          createdAt: DateTime.now(),
          subtasks: const [
            Subtask(title: 'Gather revenue sheets'),
            Subtask(title: 'Confirm participant list'),
          ],
        ),
      );

      await tester.pumpWidget(SamsungReminderApp(repository: repo));
      await Future.delayed(const Duration(milliseconds: 150));
      await tester.pump();

      // Check search bar and filter chips
      expect(find.byType(SearchBar), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Pinned'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);

      // Check pinned section header and card title
      expect(find.text('PINNED (1)'), findsOneWidget);
      expect(find.text('Prepare Client Brief'), findsOneWidget);

      // Check interactive subtasks inside the card
      expect(find.text('Gather revenue sheets'), findsOneWidget);
      expect(find.text('Confirm participant list'), findsOneWidget);

      // Check FAB button
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);

      // Tap FAB to open modal editor sheet
      await tester.tap(fabFinder);
      await Future.delayed(const Duration(milliseconds: 250));
      await tester.pump();

      // Verify editor sheet opened
      expect(find.text('New Reminder'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Schedule Date & Time'), findsOneWidget);

      await db.close();
      DatabaseHelper.instance.setDatabaseForTesting(null);
    });
  });
}
