import '../models/nlu_result.dart';
import 'interfaces.dart';

/// Mock NLU service for development. Replace with ZhipuNluService for production.
class MockNluService implements INluService {
  final bool shouldTimeout;
  final Duration delay;

  MockNluService({
    this.shouldTimeout = false,
    this.delay = const Duration(milliseconds: 300),
  });

  @override
  Future<NluResult> parse(String text) async {
    await Future.delayed(delay);
    if (shouldTimeout) throw NluTimeoutException();

    // Simple keyword-based mock logic
    final hasTime = RegExp(r'[上下]午|点|时|\d{1,2}:\d{2}').hasMatch(text);
    final hasDate = RegExp(r'明天|后天|下周|周[一二三四五六日末]|\d{1,2}月').hasMatch(text);

    final title = text
        .replaceAll(RegExp(r'明天|后天|下周|周[一二三四五六日末]'), '')
        .replaceAll(RegExp(r'[上下]午\d{1,2}点'), '')
        .replaceAll(RegExp(r'提醒我'), '')
        .replaceAll(RegExp(r'找时间|找一天'), '')
        .trim();

    final fields = <String, dynamic>{
      'title': title.isEmpty ? text : title,
      'type': text.contains('提醒') ? 'reminder' : 'schedule',
    };

    final missing = <String>[];
    String? followUp;

    if (hasDate) {
      fields['date'] = '2026-04-02';
    } else {
      missing.add('date');
    }
    if (hasTime) {
      fields['time'] = '15:00';
    } else {
      missing.add('time');
    }

    if (missing.isNotEmpty) {
      followUp = missing.contains('date')
          ? '需要安排在哪一天？'
          : '需要安排在什么时间？';
    }

    return NluResult(
      rawText: text,
      extractedFields: fields,
      missingFields: missing,
      followUpQuestion: followUp,
    );
  }

  @override
  Future<NluResult> parseFollowUp(
    String answer, {
    required Map<String, dynamic> context,
  }) async {
    await Future.delayed(delay);
    if (shouldTimeout) throw NluTimeoutException();

    return NluResult(
      rawText: answer,
      extractedFields: {
        ...context,
        'date': '2026-04-05',
        'time': '10:00',
      },
    );
  }
}

// TODO: Implement ZhipuNluService with real 智谱 GLM API
// class ZhipuNluService implements INluService { ... }
