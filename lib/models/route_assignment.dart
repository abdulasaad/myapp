// lib/models/route_assignment.dart

import 'package:flutter/foundation.dart';
import 'route.dart' as route_model;
import '../models/app_user.dart';

class RouteAssignment {
  final String id;
  final String routeId;
  final String agentId;
  final String assignedBy;
  final DateTime assignedAt;
  final String status; // 'assigned', 'in_progress', 'completed', 'cancelled'
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;
  
  // Optional expanded data when joined
  final route_model.Route? route;
  final AppUser? agent;
  final AppUser? assignedByUser;

  RouteAssignment({
    required this.id,
    required this.routeId,
    required this.agentId,
    required this.assignedBy,
    required this.assignedAt,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.notes,
    this.route,
    this.agent,
    this.assignedByUser,
  });

  factory RouteAssignment.fromJson(Map<String, dynamic> json) {
    try {
      return RouteAssignment(
        id: (json['id'] ?? '').toString(),
        routeId: (json['route_id'] ?? '').toString(),
        agentId: (json['agent_id'] ?? '').toString(),
        assignedBy: (json['assigned_by'] ?? '').toString(),
        assignedAt: json['assigned_at'] != null 
            ? DateTime.parse(json['assigned_at'].toString()) 
            : DateTime.now(),
        status: (json['status'] ?? 'assigned').toString(),
        startedAt: json['started_at'] != null 
            ? DateTime.parse(json['started_at'].toString()) 
            : null,
        completedAt: json['completed_at'] != null 
            ? DateTime.parse(json['completed_at'].toString()) 
            : null,
        notes: json['notes']?.toString(),
        route: json['routes'] != null && json['routes'] is Map<String, dynamic>
            ? route_model.Route.fromJson(json['routes']) 
            : null,
        agent: json['profiles'] != null && json['profiles'] is Map<String, dynamic>
            ? AppUser.fromJson(json['profiles']) 
            : null,
        assignedByUser: json['assigned_by_user'] != null && json['assigned_by_user'] is Map<String, dynamic>
            ? AppUser.fromJson(json['assigned_by_user']) 
            : null,
      );
    } catch (e) {
      debugPrint('Error parsing RouteAssignment: $e');
      debugPrint('JSON data: $json');
      // Return a default RouteAssignment with safe values
      return RouteAssignment(
        id: (json['id'] ?? '').toString(),
        routeId: (json['route_id'] ?? '').toString(),
        agentId: (json['agent_id'] ?? '').toString(),
        assignedBy: (json['assigned_by'] ?? '').toString(),
        assignedAt: DateTime.now(),
        status: 'assigned',
        route: null,
        agent: null,
        assignedByUser: null,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_id': routeId,
      'agent_id': agentId,
      'assigned_by': assignedBy,
      'assigned_at': assignedAt.toIso8601String(),
      'status': status,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  // Helper methods
  bool get isAssigned => status == 'assigned';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get canStart => isAssigned && startedAt == null;
  
  Duration? get duration {
    if (startedAt != null && completedAt != null) {
      return completedAt!.difference(startedAt!);
    }
    return null;
  }
  
  RouteAssignment copyWith({
    String? id,
    String? routeId,
    String? agentId,
    String? assignedBy,
    DateTime? assignedAt,
    String? status,
    DateTime? startedAt,
    DateTime? completedAt,
    String? notes,
    route_model.Route? route,
    AppUser? agent,
    AppUser? assignedByUser,
  }) {
    return RouteAssignment(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      agentId: agentId ?? this.agentId,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedAt: assignedAt ?? this.assignedAt,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      route: route ?? this.route,
      agent: agent ?? this.agent,
      assignedByUser: assignedByUser ?? this.assignedByUser,
    );
  }
}