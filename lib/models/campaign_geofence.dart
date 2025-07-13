// lib/models/campaign_geofence.dart

import 'package:flutter/material.dart';

class CampaignGeofence {
  final String id;
  final String campaignId;
  final String name;
  final String? description;
  final String areaText; // WKT polygon text
  final int maxAgents;
  final Color color;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  // Runtime capacity information (populated by API calls)
  final int? currentAgents;
  final bool? isFull;
  final int? availableSpots;

  CampaignGeofence({
    required this.id,
    required this.campaignId,
    required this.name,
    this.description,
    required this.areaText,
    required this.maxAgents,
    required this.color,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.currentAgents,
    this.isFull,
    this.availableSpots,
  });

  factory CampaignGeofence.fromJson(Map<String, dynamic> json) {
    return CampaignGeofence(
      id: json['id'] ?? json['geofence_id'] ?? '',
      campaignId: json['campaign_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      areaText: json['area_text'] ?? '',
      maxAgents: json['max_agents'] ?? 1,
      color: _parseColor(json['color'] ?? '#2196F3'),
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      createdBy: json['created_by'],
      // Capacity information from API queries
      currentAgents: json['current_agents'],
      isFull: json['is_full'],
      availableSpots: json['available_spots'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'name': name,
      'description': description,
      'area_text': areaText,
      'max_agents': maxAgents,
      'color': _colorToHex(color),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }

  static Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', ''), radix: 16) + 0xFF000000);
    } catch (e) {
      return const Color(0xFF2196F3); // Default blue
    }
  }

  static String _colorToHex(Color color) {
    return '#${(0xFF000000 | color.value).toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  // Helper methods
  bool get hasCapacityInfo => currentAgents != null && isFull != null;
  
  String get capacityText {
    if (!hasCapacityInfo) return 'Loading...';
    return '$currentAgents/$maxAgents agents';
  }

  String get statusText {
    if (!hasCapacityInfo) return 'Checking availability...';
    if (isFull!) return 'Full';
    return '$availableSpots spots available';
  }

  Color get statusColor {
    if (!hasCapacityInfo) return Colors.grey;
    if (isFull!) return Colors.red;
    if (availableSpots! <= 1) return Colors.orange;
    return Colors.green;
  }

  IconData get statusIcon {
    if (!hasCapacityInfo) return Icons.hourglass_empty;
    if (isFull!) return Icons.block;
    if (availableSpots! <= 1) return Icons.warning;
    return Icons.check_circle;
  }

  // Create a copy with updated capacity information
  CampaignGeofence copyWithCapacity({
    int? currentAgents,
    bool? isFull,
    int? availableSpots,
  }) {
    return CampaignGeofence(
      id: id,
      campaignId: campaignId,
      name: name,
      description: description,
      areaText: areaText,
      maxAgents: maxAgents,
      color: color,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      currentAgents: currentAgents ?? this.currentAgents,
      isFull: isFull ?? this.isFull,
      availableSpots: availableSpots ?? this.availableSpots,
    );
  }

  CampaignGeofence copyWith({
    String? id,
    String? campaignId,
    String? name,
    String? description,
    String? areaText,
    int? maxAgents,
    Color? color,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return CampaignGeofence(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      name: name ?? this.name,
      description: description ?? this.description,
      areaText: areaText ?? this.areaText,
      maxAgents: maxAgents ?? this.maxAgents,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      currentAgents: currentAgents,
      isFull: isFull,
      availableSpots: availableSpots,
    );
  }
}