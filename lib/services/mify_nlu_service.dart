import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/nlu_result.dart';
import 'interfaces.dart';

/// NLU 服务，使用 OpenAI 兼容接口（代理 Claude）+ function calling
class MifyNluService implements INluService {
  final Dio _dio;
  final String _apiKey;
  final String _model;
  static const _endpoint = 'http://model.mify.ai.srv/v1/chat/completions';

  MifyNluService({
    required String apiKey,
    String model = 'ppio/pa/claude-sonnet-4-6',
    Dio? dio,
  })  : _apiKey = apiKey,
        _model = model,
        _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ));

  String get _systemPrompt {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final weekday = ['一', '二', '三', '四', '五', '六', '日'][now.weekday - 1];
    return '你是一个日历助手。用户会用自然语言描述一个事项。'
        '请调用 extract_calendar_item 函数提取结构化信息。'
        '规则：'
        'title=事项标题（简洁概括，去掉时间词）；'
        'date=YYYY-MM-DD格式日期；time=HH:mm格式时间；'
        'type=schedule(有任何时间信息的日程)/todo(完全没有时间信息的待办)/reminder(用户明确说"提醒"且有时间)；'
        'reminder=提前提醒分钟数(日程默认15,待办默认0)。'
        '\n模糊时间自动补全规则：'
        '早上/早晨→08:00，上午→09:00，中午→12:00，下午→14:00，傍晚→18:00，晚上→20:00。'
        '如果只说了日期没说时间（如"明天交报告"），默认time=09:00。'
        '如果只说了时间没说日期（如"晚上吃药"），默认date=今天。'
        '如果完全没有时间信息（如"买牛奶"），type设为todo，不填date和time。'
        '\n不要追问，不要填missing_fields，直接根据已有信息判断。'
        '\n当前日期: $today (周$weekday)';
  }

  List<Map<String, dynamic>> get _tools => [
    {
      'type': 'function',
      'function': {
        'name': 'extract_calendar_item',
        'description': '从用户自然语言中提取日历事项的结构化信息',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': '事项标题'},
            'date': {'type': 'string', 'description': '日期 YYYY-MM-DD'},
            'time': {'type': 'string', 'description': '时间 HH:mm'},
            'type': {
              'type': 'string',
              'enum': ['schedule', 'todo', 'reminder'],
            },
            'reminder': {'type': 'integer', 'description': '提前提醒分钟数'},
            'missing_fields': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': '仅填date或time中缺少的字段',
            },
            'follow_up_question': {'type': 'string', 'description': '仅当date或time缺失时追问'},
          },
          'required': ['title', 'type', 'missing_fields'],
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
      {'role': 'user', 'content': '已知信息: $ctx\n用户补充: $answer'},
    ], answer);
  }

  Future<NluResult> _call(List<Map<String, String>> messages, String raw) async {
    try {
      debugPrint('[NLU] 请求: $raw');
      final resp = await _dio.post(
        _endpoint,
        options: Options(headers: {
          'api-key': _apiKey,
          'Content-Type': 'application/json',
        }),
        data: {
          'model': _model,
          'messages': messages,
          'tools': _tools,
          'tool_choice': {'type': 'function', 'function': {'name': 'extract_calendar_item'}},
          'max_tokens': 500,
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

        final rawMissing = List<String>.from(fields.remove('missing_fields') ?? []);
        fields.remove('follow_up_question');

        return NluResult(
          rawText: raw,
          extractedFields: fields,
          missingFields: const [],
        );
      }

      // Fallback: model returned text instead of tool call
      final content = msg['content'] as String?;
      if (content != null && content.isNotEmpty) {
        return NluResult(
          rawText: raw,
          extractedFields: {'title': raw, 'type': 'todo'},
          missingFields: const [],
        );
      }

      throw NluParseException();
    } on DioException catch (e) {
      debugPrint('[NLU] DioException: ${e.type} - ${e.response?.statusCode} - ${e.response?.data}');
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        throw NluTimeoutException();
      }
      rethrow;
    }
  }
}
