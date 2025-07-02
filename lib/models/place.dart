// lib/models/place.dart

import 'app_user.dart';

class Place {
  final String id;
  final String name;
  final String? description;
  final String? address;
  final double latitude;
  final double longitude;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'active', 'inactive', 'pending_approval'
  final String approvalStatus; // 'pending', 'approved', 'rejected'
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final Map<String, dynamic>? metadata;
  
  // Optional expanded data when joined
  final AppUser? createdByUser;
  final AppUser? approvedByUser;

  Place({
    required this.id,
    required this.name,
    this.description,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.approvalStatus,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.metadata,
    this.createdByUser,
    this.approvedByUser,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    try {
      return Place(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        description: json['description']?.toString(),
        address: json['address']?.toString(),
        latitude: json['latitude'] != null 
            ? double.tryParse(json['latitude'].toString()) ?? 0.0 
            : 0.0,
        longitude: json['longitude'] != null 
            ? double.tryParse(json['longitude'].toString()) ?? 0.0 
            : 0.0,
        createdBy: (json['created_by'] ?? '').toString(),
        createdAt: json['created_at'] != null 
            ? DateTime.parse(json['created_at'].toString()) 
            : DateTime.now(),
        updatedAt: json['updated_at'] != null 
            ? DateTime.parse(json['updated_at'].toString()) 
            : DateTime.now(),
        status: (json['status'] ?? 'active').toString(),
        approvalStatus: (json['approval_status'] ?? 'approved').toString(),
        approvedBy: json['approved_by']?.toString(),
        approvedAt: json['approved_at'] != null 
            ? DateTime.parse(json['approved_at'].toString()) 
            : null,
        rejectionReason: json['rejection_reason']?.toString(),
        metadata: json['metadata'] != null && json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata']) 
            : null,
        createdByUser: json['created_by_profile'] != null && json['created_by_profile'] is Map<String, dynamic>
            ? AppUser.fromJson(json['created_by_profile'])
            : null,
        approvedByUser: json['approved_by_profile'] != null && json['approved_by_profile'] is Map<String, dynamic>
            ? AppUser.fromJson(json['approved_by_profile'])
            : null,
      );
    } catch (e) {
      print('Error parsing Place: $e');
      print('JSON data: $json');
      // Return a default Place with safe values
      return Place(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'Unknown Place').toString(),
        latitude: 0.0,
        longitude: 0.0,
        createdBy: (json['created_by'] ?? '').toString(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'active',
        approvalStatus: 'approved',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'status': status,
      'approval_status': approvalStatus,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'metadata': metadata,
    };
  }

  // Helper methods
  bool get isActive => status == 'active';
  bool get isApproved => approvalStatus == 'approved';
  bool get isPending => approvalStatus == 'pending';
  bool get needsApproval => approvalStatus == 'pending';
  
  Place copyWith({
    String? id,
    String? name,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? approvalStatus,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
    Map<String, dynamic>? metadata,
    AppUser? createdByUser,
    AppUser? approvedByUser,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      metadata: metadata ?? this.metadata,
      createdByUser: createdByUser ?? this.createdByUser,
      approvedByUser: approvedByUser ?? this.approvedByUser,
    );
  }
}