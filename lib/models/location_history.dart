// lib/models/location_history.dart

import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationHistoryEntry {
  final String id;
  final String userId;
  final LatLng location;
  final DateTime timestamp;
  final double accuracy;
  final double? speed;

  LocationHistoryEntry({
    required this.id,
    required this.userId,
    required this.location,
    required this.timestamp,
    required this.accuracy,
    this.speed,
  });

  // Factory for RPC function results (coordinates already converted)
  factory LocationHistoryEntry.fromRpcResult(Map<String, dynamic> json) {
    return LocationHistoryEntry(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      location: LatLng(
        (json['latitude'] ?? 0.0).toDouble(),
        (json['longitude'] ?? 0.0).toDouble(),
      ),
      timestamp: DateTime.parse(json['recorded_at']),
      accuracy: (json['accuracy'] ?? 0.0).toDouble(),
      speed: json['speed']?.toDouble(),
    );
  }

  // Factory for direct table access (needs location parsing)
  factory LocationHistoryEntry.fromJson(Map<String, dynamic> json) {
    LatLng parseLocation(Map<String, dynamic> json) {
      if (json['location'] != null) {
        final locationValue = json['location'];
        
        // Check if it's already in text format (POINT(...))
        if (locationValue is String && locationValue.startsWith('POINT(')) {
          final pointRegex = RegExp(r'POINT\(([-\d.]+) ([-\d.]+)\)');
          final match = pointRegex.firstMatch(locationValue);
          if (match != null) {
            final lng = double.parse(match.group(1)!);
            final lat = double.parse(match.group(2)!);
            return LatLng(lat, lng);
          }
        }
        
        // Handle PostGIS binary format (WKB with SRID)
        // The format is typically: 0101000020E610000046D3D9C9E02D46407A8EC87729A94040
        // This is a hex-encoded WKB with SRID 4326 (WGS84)
        if (locationValue is String && locationValue.length > 20) {
          try {
            // For now, let's try to extract coordinates using a different approach
            // We'll create a simpler parser or use a workaround
            
            // PostGIS WKB format parsing is complex, so let's use a coordinate-based approach
            // This is a temporary solution - ideally we'd use a proper WKB parser
            
            // For now, PostGIS binary format parsing is complex
            // We'll rely on the RPC function for proper coordinate extraction
            // This is just a placeholder that logs the format for debugging
            
            // Log the binary format for debugging
            // This will help us understand the exact format if we need to parse it manually
            return LatLng(0.0, 0.0); // Placeholder - use RPC function instead
          } catch (e) {
            // Fall through to error
          }
        }
        
        // If it's a Map (JSON object), try to extract coordinates
        if (locationValue is Map) {
          try {
            if (locationValue['coordinates'] != null && locationValue['coordinates'] is List) {
              final coords = locationValue['coordinates'] as List;
              if (coords.length >= 2) {
                final lng = (coords[0] as num).toDouble();
                final lat = (coords[1] as num).toDouble();
                return LatLng(lat, lng);
              }
            }
          } catch (e) {
            // Fall through to error
          }
        }
      }
      
      throw FormatException('Invalid location format. Raw location: ${json['location']} (type: ${json['location'].runtimeType})');
    }

    // Try different timestamp column names or use current time as fallback
    DateTime timestamp;
    try {
      if (json['recorded_at'] != null) {
        timestamp = DateTime.parse(json['recorded_at']);
      } else if (json['created_at'] != null) {
        timestamp = DateTime.parse(json['created_at']);
      } else if (json['inserted_at'] != null) {
        timestamp = DateTime.parse(json['inserted_at']);
      } else if (json['timestamp'] != null) {
        timestamp = DateTime.parse(json['timestamp']);
      } else {
        // Fallback to current time if no timestamp found
        timestamp = DateTime.now();
      }
    } catch (e) {
      // If parsing fails, use current time
      timestamp = DateTime.now();
    }

    return LocationHistoryEntry(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      location: parseLocation(json),
      timestamp: timestamp,
      accuracy: (json['accuracy'] ?? 0.0).toDouble(),
      speed: json['speed']?.toDouble(),
    );
  }

  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  String get formattedLocation {
    return '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
  }

  String get formattedAccuracy {
    return '±${accuracy.toStringAsFixed(1)}m';
  }

  String get formattedSpeed {
    if (speed == null) return 'N/A';
    final speedKmh = (speed! * 3.6);
    return '${speedKmh.toStringAsFixed(1)} km/h';
  }
}

class HourlyLocationSummary {
  final DateTime hour;
  final List<LocationHistoryEntry> locations;
  final LatLng? startLocation;
  final LatLng? endLocation;
  final double totalDistance;
  final double averageSpeed;
  final double averageAccuracy;

  HourlyLocationSummary({
    required this.hour,
    required this.locations,
    this.startLocation,
    this.endLocation,
    required this.totalDistance,
    required this.averageSpeed,
    required this.averageAccuracy,
  });

  String get formattedHour {
    final hourStr = hour.hour.toString().padLeft(2, '0');
    return '$hourStr:00 - ${(hour.hour + 1).toString().padLeft(2, '0')}:00';
  }

  String get formattedDate {
    return '${hour.day}/${hour.month}/${hour.year}';
  }

  String get locationCount {
    return '${locations.length} locations';
  }

  String get formattedDistance {
    if (totalDistance < 1000) {
      return '${totalDistance.toStringAsFixed(0)}m';
    } else {
      return '${(totalDistance / 1000).toStringAsFixed(1)}km';
    }
  }

  String get formattedAverageSpeed {
    return '${averageSpeed.toStringAsFixed(1)} km/h';
  }

  String get formattedAverageAccuracy {
    return '±${averageAccuracy.toStringAsFixed(1)}m';
  }

  // Calculate distance between two points using Haversine formula
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth radius in meters
    final double dLat = _degreesToRadians(point2.latitude - point1.latitude);
    final double dLon = _degreesToRadians(point2.longitude - point1.longitude);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(point1.latitude)) *
        math.cos(_degreesToRadians(point2.latitude)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  static List<HourlyLocationSummary> groupLocationsByHour(List<LocationHistoryEntry> locations) {
    if (locations.isEmpty) return [];

    final Map<DateTime, List<LocationHistoryEntry>> hourlyGroups = {};
    
    for (final location in locations) {
      final hourKey = DateTime(
        location.timestamp.year,
        location.timestamp.month,
        location.timestamp.day,
        location.timestamp.hour,
      );
      
      if (!hourlyGroups.containsKey(hourKey)) {
        hourlyGroups[hourKey] = [];
      }
      hourlyGroups[hourKey]!.add(location);
    }

    return hourlyGroups.entries.map((entry) {
      final hour = entry.key;
      final hourLocations = entry.value;
      
      // Sort locations by timestamp within the hour
      hourLocations.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // Calculate summary statistics
      final startLocation = hourLocations.isNotEmpty ? hourLocations.first.location : null;
      final endLocation = hourLocations.length > 1 ? hourLocations.last.location : null;
      
      double totalDistance = 0.0;
      if (hourLocations.length > 1) {
        for (int i = 1; i < hourLocations.length; i++) {
          totalDistance += _calculateDistance(
            hourLocations[i - 1].location,
            hourLocations[i].location,
          );
        }
      }

      final averageSpeed = hourLocations
          .where((l) => l.speed != null)
          .map((l) => l.speed! * 3.6) // Convert m/s to km/h
          .fold(0.0, (sum, speed) => sum + speed) / 
          math.max(1, hourLocations.where((l) => l.speed != null).length);

      final averageAccuracy = hourLocations
          .map((l) => l.accuracy)
          .fold(0.0, (sum, acc) => sum + acc) / hourLocations.length;

      return HourlyLocationSummary(
        hour: hour,
        locations: hourLocations,
        startLocation: startLocation,
        endLocation: endLocation,
        totalDistance: totalDistance,
        averageSpeed: averageSpeed,
        averageAccuracy: averageAccuracy,
      );
    }).toList()
      ..sort((a, b) => b.hour.compareTo(a.hour)); // Sort by hour descending
  }
}

class AgentInfo {
  final String id;
  final String fullName;
  final String role;

  AgentInfo({
    required this.id,
    required this.fullName,
    required this.role,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) {
    return AgentInfo(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Unknown Agent',
      role: json['role']?.toString() ?? 'agent',
    );
  }
}
