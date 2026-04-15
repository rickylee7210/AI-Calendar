import 'package:flutter/foundation.dart';
import '../models/calendar_item.dart';
import '../services/interfaces.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';

enum VoiceInputState {
  idle,
  recording,
  processing, // ASR + NLU + 保存，松手后一步到位
  error,
}

class VoiceInputProvider extends ChangeNotifier {
  final IAudioRecorder _recorder;
  final IAsrService _asr;
  final INluService _nlu;
  final ICalendarDb _db;
  final IConnectivityService _connectivity;

  VoiceInputState _state = VoiceInputState.idle;
  String? _errorMessage;
  bool _inCancelZone = false;
  bool _lastSaveSuccess = false;
  String? _recognizedText;
  DateTime? _lastSavedDate;

  VoiceInputState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get inCancelZone => _inCancelZone;
  bool get lastSaveSuccess => _lastSaveSuccess;
  String? get recognizedText => _recognizedText;
  /// 最后保存事项的日期，用于跳转
  DateTime? get lastSavedDate => _lastSavedDate;
  ICalendarDb get db => _db;
  Stream<double> get amplitudeStream => _recorder.amplitudeStream;

  VoiceInputProvider({
    required IAudioRecorder recorder,
    required IAsrService asr,
    required INluService nlu,
    required ICalendarDb db,
    IConnectivityService? connectivity,
  })  : _recorder = recorder,
        _asr = asr,
        _nlu = nlu,
        _db = db,
        _connectivity = connectivity ?? MockConnectivityService();

  Future<void> startRecording() async {
    _state = VoiceInputState.recording;
    _inCancelZone = false;
    _recognizedText = null;
    notifyListeners();

    try {
      await _recorder.startRecording();
    } on MicPermissionDeniedException {
      _state = VoiceInputState.error;
      _errorMessage = '请在系统设置中开启麦克风权限';
      notifyListeners();
    } catch (e) {
      _state = VoiceInputState.error;
      _errorMessage = '录音启动失败';
      notifyListeners();
    }
  }

  void updateFingerPosition(double verticalDelta) {
    final wasInZone = _inCancelZone;
    _inCancelZone = verticalDelta < -100;
    if (_inCancelZone != wasInZone) notifyListeners();
  }

  /// 松手后一步到位：ASR → NLU → 保存
  Future<void> stopProcessAndSave() async {
    if (_inCancelZone) {
      await cancelRecording();
      return;
    }
    _lastSaveSuccess = false;
    _state = VoiceInputState.processing;
    notifyListeners();

    final path = await _recorder.stopRecording();
    debugPrint('[Voice] 录音文件路径: $path');
    if (path == null) {
      // 录音太短，静默回到 idle，不显示错误
      debugPrint('[Voice] 录音时间过短，静默忽略');
      _state = VoiceInputState.idle;
      notifyListeners();
      return;
    }

    // Check network before calling cloud services
    if (!await _connectivity.isConnected) {
      _state = VoiceInputState.error;
      _errorMessage = '网络不可用，请检查网络连接';
      notifyListeners();
      return;
    }

    try {
      final text = await _asr.recognize(path);
      if (text == null) {
        _state = VoiceInputState.idle;
        notifyListeners();
        return;
      }

      _recognizedText = text;
      notifyListeners();

      final result = await _nlu.parse(text);
      final fields = result.extractedFields;

      // 检查是否有多条待办任务
      final titles = fields['titles'] as List?;
      if (titles != null && titles.length > 1) {
        // 多条待办：逐条创建
        for (final t in titles) {
          final todoFields = Map<String, dynamic>.from(fields);
          todoFields.remove('titles');
          todoFields['title'] = t as String;
          todoFields['type'] = 'todo';
          final item = CalendarItem.fromNluResult(todoFields);
          await _db.insert(item);
          _lastSavedDate = item.dateTime;
        }
      } else {
        // 单条任务
        if (titles != null && titles.length == 1) {
          fields.remove('titles');
          fields['title'] = titles[0] as String;
        }
        final item = CalendarItem.fromNluResult(fields);
        final insertedId = await _db.insert(item);
        _lastSavedDate = item.dateTime;

        // 注册系统通知提醒（失败不阻断保存）
        if (item.type != ItemType.todo && item.dateTime != null) {
          final savedItem = item.copyWith(id: insertedId);
          try {
            await NotificationService().scheduleReminder(savedItem);
          } catch (e) {
            debugPrint('[Notification] 语音创建提醒失败: $e');
          }
        }
      }

      _lastSaveSuccess = true;
      _state = VoiceInputState.idle;
      notifyListeners();
    } on AsrTimeoutException {
      _state = VoiceInputState.error;
      _errorMessage = 'ASR引擎响应超时，请重试';
      notifyListeners();
    } catch (e, stack) {
      // ignore: avoid_print
      print('[Voice] 处理异常: $e\n$stack');
      _state = VoiceInputState.error;
      _errorMessage = '处理失败: ${e.toString().substring(0, e.toString().length.clamp(0, 100))}';
      notifyListeners();
    }
  }

  Future<void> cancelRecording() async {
    _lastSaveSuccess = false;
    await _recorder.cancelRecording();
    reset();
  }

  void reset() {
    _state = VoiceInputState.idle;
    _errorMessage = null;
    _inCancelZone = false;
    _lastSaveSuccess = false;
    notifyListeners();
  }
}
