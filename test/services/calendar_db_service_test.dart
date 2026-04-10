import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_calendar/models/calendar_item.dart';
import 'package:ai_calendar/services/calendar_db_service.dart';

void main() {
  late CalendarDbService db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = CalendarDbService();
    await db.init(inMemory: true);
  });

  tearDown(() async {
    await db.close();
  });

  group('CalendarDbService', () {
    test('insert and retrieve item', () async {
      final item = CalendarItem(
        title: '产品评审会',
        dateTime: DateTime(2026, 4, 2, 15, 0),
        type: ItemType.schedule,
        reminderMinutes: 15,
      );
      final id = await db.insert(item);
      expect(id, greaterThan(0));

      final items = await db.getAll();
      expect(items.length, 1);
      expect(items.first.title, '产品评审会');
      expect(items.first.id, id);
    });

    test('getByDate returns only matching date', () async {
      await db.insert(CalendarItem(
        title: '事项A',
        dateTime: DateTime(2026, 4, 2, 10, 0),
        type: ItemType.todo,
      ));
      await db.insert(CalendarItem(
        title: '事项B',
        dateTime: DateTime(2026, 4, 3, 10, 0),
        type: ItemType.todo,
      ));

      final items = await db.getByDate(DateTime(2026, 4, 2));
      expect(items.length, 1);
      expect(items.first.title, '事项A');
    });

    test('toggleComplete flips status', () async {
      final id = await db.insert(CalendarItem(
        title: '测试',
        type: ItemType.todo,
      ));

      await db.toggleComplete(id);
      var items = await db.getAll();
      expect(items.first.isCompleted, true);

      await db.toggleComplete(id);
      items = await db.getAll();
      expect(items.first.isCompleted, false);
    });

    test('delete removes item', () async {
      final id = await db.insert(CalendarItem(
        title: '删除测试',
        type: ItemType.todo,
      ));
      await db.delete(id);
      final items = await db.getAll();
      expect(items, isEmpty);
    });

    test('update modifies item', () async {
      final id = await db.insert(CalendarItem(
        title: '原标题',
        type: ItemType.todo,
      ));
      final items = await db.getAll();
      final updated = items.first.copyWith(title: '新标题');
      await db.update(updated);

      final result = await db.getAll();
      expect(result.first.title, '新标题');
    });
  });
}
