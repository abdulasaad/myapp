// lib/models/route.dart

import 'app_user.dart';
import 'route_place.dart';

class Route {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final String? assignedManagerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status; // 'draft', 'active', 'completed', 'archived'
  final int? estimatedDurationHours;
  final Map<String, dynamic>? metadata;
  
  // Optional expanded data when joined
  final AppUser? createdByUser;
  final AppUser? assignedManagerUser;
  final List<RoutePlace>? routePlaces;

  Route({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    this.assignedManagerId,
    required this.createdAt,
    required this.updatedAt,
    this.startDate,
    this.endDate,
    required this.status,
    this.estimatedDurationHours,
    this.metadata,
    this.createdByUser,
    this.assignedManagerUser,
    this.routePlaces,
  });

  factory Route.fromJson(Map<String, dynamic> json) {
    try {
      return Route(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        description: json['description']?.toString(),
        createdBy: (json['created_by'] ?? '').toString(),
        assignedManagerId: json['assigned_manager_id']?.toString(),
        createdAt: json['created_at'] != null 
            ? DateTime.parse(json['created_at'].toString()) 
            : DateTime.now(),
        updatedAt: json['updated_at'] != null 
            ? DateTime.parse(json['updated_at'].toString()) 
            : DateTime.now(),
        startDate: json['start_date'] != null 
            ? DateTime.parse(json['start_date'].toString()) 
            : null,
        endDate: json['end_date'] != null 
            ? DateTime.parse(json['end_date'].toString()) 
            : null,
        status: (json['status'] ?? 'active').toString(),
        estimatedDurationHours: json['estimated_duration_hours'] is int 
            ? json['estimated_duration_hours'] 
            : null,
        metadata: json['metadata'] != null && json['metadata'] is Map 
            ? Map<String, dynamic>.from(json['metadata']) 
            : null,
        createdByUser: json['created_by_profile'] != null && json['created_by_profile'] is Map<String, dynamic>
            ? AppUser.fromJson(json['created_by_profile'])
            : null,
        assignedManagerUser: json['assigned_manager_profile'] != null && json['assigned_manager_profile'] is Map<String, dynamic>
            ? AppUser.fromJson(json['assigned_manager_profile'])
            : null,
        routePlaces: json['route_places'] != null && json['route_places'] is List
            ? (json['route_places'] as List).map((rp) => RoutePlace.fromJson(rp)).toList()
            : null,
      );
    } catch (e) {
      print('Error parsing Route: $e');
      print('JSON data: $json');
      // Return a default Route with safe values
      return Route(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'Unknown Route').toString(),
        createdBy: (json['created_by'] ?? '').toString(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'active',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_by': createdBy,
      'assigned_manager_id': assignedManagerId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status,
      'estimated_duration_hours': estimatedDurationHours,
      'metadata': metadata,
    };
  }

  // Helper methods
  bool get isActive => status == 'active';
  bool get isDraft => status == 'draft';
  bool get isCompleted => status == 'completed';
  bool get isArchived => status == 'archived';
  
  bool get isCurrentlyActive {
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return isActive;
  }
  
  Route copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    String? assignedManagerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int? estimatedDurationHours,
    Map<String, dynamic>? metadata,
    AppUser? createdByUser,
    AppUser? assignedManagerUser,
    List<RoutePlace>? routePlaces,
  }) {
    return Route(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      assignedManagerId: assignedManagerId ?? this.assignedManagerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      estimatedDurationHours: estimatedDurationHours ?? this.estimatedDurationHours,
      metadata: metadata ?? this.metadata,
      createdByUser: createdByUser ?? this.createdByUser,
      assignedManagerUser: assignedManagerUser ?? this.assignedManagerUser,
      routePlaces: routePlaces ?? this.routePlaces,
    );
  }
}