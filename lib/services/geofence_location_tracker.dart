// lib/services/geofence_location_tracker.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/agent_geofence_assignment.dart';
import '../models/campaign_geofence.dart';
import '../services/campaign_geofence_service.dart';
import '../utils/constants.dart';

class GeofenceLocationTracker {
  static final GeofenceLocationTracker _instance = GeofenceLocationTracker._internal();
  factory GeofenceLocationTracker() => _instance;
  GeofenceLocationTracker._internal();

  final CampaignGeofenceService _geofenceService = CampaignGeofenceService();
  
  StreamSubscription<Position>? _positionSubscription;
  AgentGeofenceAssignment? _currentAssignment;
  CampaignGeofence? _currentGeofence;
  List<LatLng> _geofencePoints = [];
  bool _isInsideGeofence = false;
  bool _isTracking = false;
  
  // Callbacks for status changes
  Function(bool isInside)? _onGeofenceStatusChanged;
  Function(Position position)? _onLocationUpdate;
  Function(String error)? _onError;

  /// Initialize tracking for an agent's current assignment
  Future<bool> startTracking({
    required String campaignId,
    required String agentId,
    Function(bool isInside)? onGeofenceStatusChanged,
    Function(Position position)? onLocationUpdate,
    Function(String error)? onError,
  }) async {
    try {
      // Set callbacks
      _onGeofenceStatusChanged = onGeofenceStatusChanged;
      _onLocationUpdate = onLocationUpdate;
      _onError = onError;

      // Get current assignment
      _currentAssignment = await _geofenceService.getAgentCurrentAssignment(
        campaignId: campaignId,
        agentId: agentId,
      );

      if (_currentAssignment == null) {
        debugPrint('🚫 No active geofence assignment found');
        return false;
      }

      // Get geofence details
      final geofences = await _geofenceService.getAvailableGeofencesForCampaign(campaignId);
      _currentGeofence = geofences.firstWhere(
        (g) => g.id == _currentAssignment!.geofenceId,
        orElse: () => throw Exception('Geofence not found'),
      );

      // Parse geofence polygon points
      _geofencePoints = _parseWKTToLatLng(_currentGeofence!.areaText);
      
      if (_geofencePoints.length < 3) {
        debugPrint('❌ Invalid geofence polygon');
        return false;
      }

      // Check location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _onError?.call('Location services are disabled');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _onError?.call('Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _onError?.call('Location permissions are permanently denied');
        return false;
      }

      // Start position stream
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // Update every 5 meters
          timeLimit: Duration(seconds: 10),
        ),
      ).listen(
        _onPositionUpdate,
        onError: (error) {
          debugPrint('❌ Location stream error: $error');
          _onError?.call('Location tracking error: $error');
        },
      );

      _isTracking = true;
      debugPrint('✅ Started geofence tracking for assignment: ${_currentAssignment!.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting geofence tracking: $e');
      _onError?.call('Failed to start tracking: $e');
      return false;
    }
  }

  /// Stop location tracking
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    _currentAssignment = null;
    _currentGeofence = null;
    _geofencePoints.clear();
    debugPrint('🛑 Stopped geofence tracking');
  }

  /// Handle location updates
  void _onPositionUpdate(Position position) async {
    if (_currentAssignment == null || _currentGeofence == null) return;

    try {
      // Check if position is inside geofence
      final latLng = LatLng(position.latitude, position.longitude);
      final isInside = _isPointInPolygon(latLng, _geofencePoints);
      
      // Track location in database
      await _geofenceService.trackAgentLocation(
        agentId: _currentAssignment!.agentId,
        geofenceId: _currentAssignment!.geofenceId,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        isInsideGeofence: isInside,
      );

      // Check for status change
      if (isInside != _isInsideGeofence) {
        _isInsideGeofence = isInside;
        debugPrint('📍 Geofence status changed: ${isInside ? 'INSIDE' : 'OUTSIDE'}');
        _onGeofenceStatusChanged?.call(isInside);
      }

      // Notify location update
      _onLocationUpdate?.call(position);

      debugPrint('📍 Location: ${position.latitude}, ${position.longitude} - Inside: $isInside');
    } catch (e) {
      debugPrint('❌ Error processing location update: $e');
    }
  }

  /// Parse WKT POLYGON to LatLng points
  List<LatLng> _parseWKTToLatLng(String wkt) {
    try {
      // Parse WKT POLYGON format: "POLYGON((lat lng, lat lng, ...))"
      final coordsStr = wkt.replaceAll(RegExp(r'POLYGON\(\(|\)\)'), '');
      final coords = coordsStr.split(',').map((coord) {
        final parts = coord.trim().split(' ');
        if (parts.length >= 2) {
          final lat = double.tryParse(parts[0]);
          final lng = double.tryParse(parts[1]);
          if (lat != null && lng != null) {
            return LatLng(lat, lng);
          }
        }
        return null;
      }).where((point) => point != null).cast<LatLng>().toList();
      
      return coords;
    } catch (e) {
      debugPrint('❌ Error parsing WKT: $e');
      return [];
    }
  }

  /// Check if a point is inside a polygon using ray casting algorithm
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      if (((polygon[i].latitude > point.latitude) != (polygon[j].latitude > point.latitude)) &&
          (point.longitude < (polygon[j].longitude - polygon[i].longitude) * 
           (point.latitude - polygon[i].latitude) / (polygon[j].latitude - polygon[i].latitude) + polygon[i].longitude)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Calculate distance from point to geofence boundary
  double getDistanceToGeofence(LatLng point) {
    if (_geofencePoints.isEmpty) return double.infinity;

    double minDistance = double.infinity;

    // Calculate distance to each edge of the polygon
    for (int i = 0; i < _geofencePoints.length; i++) {
      final j = (i + 1) % _geofencePoints.length;
      final distance = _distanceToLineSegment(point, _geofencePoints[i], _geofencePoints[j]);
      minDistance = min(minDistance, distance);
    }

    return minDistance;
  }

  /// Calculate distance from a point to a line segment
  double _distanceToLineSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    const double earthRadius = 6371000; // Earth radius in meters

    // Convert to radians
    final lat1 = point.latitude * pi / 180;
    final lon1 = point.longitude * pi / 180;
    final lat2 = lineStart.latitude * pi / 180;
    final lon2 = lineStart.longitude * pi / 180;
    final lat3 = lineEnd.latitude * pi / 180;
    final lon3 = lineEnd.longitude * pi / 180;

    // Calculate distances using Haversine formula
    final d13 = 2 * earthRadius * asin(sqrt(
      pow(sin((lat1 - lat2) / 2), 2) + 
      cos(lat2) * cos(lat1) * pow(sin((lon1 - lon2) / 2), 2)
    ));

    final d23 = 2 * earthRadius * asin(sqrt(
      pow(sin((lat2 - lat3) / 2), 2) + 
      cos(lat3) * cos(lat2) * pow(sin((lon2 - lon3) / 2), 2)
    ));

    final d12 = 2 * earthRadius * asin(sqrt(
      pow(sin((lat1 - lat3) / 2), 2) + 
      cos(lat3) * cos(lat1) * pow(sin((lon1 - lon3) / 2), 2)
    ));

    // Check if the closest point is on the line segment
    if (d23 == 0) return d13;
    
    final cosA = (d13 * d13 + d23 * d23 - d12 * d12) / (2 * d13 * d23);
    final cosB = (d12 * d12 + d23 * d23 - d13 * d13) / (2 * d12 * d23);

    if (cosA <= 0) return d13;
    if (cosB <= 0) return d12;

    // Point is closest to somewhere on the line segment
    final sinA = sqrt(1 - cosA * cosA);
    return d13 * sinA;
  }

  // Getters
  bool get isTracking => _isTracking;
  bool get isInsideGeofence => _isInsideGeofence;
  AgentGeofenceAssignment? get currentAssignment => _currentAssignment;
  CampaignGeofence? get currentGeofence => _currentGeofence;
}

// Helper class for coordinate representation
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}