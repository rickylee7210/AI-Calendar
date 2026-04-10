import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/nlu_result.dart';
import 'interfaces.dart';

class ZhipuNluService implements INluService {
  final Dio _dio;
  final String _apiKey;
  static const _endpoint = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  static const _model = 'glm-4-flash';

  ZhipuNluService({required String apiKey, Dio? dio})
      : _apiKey = apiKey,
        _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  String get _systemPrompt {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final weekday = ['一', '二', '三', '四', '五', '六', '日'][now.weekday - 1];
    return '日历助手。提取事项信息，调用extract_calendar_item。'
        '规则：title=简洁标题；'
        'type=schedule(有时间)/todo(无时间)/reminder(明确说提醒且有时间)；'
        'date=YYYY-MM-DD；time=HH:mm；reminder=提前分钟数。'
        '模糊时间：早上08:00,上午09:00,中午12:00,下午14:00,晚上20:00。'
        '只有日期没时间→time=09:00。只有时间没日期→date=今天。'
        '完全没时间（如买菜）→type=todo，不填date/time。'
        '今天:$today(周$weekday)';
  }

  List<Map<String, dynamic>> get _tools => [
    {
      'type': 'function',
      'function': {
        'name': 'extract_calendar_item',
        'description': '提取日历事项',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'date': {'type': 'string'},
            'time': {'type': 'string'},
            'type': {'type': 'string', 'enum': ['schedule', 'todo', 'reminder']},
            'reminder': {'type': 'integer'},
          },
          'required': ['title', 'type'],
        },
      },
    },
  ];

  @override
  Future<NluResult> parse(String text) async {
    return _call([
      {'role': 'system', 'content': _systemPrompt},
      {'role': 'user', 'content': text},
    ], text);
  }

  @override
  Future<NluResult> parseFollowUp(String answer, {
    required Map<String, dynamic> context,
  }) async {
    final ctx = context.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    return _call([
      {'role': 'system', 'content': _systemPrompt},
      {'role': 'user', 'content': '已知:$ctx\n补充:$answer'},
    ], answer);
  }

  Future<NluResult> _call(List<Map<String, String>> messages, String raw) async {
    try {
      debugPrint('[NLU] 请求: $raw');
      final resp = await _dio.post(_endpoint,
        options: Options(headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        }),
        data: {
        'model': _model,
          'messages': messages,
          'tools': _tools,
          'tool_choice': {'type': 'function', 'function': {'name': 'extract_calendar_item'}},
          'max_tokens': 200,
        },
      );

      debugPrint('[NLU] 响应: ${resp.data}');
      final data = resp.data;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) throw NluParseException();

      final msg = choices[0]['message'] as Map<String, dynamic>;
      final toolCalls = msg['tool_calls'] as List?;

      if (toolCalls != null && toolCalls.isNotEmpty) {
        final argsRaw = toolCalls[0]['function']['arguments'];
        final Map<String, dynamic> fields = argsRaw is String
            ? Map<String, dynamic>.from(jsonDecode(argsRaw))
            : Map<String, dynamic>.from(argsRaw as Map);
        fields.remove('missing_fields');
        fields.remove('follow_up_question');
        return NluResult(rawText: raw, extractedFields: fields, missingFields: const []);
      }

      // Fallback
      return NluResult(
        rawText: raw,
        extractedFields: {'title': raw, 'type': 'todo'},
        missingFields: const [],
      );
    } on DioException catch (e) {
      debugPrint('[NLU] DioException: ${e.type}');
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        throw NluTimeoutException();
      }
      rethrow;
    }
  }
}
