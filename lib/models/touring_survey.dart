// lib/models/touring_survey.dart

import 'package:flutter/foundation.dart';
import 'survey_field.dart';

class TouringSurvey {
  final String id;
  final String touringTaskId;
  final String title;
  final String? description;
  final bool isRequired;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  
  // Optional expanded data when joined
  final List<SurveyField>? fields;

  TouringSurvey({
    required this.id,
    required this.touringTaskId,
    required this.title,
    this.description,
    required this.isRequired,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.fields,
  });

  factory TouringSurvey.fromJson(Map<String, dynamic> json) {
    try {
      return TouringSurvey(
        id: (json['id'] ?? '').toString(),
        touringTaskId: (json['touring_task_id'] ?? '').toString(),
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
        createdBy: json['created_by']?.toString(),
        fields: json['fields'] != null && json['fields'] is List
            ? (json['fields'] as List).map((field) => SurveyField.fromJson(field)).toList()
            : null,
      );
    } catch (e) {
      debugPrint('Error parsing TouringSurvey: $e');
      debugPrint('JSON data: $json');
      // Return a default survey with safe values
      return TouringSurvey(
        id: (json['id'] ?? '').toString(),
        touringTaskId: (json['touring_task_id'] ?? '').toString(),
        title: (json['title'] ?? 'Unknown Survey').toString(),
        isRequired: true,
        isActive: true,
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'touring_task_id': touringTaskId,
      'title': title,
      'description': description,
      'is_required': isRequired,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }

  // Helper methods
  bool get hasFields => fields != null && fields!.isNotEmpty;
  
  int get fieldCount => fields?.length ?? 0;
  
  int get requiredFieldCount => fields?.where((field) => field.isRequired).length ?? 0;
  
  List<SurveyField> get orderedFields {
    if (fields == null) return [];
    final sortedFields = List<SurveyField>.from(fields!);
    sortedFields.sort((a, b) => a.fieldOrder.compareTo(b.fieldOrder));
    return sortedFields;
  }
  
  TouringSurvey copyWith({
    String? id,
    String? touringTaskId,
    String? title,
    String? description,
    bool? isRequired,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    List<SurveyField>? fields,
  }) {
    return TouringSurvey(
      id: id ?? this.id,
      touringTaskId: touringTaskId ?? this.touringTaskId,
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TouringSurvey && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TouringSurvey(id: $id, title: $title, touringTaskId: $touringTaskId, fieldCount: $fieldCount)';
  }
}