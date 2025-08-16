// lib/models/global_survey_submission.dart

class GlobalSurveySubmission {
  final String id;
  final String surveyId;
  final String agentId;
  final Map<String, dynamic> submissionData;
  final DateTime submittedAt;
  final DateTime? updatedAt;
  final double? latitude;
  final double? longitude;

  GlobalSurveySubmission({
    required this.id,
    required this.surveyId,
    required this.agentId,
    required this.submissionData,
    required this.submittedAt,
    this.updatedAt,
    this.latitude,
    this.longitude,
  });

  factory GlobalSurveySubmission.fromJson(Map<String, dynamic> json) {
    return GlobalSurveySubmission(
      id: (json['id'] ?? '').toString(),
      surveyId: (json['survey_id'] ?? '').toString(),
      agentId: (json['agent_id'] ?? '').toString(),
      submissionData: Map<String, dynamic>.from(json['submission_data'] ?? {}),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'survey_id': surveyId,
      'agent_id': agentId,
      'submission_data': submissionData,
      'submitted_at': submittedAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

