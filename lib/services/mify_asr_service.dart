import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'interfaces.dart';

/// 统一 AI 服务，使用 OpenAI 兼容接口（代理 Claude）
class MifyAiService implements IAsrService {
  final Dio _dio;
  final String _apiKey;
  final String _model;
  static const _endpoint = 'http://model.mify.ai.srv/v1/chat/completions';

  MifyAiService({
    required String apiKey,
    String model = 'ppio/pa/claude-sonnet-4-6',
    Dio? dio,
  })  : _apiKey = apiKey,
        _model = model,
        _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ));

  /// ASR：发送音频 base64 给 Claude，让它转录文字
  @override
  Future<String?> recognize(String audioFilePath) async {
    try {
      final file = File(audioFilePath);
      if (!await file.exists()) {
        debugPrint('[ASR] 文件不存在: $audioFilePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);
      final fileSize = bytes.length;
      debugPrint('[ASR] 文件大小: $fileSize bytes, 路径: $audioFilePath');

      // 判断音频格式
      final ext = audioFilePath.split('.').last.toLowerCase();
      final mediaType = ext == 'mp3' ? 'audio/mp3' : 'audio/wav';

      final resp = await _dio.post(
        _endpoint,
        options: Options(headers: {
          'api-key': _apiKey,
          'Content-Type': 'application/json',
        }),
        data: {
          'model': _model,
          'max_tokens': 500,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'input_audio',
                  'input_audio': {
                    'data': base64Audio,
                    'format': ext == 'mp3' ? 'mp3' : 'wav',
                  },
                },
                {
                  'type': 'text',
                  'text': '请将这段音频精确转录为文字，只输出转录结果，不要添加任何解释或标点修改。',
                },
              ],
            },
          ],
        },
      );

      debugPrint('[ASR] 响应: ${resp.data}');

      final choices = resp.data['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;

      final content = choices[0]['message']['content'] as String?;
      return content?.trim().isEmpty == true ? null : content?.trim();
    } on DioException catch (e) {
      debugPrint('[ASR] DioException: ${e.type} - ${e.response?.statusCode} - ${e.response?.data}');
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        throw AsrTimeoutException();
      }
      rethrow;
    }
  }
}
