# 阶段一：核心服务层设计

## 目标

实现 AI 语音输入的完整后端链路：录音 → ASR → NLU → 存储，所有服务通过接口抽象，支持 Mock 测试。

## 架构

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌────────────┐
│ AudioRecorder│────▶│  ASR Service  │────▶│  NLU Service  │────▶│  DB Service │
│  (record包)  │     │ (科大讯飞)    │     │ (智谱GLM)     │     │  (sqflite)  │
└─────────────┘     └──────────────┘     └──────────────┘     └────────────┘
      音频文件            文本              结构化JSON           本地持久化
```

## 1. 录音服务 (AudioRecorderService)

**依赖**: `record: ^5.1.0`

**职责**:
- 按住开始录音，松开停止
- 上滑取消录音（丢弃音频）
- 录音时长 < 1秒判定为无效
- 麦克风权限检查

**接口**:
```dart
abstract class IAudioRecorder {
  Future<void> startRecording();
  Future<String?> stopRecording();   // 返回文件路径，null=时长不足
  Future<void> cancelRecording();    // 取消并删除文件
  bool get isRecording;
  Stream<double> get amplitudeStream; // 用于波形动画
  void dispose();
}
```

**录音格式**: AAC-LC, 16kHz, 单声道（讯飞要求）

## 2. ASR 服务 (AsrService)

**依赖**: `dio: ^5.4.0`, 科大讯飞 WebSocket/REST API

**方案**: 使用讯飞语音听写 (iat) REST API
- 端点: `https://iat-api.xfyun.cn/v2/iat`
- 音频格式: PCM/WAV, 16kHz, 16bit
- 超时: 10秒

**接口**:
```dart
abstract class IAsrService {
  Future<String?> recognize(String audioFilePath);
  // 返回识别文本，null=未识别到内容
  // 抛出 AsrTimeoutException / AsrNetworkException
}
```

**配置**:
```dart
class AsrConfig {
  final String appId;
  final String apiKey;
  final String apiSecret;
}
```

**错误处理**:
- 网络不可用 → AsrNetworkException
- 超时(>10s) → AsrTimeoutException
- 无有效文本 → 返回 null

## 3. NLU 服务 (NluService)

**依赖**: `dio: ^5.4.0`, 智谱 GLM API

**方案**: 使用智谱 GLM-4-Flash + Function Calling
- 端点: `https://open.bigmodel.cn/api/paas/v4/chat/completions`
- 用 system prompt 指导提取结构化信息
- 用 function calling 确保输出格式

**接口**:
```dart
abstract class INluService {
  Future<NluResult> parse(String text);
  Future<NluResult> parseFollowUp(String answer, {
    required Map<String, dynamic> context,
  });
}
```

**NluResult 结构**:
```dart
class NluResult {
  final String rawText;
  final Map<String, dynamic> extractedFields;
  // fields: title, date, time, type(schedule/todo/reminder), reminder
  final List<String> missingFields;
  final String? followUpQuestion;
  bool get isComplete => missingFields.isEmpty;
}
```

**System Prompt 设计**:
```
你是一个日历助手。用户会用自然语言描述一个事项。
请提取以下字段：
- title: 事项标题
- date: 日期 (YYYY-MM-DD格式)
- time: 时间 (HH:mm格式)
- type: 类型 (schedule/todo/reminder)
- reminder: 提前提醒分钟数

如果信息不完整，返回 missing_fields 和 follow_up_question。
当前日期: {today}
```

**Function 定义**:
```json
{
  "name": "extract_calendar_item",
  "parameters": {
    "title": {"type": "string"},
    "date": {"type": "string", "description": "YYYY-MM-DD"},
    "time": {"type": "string", "description": "HH:mm"},
    "type": {"type": "string", "enum": ["schedule","todo","reminder"]},
    "reminder": {"type": "integer"},
    "missing_fields": {"type": "array", "items": {"type": "string"}},
    "follow_up_question": {"type": "string"}
  }
}
```

## 4. 本地数据库 (CalendarDbService)

**依赖**: `sqflite: ^2.3.0`

**表结构**:
```sql
CREATE TABLE calendar_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  date_time TEXT,          -- ISO 8601
  type TEXT NOT NULL,      -- schedule/todo/reminder
  reminder_minutes INTEGER DEFAULT 15,
  is_completed INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

**接口**:
```dart
abstract class ICalendarDb {
  Future<int> insert(CalendarItem item);
  Future<List<CalendarItem>> getByDate(DateTime date);
  Future<void> update(CalendarItem item);
  Future<void> delete(int id);
  Future<void> toggleComplete(int id);
}
```

## 5. 配置管理 (AppConfig)

API 密钥不硬编码，通过环境变量或配置文件注入：

```dart
class AppConfig {
  final AsrConfig asr;
  final NluConfig nlu;

  factory AppConfig.fromEnv() => AppConfig(
    asr: AsrConfig(
      appId: const String.fromEnvironment('XFYUN_APP_ID'),
      apiKey: const String.fromEnvironment('XFYUN_API_KEY'),
      apiSecret: const String.fromEnvironment('XFYUN_API_SECRET'),
    ),
    nlu: NluConfig(
      apiKey: const String.fromEnvironment('ZHIPU_API_KEY'),
    ),
  );
}
```

## 实现顺序

1. 数据模型升级（加 id、created_at 等字段）
2. 本地数据库服务
3. 录音服务
4. ASR 服务（先 Mock，再对接讯飞）
5. NLU 服务（先 Mock，再对接智谱）
6. 配置管理

每步 TDD：写测试 → RED → 实现 → GREEN → 重构。
