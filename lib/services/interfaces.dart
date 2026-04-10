import '../models/calendar_item.dart';
import '../models/nlu_result.dart';

/// 录音服务接口
abstract class IAudioRecorder {
  Future<void> startRecording();
  Future<String?> stopRecording();
  Future<void> cancelRecording();
  bool get isRecording;
  Stream<double> get amplitudeStream;
  void dispose();
}

/// ASR 语音识别接口
abstract class IAsrService {
  Future<String?> recognize(String audioFilePath);
}

/// NLU 自然语言理解接口
abstract class INluService {
  Future<NluResult> parse(String text);
  Future<NluResult> parseFollowUp(String answer, {
    required Map<String, dynamic> context,
  });
}

/// 本地数据库接口
abstract class ICalendarDb {
  Future<void> init({bool inMemory = false});
  Future<int> insert(CalendarItem item);
  Future<List<CalendarItem>> getByDate(DateTime date);
  Future<List<CalendarItem>> getAll();
  Future<void> update(CalendarItem item);
  Future<void> delete(int id);
  Future<void> toggleComplete(int id);
  Future<void> close();
}

/// ASR 异常
class AsrTimeoutException implements Exception {
  final String message = 'ASR引擎响应超时';
}

class AsrNetworkException implements Exception {
  final String message = '网络不可用';
}

/// NLU 异常
class NluTimeoutException implements Exception {
  final String message = 'NLU引擎响应超时';
}

class NluParseException implements Exception {
  final String message = '无法理解您的输入';
}

/// 录音异常
class MicPermissionDeniedException implements Exception {
  final String message = '麦克风权限未授予';
}

class RecordingTooShortException implements Exception {
  final String message = '录音时间过短';
}
