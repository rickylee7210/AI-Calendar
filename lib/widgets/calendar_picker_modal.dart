import 'package:flutter/material.dart';
import '../services/calendar_data_service.dart';
import '../theme/app_icons.dart';
import 'month_grid.dart';

class CalendarPickerModal extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateSelected;

  const CalendarPickerModal({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<CalendarPickerModal> createState() => _CalendarPickerModalState();
}

class _CalendarPickerModalState extends State<CalendarPickerModal> {
  final _svc = CalendarDataService();
  late int _year;
  late int _month;
  late int _selectedDay;
  late PageController _pageController;
  static const _initialPage = 1200; // center point for infinite scroll

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year;
    _month = widget.initialDate.month;
    _selectedDay = widget.initialDate.day;
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToMonth(int delta) {
    setState(() {
      _month += delta;
      if (_month > 12) { _month = 1; _year++; }
      if (_month < 1) { _month = 12; _year--; }
      _selectedDay = 0;
    });
    final newPage = _pageController.page!.round() + delta;
    _pageController.animateToPage(newPage.toInt(),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  (int, int) _yearMonthForPage(int page) {
    final diff = page - _initialPage;
    final baseYear = widget.initialDate.year;
    final baseMonth = widget.initialDate.month;
    int totalMonths = (baseYear * 12 + baseMonth - 1) + diff;
    return (totalMonths ~/ 12, totalMonths % 12 + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(38),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle — 下滑关闭
          GestureDetector(
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 200) Navigator.of(context).pop();
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          // Header
          _buildHeader(),
          const SizedBox(height: 16),
          // Month grid with PageView
          SizedBox(
            height: 314,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) {
                final (y, m) = _yearMonthForPage(page);
                setState(() { _year = y; _month = m; _selectedDay = 0; });
              },
              itemBuilder: (_, page) {
                final (y, m) = _yearMonthForPage(page);
                final sel = (y == _year && m == _month) ? _selectedDay : 0;
                final grid = _svc.getMonthGrid(y, m, selectedDay: sel);
                return MonthGrid(
                  days: grid,
                  onDayTap: (date) {
                    if (date.month == m) {
                      widget.onDateSelected(date);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Row(
        children: [
          // Month title
          Text(
            '$_month月',
            style: const TextStyle(
              fontFamily: 'MiSans', fontSize: 24,
              fontWeight: FontWeight.w500, color: Colors.black, height: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          // Year
          Opacity(
            opacity: 0.5,
            child: Text(
              '$_year',
              style: const TextStyle(
                fontFamily: 'MiSans', fontSize: 24,
                fontWeight: FontWeight.w300, color: Colors.black, height: 1.0,
              ),
            ),
          ),
          const Spacer(),
          // Prev button
          _NavButton(
            key: const Key('picker-prev'),
            isForward: false,
            onTap: () => _goToMonth(-1),
          ),
          const SizedBox(width: 26),
          _NavButton(
            key: const Key('picker-next'),
            isForward: true,
            onTap: () => _goToMonth(1),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final bool isForward;
  final VoidCallback onTap;

  const _NavButton({super.key, required this.isForward, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 35, height: 35,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Transform(
          alignment: Alignment.center,
          transform: isForward ? Matrix4.identity() : Matrix4.rotationY(3.14159),
          child: Opacity(
            opacity: 0.6,
            child: Text(
              String.fromCharCode(0xF008D), // 󰂍 arrow icon
              style: const TextStyle(
                fontFamily: 'HyperOS Symbols',
                fontSize: 17, fontWeight: FontWeight.w500,
                color: Colors.black, height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
