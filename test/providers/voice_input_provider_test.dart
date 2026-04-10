import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/providers/voice_input_provider.dart';
import 'package:ai_calendar/services/audio_recorder_service.dart';
import 'package:ai_calendar/services/asr_service.dart';
import 'package:ai_calendar/services/nlu_service.dart';
import 'package:ai_calendar/services/calendar_db_service.dart';
import 'package:ai_calendar/services/connectivity_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VoiceInputProvider provider;
  late CalendarDbService db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = CalendarDbService();
    await db.init(inMemory: true);
    provider = VoiceInputProvider(
      recorder: MockAudioRecorderService(),
      asr: MockAsrService(),
      nlu: MockNluService(),
      db: db,
    );
  });

  tearDown(() async {
    provider.dispose();
    await db.close();
  });

  group('VoiceInputProvider', () {
    test('initial state is idle', () {
      expect(provider.state, VoiceInputState.idle);
    });

    test('happy path: record → stopProcessAndSave → idle + saved', () async {
      await provider.startRecording();
      expect(provider.state, VoiceInputState.recording);

      await provider.stopProcessAndSave();
      expect(provider.state, VoiceInputState.idle);

      final items = await db.getAll();
      expect(items.length, 1);
    });

    test('cancel recording returns to idle', () async {
      await provider.startRecording();
      await provider.cancelRecording();
      expect(provider.state, VoiceInputState.idle);
    });

    test('mic permission denied shows error', () async {
      final p = VoiceInputProvider(
        recorder: MockAudioRecorderService(hasPermission: false),
        asr: MockAsrService(),
        nlu: MockNluService(),
        db: db,
      );
      await p.startRecording();
      expect(p.state, VoiceInputState.error);
      expect(p.errorMessage, contains('麦克风'));
      p.dispose();
    });

    test('recording too short shows error', () async {
      final p = VoiceInputProvider(
        recorder: MockAudioRecorderService(tooShort: true),
        asr: MockAsrService(),
        nlu: MockNluService(),
        db: db,
      );
      await p.startRecording();
      await p.stopProcessAndSave();
      expect(p.state, VoiceInputState.error);
      expect(p.errorMessage, contains('过短'));
      p.dispose();
    });

    test('ASR returns null shows error', () async {
      final p = VoiceInputProvider(
        recorder: MockAudioRecorderService(),
        asr: MockAsrService(mockText: null),
        nlu: MockNluService(),
        db: db,
      );
      await p.startRecording();
      await p.stopProcessAndSave();
      expect(p.state, VoiceInputState.error);
      expect(p.errorMessage, contains('未识别'));
      p.dispose();
    });

    test('ASR timeout shows error', () async {
      final p = VoiceInputProvider(
        recorder: MockAudioRecorderService(),
        asr: MockAsrService(shouldTimeout: true),
        nlu: MockNluService(),
        db: db,
      );
      await p.startRecording();
      await p.stopProcessAndSave();
      expect(p.state, VoiceInputState.error);
      expect(p.errorMessage, contains('超时'));
      p.dispose();
    });

    test('reset returns to idle', () async {
      await provider.startRecording();
      provider.reset();
      expect(provider.state, VoiceInputState.idle);
    });

    test('network disconnected shows error', () async {
      final p = VoiceInputProvider(
        recorder: MockAudioRecorderService(),
        asr: MockAsrService(),
        nlu: MockNluService(),
        db: db,
        connectivity: MockConnectivityService(connected: false),
      );
      await p.startRecording();
      await p.stopProcessAndSave();
      expect(p.state, VoiceInputState.error);
      expect(p.errorMessage, contains('网络'));
      p.dispose();
    });
  });
}
