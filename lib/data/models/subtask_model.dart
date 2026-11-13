class Subtask {
  final int? id;
  final int? reminderId;
  final String title;
  final bool isDone;

  const Subtask({
    this.id,
    this.reminderId,
    required this.title,
    this.isDone = false,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'reminder_id': reminderId,
      'title': title,
      'is_done': isDone ? 1 : 0,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'] as int?,
      reminderId: map['reminder_id'] as int?,
      title: map['title'] as String,
      isDone: (map['is_done'] as int? ?? 0) == 1,
    );
  }

  Subtask copyWith({
    int? id,
    int? reminderId,
    String? title,
    bool? isDone,
  }) {
    return Subtask(
      id: id ?? this.id,
      reminderId: reminderId ?? this.reminderId,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subtask &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          reminderId == other.reminderId &&
          title == other.title &&
          isDone == other.isDone;

  @override
  int get hashCode =>
      id.hashCode ^ reminderId.hashCode ^ title.hashCode ^ isDone.hashCode;

  @override
  String toString() =>
      'Subtask(id: $id, reminderId: $reminderId, title: $title, isDone: $isDone)';
}
