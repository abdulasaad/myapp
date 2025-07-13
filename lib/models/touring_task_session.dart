// lib/models/touring_task_session.dart

class TouringTaskSession {
  final String id;
  final String touringTaskId;
  final String agentId;
  final DateTime startTime;
  final DateTime? endTime;
  final int elapsedSeconds; // Total active time (excluding pauses)
  final bool isActive;
  final bool isPaused;
  final bool isCompleted;
  final DateTime? lastMovementTime;
  final double? lastLatitude;
  final double? lastLongitude;
  final String? pauseReason;
  final DateTime? lastLocationUpdate;

  TouringTaskSession({
    required this.id,
    required this.touringTaskId,
    required this.agentId,
    required this.startTime,
    this.endTime,
    required this.elapsedSeconds,
    required this.isActive,
    required this.isPaused,
    required this.isCompleted,
    this.lastMovementTime,
    this.lastLatitude,
    this.lastLongitude,
    this.pauseReason,
    this.lastLocationUpdate,
  });

  factory TouringTaskSession.fromJson(Map<String, dynamic> json) {
    return TouringTaskSession(
      id: json['id'] ?? '',
      touringTaskId: json['touring_task_id'] ?? '',
      agentId: json['agent_id'] ?? '',
      startTime: json['start_time'] != null ? DateTime.parse(json['start_time']) : DateTime.now(),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      elapsedSeconds: json['elapsed_seconds'] ?? 0,
      isActive: json['is_active'] ?? false,
      isPaused: json['is_paused'] ?? false,
      isCompleted: json['is_completed'] ?? false,
      lastMovementTime: json['last_movement_time'] != null ? DateTime.parse(json['last_movement_time']) : null,
      lastLatitude: json['last_latitude']?.toDouble(),
      lastLongitude: json['last_longitude']?.toDouble(),
      pauseReason: json['pause_reason'],
      lastLocationUpdate: json['last_location_update'] != null ? DateTime.parse(json['last_location_update']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'touring_task_id': touringTaskId,
      'agent_id': agentId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'elapsed_seconds': elapsedSeconds,
      'is_active': isActive,
      'is_paused': isPaused,
      'is_completed': isCompleted,
      'last_movement_time': lastMovementTime?.toIso8601String(),
      'last_latitude': lastLatitude,
      'last_longitude': lastLongitude,
      'pause_reason': pauseReason,
      'last_location_update': lastLocationUpdate?.toIso8601String(),
    };
  }

  TouringTaskSession copyWith({
    String? id,
    String? touringTaskId,
    String? agentId,
    DateTime? startTime,
    DateTime? endTime,
    int? elapsedSeconds,
    bool? isActive,
    bool? isPaused,
    bool? isCompleted,
    DateTime? lastMovementTime,
    double? lastLatitude,
    double? lastLongitude,
    String? pauseReason,
    DateTime? lastLocationUpdate,
  }) {
    return TouringTaskSession(
      id: id ?? this.id,
      touringTaskId: touringTaskId ?? this.touringTaskId,
      agentId: agentId ?? this.agentId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
      isCompleted: isCompleted ?? this.isCompleted,
      lastMovementTime: lastMovementTime ?? this.lastMovementTime,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      pauseReason: pauseReason ?? this.pauseReason,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TouringTaskSession && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TouringTaskSession(id: $id, touringTaskId: $touringTaskId, elapsedSeconds: $elapsedSeconds)';
  }

  // Helper getters
  Duration get elapsedDuration => Duration(seconds: elapsedSeconds);
  
  String get formattedElapsedTime {
    final duration = elapsedDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  bool get hasLocation => lastLatitude != null && lastLongitude != null;
  
  String get statusText {
    if (isCompleted) return 'Completed';
    if (isPaused) return 'Paused';
    if (isActive) return 'Active';
    return 'Stopped';
  }

  Duration? get timeSinceLastMovement {
    if (lastMovementTime == null) return null;
    return DateTime.now().difference(lastMovementTime!);
  }

  Duration? get timeSinceLastUpdate {
    if (lastLocationUpdate == null) return null;
    return DateTime.now().difference(lastLocationUpdate!);
  }
}