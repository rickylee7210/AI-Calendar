# 语音输入功能实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现点击语音 icon 后完整的语音交互流程：真实录音 → 智谱 ASR 转文字 → 智谱 NLU 意图解析 → 展示确认卡片 → 创建待办/日程。

**Architecture:** 两步走架构，保持现有 `IAudioRecorder` / `IAsrService` / `INluService` 接口不变。实现三个真实服务替换 Mock，新增 VoiceOverlay UI 组件匹配 Figma 设计稿。VoiceInputProvider 状态机已完整，只需扩展振幅流支持。

**Tech Stack:** Flutter, record 包（录音+振幅流）, Dio（HTTP）, 智谱 BigModel API（ASR + NLU）, BackdropFilter（毛玻璃）, CustomPaint（波形）

**Design References:**
- 录音态: Figma node 959:27210
- 卡片确认态: Figma node 966:5639

---

### Task 1: IAudioRecorder 接口扩展 — 添加振幅流

**Files:**
- Modify: `lib/services/interfaces.dart`
- Modify: `lib/services/audio_recorder_service.dart`

**Step 1: 在 IAudioRecorder 接口添加振幅流**

```dart
// interfaces.dart — IAudioRecorder 接口添加:
Stream<double> get amplitudeStream;
```

**Step 2: MockAudioRecorderService 实现空振幅流**

```dart
// audio_recorder_service.dart — MockAudioRecorderService 添加:
@override
Stream<double> get amplitudeStream => const Stream.empty();
```

**Step 3: 运行现有测试确认不破坏**

Run: `cd "/Users/dong/Desktop/东东_Work/Vibe Coding-DONG/AI Calendar" && flutter test`

**Step 4: Commit**

```bash
git add lib/services/interfaces.dart lib/services/audio_recorder_service.dart
git commit -m "feat: add amplitudeStream to IAudioRecorder interface"
```

---

### Task 2: RealAudioRecorderService — 真实录音实现

**Files:**
- Create: `lib/services/real_audio_recorder_service.dart`

**Step 1: 实现 RealAudioRecorderService**

```dart
import 'dart:async';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'interfaces.dart';

class RealAudioRecorderService implements IAudioRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  final _amplitudeCtl = StreamController<double>.broadcast();
  Timer? _ampTimer;

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<double> get amplitudeStream => _amplitudeCtl.stream;

  @override
  Future<void> startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) throw MicPermissionDeniedException();

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: '',  // record 包自动生成临时路径
    );
    _isRecording = true;

    // 每 100ms 采样振幅
    _ampTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final amp = await _recorder.getAmplitude();
      // amp.current 范围约 -160 ~ 0 dB，归一化到 0~1
      final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
      _amplitudeCtl.add(normalized);
    });
  }

  @override
  Future<String?> stopRecording() async {
    _ampTimer?.cancel();
    _ampTimer = null;
    _isRecording = false;
    final path = await _recorder.stop();
    return path;
  }

  @override
  Future<void> cancelRecording() async {
    _ampTimer?.cancel();
    _ampTimer = null;
    _isRecording = false;
    await _recorder.stop();
  }

  @override
  void dispose() {
    _ampTimer?.cancel();
    _amplitudeCtl.close();
    _recorder.dispose();
  }
}
```

**Step 2: 在真机/模拟器上手动验证录音权限和文件生成**

**Step 3: Commit**

```bash
git add lib/services/real_audio_recorder_service.dart
git commit -m "feat: implement RealAudioRecorderService with record package"
```

---

### Task 3: ZhipuAsrService — 智谱语音转文字

**Files:**
- Create: `lib/services/zhipu_asr_service.dart`

**Step 1: 实现 ZhipuAsrService**

```dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'interfaces.dart';

class ZhipuAsrService implements IAsrService {
  final Dio _dio;
  final String _apiKey;
  static const _endpoint = 'https://open.bigmodel.cn/api/paas/v4/audio/transcriptions';

  ZhipuAsrService({required String apiKey, Dio? dio})
      : _apiKey = apiKey,
        _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ));

  @override
  Future<String?> recognize(String audioFilePath) async {
    try {
      final file = File(audioFilePath);
      if (!await file.exists()) return null;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          audioFilePath,
          filename: 'audio.m4a',
        ),
        'model': 'whisper-large-v3',
        'language': 'zh',
      });

      final resp = await _dio.post(
        _endpoint,
        options: Options(headers: {
          'Authorization': 'Bearer $_apiKey',
        }),
        data: formData,
      );

      final text = resp.data['text'] as String?;
      return text?.trim().isEmpty == true ? null : text?.trim();
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

**Step 2: 写单元测试**

```dart
// test/services/zhipu_asr_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/services/zhipu_asr_service.dart';

void main() {
  test('recognize returns null for non-existent file', () async {
    final svc = ZhipuAsrService(apiKey: 'test-key');
    final result = await svc.recognize('/tmp/nonexistent_audio.m4a');
    expect(result, isNull);
  });
}
```

**Step 3: 运行测试**

Run: `cd "/Users/dong/Desktop/东东_Work/Vibe Coding-DONG/AI Calendar" && flutter test test/services/zhipu_asr_service_test.dart`

**Step 4: Commit**

```bash
git add lib/services/zhipu_asr_service.dart test/services/zhipu_asr_service_test.dart
git commit -m "feat: implement ZhipuAsrService for speech-to-text"
```

---

### Task 4: VoiceInputProvider 扩展 — 振幅流转发

**Files:**
- Modify: `lib/providers/voice_input_provider.dart`

**Step 1: 添加振幅流 getter**

在 `VoiceInputProvider` 类中添加：

```dart
// 在类顶部添加
Stream<double> get amplitudeStream => _recorder.amplitudeStream;
```

**Step 2: 运行测试**

Run: `cd "/Users/dong/Desktop/东东_Work/Vibe Coding-DONG/AI Calendar" && flutter test`

**Step 3: Commit**

```bash
git add lib/providers/voice_input_provider.dart
git commit -m "feat: expose amplitudeStream from VoiceInputProvider"
```

---

### Task 5: VoiceOverlay — 录音态 UI（光晕背景 + 波形）

**Files:**
- Create: `lib/widgets/voice_overlay.dart`

**Step 1: 实现 VoiceOverlay widget**

关键视觉规格（来自 Figma 设计稿 959:27210）：
- 光晕背景：两个椭圆径向渐变叠加，覆盖屏幕下半部分（top: 657+）
- 识别文字：白色 17px MiSans Medium，居中，top: 735
- 波形条：~50根，宽2.4px，间距2px，圆角4.446px，白色渐变填充，高度随振幅变化
- 波形区域：left:28, top:780, width:348, height:36

```dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class VoiceOverlay extends StatefulWidget {
  final String? recognizedText;
  final Stream<double> amplitudeStream;
  final VoidCallback onTap;

  const VoiceOverlay({
    super.key,
    this.recognizedText,
    required this.amplitudeStream,
    required this.onTap,
  });

  @override
  State<VoiceOverlay> createState() => _VoiceOverlayState();
}

class _VoiceOverlayState extends State<VoiceOverlay>
    with SingleTickerProviderStateMixin {
  final List<double> _amplitudes = List.filled(50, 0.05);
  StreamSubscription<double>? _ampSub;
  late AnimationController _animCtl;

  @override
  void initState() {
    super.initState();
    _animCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();
    _ampSub = widget.amplitudeStream.listen((amp) {
      setState(() {
        _amplitudes.removeAt(0);
        _amplitudes.add(amp);
      });
    });
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _animCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            // 光晕背景 1
            Positioned(
              left: -8,
              right: -19,
              bottom: 0,
              height: 425,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.0, 0.3),
                    radius: 1.4,
                    colors: [
                      Color(0xFF4A90D9),
                      Color(0xFF2E5FA1),
                      Color(0xFF1A3A6B),
                    ],
                  ),
                ),
              ),
            ),
            // 光晕背景 2
            Positioned(
              left: -21,
              right: -32,
              bottom: 0,
              height: 420,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, 0.5),
                    radius: 1.3,
                    colors: [
                      const Color(0xFF6BB5FF).withValues(alpha: 0.8),
                      const Color(0xFF3A7BD5).withValues(alpha: 0.6),
                      const Color(0xFF1A3A6B).withValues(alpha: 0.4),
                    ],
                  ),
                ),
              ),
            ),
            // 识别文字
            if (widget.recognizedText != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 130,
                child: Center(
                  child: Text(
                    '"${widget.recognizedText}"',
                    style: const TextStyle(
                      fontFamily: 'MiSans',
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            // 波形
            Positioned(
              left: 28,
              right: 28,
              bottom: 70,
              height: 36,
              child: CustomPaint(
                painter: _WaveformPainter(amplitudes: _amplitudes),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  _WaveformPainter({required this.amplitudes});

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 2.4;
    const gap = 2.0;
    final barCount = amplitudes.length;
    final totalWidth = barCount * barWidth + (barCount - 1) * gap;
    final startX = (size.width - totalWidth) / 2;
    final centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final amp = amplitudes[i].clamp(0.05, 1.0);
      final barHeight = max(3.0, amp * size.height * 0.9);
      final x = startX + i * (barWidth + gap);

      // 越靠近中间越亮
      final distFromCenter = (i - barCount / 2).abs() / (barCount / 2);
      final opacity = (1.0 - distFromCenter * 0.7).clamp(0.2, 1.0);

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth / 2, centerY),
          width: barWidth,
          height: barHeight,
        ),
        const Radius.circular(4.446),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => true;
}
```

**Step 2: Commit**

```bash
git add lib/widgets/voice_overlay.dart
git commit -m "feat: add VoiceOverlay widget with gradient background and waveform"
```

---

### Task 6: VoiceResultCard — 卡片确认态 UI

**Files:**
- Create: `lib/widgets/voice_result_card.dart`

**Step 1: 实现毛玻璃结果卡片和添加按钮**

关键视觉规格（来自 Figma 设计稿 966:5639）：
- 提示文字：left:56, top:273, 15px MiSans Regular, 50%透明度黑色
- 卡片：left:23, top:326, 278×70, 圆角20px, 毛玻璃效果
  - 标题：17px MiSans Medium, 黑色
  - 副标题：14px MiSans Regular, 60%透明度黑色
- "添加"按钮：left:23, top:409, 66×38, 圆角100px, 毛玻璃, 文字 #3482FF 16px MiSans Medium

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/calendar_item.dart';

class VoiceResultCard extends StatelessWidget {
  final CalendarItem item;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  const VoiceResultCard({
    super.key,
    required this.item,
    required this.onAdd,
    required this.onDismiss,
  });

  String get _subtitle {
    if (item.dateTime == null) return '';
    final dt = item.dateTime!;
    final start = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final end = dt.add(const Duration(hours: 1));
    final endStr = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    final diff = dt.difference(DateTime.now());
    String timeHint;
    if (diff.inHours > 0) {
      timeHint = '${diff.inHours}小时后开始';
    } else if (diff.inMinutes > 0) {
      timeHint = '${diff.inMinutes}分钟后开始';
    } else {
      timeHint = '即将开始';
    }
    return '$start-$endStr   $timeHint';
  }

  String get _typeLabel => switch (item.type) {
    ItemType.schedule => '日程',
    ItemType.todo => '待办事项',
    ItemType.reminder => '提醒事项',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 提示文字
        Padding(
          padding: const EdgeInsets.only(left: 28, bottom: 12)  child: Text(
            '已为你创建好$_typeLabel，\n要添加吗？',
            style: TextStyle(
              fontFamily: 'MiSans',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.black.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
        ),
        // 毛玻璃卡片
        Padding(
          padding: const EdgeInsets.only(left: 23),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container        width: 278,
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.65),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 0.893,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
           blurRadius: 53.571,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 71.429,
                      offset: const Offset(0, 32.143),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontFamily: 'MiSans',
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_subtitle.isNotEmpty)
                      Text(
                        _subtitle,
                        style: TextStyle(
                          fontFamily: 'MiSans',
                          fontSize: 14,
                    fontWeight: FontWeight.w400,
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 13),
        // 添加按钮
        Padding(
          padding: const EdgeInsets.only(left: 23),
          child: GestureDetector(
            onTap: onAdd,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 66,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  child: const Text(
                    '添加',
                    style: TextStyle(
                      fontFamily: 'MiSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF3482FF),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/widgets/voice_result_card.dart
git commit -m "feat: add VoiceResultCard with glassmorphism card and add button"
```

---

### Task 7: CalendarHomeScreen 集成 — 替换现有 overlay

**Files:**
- Modify: `lib/screens/calendar_home_screen.dart`

**Step 1: 导入新 widget**

在文件顶部添加：
```dart
import '../widgets/voice_overlay.dart';
import '../widgets/vt_card.dart';
```

**Step 2: 替换 `_buildLoadingOverlay` 和 `_buildCardOverlay`**

将现有的 `_buildLoadingOverlay` 方法替换为使用 VoiceOverlay：

```dart
Widget _buildVoiceOverlay(VoiceInputProvider p) {
  return Positioned.fill(
    child: VoiceOverlay(
      recognizedText: p.recognizedText,
      amplitudeStream: p.amplitudeStream,
      onTap: () async {
        if (p.state == VoiceInputState.recording) {
          await p.stopAndProcess();
        }
      },
    ),
  );
}
```

将现有的 `_buildCardOverlay` 替换为使用 VoiceResultCard：

```dart
Widget _buildResultOverlay(VoiceInputProvider p) {
  if (p.calendarItem == null) return const SizedBox.shrink();
  return Positioned.fill(
    child: Stack(
      children: [
        // 保持光晕背景
        VoiceOverlay(
          recognizedText: p.recognizedText,
          amplitudeStream: p.amplitudeStream,
          onTap: () => p.reset(),
        ),
        // 卡片区域
        Positioned(
          left: 0,
          top: 260,
          child: VoiceResultCard(
            item: p.calendarItem!,
            onAdd: () async {
              final saved = await p.confirmAndSave();
              if (saved && mounted) {
                _loadItems();
              }
            },
            onDismiss: () => p.reset(),
          ),
        ),
    ],
    ),
  );
}
```

**Step 3: 更新 build 方法中的 Stack children**

替换 Stack 中的 overlay 条件判断：

```dart
// 替换原有的三个 overlay 条件为：
if (provider.state == VoiceInputState.recording)
  _buildVoiceOverlay(provider),
if (provider.state == VoiceInputState.recognizing ||
    provider.state == VoiceInputState.parsing)
  _buildVoiceOverlay(provider),
if (provider.state == VoiceInputState.cardReady)
  _buildResultOverlay(provider),
if (provider.state == VoiceInputState.followUp)
  _buildFollowUpOverlay(provider),
```

**Step 4: 运行 app 验证 UI**

**Step 5: Commit**

```bash
git add lib/screens/calendar_home_scit commit -m "feat: integrate VoiceOverlay and VoiceResultCard into home screen"
```

---

### Task 8: main.dart — Mock 替换为真实实现

**Files:**
- Modify: `lib/main.dart`

**Step 1: 导入真实服务**

```dart
import 'services/real_audio_recorder_service.dart';
import 'services/zhipu_asr_service.dart';
```

**Step 2: 替换 Mock 实例化**

将 `VoiceInputProvider` 的创建改为：

```dart
final effectiveKey = zhipuKey.isNotEmpty
    ? zhipuKey
    : '84a93fd3afdd48fb8cc6780c16374ff1.KUHRgnNuXAH9v6ej';

final INluService nlu = effectiveKey.isNotEmpty
    ? ZhipuNluService(apiKey: effectiveKey)
    : MockNluService();

final IAsrSasr = effectiveKey.isNotEmpty
    ? ZhipuAsrService(apiKey: effectiveKey)
    : MockAsrService();

runApp(
  ChangeNotifierProvider(
    create: (_) => VoiceInputProvider(
      recorder: RealAudioRecorderService(),
      asr: asr,
      nlu: nlu,
      db: db,
    ),
    child: const CalendarApp(),
  ),
);
```

**Step 3: 运行 app 端到端验证**

在真机上测试完整流程：点击语音 → 说话 → 看到识别文字 → 看到卡片 → 点击添加

**Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire up real audio recorder and Zhipu ASR in main.dart"
```

---

### Task 9: iOS/Android 权限配置

**Files:**
- Modify: `ios/Runner/Info.plist`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Step 1: iOS — Info.plist 添加麦克风权限描述**

确认 `Info.plist` 中包含：
```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限来录制语音输入</string>
```

**Step 2: Android — AndroidManifest.xml 添加录音权限**

确认 `AndroidManifest.xml` 中包含：
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

**Step 3: Commit**

```bash
git add ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml
git commit -m "chore: add microphone permission for iOS and Android"
```

---

### Task 10: 端到端集成测试

**Step 1: 在真机上完整测试以下流程**

1. 冷启动 app → 首页正常显示
2. 点击语音 icon → 弹出麦克风权限请求 → 允许
3. 光晕背景出现 + 波形动画
4. 说"明天下午三点开会" → 波形跟随声音变化
5. 再次点击停止 → "识别中..." → 文字出现
6. "解析中..." → 卡片滑入，显示"开会"标题 + 时间
7. 点击"添加" → 事项保存，回到首页列表
8. 验证列表中出现新事项

**Step 2: 测试异常场景**

- 拒绝麦克风权限 → 显示错误提示
- 无网络 → 显示网络不可用
- 说话太短 → 显示录音过短提示
- 点击空白区域 → 取消返回首页

**Step 3: Final commit**

```bash
git commit -m "feat: voice input feature complete — record, ASR, NLU, UI"
```
