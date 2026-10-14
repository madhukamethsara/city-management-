class ConsultationResults {
  const ConsultationResults({
    required this.consultationId,
    required this.totalResponses,
    required this.questions,
  });

  final String consultationId;
  final int totalResponses;
  final List<ConsultationQuestionResult> questions;
}

class ConsultationQuestionResult {
  const ConsultationQuestionResult({
    required this.id,
    required this.question,
    required this.allowsLongText,
    required this.responseCount,
    required this.optionCounts,
  });

  final String id;
  final String question;
  final bool allowsLongText;
  final int responseCount;
  final Map<String, int> optionCounts;
}
