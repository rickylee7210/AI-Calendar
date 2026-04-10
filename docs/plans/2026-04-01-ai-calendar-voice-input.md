# AI日历语音输入 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Flutter 日历App实现AI语音输入功能，用户按住说话后自动解析为结构化日程/待办/提醒，生成预览卡片一键确认。

**Architecture:** 采用分层架构：UI层（语音按钮、波形动画、事项卡片）→ 业务逻辑层（录音控制、ASR调用、NLU解析、多轮对话状态机）→ 数据层（本地日历数据库、用户画像存储）。ASR使用云端API（科大讯飞/Google Speech-to-Text），NLU使用LLM API提取结构化信息。

**Tech Stack:** Flutter 3.x, Dart, `record` (录音), `http`/`dio` (网络请求), `sqflite` (本地数据库), `permission_handler` (权限管理), `connectivity_plus` (网络检测)

---

## Task 1: 项目初始化与依赖配置

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `analysis_options.yaml`

**Step 1: 初始化 Flutter 项目**

```bash
flutter create --org com.example ai_calendar
```

**Step 2: 添加依赖到 pubspec.yaml**

在 `dependencies` 下添加：
```yaml
dependencies:
  flutter:
    sdk: flutter
  record: ^5.1.0
  dio: ^5.4.0
  sqflite: ^2.3.0
  path: ^1.8.3
  permission_handler: ^11.3.0
  connectivity_plus: ^6.0.0
  provider: ^6.1.0
  intl: ^0.19.0
```

在 `dev_dependencies` 下添加：
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0
  build_runner: ^2.4.0
```

**Step 3: 运行 flutter pub get 确认依赖安装**

Run: `flutter pub get`
Expected: 无报错，所有依赖成功安装

**Step 4: Commit**

```bash
git add .
git commit -m "chore: init flutter project with dependencies"
```

---

## Task 2: 数据模型定义

**Files:**
- Create: `lib/models/calendar_item.dart`
- Create: `lib/models/nlu_result.dart`
- Test: `test/models/calendar_item_test.dart`

**Step 1: 写 CalendarItem 模型的失败测试**

```dart
// test/models/calendar_item_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/models/calendar_item.dart';

void main() {
  group('CalendarItem', () {
    test('should create from NLU result map', () {
      final item = CalendarItem.fromNluResult({
        'title': '产品评审会',
        'date': '2026-04-02',
        'time': '15:00',
        'type': 'schedule',
        'reminder': 15,
      });
      expect(item.title, '产品评审会');
      expect(item.type, ItemType.schedule);
      expect(item.reminderMinutes, 15);
    });

    test('should serialize to map for database', () {
      final item = CalendarItem(
        title: '交周报',
        dateTime: DateTime(2026, 4, 4, 17, 0),
        type: ItemType.reminder,
        reminderMinutes: 0,
      );
      final map = item.toMap();
      expect(map['title'], '交周报');
      expect(map['type'], 'reminder');
    });

    test('should handle missing fields with defaults', () {
      final item = CalendarItem.fromNluResult({
        'title': '体检',
      });
      expect(item.title, '体检');
      expect(item.type, ItemType.todo);
      expect(item.hasMissingFields, true);
    });
  });
}
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/models/calendar_item_test.dart`
Expected: FAIL - 找不到 CalendarItem 类

**Step 3: 实现 CalendarItem 模型**

```dart
// lib/models/calendar_item.dart
enum ItemType { schedule, todo, reminder }

class CalendarItem {
  final String title;
  final DateTime? dateTime;
  final ItemType type;
  final int reminderMinutes;
  final bool hasMissingFields;

  CalendarItem({
    required this.title,
    this.dateTime,
    this.type = ItemType.todo,
    this.reminderMinutes = 15,
    this.hasMissingFields = false,
  });

  factory CalendarItem.fromNluResult(Map<String, dynamic> data) {
    final typeStr = data['type'] as String?;
    final type = switch (typeStr) {
      'schedule' => ItemType.schedule,
      'reminder' => ItemType.reminder,
      _ => ItemType.todo,
    };

    DateTime? dateTime;
    if (data['date'] != null && data['time'] != null) {
      dateTime = DateTime.parse('${data['date']}T${data['time']}');
    }

    final defaultReminder = switch (type) {
      ItemType.schedule => 15,
      ItemType.todo => 0,
      ItemType.reminder => 0,
    };

    return CalendarItem(
      title: data['title'] ?? '',
      dateTime: dateTime,
      type: type,
      reminderMinutes: data['reminder'] as int? ?? defaultReminder,
      hasMissingFields: data['date'] == null || data['time'] == null,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'dateTime': dateTime?.toIso8601String(),
    'type': type.name,
    'reminderMinutes': reminderMinutes,
  };
}
```

**Step 4: 实现 NluResult 模型**

```dart
// lib/models/nlu_result.dart
class NluResult {
  final String rawText;
  final Map<String, dynamic> extractedFields;
  final List<String> missingFields;
  final String? followUpQuestion;

  NluResult({
    required this.rawText,
    required this.extractedFields,
    this.missingFields = const [],
    this.followUpQuestion,
  });

  bool get isComplete => missingFields.isEmpty;

  factory NluResult.fromApiResponse(Map<String, dynamic> json) {
    return NluResult(
      rawText: json['raw_text'] ?? '',
      extractedFields: json['fields'] ?? {},
      missingFields: List<String>.from(json['missing_fields'] ?? []),
      followUpQuestion: json['follow_up_question'],
    );
  }
}
```

**Step 5: 运行测试确认通过**

Run: `flutter test test/models/calendar_item_test.dart`
Expected: PASS - 3 tests passed

**Step 6: Commit**

```bash
git add lib/models/ test/models/
git commit -m "feat: add CalendarItem and NluResult data models"
```

---

## Task 3: 录音服务层

**Files:**
- Create: `lib/services/audio_recorder_service.dart`
- Test: `test/services/audio_recorder_service_test.dart`

**Step 1: 写录音服务的失败测试**

```dart
// test/services/audio_recorder_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';
import 'package:ai_calendar/services/audio_recorder_service.dart';

@GenerateMocks([AudioRecorder])
import 'audio_recorder_service_test.mocks.dart';

void main() {
  late AudioRecorderService service;
  late MockAudioRecorder mockRecorder;

  setUp(() {
    mockRecorder = MockAudioRecorder();
    service = AudioRecorderService(recorder: mockRecorder);
  });

  group('AudioRecorderService', () {
    test('startRecording should start recorder and update state', () async {
      when(mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(mockRecorder.start(any, encoder: anyNamed('encoder')))
          .thenAnswer((_) async {});

      await service.startRecording();

      expect(service.isRecording, true);
      verify(mockRecorder.start(any, encoder: anyNamed('encoder'))).called(1);
    });

    test('stopRecording should return file path', () async {
      when(mockRecorder.stop()).thenAnswer((_) async => '/tmp/audio.m4a');

      final path = await service.stopRecording();

      expect(path, '/tmp/audio.m4a');
      expect(service.isRecording, false);
    });

    test('cancelRecording should stop and discard', () async {
      when(mockRecorder.stop()).thenAnswer((_) async => '/tmp/audio.m4a');

      await service.cancelRecording();

      expect(service.isRecording, false);
    });

    test('should throw when no mic permission', () async {
      when(mockRecorder.hasPermission()).thenAnswer((_) async => false);

      expect(
        () => service.startRecording(),
        throwsA(isA<MicPermissionDeniedException>()),
      );
    });
  });
}
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/services/audio_recorder_service_test.dart`
Expected: FAIL

**Step 3: 实现录音服务**

```dart
// lib/services/audio_recorder_service.dart
import 'dart:io';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;

class MicPermissionDeniedException implements Exception {
  final String message = '麦克风权限未授予';
}

class AudioRecorderService {
  final AudioRecorder _recorder;
  bool _isRecording = false;
  DateTime? _recordStartTime;

  bool get isRecording => _isRecording;

  AudioRecorderService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) throw MicPermissionDeniedException();

    final dir = Directory.systemTemp;
    final path = p.join(dir.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    _isRecording = true;
    _recordStartTime = DateTime.now();
  }

  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    final duration = DateTime.now().difference(_recordStartTime ?? DateTime.now());
    _isRecording = false;
    _recordStartTime = null;

    if (duration.inMilliseconds < 1000) {
      // 录音时间过短
      if (path != null) File(path).deleteSync();
      return null;
    }
    return path;
  }

  Future<void> cancelRecording() async {
    final path = await _recorder.stop();
    _isRecording = false;
    _recordStartTime = null;
    if (path != null) File(path).deleteSync();
  }

  void dispose() {
    _recorder.dispose();
  }
}
```

**Step 4: 生成 mock 并运行测试**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/services/audio_recorder_service_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/audio_recorder_service.dart test/services/
git commit -m "feat: add audio recorder service with permission check"
```

---

## Task 4: ASR 服务层

**Files:**
- Create: `lib/services/asr_service.dart`
- Test: `test/services/asr_service_test.dart`

**Step 1: 写 ASR 服务的失败测试**

```dart
// test/services/asr_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dio/dio.dart';
import 'package:ai_calendar/services/asr_service.dart';

@GenerateMocks([Dio])
import 'asr_service_test.mocks.dart';

void main() {
  late AsrService service;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    service = AsrService(dio: mockDio);
  });

  group('AsrService', () {
    test('should return recognized text on success', () async {
      when(mockDio.post(any, data: anyNamed('data'),
          options: anyNamed('options')))
        .thenAnswer((_) async => Response(
          data: {'text': '明天下午三点开产品评审会'},
          statusCode: 200,
          requestOptions: RequestOptions(),
        ));

      final result = await service.recognize('/tmp/audio.m4a');
      expect(result, '明天下午三点开产品评审会');
    });

    test('should return null when no speech detected', () async {
      when(mockDio.post(any, data: anyNamed('data'),
          options: anyNamed('options')))
        .thenAnswer((_) async => Response(
          data: {'text': ''},
          statusCode: 200,
          requestOptions: RequestOptions(),
        ));

      final result = await service.recognize('/tmp/audio.m4a');
      expect(result, null);
    });

    test('should throw on timeout', () async {
      when(mockDio.post(any, data: anyNamed('data'),
          options: anyNamed('options')))
        .thenThrow(DioException(
          type: DioExceptionType.receiveTimeout,
          requestOptions: RequestOptions(),
        ));

      expect(
        () => service.recognize('/tmp/audio.m4a'),
        throwsA(isA<AsrTimeoutException>()),
      );
    });
  });
}
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/services/asr_service_test.dart`
Expected: FAIL

**Step 3: 实现 ASR 服务**

```dart
// lib/services/asr_service.dart
import 'dart:io';
import 'package:dio/dio.dart';

class AsrTimeoutException implements Exception {
  final String message = 'ASR引擎响应超时';
}

class AsrService {
  final Dio _dio;
  static const _timeout = Duration(seconds: 10);

  AsrService({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    connectTimeout: _timeout,
    receiveTimeout: _timeout,
  ));

  Future<String?> recognize(String audioPath) async {
    try {
      final file = File(audioPath);
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(audioPath),
      });

      final response = await _dio.post(
        '/api/asr/recognize',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      final text = response.data['text'] as String?;
      return (text != null && text.isNotEmpty) ? text : null;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        throw AsrTimeoutException();
      }
      rethrow;
    }
  }
}
```

**Step 4: 生成 mock 并运行测试**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/services/asr_service_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/asr_service.dart test/services/asr_service_test.dart
git commit -m "feat: add ASR service with timeout handling"
```

---

## Task 5: NLU 服务层

**Files:**
- Create: `lib/services/nlu_service.dart`
- Test: `test/services/nlu_service_test.dart`

**Step 1: 写 NLU 服务的失败测试**

```dart
// test/services/nlu_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dio/dio.dart';
import 'package:ai_calendar/services/nlu_service.dart';
import 'package:ai_calendar/models/nlu_result.dart';

@GenerateMocks([Dio])
import 'nlu_service_test.mocks.dart';

void main() {
  late NluService service;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    service = NluService(dio: mockDio);
  });

  group('NluService', () {
    test('should parse complete expression', () async {
      when(mockDio.post(any, data: anyNamed('data')))
        .thenAnswer((_) async => Response(
          data: {
            'raw_text': '明天下午三点开产品评审会',
            'fields': {
              'title': '产品评审会',
              'date': '2026-04-02',
              'time': '15:00',
              'type': 'schedule',
            },
            'missing_fields': [],
          },
          statusCode: 200,
          requestOptions: RequestOptions(),
        ));

      final result = await service.parse('明天下午三点开产品评审会');
      expect(result.isComplete, true);
      expect(result.extractedFields['title'], '产品评审会');
    });

    test('should detect missing fields and suggest follow-up', () async {
      when(mockDio.post(any, data: anyNamed('data')))
        .thenAnswer((_) async => Response(
          data: {
            'raw_text': '下周找时间体检',
            'fields': {'title': '体检', 'type': 'todo'},
            'missing_fields': ['date', 'time'],
            'follow_up_question': '需要安排在工作日还是周末？',
          },
          statusCode: 200,
          requestOptions: RequestOptions(),
        ));

      final result = await service.parse('下周找时间体检');
      expect(result.isComplete, false);
      expect(result.followUpQuestion, '需要安排在工作日还是周末？');
    });

    test('should merge follow-up answer with context', () async {
      when(mockDio.post(any, data: anyNamed('data')))
        .thenAnswer((_) async => Response(
          data: {
            'raw_text': '周末',
            'fields': {
              'title': '体检',
              'date': '2026-04-04',
              'time': '10:00',
              'type': 'todo',
            },
            'missing_fields': [],
          },
          statusCode: 200,
          requestOptions: RequestOptions(),
        ));

      final result = await service.parseFollowUp(
        '周末',
        context: {'title': '体检', 'type': 'todo'},
      );
      expect(result.isComplete, true);
    });
  });
}
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/services/nlu_service_test.dart`
Expected: FAIL

**Step 3: 实现 NLU 服务**

```dart
// lib/services/nlu_service.dart
import 'package:dio/dio.dart';
import '../models/nlu_result.dart';

class NluTimeoutException implements Exception {
  final String message = 'NLU引擎响应超时';
}

class NluParseException implements Exception {
  final String message = '无法理解您的输入，请尝试更具体的描述';
}

class NluService {
  final Dio _dio;
  static const _timeout = Duration(seconds: 10);

  NluService({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    connectTimeout: _timeout,
    receiveTimeout: _timeout,
  ));

  Future<NluResult> parse(String text) async {
    try {
      final response = await _dio.post('/api/nlu/parse', data: {
        'text': text,
      });
      final result = NluResult.fromApiResponse(response.data);
      if (result.extractedFields.isEmpty) throw NluParseException();
      return result;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        throw NluTimeoutException();
      }
      rethrow;
    }
  }

  Future<NluResult> parseFollowUp(
    String answer, {
    required Map<String, dynamic> context,
  }) async {
    try {
      final response = await _dio.post('/api/nlu/parse', data: {
        'text': answer,
        'context': context,
      });
      return NluResult.fromApiResponse(response.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        throw NluTimeoutException();
      }
      rethrow;
    }
  }
}
```

**Step 4: 生成 mock 并运行测试**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/services/nlu_service_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/nlu_service.dart test/services/nlu_service_test.dart
git commit -m "feat: add NLU service with follow-up support"
```

---

## Task 6: 本地数据库服务

**Files:**
- Create: `lib/services/calendar_db_service.dart`
- Test: `test/services/calendar_db_service_test.dart`

**Step 1: 写数据库服务的失败测试**

```dart
// test/services/calendar_db_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/services/calendar_db_service.dart';
import 'package:ai_calendar/models/calendar_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late CalendarDbService dbService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbService = CalendarDbService();
    await dbService.initDb(inMemory: true);
  });

  tearDown(() async {
    await dbService.close();
  });

  group('CalendarDbService', () {
    test('should insert and retrieve a calendar item', () async {
      final item = CalendarItem(
        title: '产品评审会',
        dateTime: DateTime(2026, 4, 2, 15, 0),
        type: ItemType.schedule,
        reminderMinutes: 15,
      );

      final id = await dbService.insert(item);
      expect(id, greaterThan(0));

      final items = await dbService.getAll();
      expect(items.length, 1);
      expect(items.first.title, '产品评审会');
    });
  });
}
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/services/calendar_db_service_test.dart`
Expected: FAIL

**Step 3: 实现数据库服务**

```dart
// lib/services/calendar_db_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/calendar_item.dart';

class CalendarDbService {
  Database? _db;

  Future<void> initDb({bool inMemory = false}) async {
    _db = await openDatabase(
      inMemory ? inMemoryDatabasePath : join(await getDatabasesPath(), 'calendar.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            dateTime TEXT,
            type TEXT NOT NULL,
            reminderMinutes INTEGER DEFAULT 15,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insert(CalendarItem item) async {
    return await _db!.insert('items', {
      ...item.toMap(),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<CalendarItem>> getAll() async {
    final maps = await _db!.query('items', orderBy: 'dateTime ASC');
    return maps.map((m) => CalendarItem.fromNluResult(m)).toList();
  }

  Future<void> close() async => await _db?.close();
}
```

**Step 4: 添加 sqflite_common_ffi 测试依赖**

在 `pubspec.yaml` 的 `dev_dependencies` 添加：
```yaml
  sqflite_common_ffi: ^2.3.0
```

Run: `flutter pub get`

**Step 5: 运行测试确认通过**

Run: `flutter test test/services/calendar_db_service_test.dart`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/services/calendar_db_service.dart test/services/ pubspec.yaml
git commit -m "feat: add local calendar database service"
```

---

## Task 7: 语音输入状态管理（Provider）

**Files:**
- Create: `lib/providers/voice_input_provider.dart`
- Test: `test/providers/voice_input_provider_test.dart`

**Step 1: 写状态管理的失败测试**

```dart
// test/providers/voice_input_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ai_calendar/providers/voice_input_provider.dart';
import 'package:ai_calendar/services/audio_recorder_service.dart';
import 'package:ai_calendar/services/asr_service.dart';
import 'package:ai_calendar/services/nlu_service.dart';
import 'package:ai_calendar/services/calendar_db_service.dart';
import 'package:ai_calendar/models/nlu_result.dart';

@GenerateMocks([AudioRecorderService, AsrService, NluService, CalendarDbService])
import 'voice_input_provider_test.mocks.dart';

void main() {
  late VoiceInputProvider provider;
  late MockAudioRecorderService mockRecorder;
  late MockAsrService mockAsr;
  late MockNluService mockNlu;
  late MockCalendarDbService mockDb;

  setUp(() {
    mockRecorder = MockAudioRecorderService();
    mockAsr = MockAsrService();
    mockNlu = MockNluService();
    mockDb = MockCalendarDbService();
    provider = VoiceInputProvider(
      recorder: mockRecorder,
      asr: mockAsr,
      nlu: mockNlu,
      db: mockDb,
    );
  });

  group('VoiceInputProvider', () {
    test('initial state should be idle', () {
      expect(provider.state, VoiceInputState.idle);
    });

    test('full happy path: record → recognize → parse → card', () async {
      when(mockRecorder.startRecording()).thenAnswer((_) async {});
      when(mockRecorder.stopRecording())
          .thenAnswer((_) async => '/tmp/audio.m4a');
      when(mockAsr.recognize('/tmp/audio.m4a'))
          .thenAnswer((_) async => '明天下午三点开会');
      when(mockNlu.parse('明天下午三点开会'))
          .thenAnswer((_) async => NluResult(
            rawText: '明天下午三点开会',
            extractedFields: {
              'title': '开会',
              'date': '2026-04-02',
              'time': '15:00',
              'type': 'schedule',
            },
          ));

      await provider.startRecording();
      expect(provider.state, VoiceInputState.recording);

      await provider.stopAndProcess();
      expect(provider.state, VoiceInputState.cardReady);
      expect(provider.calendarItem?.title, '开会');
    });

    test('cancel recording should return to idle', () async {
      when(mockRecorder.startRecording()).thenAnswer((_) async {});
      when(mockRecorder.cancelRecording()).thenAnswer((_) async {});

      await provider.startRecording();
      await provider.cancelRecording();
      expect(provider.state, VoiceInputState.idle);
    });
  });
}
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/providers/voice_input_provider_test.dart`
Expected: FAIL

**Step 3: 实现 VoiceInputProvider**

```dart
// lib/providers/voice_input_provider.dart
import 'package:flutter/foundation.dart';
import '../models/calendar_item.dart';
import '../models/nlu_result.dart';
import '../services/audio_recorder_service.dart';
import '../services/asr_service.dart';
import '../services/nlu_service.dart';
import '../services/calendar_db_service.dart';

enum VoiceInputState {
  idle,
  recording,
  recognizing,
  parsing,
  followUp,
  cardReady,
  saving,
  error,
}

class VoiceInputProvider extends ChangeNotifier {
  final AudioRecorderService _recorder;
  final AsrService _asr;
  final NluService _nlu;
  final CalendarDbService _db;

  VoiceInputState _state = VoiceInputState.idle;
  CalendarItem? _calendarItem;
  String? _recognizedText;
  String? _errorMessage;
  String? _followUpQuestion;
  NluResult? _lastNluResult;
  int _followUpCount = 0;

  VoiceInputState get state => _state;
  CalendarItem? get calendarItem => _calendarItem;
  String? get recognizedText => _recognizedText;
  String? get errorMessage => _errorMessage;
  String? get followUpQuestion => _followUpQuestion;

  VoiceInputProvider({
    required AudioRecorderService recorder,
    required AsrService asr,
    required NluService nlu,
    required CalendarDbService db,
  })  : _recorder = recorder,
        _asr = asr,
        _nlu = nlu,
        _db = db;

  Future<void> startRecording() async {
    try {
      await _recorder.startRecording();
      _state = VoiceInputState.recording;
      notifyListeners();
    } on MicPermissionDeniedException {
      _state = VoiceInputState.error;
      _errorMessage = '请在系统设置中开启麦克风权限';
      notifyListeners();
    }
  }

  Future<void> stopAndProcess() async {
    _state = VoiceInputState.recognizing;
    notifyListeners();

    final path = await _recorder.stopRecording();
    if (path == null) {
      _state = VoiceInputState.error;
      _errorMessage = '录音时间过短，请重试';
      notifyListeners();
      return;
    }

    final text = await _asr.recognize(path);
    if (text == null) {
      _state = VoiceInputState.error;
      _errorMessage = '未识别到语音内容，请重试';
      notifyListeners();
      return;
    }

    _recognizedText = text;
    _state = VoiceInputState.parsing;
    notifyListeners();

    final result = await _nlu.parse(text);
    _handleNluResult(result);
  }

  Future<void> answerFollowUp(String answer) async {
    _followUpCount++;
    _state = VoiceInputState.parsing;
    notifyListeners();

    final result = await _nlu.parseFollowUp(
      answer,
      context: _lastNluResult?.extractedFields ?? {},
    );
    _handleNluResult(result);
  }

  void _handleNluResult(NluResult result) {
    _lastNluResult = result;
    if (result.isComplete || _followUpCount >= 3) {
      _calendarItem = CalendarItem.fromNluResult(result.extractedFields);
      _state = VoiceInputState.cardReady;
    } else {
      _followUpQuestion = result.followUpQuestion;
      _state = VoiceInputState.followUp;
    }
    notifyListeners();
  }

  Future<bool> confirmAndSave() async {
    if (_calendarItem == null) return false;
    _state = VoiceInputState.saving;
    notifyListeners();

    await _db.insert(_calendarItem!);
    reset();
    return true;
  }

  Future<void> cancelRecording() async {
    await _recorder.cancelRecording();
    reset();
  }

  void reset() {
    _state = VoiceInputState.idle;
    _calendarItem = null;
    _recognizedText = null;
    _errorMessage = null;
    _followUpQuestion = null;
    _lastNluResult = null;
    _followUpCount = 0;
    notifyListeners();
  }
}
```

**Step 4: 生成 mock 并运行测试**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/providers/voice_input_provider_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/providers/ test/providers/
git commit -m "feat: add VoiceInputProvider state management"
```

---

## Task 8: 语音输入按钮 UI 组件

**Files:**
- Create: `lib/widgets/voice_input_button.dart`
- Test: `test/widgets/voice_input_button_test.dart`

**Step 1: 写按钮 Widget 的失败测试**

```dart
// test/widgets/voice_input_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ai_calendar/widgets/voice_input_button.dart';
import 'package:ai_calendar/providers/voice_input_provider.dart';

@GenerateMocks([VoiceInputProvider])
import 'voice_input_button_test.mocks.dart';

void main() {
  late MockVoiceInputProvider mockProvider;

  setUp(() {
    mockProvider = MockVoiceInputProvider();
    when(mockProvider.state).thenReturn(VoiceInputState.idle);
    when(mockProvider.hasListeners).thenReturn(false);
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<VoiceInputProvider>.value(
          value: mockProvider,
          child: const VoiceInputButton(),
        ),
      ),
    );
  }

  group('VoiceInputButton', () {
    testWidgets('should display mic icon in idle state', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('long press should start recording', (tester) async {
      when(mockProvider.startRecording()).thenAnswer((_) async {});
      await tester.pumpWidget(buildTestWidget());

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(VoiceInputButton)),
      );
      await tester.pump(const Duration(milliseconds: 500));

      verify(mockProvider.startRecording()).called(1);
      await gesture.up();
    });
  });
}
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/widgets/voice_input_button_test.dart`
Expected: FAIL

**Step 3: 实现语音输入按钮**

```dart
// lib/widgets/voice_input_button.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_input_provider.dart';

class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({super.key});

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  Offset? _startPosition;
  static const _cancelThreshold = 50.0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VoiceInputProvider>();
    final isRecording = provider.state == VoiceInputState.recording;

    return GestureDetector(
      onLongPressStart: (details) {
        _startPosition = details.globalPosition;
        provider.startRecording();
      },
      onLongPressMoveUpdate: (details) {
        // 检测上滑取消
      },
      onLongPressEnd: (details) {
        if (_startPosition != null) {
          final dy = _startPosition!.dy - details.globalPosition.dy;
          if (dy > _cancelThreshold) {
            provider.cancelRecording();
          } else {
            provider.stopAndProcess();
          }
        }
        _startPosition = null;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isRecording ? 80 : 64,
        height: isRecording ? 80 : 64,
        decoration: BoxDecoration(
          color: isRecording
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isRecording ? Icons.mic : Icons.mic,
          color: Colors.white,
          size: isRecording ? 36 : 28,
        ),
      ),
    );
  }
}
```

**Step 4: 生成 mock 并运行测试**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/widgets/voice_input_button_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/widgets/voice_input_button.dart test/widgets/
git commit -m "feat: add voice input button with long-press and swipe-cancel"
```

---

## Task 9: 事项卡片 UI 组件

**Files:**
- Create: `lib/widgets/calendar_item_card.dart`
- Test: `test/widgets/calendar_item_card_test.dart`

**Step 1: 写事项卡片的失败测试**

```dart
// test/widgets/calendar_item_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/widgets/calendar_item_card.dart';
import 'package:ai_calendar/models/calendar_item.dart';

void main() {
  group('CalendarItemCard', () {
    testWidgets('should display all fields', (tester) async {
      final item = CalendarItem(
        title: '产品评审会',
        dateTime: DateTime(2026, 4, 2, 15, 0),
        type: ItemType.schedule,
        reminderMinutes: 15,
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
      expect(find.text('确认'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('confirm button should call onConfirm', (tester) async {
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
  });
}
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/widgets/calendar_item_card_test.dart`
Expected: FAIL

**Step 3: 实现事项卡片组件**

```dart
// lib/widgets/calendar_item_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_item.dart';

class CalendarItemCard extends StatefulWidget {
  final CalendarItem item;
  final String recognizedText;
  final ValueChanged<CalendarItem> onConfirm;
  final VoidCallback onCancel;

  const CalendarItemCard({
    super.key,
    required this.item,
    required this.recognizedText,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<CalendarItemCard> createState() => _CalendarItemCardState();
}

class _CalendarItemCardState extends State<CalendarItemCard> {
  late TextEditingController _titleController;
  late DateTime? _dateTime;
  late ItemType _type;
  late int _reminderMinutes;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _dateTime = widget.item.dateTime;
    _type = widget.item.type;
    _reminderMinutes = widget.item.reminderMinutes;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String get _typeLabel => switch (_type) {
    ItemType.schedule => '日程',
    ItemType.todo => '待办',
    ItemType.reminder => '提醒',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 原始识别文本
            Text(
              widget.recognizedText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            // 标题
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // 日期时间
            if (_dateTime != null)
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(DateFormat('yyyy-MM-dd HH:mm').format(_dateTime!)),
                onTap: () => _pickDateTime(context),
              ),
            // 类型选择
            DropdownButtonFormField<ItemType>(
              value: _type,
              decoration: const InputDecoration(labelText: '类型'),
              items: ItemType.values.map((t) => DropdownMenuItem(
                value: t,
                child: Text(switch (t) {
                  ItemType.schedule => '日程',
                  ItemType.todo => '待办',
                  ItemType.reminder => '提醒',
                }),
              )).toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 16),
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => widget.onConfirm(CalendarItem(
                    title: _titleController.text,
                    dateTime: _dateTime,
                    type: _type,
                    reminderMinutes: _reminderMinutes,
                  )),
                  child: const Text('确认'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime ?? DateTime.now()),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }
}
```

**Step 4: 运行测试确认通过**

Run: `flutter test test/widgets/calendar_item_card_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/widgets/calendar_item_card.dart test/widgets/
git commit -m "feat: add editable calendar item card widget"
```

---

## Task 10: 多轮对话 UI 组件

**Files:**
- Create: `lib/widgets/follow_up_dialog.dart`
- Test: `test/widgets/follow_up_dialog_test.dart`

**Step 1: 写多轮对话组件的失败测试**

```dart
// test/widgets/follow_up_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/widgets/follow_up_dialog.dart';

void main() {
  group('FollowUpDialog', () {
    testWidgets('should display question and text input', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FollowUpDialog(
            question: '需要安排在工作日还是周末？',
            onTextSubmit: (_) {},
            onVoiceInput: () {},
          ),
        ),
      ));

      expect(find.text('需要安排在工作日还是周末？'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('text submit should call callback', (tester) async {
      String? submitted;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FollowUpDialog(
            question: '什么时间？',
            onTextSubmit: (t) => submitted = t,
            onVoiceInput: () {},
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), '周末');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submitted, '周末');
    });
  });
}
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/widgets/follow_up_dialog_test.dart`
Expected: FAIL

**Step 3: 实现多轮对话组件**

```dart
// lib/widgets/follow_up_dialog.dart
import 'package:flutter/material.dart';

class FollowUpDialog extends StatefulWidget {
  final String question;
  final ValueChanged<String> onTextSubmit;
  final VoidCallback onVoiceInput;

  const FollowUpDialog({
    super.key,
    required this.question,
    required this.onTextSubmit,
    required this.onVoiceInput,
  });

  @override
  State<FollowUpDialog> createState() => _FollowUpDialogState();
}

class _FollowUpDialogState extends State<FollowUpDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onTextSubmit(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.question,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '输入回答...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _submit,
                  icon: const Icon(Icons.send),
                ),
                IconButton(
                  onPressed: widget.onVoiceInput,
                  icon: const Icon(Icons.mic),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 4: 运行测试确认通过**

Run: `flutter test test/widgets/follow_up_dialog_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/widgets/follow_up_dialog.dart test/widgets/
git commit -m "feat: add follow-up dialog with text and voice input"
```

---

## Task 11: 主界面集成

**Files:**
- Create: `lib/screens/calendar_home_screen.dart`
- Modify: `lib/main.dart`
- Test: `test/screens/calendar_home_screen_test.dart`

**Step 1: 写主界面的失败测试**

```dart
// test/screens/calendar_home_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ai_calendar/screens/calendar_home_screen.dart';
import 'package:ai_calendar/providers/voice_input_provider.dart';

@GenerateMocks([VoiceInputProvider])
import 'calendar_home_screen_test.mocks.dart';

void main() {
  late MockVoiceInputProvider mockProvider;

  setUp(() {
    mockProvider = MockVoiceInputProvider();
    when(mockProvider.state).thenReturn(VoiceInputState.idle);
    when(mockProvider.hasListeners).thenReturn(false);
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: ChangeNotifierProvider<VoiceInputProvider>.value(
        value: mockProvider,
        child: const CalendarHomeScreen(),
      ),
    );
  }

  group('CalendarHomeScreen', () {
    testWidgets('should show voice button and text input icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.keyboard), findsOneWidget);
    });

    testWidgets('should show card when state is cardReady', (tester) async {
      when(mockProvider.state).thenReturn(VoiceInputState.cardReady);
      when(mockProvider.calendarItem).thenReturn(null);
      when(mockProvider.recognizedText).thenReturn('开会');

      await tester.pumpWidget(buildTestWidget());
      // Card area should be visible
      expect(find.byType(CalendarHomeScreen), findsOneWidget);
    });
  });
}
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/screens/calendar_home_screen_test.dart`
Expected: FAIL

**Step 3: 实现主界面**

```dart
// lib/screens/calendar_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_input_provider.dart';
import '../widgets/voice_input_button.dart';
import '../widgets/calendar_item_card.dart';
import '../widgets/follow_up_dialog.dart';

class CalendarHomeScreen extends StatelessWidget {
  const CalendarHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VoiceInputProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('日历')),
      body: Stack(
        children: [
          // 日历主体内容（占位）
          const Center(child: Text('日历视图')),

          // 状态提示
          if (provider.state == VoiceInputState.recognizing)
            const Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('识别中...'),
              ],
            )),

          // 错误提示
          if (provider.state == VoiceInputState.error)
            _buildErrorSnackBar(context, provider),

          // 多轮对话
          if (provider.state == VoiceInputState.followUp &&
              provider.followUpQuestion != null)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: FollowUpDialog(
                question: provider.followUpQuestion!,
                onTextSubmit: (text) => provider.answerFollowUp(text),
                onVoiceInput: () => provider.startRecording(),
              ),
            ),

          // 事项卡片
          if (provider.state == VoiceInputState.cardReady &&
              provider.calendarItem != null)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: CalendarItemCard(
                item: provider.calendarItem!,
                recognizedText: provider.recognizedText ?? '',
                onConfirm: (_) async {
                  final saved = await provider.confirmAndSave();
                  if (saved && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('保存成功')),
                    );
                  }
                },
                onCancel: () => provider.reset(),
              ),
            ),
        ],
      ),
      // 底部输入区域
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 文本输入入口
              IconButton(
                onPressed: () => _showTextInput(context, provider),
                icon: const Icon(Icons.keyboard),
              ),
              const SizedBox(width: 16),
              // 语音输入按钮
              const VoiceInputButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorSnackBar(BuildContext context, VoiceInputProvider provider) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? '发生错误'),
          action: SnackBarAction(
            label: '重试',
            onPressed: () => provider.reset(),
          ),
        ),
      );
    });
    return const SizedBox.shrink();
  }

  void _showTextInput(BuildContext context, VoiceInputProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final controller = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '输入事项，如"明天下午三点开会"',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty) {
                      Navigator.pop(ctx);
                      provider.processText(text.trim());
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    Navigator.pop(ctx);
                    provider.processText(text);
                  }
                },
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

**Step 4: 在 VoiceInputProvider 中添加 processText 方法**

在 `lib/providers/voice_input_provider.dart` 中添加：
```dart
  Future<void> processText(String text) async {
    _recognizedText = text;
    _state = VoiceInputState.parsing;
    notifyListeners();

    try {
      final result = await _nlu.parse(text);
      _handleNluResult(result);
    } on NluParseException {
      _state = VoiceInputState.error;
      _errorMessage = '无法理解您的输入，请尝试更具体的描述';
      notifyListeners();
    } on NluTimeoutException {
      _state = VoiceInputState.error;
      _errorMessage = 'AI引擎响应超时，请重试';
      notifyListeners();
    }
  }
```

**Step 5: 更新 main.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/voice_input_provider.dart';
import 'services/audio_recorder_service.dart';
import 'services/asr_service.dart';
import 'services/nlu_service.dart';
import 'services/calendar_db_service.dart';
import 'screens/calendar_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dbService = CalendarDbService();
  await dbService.initDb();

  runApp(
    ChangeNotifierProvider(
      create: (_) => VoiceInputProvider(
        recorder: AudioRecorderService(),
        asr: AsrService(),
        nlu: NluService(),
        db: dbService,
      ),
      child: const CalendarApp(),
    ),
  );
}

class CalendarApp extends StatelessWidget {
  const CalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI日历',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const CalendarHomeScreen(),
    );
  }
}
```

**Step 6: 生成 mock 并运行测试**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/screens/calendar_home_screen_test.dart`
Expected: PASS

**Step 7: Commit**

```bash
git add lib/screens/ lib/main.dart test/screens/
git commit -m "feat: integrate calendar home screen with voice and text input"
```

---

## Task 12: 网络与权限错误处理

**Files:**
- Create: `lib/services/connectivity_service.dart`
- Modify: `lib/providers/voice_input_provider.dart`
- Test: `test/services/connectivity_service_test.dart`

**Step 1: 写网络检测服务的失败测试**

```dart
// test/services/connectivity_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ai_calendar/services/connectivity_service.dart';

@GenerateMocks([Connectivity])
import 'connectivity_service_test.mocks.dart';

void main() {
  late ConnectivityService service;
  late MockConnectivity mockConnectivity;

  setUp(() {
    mockConnectivity = MockConnectivity();
    service = ConnectivityService(connectivity: mockConnectivity);
  });

  group('ConnectivityService', () {
    test('should return true when connected', () async {
      when(mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);
      expect(await service.isConnected, true);
    });

    test('should return false when no connection', () async {
      when(mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);
      expect(await service.isConnected, false);
    });
  });
}
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/services/connectivity_service_test.dart`
Expected: FAIL

**Step 3: 实现网络检测服务**

```dart
// lib/services/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}
```

**Step 4: 在 VoiceInputProvider 中集成网络检查**

在 `stopAndProcess()` 方法开头添加网络检查：
```dart
  // 在 stopAndProcess 方法中，录音停止后、调用 ASR 前添加：
  if (!await _connectivity.isConnected) {
    _state = VoiceInputState.error;
    _errorMessage = '网络不可用，请检查网络连接';
    notifyListeners();
    return;
  }
```

**Step 5: 生成 mock 并运行所有测试**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test`
Expected: ALL PASS

**Step 6: Commit**

```bash
git add lib/services/connectivity_service.dart lib/providers/ test/
git commit -m "feat: add connectivity check and error handling"
```

---

## Task 13: 全量集成测试

**Files:**
- Create: `test/integration/voice_input_flow_test.dart`

**Step 1: 写端到端集成测试**

```dart
// test/integration/voice_input_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ai_calendar/providers/voice_input_provider.dart';
import 'package:ai_calendar/services/audio_recorder_service.dart';
import 'package:ai_calendar/services/asr_service.dart';
import 'package:ai_calendar/services/nlu_service.dart';
import 'package:ai_calendar/services/calendar_db_service.dart';
import 'package:ai_calendar/services/connectivity_service.dart';
import 'package:ai_calendar/models/nlu_result.dart';

@GenerateMocks([
  AudioRecorderService, AsrService, NluService,
  CalendarDbService, ConnectivityService,
])
import 'voice_input_flow_test.mocks.dart';

void main() {
  late VoiceInputProvider provider;
  late MockAudioRecorderService mockRecorder;
  late MockAsrService mockAsr;
  late MockNluService mockNlu;
  late MockCalendarDbService mockDb;

  setUp(() {
    mockRecorder = MockAudioRecorderService();
    mockAsr = MockAsrService();
    mockNlu = MockNluService();
    mockDb = MockCalendarDbService();
    provider = VoiceInputProvider(
      recorder: mockRecorder,
      asr: mockAsr,
      nlu: mockNlu,
      db: mockDb,
    );
  });

  test('完整流程：录音 → 识别 → 解析 → 生成卡片 → 保存', () async {
    when(mockRecorder.startRecording()).thenAnswer((_) async {});
    when(mockRecorder.stopRecording())
        .thenAnswer((_) async => '/tmp/audio.m4a');
    when(mockAsr.recognize(any))
        .thenAnswer((_) async => '明天下午三点开产品评审会');
    when(mockNlu.parse(any))
        .thenAnswer((_) async => NluResult(
          rawText: '明天下午三点开产品评审会',
          extractedFields: {
            'title': '产品评审会',
            'date': '2026-04-02',
            'time': '15:00',
            'type': 'schedule',
            'reminder': 15,
          },
        ));
    when(mockDb.insert(any)).thenAnswer((_) async => 1);

    // 1. 开始录音
    await provider.startRecording();
    expect(provider.state, VoiceInputState.recording);

    // 2. 停止并处理
    await provider.stopAndProcess();
    expect(provider.state, VoiceInputState.cardReady);
    expect(provider.calendarItem?.title, '产品评审会');

    // 3. 确认保存
    final saved = await provider.confirmAndSave();
    expect(saved, true);
    expect(provider.state, VoiceInputState.idle);
    verify(mockDb.insert(any)).called(1);
  });

  test('多轮对话流程：不完整表达 → 追问 → 补全 → 卡片', () async {
    when(mockRecorder.startRecording()).thenAnswer((_) async {});
    when(mockRecorder.stopRecording())
        .thenAnswer((_) async => '/tmp/audio.m4a');
    when(mockAsr.recognize(any))
        .thenAnswer((_) async => '下周找时间体检');
    when(mockNlu.parse(any))
        .thenAnswer((_) async => NluResult(
          rawText: '下周找时间体检',
          extractedFields: {'title': '体检', 'type': 'todo'},
          missingFields: ['date', 'time'],
          followUpQuestion: '需要安排在工作日还是周末？',
        ));
    when(mockNlu.parseFollowUp(any, context: anyNamed('context')))
        .thenAnswer((_) async => NluResult(
          rawText: '周末',
          extractedFields: {
            'title': '体检',
            'date': '2026-04-04',
            'time': '10:00',
            'type': 'todo',
          },
        ));

    await provider.startRecording();
    await provider.stopAndProcess();
    expect(provider.state, VoiceInputState.followUp);
    expect(provider.followUpQuestion, '需要安排在工作日还是周末？');

    await provider.answerFollowUp('周末');
    expect(provider.state, VoiceInputState.cardReady);
    expect(provider.calendarItem?.title, '体检');
  });

  test('文本输入流程：直接文本 → 解析 → 卡片', () async {
    when(mockNlu.parse(any))
        .thenAnswer((_) async => NluResult(
          rawText: '周五提醒我交周报',
          extractedFields: {
            'title': '交周报',
            'date': '2026-04-03',
            'time': '09:00',
            'type': 'reminder',
          },
        ));

    await provider.processText('周五提醒我交周报');
    expect(provider.state, VoiceInputState.cardReady);
    expect(provider.calendarItem?.title, '交周报');
  });
}
```

**Step 2: 生成 mock 并运行集成测试**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/integration/`
Expected: ALL PASS

**Step 3: 运行全量测试**

Run: `flutter test`
Expected: ALL PASS

**Step 4: Commit**

```bash
git add test/integration/
git commit -m "test: add integration tests for full voice input flow"
```

---

## 任务依赖关系

```
Task 1 (项目初始化)
  └── Task 2 (数据模型)
       ├── Task 3 (录音服务)
       ├── Task 4 (ASR服务)
       ├── Task 5 (NLU服务)
       └── Task 6 (数据库服务)
            └── Task 7 (状态管理 Provider)
                 ├── Task 8 (语音按钮 UI)
                 ├── Task 9 (事项卡片 UI)
                 ├── Task 10 (多轮对话 UI)
                 └── Task 11 (主界面集成)
                      └── Task 12 (错误处理)
                           └── Task 13 (集成测试)
```
