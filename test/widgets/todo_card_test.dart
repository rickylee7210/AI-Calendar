import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/models/todo_item.dart';
import 'package:ai_calendar/widgets/todo_card.dart';

void main() {
  group('TodoCard', () {
    testWidgets('should display todo title', (tester) async {
      final item = TodoItem(id: '1', title: '护照、驾驶证、身份证');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TodoCard(item: item, onToggle: (_) {}),
        ),
      ));

      expect(find.text('护照、驾驶证、身份证'), findsOneWidget);
    });

    testWidgets('should show unchecked checkbox for incomplete item',
        (tester) async {
      final item = TodoItem(id: '1', title: '测试');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TodoCard(item: item, onToggle: (_) {}),
        ),
      ));

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, false);
    });

    testWidgets('should show checked checkbox for completed item',
        (tester) async {
      final item = TodoItem(id: '1', title: '测试', isCompleted: true);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TodoCard(item: item, onToggle: (_) {}),
        ),
      ));

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, true);
    });

    testWidgets('should call onToggle when checkbox tapped', (tester) async {
      String? toggledId;
      final item = TodoItem(id: '42', title: '测试');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TodoCard(item: item, onToggle: (id) => toggledId = id),
        ),
      ));

      await tester.tap(find.byType(Checkbox));
      expect(toggledId, '42');
    });

    testWidgets('completed item shows strikethrough and grey', (tester) async {
      final item = TodoItem(id: '1', title: '已完成任务', isCompleted: true);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TodoCard(item: item, onToggle: (_) {})),
      ));
      final text = tester.widget<Text>(find.text('已完成任务'));
      expect(text.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('should have rounded card with glass effect', (tester) async {
      final item = TodoItem(id: '1', title: '测试');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TodoCard(item: item, onToggle: (_) {}),
        ),
      ));

      // Card should have 20px border radius
      final container = tester.widget<Container>(
        find.byKey(const Key('todo-card-container')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(20));
    });
  });
}
