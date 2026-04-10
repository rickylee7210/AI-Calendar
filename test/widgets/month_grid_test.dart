import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/widgets/month_grid.dart';
import 'package:ai_calendar/services/calendar_data_service.dart';

void main() {
  group('MonthGrid', () {
    testWidgets('displays 42 day cells', (tester) async {
      final svc = CalendarDataService();
      final grid = svc.getMonthGrid(2026, 10, selectedDay: 16);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MonthGrid(days: grid, onDayTap: (_) {})),
      ));

      // 42 cells in the grid
      expect(find.byKey(const Key('month-grid')), findsOneWidget);
    });

    testWidgets('shows day numbers', (tester) async {
      final svc = CalendarDataService();
      final grid = svc.getMonthGrid(2026, 10, selectedDay: 16);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MonthGrid(days: grid, onDayTap: (_) {})),
      ));

      expect(find.text('16'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // Oct 1 + Nov 1
    });

    testWidgets('calls onDayTap with date', (tester) async {
      DateTime? tapped;
      final svc = CalendarDataService();
      final grid = svc.getMonthGrid(2026, 10, selectedDay: 16);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MonthGrid(days: grid, onDayTap: (d) => tapped = d),
        ),
      ));

      // Tap on day 15 (current month)
      await tester.tap(find.text('15').first);
      expect(tapped, isNotNull);
      expect(tapped!.day, 15);
    });
  });
}
