enum ItemType { schedule, todo, reminder }

class CalendarItem {
  final int? id;
  final String title;
  final DateTime? dateTime;
  final DateTime? endTime;
  final ItemType type;
  final int reminderMinutes;
  final bool isCompleted;
  final bool isAllDay;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CalendarItem({
    this.id,
    required this.title,
    this.dateTime,
    this.endTime,
    this.type = ItemType.todo,
    this.reminderMinutes = 15,
    this.isCompleted = false,
    this.isAllDay = false,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory CalendarItem.fromNluResult(Map<String, dynamic> data) {
    final typeStr = data['type'] as String?;
    final type = switch (typeStr) {
      'schedule' => ItemType.schedule,
      'reminder' => ItemType.reminder,
      _ => ItemType.todo,
    };
    DateTime? dt;
    if (data['date'] != null && data['time'] != null) {
      dt = DateTime.parse('${data['date']}T${data['time']}');
    } else if (data['date'] != null) {
      dt = DateTime.parse('${data['date']}T09:00');
    } else {
      // todo 没有日期，默认今天
      final now = DateTime.now();
      dt = DateTime(now.year, now.month, now.day);
    }
    return CalendarItem(
      title: data['title'] ?? '',
      dateTime: dt,
      type: type,
      reminderMinutes: data['reminder'] as int? ?? (type == ItemType.todo ? 0 : 15),
    );
  }

  factory CalendarItem.fromDbMap(Map<String, dynamic> m) {
    return CalendarItem(
      id: m['id'] as int?,
      title: m['title'] as String,
      dateTime: m['date_time'] != null ? DateTime.parse(m['date_time'] as String) : null,
      endTime: m['end_time'] != null ? DateTime.parse(m['end_time'] as String) : null,
      type: switch (m['type'] as String?) {
        'schedule' => ItemType.schedule,
        'reminder' => ItemType.reminder,
        _ => ItemType.todo,
      },
      reminderMinutes: m['reminder_minutes'] as int? ?? 15,
      isCompleted: (m['is_completed'] as int?) == 1,
      isAllDay: (m['is_all_day'] as int?) == 1,
      note: m['note'] as String?,
      createdAt: m['created_at'] != null ? DateTime.parse(m['created_at'] as String) : null,
      updatedAt: m['updated_at'] != null ? DateTime.parse(m['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      if (id != null) 'id': id,
      'title': title,
      'date_time': dateTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'type': type.name,
      'reminder_minutes': reminderMinutes,
      'is_completed': isCompleted ? 1 : 0,
      'is_all_day': isAllDay ? 1 : 0,
      'note': note,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    };
  }

  CalendarItem copyWith({
    int? id, String? title, DateTime? dateTime, DateTime? endTime,
    ItemType? type, int? reminderMinutes, bool? isCompleted,
    bool? isAllDay, String? note,
  }) {
    return CalendarItem(
      id: id ?? this.id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      isAllDay: isAllDay ?? this.isAllDay,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
