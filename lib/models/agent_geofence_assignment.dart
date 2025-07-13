// lib/models/agent_geofence_assignment.dart

enum AssignmentStatus {
  active,
  completed,
  cancelled,
}

class AgentGeofenceAssignment {
  final String id;
  final String campaignId;
  final String geofenceId;
  final String agentId;
  final DateTime assignedAt;
  final AssignmentStatus status;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final Duration? totalTimeInside;
  final DateTime createdAt;

  // Optional fields populated when joining with other tables
  final String? geofenceName;
  final String? agentName;
  final String? campaignName;

  AgentGeofenceAssignment({
    required this.id,
    required this.campaignId,
    required this.geofenceId,
    required this.agentId,
    required this.assignedAt,
    required this.status,
    this.entryTime,
    this.exitTime,
    this.totalTimeInside,
    required this.createdAt,
    this.geofenceName,
    this.agentName,
    this.campaignName,
  });

  factory AgentGeofenceAssignment.fromJson(Map<String, dynamic> json) {
    return AgentGeofenceAssignment(
      id: json['id'],
      campaignId: json['campaign_id'],
      geofenceId: json['geofence_id'],
      agentId: json['agent_id'],
      assignedAt: DateTime.parse(json['assigned_at']),
      status: _parseStatus(json['status']),
      entryTime: json['entry_time'] != null ? DateTime.parse(json['entry_time']) : null,
      exitTime: json['exit_time'] != null ? DateTime.parse(json['exit_time']) : null,
      totalTimeInside: json['total_time_inside'] != null 
          ? _parseDuration(json['total_time_inside']) 
          : null,
      createdAt: DateTime.parse(json['created_at']),
      geofenceName: json['geofence_name'],
      agentName: json['agent_name'],
      campaignName: json['campaign_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'geofence_id': geofenceId,
      'agent_id': agentId,
      'assigned_at': assignedAt.toIso8601String(),
      'status': status.name,
      'entry_time': entryTime?.toIso8601String(),
      'exit_time': exitTime?.toIso8601String(),
      'total_time_inside': totalTimeInside?.toString(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  static AssignmentStatus _parseStatus(String statusStr) {
    switch (statusStr.toLowerCase()) {
      case 'active':
        return AssignmentStatus.active;
      case 'completed':
        return AssignmentStatus.completed;
      case 'cancelled':
        return AssignmentStatus.cancelled;
      default:
        return AssignmentStatus.active;
    }
  }

  static Duration? _parseDuration(String durationStr) {
    try {
      // Parse PostgreSQL interval format (e.g., "02:30:45" or "1 day 02:30:45")
      final regex = RegExp(r'(\d+)\s*days?\s*)?(\d{2}):(\d{2}):(\d{2})');
      final match = regex.firstMatch(durationStr);
      
      if (match != null) {
        final days = int.tryParse(match.group(1) ?? '0') ?? 0;
        final hours = int.parse(match.group(2)!);
        final minutes = int.parse(match.group(3)!);
        final seconds = int.parse(match.group(4)!);
        
        return Duration(
          days: days,
          hours: hours,
          minutes: minutes,
          seconds: seconds,
        );
      }
      
      // Fallback: try to parse as simple duration
      return Duration(milliseconds: int.tryParse(durationStr) ?? 0);
    } catch (e) {
      return null;
    }
  }

  // Helper methods
  bool get isActive => status == AssignmentStatus.active;
  bool get isCompleted => status == AssignmentStatus.completed;
  bool get isCancelled => status == AssignmentStatus.cancelled;
  bool get isCurrentlyInside => isActive && entryTime != null && exitTime == null;

  String get statusDisplayName {
    switch (status) {
      case AssignmentStatus.active:
        return 'Active';
      case AssignmentStatus.completed:
        return 'Completed';
      case AssignmentStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get timeInsideText {
    if (totalTimeInside == null) {
      if (isCurrentlyInside && entryTime != null) {
        final currentDuration = DateTime.now().difference(entryTime!);
        return _formatDuration(currentDuration);
      }
      return 'No time recorded';
    }
    return _formatDuration(totalTimeInside!);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Duration get currentSessionDuration {
    if (isCurrentlyInside && entryTime != null) {
      return DateTime.now().difference(entryTime!);
    }
    return Duration.zero;
  }

  AgentGeofenceAssignment copyWith({
    String? id,
    String? campaignId,
    String? geofenceId,
    String? agentId,
    DateTime? assignedAt,
    AssignmentStatus? status,
    DateTime? entryTime,
    DateTime? exitTime,
    Duration? totalTimeInside,
    DateTime? createdAt,
    String? geofenceName,
    String? agentName,
    String? campaignName,
  }) {
    return AgentGeofenceAssignment(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      geofenceId: geofenceId ?? this.geofenceId,
      agentId: agentId ?? this.agentId,
      assignedAt: assignedAt ?? this.assignedAt,
      status: status ?? this.status,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      totalTimeInside: totalTimeInside ?? this.totalTimeInside,
      createdAt: createdAt ?? this.createdAt,
      geofenceName: geofenceName ?? this.geofenceName,
      agentName: agentName ?? this.agentName,
      campaignName: campaignName ?? this.campaignName,
    );
  }
}