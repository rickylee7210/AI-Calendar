import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
      if (!await file.exists()) {
        debugPrint('[ASR] 文件不存在: $audioFilePath');
        return null;
      }
      final fileSize = await file.length();
      debugPrint('[ASR] 文件大小: $fileSize bytes, 路径: $audioFilePath');

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          audioFilePath,
          filename: 'audio.wav',
        ),
        'model': 'glm-asr-2512',
      });

      final resp = await _dio.post(
        _endpoint,
        options: Options(headers: {
          'Authorization': 'Bearer $_apiKey',
        }),
        data: formData,
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
