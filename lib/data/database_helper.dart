import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String _databaseName = 'samsung_reminders.db';
  static const int _databaseVersion = 1;

  // Table Names
  static const String tableCategories = 'categories';
  static const String tableReminders = 'reminders';
  static const String tableSubtasks = 'subtasks';

  // Category Columns
  static const String colCatId = 'id';
  static const String colCatName = 'name';
  static const String colCatColorHex = 'color_hex';
  static const String colCatIconCode = 'icon_code';

  // Reminder Columns
  static const String colRemId = 'id';
  static const String colRemTitle = 'title';
  static const String colRemNotes = 'notes';
  static const String colRemCategoryId = 'category_id';
  static const String colRemDueDatetime = 'due_datetime';
  static const String colRemEarlyAlertMinutes = 'early_alert_minutes';
  static const String colRemRepeatRule = 'repeat_rule';
  static const String colRemAlertSeverity = 'alert_severity';
  static const String colRemLocationLat = 'location_lat';
  static const String colRemLocationLng = 'location_lng';
  static const String colRemLocationRadius = 'location_radius';
  static const String colRemLocationTriggerType = 'location_trigger_type';
  static const String colRemImagePath = 'image_path';
  static const String colRemIsPinned = 'is_pinned';
  static const String colRemIsCompleted = 'is_completed';
  static const String colRemCreatedAt = 'created_at';

  // Subtask Columns
  static const String colSubId = 'id';
  static const String colSubReminderId = 'reminder_id';
  static const String colSubTitle = 'title';
  static const String colSubIsDone = 'is_done';

  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;
  static Future<Database>? _initDbFuture;

  DatabaseHelper._internal();

  /// Setter for testing purposes (allows injecting mock/in-memory DB)
  void setDatabaseForTesting(Database? db) {
    _database = db;
    _initDbFuture = db != null ? Future.value(db) : null;
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _initDbFuture ??= _initDatabaseSafe();
    _database = await _initDbFuture!;
    return _database!;
  }

  Future<Database> _initDatabaseSafe() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, _databaseName);

      return await openDatabase(
        path,
        version: _databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
      );
    } catch (e, stack) {
      debugPrint('DatabaseHelper openDatabase error: $e\n$stack');
      _initDbFuture = null;
      try {
        final dbPath = await getDatabasesPath();
        final path = p.join(dbPath, _databaseName);
        await deleteDatabase(path);
        final freshDb = await openDatabase(
          path,
          version: _databaseVersion,
          onConfigure: _onConfigure,
          onCreate: _onCreate,
        );
        _database = freshDb;
        return freshDb;
      } catch (fallbackError) {
        debugPrint('DatabaseHelper recovery error: $fallbackError');
        rethrow;
      }
    }
  }

  Future<void> _onConfigure(Database db) async {
    // Enforce foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Categories Table
    await db.execute('''
      CREATE TABLE $tableCategories (
        $colCatId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colCatName TEXT NOT NULL,
        $colCatColorHex TEXT NOT NULL,
        $colCatIconCode INTEGER NOT NULL
      );
    ''');

    // 2. Reminders Table
    await db.execute('''
      CREATE TABLE $tableReminders (
        $colRemId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colRemTitle TEXT NOT NULL,
        $colRemNotes TEXT,
        $colRemCategoryId INTEGER,
        $colRemDueDatetime TEXT,
        $colRemEarlyAlertMinutes INTEGER NOT NULL DEFAULT 0,
        $colRemRepeatRule TEXT NOT NULL DEFAULT 'none',
        $colRemAlertSeverity TEXT NOT NULL DEFAULT 'short',
        $colRemLocationLat REAL,
        $colRemLocationLng REAL,
        $colRemLocationRadius REAL,
        $colRemLocationTriggerType TEXT,
        $colRemImagePath TEXT,
        $colRemIsPinned INTEGER NOT NULL DEFAULT 0,
        $colRemIsCompleted INTEGER NOT NULL DEFAULT 0,
        $colRemCreatedAt TEXT NOT NULL,
        FOREIGN KEY ($colRemCategoryId) REFERENCES $tableCategories ($colCatId) ON DELETE SET NULL
      );
    ''');

    // 3. Subtasks Table
    await db.execute('''
      CREATE TABLE $tableSubtasks (
        $colSubId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colSubReminderId INTEGER NOT NULL,
        $colSubTitle TEXT NOT NULL,
        $colSubIsDone INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY ($colSubReminderId) REFERENCES $tableReminders ($colRemId) ON DELETE CASCADE
      );
    ''');

    // Indexes for query performance
    await db.execute(
      'CREATE INDEX idx_reminders_cat ON $tableReminders ($colRemCategoryId);',
    );
    await db.execute(
      'CREATE INDEX idx_reminders_completed ON $tableReminders ($colRemIsCompleted);',
    );
    await db.execute(
      'CREATE INDEX idx_reminders_pinned ON $tableReminders ($colRemIsPinned);',
    );
    await db.execute(
      'CREATE INDEX idx_reminders_due ON $tableReminders ($colRemDueDatetime);',
    );
    await db.execute(
      'CREATE INDEX idx_subtasks_rem ON $tableSubtasks ($colSubReminderId);',
    );

    // Seed default categories
    await _seedDefaultCategories(db);
  }

  Future<void> _seedDefaultCategories(Database db) async {
    final batch = db.batch();

    final defaultCategories = [
      {'name': 'Personal', 'color_hex': '#2196F3', 'icon_code': 0xe491},
      {'name': 'Work', 'color_hex': '#FF9800', 'icon_code': 0xe6f2},
      {'name': 'Shopping', 'color_hex': '#4CAF50', 'icon_code': 0xe59c},
      {'name': 'Urgent', 'color_hex': '#F44336', 'icon_code': 0xe002},
    ];

    for (final category in defaultCategories) {
      batch.insert(tableCategories, category);
    }

    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
      _initDbFuture = null;
    }
  }
}
