// lib/models/place_visit.dart

import 'place.dart';
import 'route_assignment.dart';

class PlaceVisit {
  final String id;
  final String routeAssignmentId;
  final String placeId;
  final String agentId;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final int? durationMinutes; // Generated column in database
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final String status; // 'pending', 'checked_in', 'completed', 'skipped'
  final String? visitNotes;
  final int visitNumber; // Which visit number this is (1st, 2nd, etc.)
  final DateTime createdAt;
  
  // Optional expanded data when joined
  final Place? place;
  final RouteAssignment? routeAssignment;

  PlaceVisit({
    required this.id,
    required this.routeAssignmentId,
    required this.placeId,
    required this.agentId,
    this.checkedInAt,
    this.checkedOutAt,
    this.durationMinutes,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    required this.status,
    this.visitNotes,
    this.visitNumber = 1,
    required this.createdAt,
    this.place,
    this.routeAssignment,
  });

  factory PlaceVisit.fromJson(Map<String, dynamic> json) {
    try {
      return PlaceVisit(
        id: (json['id'] ?? '').toString(),
        routeAssignmentId: (json['route_assignment_id'] ?? '').toString(),
        placeId: (json['place_id'] ?? '').toString(),
        agentId: (json['agent_id'] ?? '').toString(),
        checkedInAt: json['checked_in_at'] != null 
            ? DateTime.parse(json['checked_in_at'].toString()) 
            : null,
        checkedOutAt: json['checked_out_at'] != null 
            ? DateTime.parse(json['checked_out_at'].toString()) 
            : null,
        durationMinutes: json['duration_minutes'] is int 
            ? json['duration_minutes'] 
            : null,
        checkInLatitude: json['check_in_latitude'] != null 
            ? double.tryParse(json['check_in_latitude'].toString()) 
            : null,
        checkInLongitude: json['check_in_longitude'] != null 
            ? double.tryParse(json['check_in_longitude'].toString()) 
            : null,
        checkOutLatitude: json['check_out_latitude'] != null 
            ? double.tryParse(json['check_out_latitude'].toString()) 
            : null,
        checkOutLongitude: json['check_out_longitude'] != null 
            ? double.tryParse(json['check_out_longitude'].toString()) 
            : null,
        status: (json['status'] ?? 'pending').toString(),
        visitNotes: json['visit_notes']?.toString(),
        visitNumber: json['visit_number'] is int 
            ? json['visit_number'] 
            : 1,
        createdAt: json['created_at'] != null 
            ? DateTime.parse(json['created_at'].toString()) 
            : DateTime.now(),
        place: json['places'] != null && json['places'] is Map<String, dynamic>
            ? Place.fromJson(json['places']) 
            : null,
        routeAssignment: json['route_assignments'] != null && json['route_assignments'] is Map<String, dynamic>
            ? RouteAssignment.fromJson(json['route_assignments']) 
            : null,
      );
    } catch (e) {
      print('Error parsing PlaceVisit: $e');
      print('JSON data: $json');
      // Return a default PlaceVisit with safe values
      return PlaceVisit(
        id: (json['id'] ?? '').toString(),
        routeAssignmentId: (json['route_assignment_id'] ?? '').toString(),
        placeId: (json['place_id'] ?? '').toString(),
        agentId: (json['agent_id'] ?? '').toString(),
        status: 'pending',
        visitNumber: 1,
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_assignment_id': routeAssignmentId,
      'place_id': placeId,
      'agent_id': agentId,
      'checked_in_at': checkedInAt?.toIso8601String(),
      'checked_out_at': checkedOutAt?.toIso8601String(),
      'check_in_latitude': checkInLatitude,
      'check_in_longitude': checkInLongitude,
      'check_out_latitude': checkOutLatitude,
      'check_out_longitude': checkOutLongitude,
      'status': status,
      'visit_notes': visitNotes,
      'visit_number': visitNumber,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper methods
  bool get isPending => status == 'pending';
  bool get isCheckedIn => status == 'checked_in';
  bool get isCompleted => status == 'completed';
  bool get isSkipped => status == 'skipped';
  bool get canCheckIn => isPending;
  bool get canCheckOut => isCheckedIn;
  
  Duration? get visitDuration {
    if (checkedInAt != null && checkedOutAt != null) {
      return checkedOutAt!.difference(checkedInAt!);
    }
    return null;
  }
  
  String get formattedDuration {
    if (durationMinutes == null) return 'N/A';
    final hours = durationMinutes! ~/ 60;
    final minutes = durationMinutes! % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
  
  PlaceVisit copyWith({
    String? id,
    String? routeAssignmentId,
    String? placeId,
    String? agentId,
    DateTime? checkedInAt,
    DateTime? checkedOutAt,
    int? durationMinutes,
    double? checkInLatitude,
    double? checkInLongitude,
    double? checkOutLatitude,
    double? checkOutLongitude,
    String? status,
    String? visitNotes,
    int? visitNumber,
    DateTime? createdAt,
    Place? place,
    RouteAssignment? routeAssignment,
  }) {
    return PlaceVisit(
      id: id ?? this.id,
      routeAssignmentId: routeAssignmentId ?? this.routeAssignmentId,
      placeId: placeId ?? this.placeId,
      agentId: agentId ?? this.agentId,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      checkedOutAt: checkedOutAt ?? this.checkedOutAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      checkInLatitude: checkInLatitude ?? this.checkInLatitude,
      checkInLongitude: checkInLongitude ?? this.checkInLongitude,
      checkOutLatitude: checkOutLatitude ?? this.checkOutLatitude,
      checkOutLongitude: checkOutLongitude ?? this.checkOutLongitude,
      status: status ?? this.status,
      visitNotes: visitNotes ?? this.visitNotes,
      visitNumber: visitNumber ?? this.visitNumber,
      createdAt: createdAt ?? this.createdAt,
      place: place ?? this.place,
      routeAssignment: routeAssignment ?? this.routeAssignment,
    );
  }
}