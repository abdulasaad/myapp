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
    );
  }
}