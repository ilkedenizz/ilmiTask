import 'category_model.dart';
import 'subtask_model.dart';

class ReminderRepeatRule {
  static const String none = 'none';
  static const String daily = 'daily';
  static const String weekdays = 'weekdays';
  static const String weekly = 'weekly';
  static const String monthly = 'monthly';

  static const List<String> all = [none, daily, weekdays, weekly, monthly];
}

class ReminderAlertSeverity {
  static const String light = 'light';
  static const String short = 'short';
  static const String strongFullscreen = 'strong_fullscreen';

  static const List<String> all = [light, short, strongFullscreen];
}

class LocationTriggerType {
  static const String arrive = 'arrive';
  static const String leave = 'leave';

  static const List<String> all = [arrive, leave];
}

class Reminder {
  final int? id;
  final String title;
  final String? notes;
  final int? categoryId;
  final DateTime? dueDatetime;
  final int earlyAlertMinutes;
  final String repeatRule;
  final String alertSeverity;
  final double? locationLat;
  final double? locationLng;
  final double? locationRadius;
  final String? locationTriggerType;
  final String? imagePath;
  final bool isPinned;
  final bool isCompleted;
  final DateTime createdAt;

  // Joined/associated entities
  final List<Subtask> subtasks;
  final CategoryModel? category;

  const Reminder({
    this.id,
    required this.title,
    this.notes,
    this.categoryId,
    this.dueDatetime,
    this.earlyAlertMinutes = 0,
    this.repeatRule = ReminderRepeatRule.none,
    this.alertSeverity = ReminderAlertSeverity.short,
    this.locationLat,
    this.locationLng,
    this.locationRadius,
    this.locationTriggerType,
    this.imagePath,
    this.isPinned = false,
    this.isCompleted = false,
    required this.createdAt,
    this.subtasks = const [],
    this.category,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'notes': notes,
      'category_id': categoryId,
      'due_datetime': dueDatetime?.toIso8601String(),
      'early_alert_minutes': earlyAlertMinutes,
      'repeat_rule': repeatRule,
      'alert_severity': alertSeverity,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'location_radius': locationRadius,
      'location_trigger_type': locationTriggerType,
      'image_path': imagePath,
      'is_pinned': isPinned ? 1 : 0,
      'is_completed': isCompleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Reminder.fromMap(
    Map<String, dynamic> map, {
    List<Subtask>? subtasks,
    CategoryModel? category,
  }) {
    final dueRaw = map['due_datetime'] as String?;
    final createdRaw = map['created_at'] as String?;

    return Reminder(
      id: map['id'] as int?,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      categoryId: map['category_id'] as int?,
      dueDatetime: dueRaw != null ? DateTime.tryParse(dueRaw) : null,
      earlyAlertMinutes: (map['early_alert_minutes'] as int?) ?? 0,
      repeatRule: (map['repeat_rule'] as String?) ?? ReminderRepeatRule.none,
      alertSeverity:
          (map['alert_severity'] as String?) ?? ReminderAlertSeverity.short,
      locationLat: (map['location_lat'] as num?)?.toDouble(),
      locationLng: (map['location_lng'] as num?)?.toDouble(),
      locationRadius: (map['location_radius'] as num?)?.toDouble(),
      locationTriggerType: map['location_trigger_type'] as String?,
      imagePath: map['image_path'] as String?,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      createdAt: createdRaw != null
          ? (DateTime.tryParse(createdRaw) ?? DateTime.now())
          : DateTime.now(),
      subtasks: subtasks ?? const [],
      category: category,
    );
  }

  Reminder copyWith({
    int? id,
    String? title,
    String? notes,
    int? categoryId,
    DateTime? dueDatetime,
    int? earlyAlertMinutes,
    String? repeatRule,
    String? alertSeverity,
    double? locationLat,
    double? locationLng,
    double? locationRadius,
    String? locationTriggerType,
    String? imagePath,
    bool? isPinned,
    bool? isCompleted,
    DateTime? createdAt,
    List<Subtask>? subtasks,
    CategoryModel? category,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      categoryId: categoryId ?? this.categoryId,
      dueDatetime: dueDatetime ?? this.dueDatetime,
      earlyAlertMinutes: earlyAlertMinutes ?? this.earlyAlertMinutes,
      repeatRule: repeatRule ?? this.repeatRule,
      alertSeverity: alertSeverity ?? this.alertSeverity,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      locationRadius: locationRadius ?? this.locationRadius,
      locationTriggerType: locationTriggerType ?? this.locationTriggerType,
      imagePath: imagePath ?? this.imagePath,
      isPinned: isPinned ?? this.isPinned,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      subtasks: subtasks ?? this.subtasks,
      category: category ?? this.category,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reminder &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          notes == other.notes &&
          categoryId == other.categoryId &&
          dueDatetime == other.dueDatetime &&
          earlyAlertMinutes == other.earlyAlertMinutes &&
          repeatRule == other.repeatRule &&
          alertSeverity == other.alertSeverity &&
          locationLat == other.locationLat &&
          locationLng == other.locationLng &&
          locationRadius == other.locationRadius &&
          locationTriggerType == other.locationTriggerType &&
          imagePath == other.imagePath &&
          isPinned == other.isPinned &&
          isCompleted == other.isCompleted &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      notes.hashCode ^
      categoryId.hashCode ^
      dueDatetime.hashCode ^
      earlyAlertMinutes.hashCode ^
      repeatRule.hashCode ^
      alertSeverity.hashCode ^
      locationLat.hashCode ^
      locationLng.hashCode ^
      locationRadius.hashCode ^
      locationTriggerType.hashCode ^
      imagePath.hashCode ^
      isPinned.hashCode ^
      isCompleted.hashCode ^
      createdAt.hashCode;

  @override
  String toString() =>
      'Reminder(id: $id, title: $title, categoryId: $categoryId, dueDatetime: $dueDatetime, isPinned: $isPinned, isCompleted: $isCompleted, subtasks: ${subtasks.length})';
}
