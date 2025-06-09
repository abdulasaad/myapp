// lib/models/active_agent.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';

class ActiveAgent {
  final String id;
  final String fullName;
  // --- FIX: Make these properties nullable to handle agents with no history ---
  final LatLng? lastKnownLocation;
  final DateTime? lastSeen;

  ActiveAgent({
    required this.id,
    required this.fullName,
    this.lastKnownLocation, // Now optional
    this.lastSeen,        // Now optional
  });

  factory ActiveAgent.fromJson(Map<String, dynamic> json) {
    // This helper function now safely returns a nullable LatLng.
    LatLng? parsePoint(String? pointString) {
      if (pointString == null) {
        return null; // <-- Return null if no location is provided from the DB
      }
      final pointRegex = RegExp(r'POINT\(([-\d.]+) ([-\d.]+)\)');
      final match = pointRegex.firstMatch(pointString);
      if (match != null) {
        final lng = double.parse(match.group(1)!);
        final lat = double.parse(match.group(2)!);
        return LatLng(lat, lng);
      }
      return null; // Return null if parsing fails
    }

    return ActiveAgent(
      id: json['id'], 
      // Add a fallback for name just in case
      fullName: json['full_name'] ?? 'Unknown Agent', 
      lastKnownLocation: parsePoint(json['last_location']),
      // --- FIX: This check prevents the 'Null' is not a 'String' crash ---
      lastSeen: json['last_seen'] == null 
          ? null 
          : DateTime.parse(json['last_seen']),
    );
  }
}