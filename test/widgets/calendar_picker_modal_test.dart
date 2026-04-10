import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/widgets/calendar_picker_modal.dart';

void main() {
  group('CalendarPickerModal', () {
    testWidgets('displays month title and year', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CalendarPickerModal(
          initialDate: DateTime(2026, 10, 16),
          onDateSelected: (_) {},
        )),
      ));
      expect(find.text('10月'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
    });

    testWidgets('has left and right navigation buttons', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CalendarPickerModal(
          initialDate: DateTime(2026, 10, 16),
          onDateSelected: (_) {},
        )),
      ));
      expect(find.byKey(const Key('picker-prev')), findsOneWidget);
      expect(find.byKey(const Key('picker-next')), findsOneWidget);
    });

    testWidgets('shows month grid', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CalendarPickerModal(
          initialDate: DateTime(2026, 10, 16),
          onDateSelected: (_) {},
        )),
      ));
      expect(find.byKey(const Key('month-grid')), findsOneWidget);
    });

    testWidgets('tapping next changes month', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CalendarPickerModal(
          initialDate: DateTime(2026, 10, 16),
          onDateSelected: (_) {},
        )),
      ));
      await tester.tap(find.byKey(const Key('picker-next')));
      await tester.pumpAndSettle();
      expect(find.text('11月'), findsOneWidget);
    });

    testWidgets('tapping prev changes month', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CalendarPickerModal(
          initialDate: DateTime(2026, 10, 16),
          onDateSelected: (_) {},
        )),
      ));
      await tester.tap(find.byKey(const Key('picker-prev')));
      await tester.pumpAndSettle();
      expect(find.text('9月'), findsOneWidget);
    });
  });
}
