import 'package:flutter/material.dart';
import '../models/calendar_day.dart';

class DayCell extends StatelessWidget {
  final CalendarDay day;
  final VoidCallback onTap;

  const DayCell({super.key, required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Color logic:
    // selected + today → red fill, white text
    // selected + !today → grey fill, black text
    // !selected + today → transparent, red text
    // !selected + !today → transparent, black text

    Color bgColor;
    Color textColor;
    Color lunarColor;

    if (day.isSelected && day.isToday) {
      bgColor = const Color(0xFFFA382E);
      textColor = Colors.white;
      lunarColor = Colors.white;
    } else if (day.isSelected && !day.isToday) {
      bgColor = Colors.black.withValues(alpha: 0.06);
      textColor = Colors.black;
      lunarColor = Colors.black.withValues(alpha: 0.6);
    } else if (!day.isSelected && day.isToday) {
      bgColor = Colors.transparent;
      textColor = const Color(0xFFFA382E);
      lunarColor = const Color(0xFFFA382E).withValues(alpha: 0.6);
    } else {
      bgColor = Colors.transparent;
      textColor = Colors.black;
      lunarColor = Colors.black.withValues(alpha: 0.6);
    }

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: 0.9,
        child: Container(
          key: const Key('day-cell-bg'),
          width: 51,
          height: 51,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(9000),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontFamily: 'MiSans', fontSize: 19,
                  fontWeight: FontWeight.w500, color: textColor, height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                day.lunarText,
                style: TextStyle(
                  fontFamily: 'MiSans', fontSize: 11,
                  fontWeight: FontWeight.w400, color: lunarColor, height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
