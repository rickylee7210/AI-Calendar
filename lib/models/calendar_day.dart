class CalendarDay {
  final int day;
  final String lunarText;
  final bool isSelected;
  final bool isWeekend;
  final bool isToday;

  const CalendarDay({
    required this.day,
    required this.lunarText,
    this.isSelected = false,
    this.isWeekend = false,
    this.isToday = false,
  });
}
