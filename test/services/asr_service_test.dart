import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/services/asr_service.dart';
import 'package:ai_calendar/services/interfaces.dart';

void main() {
  group('MockAsrService', () {
    test('should return text for valid audio', () async {
      final svc = MockAsrService(mockText: '明天下午三点开会');
      final result = await svc.recognize('/tmp/audio.m4a');
      expect(result, '明天下午三点开会');
    });

    test('should return null when no speech', () async {
      final svc = MockAsrService(mockText: null);
      final result = await svc.recognize('/tmp/audio.m4a');
      expect(result, isNull);
    });

    test('should throw timeout when configured', () async {
      final svc = MockAsrService(shouldTimeout: true);
      expect(
        () => svc.recognize('/tmp/audio.m4a'),
        throwsA(isA<AsrTimeoutException>()),
      );
    });
  });
}
