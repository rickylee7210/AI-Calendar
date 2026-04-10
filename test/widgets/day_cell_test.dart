import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/models/calendar_day.dart';
import 'package:ai_calendar/widgets/day_cell.dart';

void main() {
  group('DayCell', () {
    testWidgets('displays day number and lunar text', (tester) async {
      final day = CalendarDay(day: 16, lunarText: '初七');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DayCell(day: day, onTap: () {})),
      ));
      expect(find.text('16'), findsOneWidget);
      expect(find.text('初七'), findsOneWidget);
    });

    testWidgets('selected + today = red fill', (tester) async {
      final day = CalendarDay(day: 16, lunarText: '初七', isSelected: true, isToday: true);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DayCell(day: day, onTap: () {})),
      ));
      final container = tester.widget<Container>(find.byKey(const Key('day-cell-bg')));
      final deco = container.decoration as BoxDecoration;
      expect(deco.color, const Color(0xFFFA382E));
    });

    testWidgets('selected + not today = grey fill', (tester) async {
      final day = CalendarDay(day: 15, lunarText: '初六', isSelected: true, isToday: false);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DayCell(day: day, onTap: () {})),
      ));
      final container = tester.widget<Container>(find.byKey(const Key('day-cell-bg')));
      final deco = container.decoration as BoxDecoration;
      // Grey fill
      expect(deco.color, isNot(const Color(0xFFFA382E)));
      expect(deco.color, isNot(Colors.transparent));
    });

    testWidgets('not selected + today = red text', (tester) async {
      final day = CalendarDay(day: 16, lunarText: '初七', isSelected: false, isToday: true);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DayCell(day: day, onTap: () {})),
      ));
      final dayText = tester.widget<Text>(find.text('16'));
      expect(dayText.style?.color, const Color(0xFFFA382E));
    });

    testWidgets('not selected + not today = black text', (tester) async {
      final day = CalendarDay(day: 12, lunarText: '初三');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DayCell(day: day, onTap: () {})),
      ));
      final dayText = tester.widget<Text>(find.text('12'));
      expect(dayText.style?.color, Colors.black);
    });

    testWidgets('calls onTap', (tester) async {
      bool tapped = false;
      final day = CalendarDay(day: 16, lunarText: '初七');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DayCell(day: day, onTap: () => tapped = true)),
      ));
      await tester.tap(find.text('16'));
      expect(tapped, true);
    });
  });
}
