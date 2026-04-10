import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/models/calendar_day.dart';

void main() {
  group('CalendarDay', () {
    test('should store day number and lunar text', () {
      final day = CalendarDay(day: 16, lunarText: '初七', isSelected: true);
      expect(day.day, 16);
      expect(day.lunarText, '初七');
      expect(day.isSelected, true);
    });

    test('should default isSelected to false', () {
      final day = CalendarDay(day: 12, lunarText: '初三');
      expect(day.isSelected, false);
    });

    test('should support isWeekend flag', () {
      final day = CalendarDay(day: 17, lunarText: '初八', isWeekend: true);
      expect(day.isWeekend, true);
    });
  });
}
