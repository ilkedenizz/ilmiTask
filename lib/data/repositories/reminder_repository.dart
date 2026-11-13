import 'package:sqflite/sqflite.dart';
import '../../services/notification_service.dart';
import '../database_helper.dart';
import '../models/category_model.dart';
import '../models/reminder_model.dart';
import '../models/subtask_model.dart';

class ReminderRepository {
  final DatabaseHelper _dbHelper;
  final NotificationService _notificationService;

  ReminderRepository({
    DatabaseHelper? dbHelper,
    NotificationService? notificationService,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _notificationService =
            notificationService ?? NotificationService.instance;

  Future<Database> get _db async => await _dbHelper.database;

  // ==========================================
  // REMINDER CRUD OPERATIONS
  // ==========================================

  /// Inserts a new reminder along with any initial subtasks inside a transaction.
  Future<Reminder> insertReminder(Reminder reminder) async {
    final db = await _db;
    final inserted = await db.transaction<Reminder>((txn) async {
      final reminderMap = reminder.toMap();
      final reminderId = await txn.insert(
        DatabaseHelper.tableReminders,
        reminderMap,
      );

      final insertedSubtasks = <Subtask>[];
      for (final subtask in reminder.subtasks) {
        final subtaskMap = subtask.copyWith(reminderId: reminderId).toMap();
        final subtaskId = await txn.insert(
          DatabaseHelper.tableSubtasks,
          subtaskMap,
        );
        insertedSubtasks.add(
          subtask.copyWith(id: subtaskId, reminderId: reminderId),
        );
      }

      return reminder.copyWith(
        id: reminderId,
        subtasks: insertedSubtasks,
      );
    });

    // Sync notification engine
    await _notificationService.scheduleReminderNotification(inserted);
    return inserted;
  }

  /// Updates an existing reminder and optionally synchronizes its subtasks.
  Future<int> updateReminder(Reminder reminder, {bool syncSubtasks = false}) async {
    final db = await _db;
    if (reminder.id == null) {
      throw ArgumentError('Cannot update a reminder without an ID.');
    }

    int count;
    if (!syncSubtasks) {
      count = await db.update(
        DatabaseHelper.tableReminders,
        reminder.toMap(),
        where: '${DatabaseHelper.colRemId} = ?',
        whereArgs: [reminder.id],
      );
    } else {
      count = await db.transaction<int>((txn) async {
        final c = await txn.update(
          DatabaseHelper.tableReminders,
          reminder.toMap(),
          where: '${DatabaseHelper.colRemId} = ?',
          whereArgs: [reminder.id],
        );

        // Re-sync subtasks: remove existing and re-insert current
        await txn.delete(
          DatabaseHelper.tableSubtasks,
          where: '${DatabaseHelper.colSubReminderId} = ?',
          whereArgs: [reminder.id],
        );

        for (final subtask in reminder.subtasks) {
          final subtaskMap = subtask.copyWith(reminderId: reminder.id).toMap();
          await txn.insert(DatabaseHelper.tableSubtasks, subtaskMap);
        }

        return c;
      });
    }

    // Sync notification engine
    if (reminder.isCompleted) {
      await _notificationService.cancelReminderNotification(reminder.id!);
    } else {
      await _notificationService.scheduleReminderNotification(reminder);
    }

    return count;
  }

  /// Deletes a reminder by ID. Associated subtasks are automatically removed via ON DELETE CASCADE.
  Future<int> deleteReminder(int id) async {
    final db = await _db;
    final count = await db.delete(
      DatabaseHelper.tableReminders,
      where: '${DatabaseHelper.colRemId} = ?',
      whereArgs: [id],
    );

    // Cancel pending alarms for this reminder
    await _notificationService.cancelReminderNotification(id);
    return count;
  }

  /// Fetches a single reminder by ID with its subtasks and category populated.
  Future<Reminder?> getReminderById(int id) async {
    final db = await _db;
    final results = await db.query(
      DatabaseHelper.tableReminders,
      where: '${DatabaseHelper.colRemId} = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final subtasks = await getSubtasksForReminder(id);
    CategoryModel? category;
    final categoryId = results.first[DatabaseHelper.colRemCategoryId] as int?;
    if (categoryId != null) {
      category = await getCategoryById(categoryId);
    }

    return Reminder.fromMap(
      results.first,
      subtasks: subtasks,
      category: category,
    );
  }

  // ==========================================
  // QUERY & FILTER OPERATIONS
  // ==========================================

  /// Retrieves all reminders with optional completion filtering and hydrated subtasks/categories.
  Future<List<Reminder>> getAllReminders({
    bool? isCompleted,
    bool includeSubtasks = true,
  }) async {
    String? whereClause;
    List<dynamic>? whereArgs;

    if (isCompleted != null) {
      whereClause = '${DatabaseHelper.colRemIsCompleted} = ?';
      whereArgs = [isCompleted ? 1 : 0];
    }

    return await _queryReminders(
      where: whereClause,
      whereArgs: whereArgs,
      orderBy:
          '${DatabaseHelper.colRemIsPinned} DESC, ${DatabaseHelper.colRemDueDatetime} ASC, ${DatabaseHelper.colRemCreatedAt} DESC',
      includeSubtasks: includeSubtasks,
    );
  }

  /// Retrieves reminders filtered by category ID.
  Future<List<Reminder>> getRemindersByCategory(
    int categoryId, {
    bool? isCompleted,
    bool includeSubtasks = true,
  }) async {
    final where = isCompleted != null
        ? '${DatabaseHelper.colRemCategoryId} = ? AND ${DatabaseHelper.colRemIsCompleted} = ?'
        : '${DatabaseHelper.colRemCategoryId} = ?';
    final whereArgs = isCompleted != null ? [categoryId, isCompleted ? 1 : 0] : [categoryId];

    return await _queryReminders(
      where: where,
      whereArgs: whereArgs,
      orderBy:
          '${DatabaseHelper.colRemIsPinned} DESC, ${DatabaseHelper.colRemDueDatetime} ASC',
      includeSubtasks: includeSubtasks,
    );
  }

  /// Retrieves pinned reminders.
  Future<List<Reminder>> getPinnedReminders({
    bool? isCompleted,
    bool includeSubtasks = true,
  }) async {
    final where = isCompleted != null
        ? '${DatabaseHelper.colRemIsPinned} = 1 AND ${DatabaseHelper.colRemIsCompleted} = ?'
        : '${DatabaseHelper.colRemIsPinned} = 1';
    final whereArgs = isCompleted != null ? [isCompleted ? 1 : 0] : null;

    return await _queryReminders(
      where: where,
      whereArgs: whereArgs,
      orderBy:
          '${DatabaseHelper.colRemDueDatetime} ASC, ${DatabaseHelper.colRemCreatedAt} DESC',
      includeSubtasks: includeSubtasks,
    );
  }

  /// Retrieves upcoming reminders with due dates.
  Future<List<Reminder>> getUpcomingReminders({
    DateTime? before,
    bool includeSubtasks = true,
  }) async {
    String where = '${DatabaseHelper.colRemIsCompleted} = 0 AND ${DatabaseHelper.colRemDueDatetime} IS NOT NULL';
    List<dynamic>? whereArgs;

    if (before != null) {
      where += ' AND ${DatabaseHelper.colRemDueDatetime} <= ?';
      whereArgs = [before.toIso8601String()];
    }

    return await _queryReminders(
      where: where,
      whereArgs: whereArgs,
      orderBy: '${DatabaseHelper.colRemDueDatetime} ASC',
      includeSubtasks: includeSubtasks,
    );
  }

  // ==========================================
  // STATUS TOGGLES
  // ==========================================

  /// Toggles reminder completed state and synchronizes scheduled alarms.
  Future<int> toggleReminderCompletion(int id, bool isCompleted) async {
    final db = await _db;
    final count = await db.update(
      DatabaseHelper.tableReminders,
      {DatabaseHelper.colRemIsCompleted: isCompleted ? 1 : 0},
      where: '${DatabaseHelper.colRemId} = ?',
      whereArgs: [id],
    );

    if (isCompleted) {
      await _notificationService.cancelReminderNotification(id);
    } else {
      final updated = await getReminderById(id);
      if (updated != null) {
        await _notificationService.scheduleReminderNotification(updated);
      }
    }

    return count;
  }

  /// Toggles reminder pinned state.
  Future<int> toggleReminderPinned(int id, bool isPinned) async {
    final db = await _db;
    return await db.update(
      DatabaseHelper.tableReminders,
      {DatabaseHelper.colRemIsPinned: isPinned ? 1 : 0},
      where: '${DatabaseHelper.colRemId} = ?',
      whereArgs: [id],
    );
  }

  /// Toggles subtask completed state.
  Future<int> toggleSubtaskCompletion(int subtaskId, bool isDone) async {
    final db = await _db;
    return await db.update(
      DatabaseHelper.tableSubtasks,
      {DatabaseHelper.colSubIsDone: isDone ? 1 : 0},
      where: '${DatabaseHelper.colSubId} = ?',
      whereArgs: [subtaskId],
    );
  }

  // ==========================================
  // SUBTASK CRUD
  // ==========================================

  /// Inserts a new subtask.
  Future<Subtask> insertSubtask(Subtask subtask) async {
    final db = await _db;
    final id = await db.insert(
      DatabaseHelper.tableSubtasks,
      subtask.toMap(),
    );
    return subtask.copyWith(id: id);
  }

  /// Updates a subtask.
  Future<int> updateSubtask(Subtask subtask) async {
    final db = await _db;
    if (subtask.id == null) {
      throw ArgumentError('Cannot update a subtask without an ID.');
    }
    return await db.update(
      DatabaseHelper.tableSubtasks,
      subtask.toMap(),
      where: '${DatabaseHelper.colSubId} = ?',
      whereArgs: [subtask.id],
    );
  }

  /// Deletes a subtask by ID.
  Future<int> deleteSubtask(int subtaskId) async {
    final db = await _db;
    return await db.delete(
      DatabaseHelper.tableSubtasks,
      where: '${DatabaseHelper.colSubId} = ?',
      whereArgs: [subtaskId],
    );
  }

  /// Fetches all subtasks for a specific reminder.
  Future<List<Subtask>> getSubtasksForReminder(int reminderId) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseHelper.tableSubtasks,
      where: '${DatabaseHelper.colSubReminderId} = ?',
      whereArgs: [reminderId],
      orderBy: '${DatabaseHelper.colSubId} ASC',
    );
    return maps.map((m) => Subtask.fromMap(m)).toList();
  }

  // ==========================================
  // CATEGORY OPERATIONS
  // ==========================================

  /// Gets all categories.
  Future<List<CategoryModel>> getAllCategories() async {
    final db = await _db;
    final maps = await db.query(
      DatabaseHelper.tableCategories,
      orderBy: '${DatabaseHelper.colCatId} ASC',
    );
    return maps.map((m) => CategoryModel.fromMap(m)).toList();
  }

  /// Gets a single category by ID.
  Future<CategoryModel?> getCategoryById(int id) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseHelper.tableCategories,
      where: '${DatabaseHelper.colCatId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CategoryModel.fromMap(maps.first);
  }

  /// Inserts a new category.
  Future<CategoryModel> insertCategory(CategoryModel category) async {
    final db = await _db;
    final id = await db.insert(
      DatabaseHelper.tableCategories,
      category.toMap(),
    );
    return category.copyWith(id: id);
  }

  /// Updates an existing category.
  Future<int> updateCategory(CategoryModel category) async {
    final db = await _db;
    if (category.id == null) {
      throw ArgumentError('Cannot update a category without an ID.');
    }
    return await db.update(
      DatabaseHelper.tableCategories,
      category.toMap(),
      where: '${DatabaseHelper.colCatId} = ?',
      whereArgs: [category.id],
    );
  }

  /// Deletes a category. Associated reminders will have category_id set to NULL.
  Future<int> deleteCategory(int id) async {
    final db = await _db;
    return await db.delete(
      DatabaseHelper.tableCategories,
      where: '${DatabaseHelper.colCatId} = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // PRIVATE QUERY HELPER (BATCH-JOIN OPTIMIZED)
  // ==========================================

  Future<List<Reminder>> _queryReminders({
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    bool includeSubtasks = true,
  }) async {
    final db = await _db;
    final reminderMaps = await db.query(
      DatabaseHelper.tableReminders,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );

    if (reminderMaps.isEmpty) return [];

    // Pre-load all categories into a lookup map to avoid N queries
    final categories = await getAllCategories();
    final categoryMap = {for (final cat in categories) cat.id!: cat};

    // If subtasks are requested, batch fetch all subtasks for these reminder IDs
    final subtasksByReminderId = <int, List<Subtask>>{};
    if (includeSubtasks) {
      final reminderIds = reminderMaps
          .map((m) => m[DatabaseHelper.colRemId] as int)
          .toList();

      if (reminderIds.isNotEmpty) {
        final placeholders = List.filled(reminderIds.length, '?').join(',');
        final subtaskMaps = await db.query(
          DatabaseHelper.tableSubtasks,
          where: '${DatabaseHelper.colSubReminderId} IN ($placeholders)',
          whereArgs: reminderIds,
          orderBy: '${DatabaseHelper.colSubId} ASC',
        );

        for (final sMap in subtaskMaps) {
          final subtask = Subtask.fromMap(sMap);
          if (subtask.reminderId != null) {
            subtasksByReminderId
                .putIfAbsent(subtask.reminderId!, () => [])
                .add(subtask);
          }
        }
      }
    }

    return reminderMaps.map((map) {
      final remId = map[DatabaseHelper.colRemId] as int;
      final catId = map[DatabaseHelper.colRemCategoryId] as int?;
      return Reminder.fromMap(
        map,
        subtasks: subtasksByReminderId[remId] ?? const [],
        category: catId != null ? categoryMap[catId] : null,
      );
    }).toList();
  }
}
