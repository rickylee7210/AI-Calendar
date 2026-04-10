/// A single day cell in the month grid
class MonthDay {
  final int day;
  final String lunarText;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final DateTime date;

  const MonthDay({
    required this.day,
    required this.lunarText,
    required this.date,
    this.isCurrentMonth = true,
    this.isToday = false,
    this.isSelected = false,
  });
}
