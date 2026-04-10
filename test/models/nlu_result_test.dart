import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/models/nlu_result.dart';

void main() {
  group('NluResult', () {
    test('complete result should have isComplete true', () {
      final r = NluResult(
        rawText: '明天下午三点开会',
        extractedFields: {'title': '开会', 'date': '2026-04-02', 'time': '15:00', 'type': 'schedule'},
      );
      expect(r.isComplete, true);
    });

    test('incomplete result should have followUpQuestion', () {
      final r = NluResult(
        rawText: '下周体检',
        extractedFields: {'title': '体检'},
        missingFields: ['date', 'time'],
        followUpQuestion: '需要安排在工作日还是周末？',
      );
      expect(r.isComplete, false);
      expect(r.followUpQuestion, isNotNull);
    });

    test('should parse from API response', () {
      final r = NluResult.fromApiResponse({
        'raw_text': '开会',
        'fields': {'title': '开会'},
        'missing_fields': ['date'],
        'follow_up_question': '什么时候？',
      });
      expect(r.rawText, '开会');
      expect(r.isComplete, false);
    });
  });
}
