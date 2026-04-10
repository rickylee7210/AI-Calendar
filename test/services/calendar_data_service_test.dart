import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/services/calendar_data_service.dart';

void main() {
  late CalendarDataService svc;
  setUp(() => svc = CalendarDataService());

  group('CalendarDataService', () {
    test('getMonthGrid returns 42 cells (7x6)', () {
      final grid = svc.getMonthGrid(2026, 10);
      expect(grid.length, 42);
    });

    test('October 2026 starts on Thursday (first row has padding)', () {
      final grid = svc.getMonthGrid(2026, 10);
      // Oct 1 2026 is Thursday → index 3 (Mon=0)
      expect(grid[3].day, 1);
      expect(grid[3].isCurrentMonth, true);
      // Padding days before Oct 1 are from September
      expect(grid[0].isCurrentMonth, false);
      expect(grid[0].day, 28); // Sep 28
    });

    test('last day of October is 31', () {
      final grid = svc.getMonthGrid(2026, 10);
      final octDays = grid.where((d) => d.isCurrentMonth).toList();
      expect(octDays.length, 31);
      expect(octDays.last.day, 31);
    });

    test('each cell has lunar text', () {
      final grid = svc.getMonthGrid(2026, 10);
      final oct1 = grid.firstWhere((d) => d.isCurrentMonth && d.day == 1);
      expect(oct1.lunarText, isNotEmpty);
    });

    test('selected date is marked', () {
      final grid = svc.getMonthGrid(2026, 10, selectedDay: 16);
      final oct16 = grid.firstWhere((d) => d.isCurrentMonth && d.day == 16);
      expect(oct16.isSelected, true);
    });

    test('today is marked', () {
      final now = DateTime.now();
      final grid = svc.getMonthGrid(now.year, now.month);
      final today = grid.where((d) => d.isToday);
      expect(today.length, 1);
    });

    test('February 2024 leap year has 29 days', () {
      final grid = svc.getMonthGrid(2024, 2);
      final febDays = grid.where((d) => d.isCurrentMonth).toList();
      expect(febDays.length, 29);
    });

    test('getWeekForDate returns 7 days containing the date', () {
      final week = svc.getWeekForDate(DateTime(2026, 10, 16));
      expect(week.length, 7);
      // Oct 16 2026 is Friday → week Mon-Sun = Oct 12-18
      expect(week.first.day, 12);
      expect(week.last.day, 18);
    });
  });
}
