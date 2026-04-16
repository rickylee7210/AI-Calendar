import 'package:flutter/material.dart';
import '../models/calendar_day.dart';
import '../services/calendar_data_service.dart';
import '../utils/haptic.dart';
import 'day_cell.dart';

class WeekStrip extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const WeekStrip({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  State<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<WeekStrip> {
  static const _centerPage = 1000;
  final _svc = CalendarDataService();
  late PageController _pageController;
  late DateTime _baseMonday; // Monday of the initial week

  @override
  void initState() {
    super.initState();
    _baseMonday = _mondayOf(widget.selectedDate);
    _pageController = PageController(initialPage: _centerPage);
  }

  @override
  void didUpdateWidget(WeekStrip old) {
    super.didUpdateWidget(old);
    if (widget.selectedDate != old.selectedDate) {
      final newMonday = _mondayOf(widget.selectedDate);
      if (newMonday != _mondayOf(old.selectedDate)) {
        final diff = newMonday.difference(_baseMonday).inDays ~/ 7;
        final targetPage = _centerPage + diff;
        if ((_pageController.page?.round() ?? _centerPage) != targetPage) {
          _pageController.animateToPage(targetPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _mondayOf(DateTime date) {
    final weekday = (date.weekday - 1) % 7;
    return DateTime(date.year, date.month, date.day - weekday);
  }

  DateTime _mondayForPage(int page) {
    final diff = page - _centerPage;
    return _baseMonday.add(Duration(days: diff * 7));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return SizedBox(
      height: 51,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) {
          final monday = _mondayForPage(page);
          // Select same weekday in new week, or monday
          final weekdayIdx = (widget.selectedDate.weekday - 1) % 7;
          final newDate = monday.add(Duration(days: weekdayIdx));
          widget.onDateChanged(newDate);
        },
        itemBuilder: (_, page) {
          final monday = _mondayForPage(page);
          final week = _svc.getWeekForDate(monday);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final d = week[i];
                final cellDate = monday.add(Duration(days: i));
                final isSelected = cellDate.year == widget.selectedDate.year &&
                    cellDate.month == widget.selectedDate.month &&
                    cellDate.day == widget.selectedDate.day;
                final isToday = cellDate.year == now.year &&
                    cellDate.month == now.month &&
                    cellDate.day == now.day;

                return DayCell(
                  day: CalendarDay(
                    day: d.day,
                    lunarText: d.lunarText,
                    isSelected: isSelected,
                    isWeekend: d.isWeekend,
                    isToday: isToday,
                  ),
                  onTap: () { hapticTap(); widget.onDateChanged(cellDate); },
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
