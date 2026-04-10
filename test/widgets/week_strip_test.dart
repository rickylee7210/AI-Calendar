import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/widgets/week_strip.dart';

void main() {
  group('WeekStrip', () {
    testWidgets('displays 7 day cells', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: WeekStrip(
          selectedDate: DateTime(2026, 10, 16),
          onDateChanged: (_) {},
        )),
      ));
      expect(find.byKey(const Key('day-cell-bg')), findsNWidgets(7));
    });

    testWidgets('shows correct days for the week', (tester) async {
      // Oct 16 2026 is Friday → week is Mon Oct 12 - Sun Oct 18
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: WeekStrip(
          selectedDate: DateTime(2026, 10, 16),
          onDateChanged: (_) {},
        )),
      ));
      expect(find.text('12'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
    });

    testWidgets('tapping a day calls onDateChanged', (tester) async {
      DateTime? changed;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: WeekStrip(
          selectedDate: DateTime(2026, 10, 16),
          onDateChanged: (d) => changed = d,
        )),
      ));
      await tester.tap(find.text('14'));
      expect(changed?.day, 14);
    });

    testWidgets('supports swipe to next week', (tester) async {
      DateTime? changed;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: WeekStrip(
          selectedDate: DateTime(2026, 10, 16),
          onDateChanged: (d) => changed = d,
        )),
      ));
      // Swipe left to go to next week
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();
      // Should have called onDateChanged with a date in next week
      expect(changed, isNotNull);
      expect(changed!.isAfter(DateTime(2026, 10, 18)), true);
    });
  });
}
