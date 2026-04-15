import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'interfaces.dart';

/// ASR 服务，使用 mify 内网 Whisper API
class MifyWhisperService implements IAsrService {
  final Dio _dio;
  final String _apiKey;
  final String _model;
  static const _endpoint = 'http://model.mify.ai.srv/v1/audio/transcriptions';

  MifyWhisperService({
    required String apiKey,
    String model = 'whisper',
    Dio? dio,
  })  : _apiKey = apiKey,
        _model = model,
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
      debugPrint('[ASR] 文件大小: $fileSize bytes, model: $_model');

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          audioFilePath,
          filename: 'audio.wav',
        ),
        'model': _model,
      });

      final resp = await _dio.post(
        _endpoint,
        options: Options(headers: {
          'api-key': _apiKey,
          'X-Model': _model,
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
