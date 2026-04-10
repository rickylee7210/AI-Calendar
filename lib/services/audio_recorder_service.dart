import 'interfaces.dart';

/// Mock audio recorder for development. Replace with real record-based impl for production.
class MockAudioRecorderService implements IAudioRecorder {
  final bool hasPermission;
  final bool tooShort;
  bool _isRecording = false;

  MockAudioRecorderService({
    this.hasPermission = true,
    this.tooShort = false,
  });

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<double> get amplitudeStream => const Stream.empty();

  @override
  Future<void> startRecording() async {
    if (!hasPermission) throw MicPermissionDeniedException();
    _isRecording = true;
  }

  @override
  Future<String?> stopRecording() async {
    _isRecording = false;
    if (tooShort) return null;
    return '/tmp/mock_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  @override
  Future<void> cancelRecording() async {
    _isRecording = false;
  }

  @override
  void dispose() {}
}

// TODO: Implement RealAudioRecorderService using record package
// class RealAudioRecorderService implements IAudioRecorder { ... }
