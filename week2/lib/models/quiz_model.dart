class QuizModel {
  final String question;
  final String type;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  QuizModel({
    required this.question,
    required this.type,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(
      question: json['question'] ?? '',
      type: json['type'] ?? 'multiple_choice',
      options: List<String>.from(json['options'] ?? []),
      correctIndex: json['correct_index'] ?? 0,
      explanation: json['explanation'] ?? '',
    );
  }

  // [MỚI] Hàm này giúp biến đổi Object thành JSON để lưu xuống máy
  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'type': type,
      'options': options,
      'correct_index': correctIndex,
      'explanation': explanation,
    };
  }
}
