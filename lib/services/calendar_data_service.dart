import 'package:lunar/lunar.dart';
import '../models/month_day.dart';
import '../models/calendar_day.dart';

class CalendarDataService {
  /// Generate a 42-cell (7x6) grid for the given year/month.
  /// Week starts on Monday.
  List<MonthDay> getMonthGrid(int year, int month, {int? selectedDay}) {
    final now = DateTime.now();
    final firstOfMonth = DateTime(year, month, 1);
    // Monday=1 in Dart, we want Monday=0
    final startWeekday = (firstOfMonth.weekday - 1) % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final cells = <MonthDay>[];

    // Previous month padding
    final prevMonth = DateTime(year, month, 0); // last day of prev month
    for (int i = startWeekday - 1; i >= 0; i--) {
      final d = DateTime(prevMonth.year, prevMonth.month, prevMonth.day - i);
      cells.add(_makeDay(d, isCurrentMonth: false, now: now));
    }

    // Current month
    for (int day = 1; day <= daysInMonth; day++) {
      final d = DateTime(year, month, day);
      cells.add(_makeDay(d,
        isCurrentMonth: true,
        now: now,
        isSelected: day == selectedDay,
      ));
    }

    // Next month padding to fill 42 cells
    int nextDay = 1;
    while (cells.length < 42) {
      final d = DateTime(year, month + 1, nextDay++);
      cells.add(_makeDay(d, isCurrentMonth: false, now: now));
    }

    return cells;
  }

  /// Get the week (Mon-Sun) containing the given date
  List<CalendarDay> getWeekForDate(DateTime date) {
    final weekday = (date.weekday - 1) % 7; // Mon=0
    final monday = date.subtract(Duration(days: weekday));

    return List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      final lunar = Lunar.fromDate(d);
      final lunarText = _getLunarDayText(lunar);
      return CalendarDay(
        day: d.day,
        lunarText: lunarText,
        isWeekend: d.weekday >= 6,
      );
    });
  }

  MonthDay _makeDay(DateTime d, {
    required bool isCurrentMonth,
    required DateTime now,
    bool isSelected = false,
  }) {
    final lunar = Lunar.fromDate(d);
    return MonthDay(
      day: d.day,
      date: d,
      lunarText: _getLunarDayText(lunar),
      isCurrentMonth: isCurrentMonth,
      isToday: d.year == now.year && d.month == now.month && d.day == now.day,
      isSelected: isSelected,
    );
  }

  String _getLunarDayText(Lunar lunar) {
    // Priority: festival > solar term > lunar day
    final festivals = lunar.getFestivals();
    if (festivals.isNotEmpty) return festivals.first;

    final jieQi = lunar.getJieQi();
    if (jieQi.isNotEmpty) return jieQi;

    // First day of lunar month shows month name
    if (lunar.getDay() == 1) {
      return '${lunar.getMonthInChinese()}月';
    }

    return lunar.getDayInChinese();
  }
}
