import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'interfaces.dart';

/// 统一 AI 服务，使用 OpenAI 兼容接口（mimo-v2-omni 多模态 ASR）
class MifyAiService implements IAsrService {
  final Dio _dio;
  final String _apiKey;
  final String _model;
  static const _endpoint = 'http://model.mify.ai.srv/v1/chat/completions';

  MifyAiService({
    required String apiKey,
    String model = 'xiaomi/mimo-v2-omni',
    Dio? dio,
  })  : _apiKey = apiKey,
        _model = model,
        _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ));

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
      debugPrint('[ASR] 文件大小: ${bytes.length} bytes');

      final ext = audioFilePath.split('.').last.toLowerCase();

      final resp = await _dio.post(
        _endpoint,
        options: Options(headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': _model,
          'max_tokens': 100,
          'temperature': 0,
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
                  'text': '转录音频，只输出文字。',
                },
              ],
            },
          ],
        },
      );

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
