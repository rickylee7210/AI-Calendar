import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/models/todo_item.dart';

void main() {
  group('TodoItem', () {
    test('should store title and completed status', () {
      final item = TodoItem(id: '1', title: '护照、驾驶证、身份证');
      expect(item.title, '护照、驾驶证、身份证');
      expect(item.isCompleted, false);
    });

    test('should support toggling completed', () {
      final item = TodoItem(id: '1', title: '测试', isCompleted: false);
      final toggled = item.copyWith(isCompleted: true);
      expect(toggled.isCompleted, true);
      expect(toggled.title, '测试');
    });
  });
}
