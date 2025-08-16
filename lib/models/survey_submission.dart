// lib/models/survey_submission.dart

import 'package:flutter/foundation.dart';

class SurveySubmission {
  final String id;
  final String surveyId;
  final String agentId;
  final String? sessionId;
  final String touringTaskId;
  final Map<String, dynamic> submissionData;
  final DateTime submittedAt;
  final DateTime? updatedAt;
  final double? latitude;
  final double? longitude;

  SurveySubmission({
    required this.id,
    required this.surveyId,
    required this.agentId,
    this.sessionId,
    required this.touringTaskId,
    required this.submissionData,
    required this.submittedAt,
    this.updatedAt,
    this.latitude,
    this.longitude,
  });

  factory SurveySubmission.fromJson(Map<String, dynamic> json) {
    try {
      // Parse submission data from JSONB
      Map<String, dynamic> submissionData = {};
      if (json['submission_data'] != null) {
        try {
          final data = json['submission_data'];
          if (data is Map<String, dynamic>) {
            submissionData = Map<String, dynamic>.from(data);
          } else if (data is String) {
            // Try to decode if it's a JSON string
            submissionData = Map<String, dynamic>.from(
              Map.castFrom(json['submission_data'])
            );
          }
        } catch (e) {
          debugPrint('Error parsing submission data: $e');
          submissionData = {};
        }
      }

      return SurveySubmission(
        id: (json['id'] ?? '').toString(),
        surveyId: (json['survey_id'] ?? '').toString(),
        agentId: (json['agent_id'] ?? '').toString(),
        sessionId: json['session_id']?.toString(),
        touringTaskId: (json['touring_task_id'] ?? '').toString(),
        submissionData: submissionData,
        submittedAt: json['submitted_at'] != null 
            ? DateTime.parse(json['submitted_at'].toString()) 
            : DateTime.now(),
        updatedAt: json['updated_at'] != null 
            ? DateTime.parse(json['updated_at'].toString()) 
            : null,
        latitude: json['latitude']?.toDouble(),
        longitude: json['longitude']?.toDouble(),
      );
    } catch (e) {
      debugPrint('Error parsing SurveySubmission: $e');
      debugPrint('JSON data: $json');
      // Return a default submission with safe values
      return SurveySubmission(
        id: (json['id'] ?? '').toString(),
        surveyId: (json['survey_id'] ?? '').toString(),
        agentId: (json['agent_id'] ?? '').toString(),
        touringTaskId: (json['touring_task_id'] ?? '').toString(),
        submissionData: {},
        submittedAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'survey_id': surveyId,
      'agent_id': agentId,
      'session_id': sessionId,
      'touring_task_id': touringTaskId,
      'submission_data': submissionData,
      'submitted_at': submittedAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Helper methods
  bool get hasLocation => latitude != null && longitude != null;
  
  int get fieldCount => submissionData.length;
  
  bool get isEmpty => submissionData.isEmpty;
  
  // Get value for a specific field
  T? getFieldValue<T>(String fieldName) {
    final value = submissionData[fieldName];
    if (value is T) {
      return value;
    }
    return null;
  }

  // Get string value for a field (handles type conversion)
  String? getFieldValueAsString(String fieldName) {
    final value = submissionData[fieldName];
    if (value == null) return null;
    if (value is String) return value;
    if (value is List) return value.join(', ');
    return value.toString();
  }

  // Get list value for multi-select fields
  List<String>? getFieldValueAsList(String fieldName) {
    final value = submissionData[fieldName];
    if (value == null) return null;
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    if (value is String) {
      return [value];
    }
    return null;
  }

  // Get numeric value for number/rating fields
  num? getFieldValueAsNumber(String fieldName) {
    final value = submissionData[fieldName];
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value);
    }
    return null;
  }

  // Get boolean value for boolean fields
  bool? getFieldValueAsBool(String fieldName) {
    final value = submissionData[fieldName];
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is num) {
      return value != 0;
    }
    return null;
  }

  // Get DateTime value for date fields
  DateTime? getFieldValueAsDateTime(String fieldName) {
    final value = submissionData[fieldName];
    if (value == null) return null;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        debugPrint('Error parsing date value: $value');
        return null;
      }
    }
    return null;
  }

  // Check if a field has a value
  bool hasFieldValue(String fieldName) {
    final value = submissionData[fieldName];
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    return true;
  }

  // Set field value (for building submissions)
  SurveySubmission setFieldValue(String fieldName, dynamic value) {
    final newData = Map<String, dynamic>.from(submissionData);
    if (value == null) {
      newData.remove(fieldName);
    } else {
      newData[fieldName] = value;
    }
    
    return copyWith(submissionData: newData);
  }

  // Remove field value
  SurveySubmission removeFieldValue(String fieldName) {
    final newData = Map<String, dynamic>.from(submissionData);
    newData.remove(fieldName);
    return copyWith(submissionData: newData);
  }

  // Get all field names that have values
  List<String> get populatedFieldNames => submissionData.keys.toList();

  // Get formatted submission summary
  String getSubmissionSummary({int maxFields = 3}) {
    if (isEmpty) return 'No data submitted';
    
    final entries = submissionData.entries.take(maxFields);
    final summary = entries.map((entry) {
      final value = getFieldValueAsString(entry.key) ?? 'No value';
      return '${entry.key}: ${value.length > 30 ? '${value.substring(0, 30)}...' : value}';
    }).join('\n');
    
    final remaining = submissionData.length - maxFields;
    if (remaining > 0) {
      return '$summary\n... and $remaining more fields';
    }
    
    return summary;
  }

  SurveySubmission copyWith({
    String? id,
    String? surveyId,
    String? agentId,
    String? sessionId,
    String? touringTaskId,
    Map<String, dynamic>? submissionData,
    DateTime? submittedAt,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
  }) {
    return SurveySubmission(
      id: id ?? this.id,
      surveyId: surveyId ?? this.surveyId,
      agentId: agentId ?? this.agentId,
      sessionId: sessionId ?? this.sessionId,
      touringTaskId: touringTaskId ?? this.touringTaskId,
      submissionData: submissionData ?? this.submissionData,
      submittedAt: submittedAt ?? this.submittedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SurveySubmission && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SurveySubmission(id: $id, surveyId: $surveyId, agentId: $agentId, fieldCount: $fieldCount)';
  }
}