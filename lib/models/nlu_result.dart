class NluResult {
  final String rawText;
  final Map<String, dynamic> extractedFields;
  final List<String> missingFields;
  final String? followUpQuestion;

  NluResult({
    required this.rawText,
    required this.extractedFields,
    this.missingFields = const [],
    this.followUpQuestion,
  });

  bool get isComplete => missingFields.isEmpty;

  factory NluResult.fromApiResponse(Map<String, dynamic> json) {
    return NluResult(
      rawText: json['raw_text'] ?? '',
      extractedFields: Map<String, dynamic>.from(json['fields'] ?? {}),
      missingFields: List<String>.from(json['missing_fields'] ?? []),
      followUpQuestion: json['follow_up_question'],
    );
  }
}
