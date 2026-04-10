import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_calendar/providers/voice_input_provider.dart';
import 'package:ai_calendar/services/audio_recorder_service.dart';
import 'package:ai_calendar/services/asr_service.dart';
import 'package:ai_calendar/services/nlu_service.dart';
import 'package:ai_calendar/services/calendar_db_service.dart';
import 'package:ai_calendar/services/connectivity_service.dart';

void main() {
  late CalendarDbService db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = CalendarDbService();
    await db.init(inMemory: true);
  });

  tearDown(() async => await db.close());

  VoiceInputProvider makeProvider({
    MockAudioRecorderService? recorder,
    MockAsrService? asr,
    MockNluService? nlu,
    MockConnectivityService? connectivity,
  }) {
    return VoiceInputProvider(
      recorder: recorder ?? MockAudioRecorderService(),
      asr: asr ?? MockAsrService(),
      nlu: nlu ?? MockNluService(),
      db: db,
      connectivity: connectivity,
    );
  }

  test('完整语音流程：长按录音 → 松手 → 自动保存', () async {
    final p = makeProvider();
    await p.startRecording();
    expect(p.state, VoiceInputState.recording);

    await p.stopProcessAndSave();
    expect(p.state, VoiceInputState.idle);

    final items = await db.getAll();
    expect(items.length, 1);
    p.dispose();
  });

  test('取消录音流程', () async {
    final p = makeProvider();
    await p.startRecording();
    await p.cancelRecording();
    expect(p.state, VoiceInputState.idle);
    p.dispose();
  });

  test('网络断开 → 错误提示', () async {
    final p = makeProvider(
      connectivity: MockConnectivityService(connected: false),
    );
    await p.startRecording();
    await p.stopProcessAndSave();
    expect(p.state, VoiceInputState.error);
    expect(p.errorMessage, contains('网络'));
    p.dispose();
  });

  test('麦克风权限拒绝 → 错误提示', () async {
    final p = makeProvider(
      recorder: MockAudioRecorderService(hasPermission: false),
    );
    await p.startRecording();
    expect(p.state, VoiceInputState.error);
    expect(p.errorMessage, contains('麦克风'));
    p.dispose();
  });

  test('录音过短 → 错误提示', () async {
    final p = makeProvider(
      recorder: MockAudioRecorderService(tooShort: true),
    );
    await p.startRecording();
    await p.stopProcessAndSave();
    expect(p.state, VoiceInputState.error);
    expect(p.errorMessage, contains('过短'));
    p.dispose();
  });

  test('ASR 超时 → 错误提示', () async {
    final p = makeProvider(asr: MockAsrService(shouldTimeout: true));
    await p.startRecording();
    await p.stopProcessAndSave();
    expect(p.state, VoiceInputState.error);
    expect(p.errorMessage, contains('超时'));
    p.dispose();
  });

  test('ASR 无结果 → 错误提示', () async {
    final p = makeProvider(asr: MockAsrService(mockText: null));
    await p.startRecording();
    await p.stopProcessAndSave();
    expect(p.state, VoiceInputState.error);
    expect(p.errorMessage, contains('未识别'));
    p.dispose();
  });

  test('多次录音累积数据', () async {
    final p = makeProvider();

    await p.startRecording();
    await p.stopProcessAndSave();

    await p.startRecording();
    await p.stopProcessAndSave();

    final items = await db.getAll();
    expect(items.length, 2);
    p.dispose();
  });
}
