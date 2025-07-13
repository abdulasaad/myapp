// lib/models/agent_location_tracking.dart

class AgentLocationTracking {
  final String id;
  final String agentId;
  final String campaignId;
  final String? geofenceId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final bool isInsideGeofence;
  final DateTime recordedAt;

  // Optional fields populated when joining with other tables
  final String? agentName;
  final String? geofenceName;

  AgentLocationTracking({
    required this.id,
    required this.agentId,
    required this.campaignId,
    this.geofenceId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.isInsideGeofence,
    required this.recordedAt,
    this.agentName,
    this.geofenceName,
  });

  factory AgentLocationTracking.fromJson(Map<String, dynamic> json) {
    return AgentLocationTracking(
      id: json['id'],
      agentId: json['agent_id'],
      campaignId: json['campaign_id'],
      geofenceId: json['geofence_id'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: json['accuracy'] != null ? (json['accuracy'] as num).toDouble() : null,
      isInsideGeofence: json['is_inside_geofence'] ?? false,
      recordedAt: DateTime.parse(json['recorded_at']),
      agentName: json['agent_name'],
      geofenceName: json['geofence_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'agent_id': agentId,
      'campaign_id': campaignId,
      'geofence_id': geofenceId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'is_inside_geofence': isInsideGeofence,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }

  // Helper methods
  String get coordinates => '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  
  String get accuracyText {
    if (accuracy == null) return 'Unknown accuracy';
    if (accuracy! < 5) return 'High accuracy (${accuracy!.toStringAsFixed(1)}m)';
    if (accuracy! < 20) return 'Good accuracy (${accuracy!.toStringAsFixed(1)}m)';
    return 'Low accuracy (${accuracy!.toStringAsFixed(1)}m)';
  }

  String get statusText => isInsideGeofence ? 'Inside geofence' : 'Outside geofence';

  String get timeAgoText {
    final now = DateTime.now();
    final difference = now.difference(recordedAt);
    
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  bool get isRecent => DateTime.now().difference(recordedAt).inMinutes < 5;

  AgentLocationTracking copyWith({
    String? id,
    String? agentId,
    String? campaignId,
    String? geofenceId,
    double? latitude,
    double? longitude,
    double? accuracy,
    bool? isInsideGeofence,
    DateTime? recordedAt,
    String? agentName,
    String? geofenceName,
  }) {
    return AgentLocationTracking(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      campaignId: campaignId ?? this.campaignId,
      geofenceId: geofenceId ?? this.geofenceId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      isInsideGeofence: isInsideGeofence ?? this.isInsideGeofence,
      recordedAt: recordedAt ?? this.recordedAt,
      agentName: agentName ?? this.agentName,
      geofenceName: geofenceName ?? this.geofenceName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentLocationTracking &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AgentLocationTracking{id: $id, agentId: $agentId, coordinates: $coordinates, isInsideGeofence: $isInsideGeofence, recordedAt: $recordedAt}';
  }
}