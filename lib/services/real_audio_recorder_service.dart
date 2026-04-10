import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'interfaces.dart';

class RealAudioRecorderService implements IAudioRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  final _amplitudeCtl = StreamController<double>.broadcast();
  Timer? _ampTimer;
  String? _pcmPath;

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<double> get amplitudeStream => _amplitudeCtl.stream;

  @override
  Future<void> startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) throw MicPermissionDeniedException();

    final dir = Directory.systemTemp;
    _pcmPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.pcm';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _pcmPath!,
    );
    _isRecording = true;

    _ampTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final amp = await _recorder.getAmplitude();
      final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
      _amplitudeCtl.add(normalized);
    });
  }

  @override
  Future<String?> stopRecording() async {
    _ampTimer?.cancel();
    _ampTimer = null;
    _isRecording = false;
    final pcmPath = await _recorder.stop();
    if (pcmPath == null) return null;

    // PCM → WAV：手动加 WAV 头，确保智谱 ASR 能正确解析
    try {
      final wavPath = pcmPath.replaceAll('.pcm', '.wav');
      await _pcmToWav(pcmPath, wavPath, sampleRate: 16000, numChannels: 1);
      // 删除原始 PCM
      await File(pcmPath).delete().catchError((_) => File(pcmPath));
      debugPrint('[Recorder] WAV 文件: $wavPath, 大小: ${await File(wavPath).length()} bytes');
      return wavPath;
    } catch (e) {
      debugPrint('[Recorder] PCM→WAV 转换失败: $e');
      return null;
    }
  }

  /// 将原始 PCM 数据包装为标准 WAV 文件，并归一化音量
  static Future<void> _pcmToWav(
    String pcmPath,
    String wavPath, {
    required int sampleRate,
    required int numChannels,
    int bitsPerSample = 16,
  }) async {
    final pcmFile = File(pcmPath);
    final pcmBytes = await pcmFile.readAsBytes();
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;

    // 读取 PCM 采样并归一化音量
    final sampleCount = pcmBytes.length ~/ 2;
    final samples = Int16List(sampleCount);
    final byteData = ByteData.sublistView(pcmBytes);
    int maxAbs = 0;
    for (int i = 0; i < sampleCount; i++) {
      final s = byteData.getInt16(i * 2, Endian.little);
      samples[i] = s;
      final abs = s < 0 ? -s : s;
      if (abs > maxAbs) maxAbs = abs;
    }

    // 归一化到 80% 满幅，避免削波
    if (maxAbs > 0 && maxAbs < 26000) {
      final gain = 26000.0 / maxAbs;
      debugPrint('[Recorder] 音量归一化: maxAbs=$maxAbs, gain=${gain.toStringAsFixed(1)}x');
      for (int i = 0; i < sampleCount; i++) {
        final boosted = (samples[i] * gain).round().clamp(-32767, 32767);
        samples[i] = boosted;
      }
    }

    final normalizedBytes = Uint8List(sampleCount * 2);
    final normalizedData = ByteData.sublistView(normalizedBytes);
    for (int i = 0; i < sampleCount; i++) {
      normalizedData.setInt16(i * 2, samples[i], Endian.little);
    }

    final dataSize = normalizedBytes.length;
    final header = ByteData(44);
    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final wavFile = File(wavPath);
    final sink = wavFile.openWrite();
    sink.add(header.buffer.asUint8List());
    sink.add(normalizedBytes);
    await sink.close();
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
