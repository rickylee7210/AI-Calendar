import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/models/calendar_item.dart';
import 'package:ai_calendar/widgets/calendar_item_card.dart';

void main() {
  group('CalendarItemCard', () {
    testWidgets('displays title and recognized text', (tester) async {
      final item = CalendarItem(
        title: '产品评审会',
        dateTime: DateTime(2026, 4, 2, 15, 0),
        type: ItemType.schedule,
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CalendarItemCard(
            item: item,
            recognizedText: '明天下午三点开产品评审会',
            onConfirm: (_) {},
            onCancel: () {},
          ),
        ),
      ));
      expect(find.text('产品评审会'), findsOneWidget);
      expect(find.text('明天下午三点开产品评审会'), findsOneWidget);
    });

    testWidgets('shows confirm and cancel buttons', (tester) async {
      final item = CalendarItem(title: '测试', type: ItemType.todo);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CalendarItemCard(
            item: item,
            recognizedText: '测试',
            onConfirm: (_) {},
            onCancel: () {},
          ),
        ),
      ));
      expect(find.text('确认'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('confirm calls onConfirm with item', (tester) async {
      CalendarItem? confirmed;
      final item = CalendarItem(
        title: '开会',
        dateTime: DateTime(2026, 4, 2, 15, 0),
        type: ItemType.schedule,
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CalendarItemCard(
            item: item,
            recognizedText: '开会',
            onConfirm: (i) => confirmed = i,
            onCancel: () {},
          ),
        ),
      ));
      await tester.tap(find.text('确认'));
      expect(confirmed, isNotNull);
    });

    testWidgets('cancel calls onCancel', (tester) async {
      bool cancelled = false;
      final item = CalendarItem(title: '测试', type: ItemType.todo);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CalendarItemCard(
            item: item,
            recognizedText: '测试',
            onConfirm: (_) {},
            onCancel: () => cancelled = true,
          ),
        ),
      ));
      await tester.tap(find.text('取消'));
      expect(cancelled, true);
    });

    testWidgets('shows type dropdown', (tester) async {
      final item = CalendarItem(title: '测试', type: ItemType.schedule);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CalendarItemCard(
            item: item,
            recognizedText: '测试',
            onConfirm: (_) {},
            onCancel: () {},
          ),
        ),
      ));
      expect(find.text('日程'), findsOneWidget);
    });
  });
}
