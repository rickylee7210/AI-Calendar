import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/services/audio_recorder_service.dart';
import 'package:ai_calendar/services/interfaces.dart';

void main() {
  group('MockAudioRecorderService', () {
    late MockAudioRecorderService svc;
    setUp(() => svc = MockAudioRecorderService());

    test('initial state is not recording', () {
      expect(svc.isRecording, false);
    });

    test('startRecording sets isRecording true', () async {
      await svc.startRecording();
      expect(svc.isRecording, true);
    });

    test('stopRecording returns path and resets state', () async {
      await svc.startRecording();
      final path = await svc.stopRecording();
      expect(path, isNotNull);
      expect(svc.isRecording, false);
    });

    test('cancelRecording resets state', () async {
      await svc.startRecording();
      await svc.cancelRecording();
      expect(svc.isRecording, false);
    });

    test('stopRecording returns null when too short', () async {
      final svc = MockAudioRecorderService(tooShort: true);
      await svc.startRecording();
      final path = await svc.stopRecording();
      expect(path, isNull);
    });

    test('startRecording throws when no permission', () async {
      final svc = MockAudioRecorderService(hasPermission: false);
      expect(
        () => svc.startRecording(),
        throwsA(isA<MicPermissionDeniedException>()),
      );
    });
  });
}
