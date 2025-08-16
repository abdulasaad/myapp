// lib/models/survey_field.dart

import 'package:flutter/foundation.dart';

enum SurveyFieldType {
  text,
  number,
  select,
  multiselect,
  boolean,
  date,
  textarea,
  rating,
  photo,
}

class SurveyFieldValidation {
  final int? minLength;
  final int? maxLength;
  final num? minValue;
  final num? maxValue;
  final String? pattern; // Regex pattern
  final String? errorMessage;

  SurveyFieldValidation({
    this.minLength,
    this.maxLength,
    this.minValue,
    this.maxValue,
    this.pattern,
    this.errorMessage,
  });

  factory SurveyFieldValidation.fromJson(Map<String, dynamic> json) {
    return SurveyFieldValidation(
      minLength: json['min_length']?.toInt(),
      maxLength: json['max_length']?.toInt(),
      minValue: json['min_value']?.toDouble(),
      maxValue: json['max_value']?.toDouble(),
      pattern: json['pattern']?.toString(),
      errorMessage: json['error_message']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (minLength != null) 'min_length': minLength,
      if (maxLength != null) 'max_length': maxLength,
      if (minValue != null) 'min_value': minValue,
      if (maxValue != null) 'max_value': maxValue,
      if (pattern != null) 'pattern': pattern,
      if (errorMessage != null) 'error_message': errorMessage,
    };
  }
}

class SurveyField {
  final String id;
  final String surveyId;
  final String fieldName;
  final SurveyFieldType fieldType;
  final String fieldLabel;
  final String? fieldPlaceholder;
  final List<String>? fieldOptions; // For select/multiselect
  final bool isRequired;
  final int fieldOrder;
  final SurveyFieldValidation? validationRules;
  final DateTime createdAt;

  SurveyField({
    required this.id,
    required this.surveyId,
    required this.fieldName,
    required this.fieldType,
    required this.fieldLabel,
    this.fieldPlaceholder,
    this.fieldOptions,
    required this.isRequired,
    required this.fieldOrder,
    this.validationRules,
    required this.createdAt,
  });

  factory SurveyField.fromJson(Map<String, dynamic> json) {
    try {
      // Parse field type
      SurveyFieldType fieldType = SurveyFieldType.text;
      final typeString = json['field_type']?.toString() ?? 'text';
      try {
        fieldType = SurveyFieldType.values.firstWhere(
          (type) => type.name == typeString,
        );
      } catch (e) {
        debugPrint('Unknown field type: $typeString, defaulting to text');
        fieldType = SurveyFieldType.text;
      }

      // Parse field options from JSONB
      List<String>? fieldOptions;
      if (json['field_options'] != null) {
        try {
          final optionsData = json['field_options'];
          if (optionsData is Map && optionsData['options'] is List) {
            fieldOptions = (optionsData['options'] as List)
                .map((option) => option.toString())
                .toList();
          } else if (optionsData is List) {
            fieldOptions = optionsData.map((option) => option.toString()).toList();
          }
        } catch (e) {
          debugPrint('Error parsing field options: $e');
        }
      }

      // Parse validation rules from JSONB
      SurveyFieldValidation? validationRules;
      if (json['validation_rules'] != null) {
        try {
          final rulesData = json['validation_rules'];
          if (rulesData is Map<String, dynamic>) {
            validationRules = SurveyFieldValidation.fromJson(rulesData);
          }
        } catch (e) {
          debugPrint('Error parsing validation rules: $e');
        }
      }

      return SurveyField(
        id: (json['id'] ?? '').toString(),
        surveyId: (json['survey_id'] ?? '').toString(),
        fieldName: (json['field_name'] ?? '').toString(),
        fieldType: fieldType,
        fieldLabel: (json['field_label'] ?? '').toString(),
        fieldPlaceholder: json['field_placeholder']?.toString(),
        fieldOptions: fieldOptions,
        isRequired: json['is_required'] ?? false,
        fieldOrder: json['field_order'] ?? 0,
        validationRules: validationRules,
        createdAt: json['created_at'] != null 
            ? DateTime.parse(json['created_at'].toString()) 
            : DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error parsing SurveyField: $e');
      debugPrint('JSON data: $json');
      // Return a default field with safe values
      return SurveyField(
        id: (json['id'] ?? '').toString(),
        surveyId: (json['survey_id'] ?? '').toString(),
        fieldName: (json['field_name'] ?? 'unknown_field').toString(),
        fieldType: SurveyFieldType.text,
        fieldLabel: (json['field_label'] ?? 'Unknown Field').toString(),
        isRequired: false,
        fieldOrder: 0,
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    final json = {
      'id': id,
      'survey_id': surveyId,
      'field_name': fieldName,
      'field_type': fieldType.name,
      'field_label': fieldLabel,
      'field_placeholder': fieldPlaceholder,
      'is_required': isRequired,
      'field_order': fieldOrder,
      'created_at': createdAt.toIso8601String(),
    };

    // Add field options if present
    if (fieldOptions != null && fieldOptions!.isNotEmpty) {
      json['field_options'] = {'options': fieldOptions};
    }

    // Add validation rules if present
    if (validationRules != null) {
      json['validation_rules'] = validationRules!.toJson();
    }

    return json;
  }

  // Helper methods
  bool get hasOptions => fieldOptions != null && fieldOptions!.isNotEmpty;
  
  bool get hasValidation => validationRules != null;
  
  bool get isSelectType => fieldType == SurveyFieldType.select || fieldType == SurveyFieldType.multiselect;
  
  bool get isNumericType => fieldType == SurveyFieldType.number || fieldType == SurveyFieldType.rating;
  
  bool get isTextType => fieldType == SurveyFieldType.text || fieldType == SurveyFieldType.textarea;
  
  String get typeDisplayName {
    switch (fieldType) {
      case SurveyFieldType.text:
        return 'Text';
      case SurveyFieldType.number:
        return 'Number';
      case SurveyFieldType.select:
        return 'Single Select';
      case SurveyFieldType.multiselect:
        return 'Multi Select';
      case SurveyFieldType.boolean:
        return 'Yes/No';
      case SurveyFieldType.date:
        return 'Date';
      case SurveyFieldType.textarea:
        return 'Long Text';
      case SurveyFieldType.rating:
        return 'Rating';
      case SurveyFieldType.photo:
        return 'Photo';
    }
  }

  // Validation methods
  String? validateValue(dynamic value) {
    if (isRequired && (value == null || value.toString().trim().isEmpty)) {
      return '$fieldLabel is required';
    }

    if (value == null || value.toString().trim().isEmpty) {
      return null; // Valid if not required and empty
    }

    final validation = validationRules;
    if (validation == null) return null;

    final stringValue = value.toString();

    // Text length validation
    if (validation.minLength != null && stringValue.length < validation.minLength!) {
      return validation.errorMessage ?? '$fieldLabel must be at least ${validation.minLength} characters';
    }

    if (validation.maxLength != null && stringValue.length > validation.maxLength!) {
      return validation.errorMessage ?? '$fieldLabel must not exceed ${validation.maxLength} characters';
    }

    // Numeric value validation
    if (isNumericType) {
      final numValue = num.tryParse(stringValue);
      if (numValue == null) {
        return '$fieldLabel must be a valid number';
      }

      if (validation.minValue != null && numValue < validation.minValue!) {
        return validation.errorMessage ?? '$fieldLabel must be at least ${validation.minValue}';
      }

      if (validation.maxValue != null && numValue > validation.maxValue!) {
        return validation.errorMessage ?? '$fieldLabel must not exceed ${validation.maxValue}';
      }
    }

    // Pattern validation
    if (validation.pattern != null && validation.pattern!.isNotEmpty) {
      final regex = RegExp(validation.pattern!);
      if (!regex.hasMatch(stringValue)) {
        return validation.errorMessage ?? '$fieldLabel format is invalid';
      }
    }

    return null; // Valid
  }

  SurveyField copyWith({
    String? id,
    String? surveyId,
    String? fieldName,
    SurveyFieldType? fieldType,
    String? fieldLabel,
    String? fieldPlaceholder,
    List<String>? fieldOptions,
    bool? isRequired,
    int? fieldOrder,
    SurveyFieldValidation? validationRules,
    DateTime? createdAt,
  }) {
    return SurveyField(
      id: id ?? this.id,
      surveyId: surveyId ?? this.surveyId,
      fieldName: fieldName ?? this.fieldName,
      fieldType: fieldType ?? this.fieldType,
      fieldLabel: fieldLabel ?? this.fieldLabel,
      fieldPlaceholder: fieldPlaceholder ?? this.fieldPlaceholder,
      fieldOptions: fieldOptions ?? this.fieldOptions,
      isRequired: isRequired ?? this.isRequired,
      fieldOrder: fieldOrder ?? this.fieldOrder,
      validationRules: validationRules ?? this.validationRules,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SurveyField && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SurveyField(id: $id, fieldName: $fieldName, fieldType: ${fieldType.name}, isRequired: $isRequired)';
  }
}