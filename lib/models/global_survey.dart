// lib/models/global_survey.dart

import 'survey_field.dart';

class GlobalSurvey {
  final String id;
  final String title;
  final String? description;
  final bool isRequired;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final List<SurveyField>? fields;

  GlobalSurvey({
    required this.id,
    required this.title,
    this.description,
    required this.isRequired,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    this.fields,
  });

  factory GlobalSurvey.fromJson(Map<String, dynamic> json) {
    return GlobalSurvey(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      isRequired: json['is_required'] ?? true,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
      createdBy: (json['created_by'] ?? '').toString(),
      fields: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'is_required': isRequired,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }

  bool get hasFields => fields != null && fields!.isNotEmpty;
  int get fieldCount => fields?.length ?? 0;

  List<SurveyField> get orderedFields {
    if (fields == null) return [];
    final sorted = List<SurveyField>.from(fields!);
    sorted.sort((a, b) => a.fieldOrder.compareTo(b.fieldOrder));
    return sorted;
  }

  GlobalSurvey copyWith({
    String? id,
    String? title,
    String? description,
    bool? isRequired,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    List<SurveyField>? fields,
  }) {
    return GlobalSurvey(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isRequired: isRequired ?? this.isRequired,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      fields: fields ?? this.fields,
    );
  }
}

