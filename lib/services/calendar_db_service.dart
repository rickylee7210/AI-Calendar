import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/calendar_item.dart';
import 'interfaces.dart';

class CalendarDbService implements ICalendarDb {
  Database? _db;

  @override
  Future<void> init({bool inMemory = false}) async {
    final path = inMemory
        ? inMemoryDatabasePath
        : p.join(await getDatabasesPath(), 'calendar.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE calendar_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            date_time TEXT,
            end_time TEXT,
            type TEXT NOT NULL,
            reminder_minutes INTEGER DEFAULT 15,
            is_completed INTEGER DEFAULT 0,
            is_all_day INTEGER DEFAULT 0,
            note TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE calendar_items ADD COLUMN end_time TEXT');
          await db.execute('ALTER TABLE calendar_items ADD COLUMN is_all_day INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE calendar_items ADD COLUMN note TEXT');
        }
      },
    );
  }

  @override
  Future<int> insert(CalendarItem item) async {
    return await _db!.insert('calendar_items', item.toMap());
  }

  @override
  Future<List<CalendarItem>> getAll() async {
    final maps = await _db!.query('calendar_items', orderBy: 'date_time ASC');
    return maps.map((m) => CalendarItem.fromDbMap(m)).toList();
  }

  @override
  Future<List<CalendarItem>> getByDate(DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final maps = await _db!.query(
      'calendar_items',
      where: "date_time LIKE ?",
      whereArgs: ['$dateStr%'],
      orderBy: 'date_time ASC',
    );
    return maps.map((m) => CalendarItem.fromDbMap(m)).toList();
  }

  @override
  Future<void> update(CalendarItem item) async {
    await _db!.update('calendar_items', item.toMap(),
      where: 'id = ?', whereArgs: [item.id]);
  }

  @override
  Future<void> delete(int id) async {
    await _db!.delete('calendar_items', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> toggleComplete(int id) async {
    await _db!.rawUpdate(
      'UPDATE calendar_items SET is_completed = CASE WHEN is_completed = 0 THEN 1 ELSE 0 END, updated_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }

  @override
  Future<void> close() async => await _db?.close();
}
