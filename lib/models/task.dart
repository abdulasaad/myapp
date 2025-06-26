// lib/models/task.dart

class Task {
  final String id;
  // This is now nullable to support standalone tasks
  final String? campaignId; 
  final String title;
  final String? description;
  final int points;
  final String status;
  
  // --- NEW: Add the new fields from the database ---
  final String? locationName;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? requiredEvidenceCount;
  final bool? enforceGeofence;
  
  // --- TEMPLATE SYSTEM: Add template-related fields ---
  final String? templateId;
  final Map<String, dynamic>? customFields;
  final int? templateVersion;

  Task({
    required this.id,
    this.campaignId,
    required this.title,
    this.description,
    required this.points,
    required this.status,
    // Add new fields to the constructor
    this.locationName,
    this.startDate,
    this.endDate,
    this.requiredEvidenceCount,
    this.enforceGeofence,
    // Template system fields
    this.templateId,
    this.customFields,
    this.templateVersion,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      campaignId: json['campaign_id'],
      title: json['title'],
      description: json['description'],
      points: json['points'] ?? 0,
      status: json['status'] ?? 'pending',
      // --- NEW: Safely parse the new nullable fields ---
      locationName: json['location_name'],
      startDate: json['start_date'] == null ? null : DateTime.parse(json['start_date']),
      endDate: json['end_date'] == null ? null : DateTime.parse(json['end_date']),
      requiredEvidenceCount: json['required_evidence_count'],
      enforceGeofence: json['enforce_geofence'],
      // --- TEMPLATE SYSTEM: Parse template fields ---
      templateId: json['template_id'],
      customFields: json['custom_fields'] != null 
          ? Map<String, dynamic>.from(json['custom_fields'])
          : null,
      templateVersion: json['template_version'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'title': title,
      'description': description,
      'points': points,
      'status': status,
      'location_name': locationName,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'required_evidence_count': requiredEvidenceCount,
      'enforce_geofence': enforceGeofence,
      'template_id': templateId,
      'custom_fields': customFields,
      'template_version': templateVersion,
    };
  }

  bool get isFromTemplate => templateId != null;
  bool get hasCustomFields => customFields != null && customFields!.isNotEmpty;

  Task copyWith({
    String? id,
    String? campaignId,
    String? title,
    String? description,
    int? points,
    String? status,
    String? locationName,
    DateTime? startDate,
    DateTime? endDate,
    int? requiredEvidenceCount,
    bool? enforceGeofence,
    String? templateId,
    Map<String, dynamic>? customFields,
    int? templateVersion,
  }) {
    return Task(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      title: title ?? this.title,
      description: description ?? this.description,
      points: points ?? this.points,
      status: status ?? this.status,
      locationName: locationName ?? this.locationName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      requiredEvidenceCount: requiredEvidenceCount ?? this.requiredEvidenceCount,
      enforceGeofence: enforceGeofence ?? this.enforceGeofence,
      templateId: templateId ?? this.templateId,
      customFields: customFields ?? this.customFields,
      templateVersion: templateVersion ?? this.templateVersion,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Task && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Task(id: $id, title: $title, templateId: $templateId)';
  }
}