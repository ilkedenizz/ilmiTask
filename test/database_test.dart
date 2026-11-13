import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/data/database_helper.dart';
import 'package:reminder_app/data/models/category_model.dart';
import 'package:reminder_app/data/models/reminder_model.dart';
import 'package:reminder_app/data/models/subtask_model.dart';
import 'package:reminder_app/data/repositories/reminder_repository.dart';
import 'package:reminder_app/services/notification_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class RecordingNotificationService extends NotificationService {
  final List<Reminder> scheduledReminders = [];
  final List<int> cancelledReminderIds = [];

  RecordingNotificationService();

  @override
  Future<void> scheduleReminderNotification(Reminder reminder) async {
    if (reminder.dueDatetime == null || reminder.isCompleted) {
      await cancelReminderNotification(reminder.id!);
      return;
    }
    scheduledReminders.add(reminder);
  }

  @override
  Future<void> cancelReminderNotification(int reminderId) async {
    cancelledReminderIds.add(reminderId);
    cancelledReminderIds.add(reminderId + NotificationService.earlyAlertIdOffset);
  }
}

void main() {
  // Setup sqflite ffi for desktop/VM test environment
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ReminderRepository repository;
  late RecordingNotificationService notificationService;

  setUp(() async {
    notificationService = RecordingNotificationService();
    NotificationService.instance = notificationService;

    // Open an in-memory database for clean, isolated tests
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
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
              ${DatabaseHelper.colRemCreatedAt} TEXT NOT NULL,
              FOREIGN KEY (${DatabaseHelper.colRemCategoryId}) REFERENCES ${DatabaseHelper.tableCategories} (${DatabaseHelper.colCatId}) ON DELETE SET NULL
            );
          ''');

          await db.execute('''
            CREATE TABLE ${DatabaseHelper.tableSubtasks} (
              ${DatabaseHelper.colSubId} INTEGER PRIMARY KEY AUTOINCREMENT,
              ${DatabaseHelper.colSubReminderId} INTEGER NOT NULL,
              ${DatabaseHelper.colSubTitle} TEXT NOT NULL,
              ${DatabaseHelper.colSubIsDone} INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (${DatabaseHelper.colSubReminderId}) REFERENCES ${DatabaseHelper.tableReminders} (${DatabaseHelper.colRemId}) ON DELETE CASCADE
            );
          ''');

          // Seed default categories
          final batch = db.batch();
          final defaultCategories = [
            {'name': 'Personal', 'color_hex': '#2196F3', 'icon_code': 0xe491},
            {'name': 'Work', 'color_hex': '#FF9800', 'icon_code': 0xe6f2},
            {'name': 'Shopping', 'color_hex': '#4CAF50', 'icon_code': 0xe59c},
            {'name': 'Urgent', 'color_hex': '#F44336', 'icon_code': 0xe002},
          ];
          for (final c in defaultCategories) {
            batch.insert(DatabaseHelper.tableCategories, c);
          }
          await batch.commit(noResult: true);
        },
      ),
    );

    DatabaseHelper.instance.setDatabaseForTesting(db);
    repository = ReminderRepository(
      dbHelper: DatabaseHelper.instance,
      notificationService: notificationService,
    );
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.instance.setDatabaseForTesting(null);
  });

  test('Database helper seeds default categories correctly', () async {
    final List<CategoryModel> categories = await repository.getAllCategories();
    expect(categories.length, 4);
    expect(categories.map((c) => c.name), containsAll(['Personal', 'Work', 'Shopping', 'Urgent']));
  });

  test('Insert reminder with subtasks and verify full retrieval & notification scheduling', () async {
    final categories = await repository.getAllCategories();
    final workCategory = categories.firstWhere((c) => c.name == 'Work');

    final reminder = Reminder(
      title: 'Review Sprint Deliverables',
      notes: 'Prepare notes for 10am sync',
      categoryId: workCategory.id,
      dueDatetime: DateTime.parse('2026-11-14T10:00:00.000'),
      earlyAlertMinutes: 15,
      repeatRule: ReminderRepeatRule.daily,
      alertSeverity: ReminderAlertSeverity.strongFullscreen,
      isPinned: true,
      createdAt: DateTime.now(),
      subtasks: const [
        Subtask(title: 'Check database migrations'),
        Subtask(title: 'Validate notification permissions'),
      ],
    );

    final inserted = await repository.insertReminder(reminder);
    expect(inserted.id, isNotNull);
    expect(inserted.subtasks.length, 2);
    expect(inserted.subtasks.first.id, isNotNull);
    expect(inserted.subtasks.first.reminderId, inserted.id);

    // Verify NotificationService scheduled the alarm automatically
    expect(notificationService.scheduledReminders.length, 1);
    expect(notificationService.scheduledReminders.first.id, inserted.id);
    expect(notificationService.scheduledReminders.first.alertSeverity, 'strong_fullscreen');

    // Fetch by ID
    final fetched = await repository.getReminderById(inserted.id!);
    expect(fetched, isNotNull);
    expect(fetched!.title, 'Review Sprint Deliverables');
    expect(fetched.category?.name, 'Work');
    expect(fetched.isPinned, isTrue);
    expect(fetched.alertSeverity, 'strong_fullscreen');
    expect(fetched.subtasks.length, 2);
    expect(fetched.subtasks[0].title, 'Check database migrations');
  });

  test('Cascade delete removes subtasks and cancels scheduled alarm', () async {
    final reminder = Reminder(
      title: 'Task with subtasks to delete',
      dueDatetime: DateTime.parse('2026-11-14T12:00:00.000'),
      createdAt: DateTime.now(),
      subtasks: const [
        Subtask(title: 'Subtask 1'),
        Subtask(title: 'Subtask 2'),
      ],
    );

    final inserted = await repository.insertReminder(reminder);
    expect(inserted.id, isNotNull);
    expect(notificationService.scheduledReminders.length, 1);

    // Verify subtasks exist
    var subtasks = await repository.getSubtasksForReminder(inserted.id!);
    expect(subtasks.length, 2);

    // Delete parent reminder
    final deletedCount = await repository.deleteReminder(inserted.id!);
    expect(deletedCount, 1);

    // Verify reminder is gone
    final fetched = await repository.getReminderById(inserted.id!);
    expect(fetched, isNull);

    // Verify subtasks were cascaded and deleted
    subtasks = await repository.getSubtasksForReminder(inserted.id!);
    expect(subtasks, isEmpty);

    // Verify notification was cancelled
    expect(notificationService.cancelledReminderIds, contains(inserted.id));
  });

  test('Toggle reminder completion cancels alarm; un-completing reschedules alarm', () async {
    final reminder = Reminder(
      title: 'Test status toggles',
      dueDatetime: DateTime.parse('2026-11-14T14:00:00.000'),
      createdAt: DateTime.now(),
      subtasks: const [
        Subtask(title: 'Subtask to toggle'),
      ],
    );

    final inserted = await repository.insertReminder(reminder);
    expect(inserted.isCompleted, isFalse);
    expect(notificationService.scheduledReminders.length, 1);

    // Toggle reminder to completed -> should cancel notification
    await repository.toggleReminderCompletion(inserted.id!, true);
    final updatedReminder = await repository.getReminderById(inserted.id!);
    expect(updatedReminder!.isCompleted, isTrue);
    expect(notificationService.cancelledReminderIds, contains(inserted.id));

    // Toggle back to active -> should reschedule notification
    final countBefore = notificationService.scheduledReminders.length;
    await repository.toggleReminderCompletion(inserted.id!, false);
    expect(notificationService.scheduledReminders.length, countBefore + 1);

    // Toggle subtask
    final subtaskId = inserted.subtasks.first.id!;
    await repository.toggleSubtaskCompletion(subtaskId, true);
    final updatedSubtasks = await repository.getSubtasksForReminder(inserted.id!);
    expect(updatedSubtasks.first.isDone, isTrue);
  });

  test('Filter reminders by category and pinned status', () async {
    final categories = await repository.getAllCategories();
    final personalCat = categories.firstWhere((c) => c.name == 'Personal');
    final shoppingCat = categories.firstWhere((c) => c.name == 'Shopping');

    await repository.insertReminder(
      Reminder(
        title: 'Personal Pinned Task',
        categoryId: personalCat.id,
        isPinned: true,
        createdAt: DateTime.now(),
      ),
    );

    await repository.insertReminder(
      Reminder(
        title: 'Shopping Unpinned Task',
        categoryId: shoppingCat.id,
        isPinned: false,
        createdAt: DateTime.now(),
      ),
    );

    // Filter by category
    final personalReminders = await repository.getRemindersByCategory(personalCat.id!);
    expect(personalReminders.length, 1);
    expect(personalReminders.first.title, 'Personal Pinned Task');

    // Filter by pinned
    final pinnedReminders = await repository.getPinnedReminders();
    expect(pinnedReminders.length, 1);
    expect(pinnedReminders.first.title, 'Personal Pinned Task');
  });
}
