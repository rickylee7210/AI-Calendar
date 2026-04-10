import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/services/nlu_service.dart';
import 'package:ai_calendar/services/interfaces.dart';

void main() {
  group('MockNluService', () {
    late MockNluService svc;
    setUp(() => svc = MockNluService());

    test('should parse complete expression', () async {
      final r = await svc.parse('明天下午三点开产品评审会');
      expect(r.isComplete, true);
      expect(r.extractedFields['title'], isNotEmpty);
    });

    test('should detect incomplete expression', () async {
      final r = await svc.parse('下周体检');
      expect(r.isComplete, false);
      expect(r.followUpQuestion, isNotNull);
    });

    test('should complete after follow-up', () async {
      final r = await svc.parseFollowUp('周末', context: {'title': '体检'});
      expect(r.isComplete, true);
    });

    test('should throw timeout when configured', () async {
      final svc = MockNluService(shouldTimeout: true);
      expect(
        () => svc.parse('test'),
        throwsA(isA<NluTimeoutException>()),
      );
    });
  });
}
