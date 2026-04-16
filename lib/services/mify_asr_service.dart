import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'interfaces.dart';

/// ASR 服务，使用火山引擎语音识别（通过 mify 网关）
class MifyAiService implements IAsrService {
  final Dio _dio;
  final String _apiKey;
  static const _endpoint = 'http://model.mify.ai.srv/v1/audio/transcriptions';

  MifyAiService({
    required String apiKey,
    Dio? dio,
  })  : _apiKey = apiKey,
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

      final resp = await _dio.post(
        _endpoint,
        options: Options(headers: {
          'api-key': _apiKey,
          'X-Model-Provider-Id': 'volcengine_maas',
          'Content-Type': 'application/json',
        }),
        data: {
          'audio': {'data': base64Audio},
          'model': 'volc.bigasr.auc_turbo',
        },
      );

      debugPrint('[ASR] 响应: ${resp.data}');

      final text = resp.data['text'] as String?;
      return text?.trim().isEmpty == true ? null : text?.trim();
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
