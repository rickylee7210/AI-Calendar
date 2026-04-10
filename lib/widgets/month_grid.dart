import 'package:flutter/material.dart';
import '../models/month_day.dart';

class MonthGrid extends StatelessWidget {
  final List<MonthDay> days;
  final ValueChanged<DateTime> onDayTap;

  const MonthGrid({super.key, required this.days, required this.onDayTap});

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('month-grid'),
      children: [
        // Weekday header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: _weekdays.map((d) => Expanded(
              child: Center(
                child: Text(d, style: const TextStyle(
                  fontFamily: 'MiSans', fontSize: 11.25,
                  fontWeight: FontWeight.w400, color: Colors.black,
                  letterSpacing: 0.11, height: 1.0,
                )),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 11),
        // Day grid: 6 rows x 7 cols
        ...List.generate(6, (row) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: List.generate(7, (col) {
              final idx = row * 7 + col;
              if (idx >= days.length) return const Expanded(child: SizedBox());
              final day = days[idx];
              return Expanded(child: _DayGridCell(day: day, onTap: () => onDayTap(day.date)));
            }),
          ),
        )),
      ],
    );
  }
}

class _DayGridCell extends StatelessWidget {
  final MonthDay day;
  final VoidCallback onTap;

  const _DayGridCell({required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final opacity = day.isCurrentMonth ? 1.0 : 0.14;
    final textColor = Colors.black.withValues(alpha: opacity);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Selected ring
            if (day.isSelected)
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFA382E), width: 2),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontFamily: 'MiSans', fontSize: 17.81,
                    fontWeight: FontWeight.w400, color: textColor,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
