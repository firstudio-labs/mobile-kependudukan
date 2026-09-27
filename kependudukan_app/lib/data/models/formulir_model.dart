class FormulirModel {
  final int id;
  final String title;
  final String? description;
  final String status;
  final String displayLocation;
  final DateTime? createdAt;
  final bool isFilled;
  final List<FormulirQuestionModel> questions;

  FormulirModel({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.displayLocation,
    this.createdAt,
    required this.isFilled,
    required this.questions,
  });

  factory FormulirModel.fromJson(Map<String, dynamic> json) {
    return FormulirModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      // Map is_active (int/bool) to status string or use existing status if valid
      status: json['status'] ?? (json['is_active'] == 1 ? 'Active' : 'Inactive'),
      displayLocation: json['display_location'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      isFilled: json['is_filled'] ?? false,
      questions: (json['questions'] as List?)
              ?.map((q) => FormulirQuestionModel.fromJson(q))
              .toList() ??
          [],
    );
  }
}

class FormulirQuestionModel {
  final int id;
  final String questionText;
  final String questionType;
  final List<String>? options;

  FormulirQuestionModel({
    required this.id,
    required this.questionText,
    required this.questionType,
    this.options,
  });

  factory FormulirQuestionModel.fromJson(Map<String, dynamic> json) {
    return FormulirQuestionModel(
      id: json['id'],
      questionText: json['question_text'],
      questionType: json['question_type'],
      options: json['options'] != null ? List<String>.from(json['options']) : null,
    );
  }
}
