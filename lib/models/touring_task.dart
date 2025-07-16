// lib/models/touring_task.dart

import 'package:flutter/material.dart';

class TouringTask {
  final String id;
  final String campaignId;
  final String geofenceId;
  final String title;
  final String? description;
  final int requiredTimeMinutes;
  final int movementTimeoutSeconds;
  final double minMovementThreshold; // in meters
  final int points;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  
  // Schedule fields
  final String? dailyStartTime; // Format: "HH:MM"
  final String? dailyEndTime; // Format: "HH:MM"
  final bool useSchedule; // Whether to use daily schedule or be available all day

  TouringTask({
    required this.id,
    required this.campaignId,
    required this.geofenceId,
    required this.title,
    this.description,
    required this.requiredTimeMinutes,
    required this.movementTimeoutSeconds,
    required this.minMovementThreshold,
    required this.points,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.dailyStartTime,
    this.dailyEndTime,
    this.useSchedule = false,
  });

  factory TouringTask.fromJson(Map<String, dynamic> json) {
    return TouringTask(
      id: json['id'] ?? '',
      campaignId: json['campaign_id'] ?? '',
      geofenceId: json['geofence_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      requiredTimeMinutes: json['required_time_minutes'] ?? 30,
      movementTimeoutSeconds: json['movement_timeout_seconds'] ?? 60,
      minMovementThreshold: (json['min_movement_threshold'] ?? 5.0).toDouble(),
      points: json['points'] ?? 10,
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      createdBy: json['created_by'],
      dailyStartTime: json['daily_start_time'],
      dailyEndTime: json['daily_end_time'],
      useSchedule: json['use_schedule'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'geofence_id': geofenceId,
      'title': title,
      'description': description,
      'required_time_minutes': requiredTimeMinutes,
      'movement_timeout_seconds': movementTimeoutSeconds,
      'min_movement_threshold': minMovementThreshold,
      'points': points,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'daily_start_time': dailyStartTime,
      'daily_end_time': dailyEndTime,
      'use_schedule': useSchedule,
    };
  }

  TouringTask copyWith({
    String? id,
    String? campaignId,
    String? geofenceId,
    String? title,
    String? description,
    int? requiredTimeMinutes,
    int? movementTimeoutSeconds,
    double? minMovementThreshold,
    int? points,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? dailyStartTime,
    String? dailyEndTime,
    bool? useSchedule,
  }) {
    return TouringTask(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      geofenceId: geofenceId ?? this.geofenceId,
      title: title ?? this.title,
      description: description ?? this.description,
      requiredTimeMinutes: requiredTimeMinutes ?? this.requiredTimeMinutes,
      movementTimeoutSeconds: movementTimeoutSeconds ?? this.movementTimeoutSeconds,
      minMovementThreshold: minMovementThreshold ?? this.minMovementThreshold,
      points: points ?? this.points,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      dailyStartTime: dailyStartTime ?? this.dailyStartTime,
      dailyEndTime: dailyEndTime ?? this.dailyEndTime,
      useSchedule: useSchedule ?? this.useSchedule,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TouringTask && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TouringTask(id: $id, title: $title, geofenceId: $geofenceId)';
  }

  // Helper getters
  String get formattedDuration {
    if (requiredTimeMinutes < 60) {
      return '${requiredTimeMinutes}m';
    } else {
      final hours = requiredTimeMinutes ~/ 60;
      final minutes = requiredTimeMinutes % 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }

  String get movementTimeoutText {
    if (movementTimeoutSeconds < 60) {
      return '${movementTimeoutSeconds}s';
    } else {
      final minutes = movementTimeoutSeconds ~/ 60;
      final seconds = movementTimeoutSeconds % 60;
      return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
    }
  }

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';

  // Schedule helper methods
  bool isAvailableAtTime(DateTime dateTime) {
    if (!useSchedule || dailyStartTime == null || dailyEndTime == null) {
      return true; // Available all day if no schedule is set
    }
    
    final currentTime = TimeOfDay.fromDateTime(dateTime);
    final startTime = _parseTimeString(dailyStartTime!);
    final endTime = _parseTimeString(dailyEndTime!);
    
    if (startTime == null || endTime == null) {
      return true; // Default to available if parsing fails
    }
    
    return _isTimeInRange(currentTime, startTime, endTime);
  }
  
  TimeOfDay? _parseTimeString(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length != 2) return null;
      
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }
  
  bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    
    if (startMinutes <= endMinutes) {
      // Same day range
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Crosses midnight
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }
  
  String get scheduleDisplayText {
    if (!useSchedule || dailyStartTime == null || dailyEndTime == null) {
      return 'Available all day';
    }
    
    final start = _parseTimeString(dailyStartTime!);
    final end = _parseTimeString(dailyEndTime!);
    
    if (start == null || end == null) {
      return 'Available all day';
    }
    
    // Format times for display
    final startFormatted = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final endFormatted = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    
    return '$startFormatted - $endFormatted';
  }
}