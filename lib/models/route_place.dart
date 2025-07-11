// lib/models/route_place.dart

import 'package:flutter/foundation.dart';
import 'place.dart';

class RoutePlace {
  final String? id;
  final String routeId;
  final String placeId;
  final int visitOrder;
  final int estimatedDurationMinutes;
  final int requiredEvidenceCount;
  final int visitFrequency; // Number of times to visit this place
  final String? instructions;
  final DateTime createdAt;
  
  // Optional expanded data when joined with places table
  final Place? place;

  RoutePlace({
    this.id,
    required this.routeId,
    required this.placeId,
    required this.visitOrder,
    required this.estimatedDurationMinutes,
    required this.requiredEvidenceCount,
    this.visitFrequency = 1,
    this.instructions,
    required this.createdAt,
    this.place,
  });

  factory RoutePlace.fromJson(Map<String, dynamic> json) {
    try {
      return RoutePlace(
        id: (json['id'] ?? '').toString(),
        routeId: (json['route_id'] ?? '').toString(),
        placeId: (json['place_id'] ?? '').toString(),
        visitOrder: json['visit_order'] is int ? json['visit_order'] : 0,
        estimatedDurationMinutes: json['estimated_duration_minutes'] is int 
            ? json['estimated_duration_minutes'] 
            : 30,
        requiredEvidenceCount: json['required_evidence_count'] is int 
            ? json['required_evidence_count'] 
            : 1,
        visitFrequency: json['visit_frequency'] is int 
            ? json['visit_frequency'] 
            : 1,
        instructions: json['instructions']?.toString(),
        createdAt: json['created_at'] != null 
            ? DateTime.parse(json['created_at'].toString()) 
            : DateTime.now(),
        place: json['places'] != null && json['places'] is Map<String, dynamic>
            ? Place.fromJson(json['places']) 
            : null,
      );
    } catch (e) {
      debugPrint('Error parsing RoutePlace: $e');
      debugPrint('JSON data: $json');
      // Return a default RoutePlace with safe values
      return RoutePlace(
        id: (json['id'] ?? '').toString(),
        routeId: (json['route_id'] ?? '').toString(),
        placeId: (json['place_id'] ?? '').toString(),
        visitOrder: 0,
        estimatedDurationMinutes: 30,
        requiredEvidenceCount: 1,
        visitFrequency: 1,
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_id': routeId,
      'place_id': placeId,
      'visit_order': visitOrder,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'required_evidence_count': requiredEvidenceCount,
      'visit_frequency': visitFrequency,
      'instructions': instructions,
      'created_at': createdAt.toIso8601String(),
    };
  }

  RoutePlace copyWith({
    String? id,
    String? routeId,
    String? placeId,
    int? visitOrder,
    int? estimatedDurationMinutes,
    int? requiredEvidenceCount,
    int? visitFrequency,
    String? instructions,
    DateTime? createdAt,
    Place? place,
  }) {
    return RoutePlace(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      placeId: placeId ?? this.placeId,
      visitOrder: visitOrder ?? this.visitOrder,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      requiredEvidenceCount: requiredEvidenceCount ?? this.requiredEvidenceCount,
      visitFrequency: visitFrequency ?? this.visitFrequency,
      instructions: instructions ?? this.instructions,
      createdAt: createdAt ?? this.createdAt,
      place: place ?? this.place,
    );
  }
}