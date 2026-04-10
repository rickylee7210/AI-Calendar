import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/models/calendar_item.dart';

void main() {
  group('CalendarItem', () {
    test('should create from NLU result map', () {
      final item = CalendarItem.fromNluResult({
        'title': '产品评审会',
        'date': '2026-04-02',
        'time': '15:00',
        'type': 'schedule',
        'reminder': 15,
      });
      expect(item.title, '产品评审会');
      expect(item.type, ItemType.schedule);
      expect(item.reminderMinutes, 15);
      expect(item.dateTime, DateTime(2026, 4, 2, 15, 0));
    });

    test('should serialize to map for database', () {
      final item = CalendarItem(
        title: '交周报',
        dateTime: DateTime(2026, 4, 4, 17, 0),
        type: ItemType.reminder,
        reminderMinutes: 0,
      );
      final map = item.toMap();
      expect(map['title'], '交周报');
      expect(map['type'], 'reminder');
      expect(map['is_completed'], 0);
    });

    test('should deserialize from database map', () {
      final item = CalendarItem.fromDbMap({
        'id': 1,
        'title': '开会',
        'date_time': '2026-04-02T15:00:00.000',
        'type': 'schedule',
        'reminder_minutes': 15,
        'is_completed': 0,
        'created_at': '2026-04-01T10:00:00.000',
        'updated_at': '2026-04-01T10:00:00.000',
      });
      expect(item.id, 1);
      expect(item.title, '开会');
      expect(item.type, ItemType.schedule);
      expect(item.isCompleted, false);
    });

    test('should handle missing fields with defaults', () {
      final item = CalendarItem.fromNluResult({'title': '体检'});
      expect(item.title, '体检');
      expect(item.type, ItemType.todo);
      expect(item.dateTime, isNull);
    });

    test('should support copyWith', () {
      final item = CalendarItem(title: '测试', type: ItemType.todo);
      final updated = item.copyWith(isCompleted: true);
      expect(updated.isCompleted, true);
      expect(updated.title, '测试');
    });

    test('should support endTime, isAllDay, note', () {
      final item = CalendarItem(
        title: '开会',
        dateTime: DateTime(2026, 4, 2, 15, 0),
        endTime: DateTime(2026, 4, 2, 16, 0),
        type: ItemType.schedule,
        isAllDay: false,
        note: '带笔记本',
      );
      expect(item.endTime, DateTime(2026, 4, 2, 16, 0));
      expect(item.isAllDay, false);
      expect(item.note, '带笔记本');
    });

    test('toMap includes new fields', () {
      final item = CalendarItem(
        title: '测试',
        type: ItemType.schedule,
        endTime: DateTime(2026, 4, 2, 16, 0),
        isAllDay: true,
        note: '备注',
      );
      final map = item.toMap();
      expect(map['end_time'], isNotNull);
      expect(map['is_all_day'], 1);
      expect(map['note'], '备注');
    });

    test('fromDbMap reads new fields', () {
      final item = CalendarItem.fromDbMap({
        'id': 1,
        'title': '开会',
        'date_time': '2026-04-02T15:00:00.000',
        'end_time': '2026-04-02T16:00:00.000',
        'type': 'schedule',
        'reminder_minutes': 15,
        'is_completed': 0,
        'is_all_day': 1,
        'note': '带电脑',
        'created_at': '2026-04-01T10:00:00.000',
        'updated_at': '2026-04-01T10:00:00.000',
      });
      expect(item.endTime, DateTime(2026, 4, 2, 16, 0));
      expect(item.isAllDay, true);
      expect(item.note, '带电脑');
    });
  });
}
