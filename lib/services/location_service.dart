// lib/services/location_service.dart

import 'dart:async'; // <-- FIX: Corrected import from 'dart.async' to 'dart:async'
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';

final logger = Logger();

class GeofenceStatus {
  final String campaignId;
  final bool isInside;
  GeofenceStatus({required this.campaignId, required this.isInside});
}

class LocationService {
  Timer? _timer;
  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _locationDataController = StreamController<Position>.broadcast();
  final StreamController<GeofenceStatus> _geofenceStatusController = StreamController<GeofenceStatus>.broadcast();

  Stream<Position> get locationStream => _locationDataController.stream;
  Stream<GeofenceStatus> get geofenceStatusStream => _geofenceStatusController.stream;

  String? _activeCampaignId;

  // --- FIX: Method renamed back to setActiveCampaign for consistency ---
  void setActiveCampaign(String? campaignId) {
    _activeCampaignId = campaignId;
    if (campaignId != null) {
      logger.i("LocationService is now tracking for campaign: $campaignId");
    } else {
      logger.i("LocationService is no longer tracking for a specific campaign.");
    }
    
    // Background service replaced with position streaming
  }

  Future<void> start() async {
    logger.i("Attempting to start LocationService...");
    stop();
    final hasPermission = await _handlePermission();
    if (!hasPermission) return;
    
    // Start location stream for continuous tracking (works in background)
    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters of movement
        timeLimit: Duration(seconds: 30), // Timeout for each location request
      );
      
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          logger.i("Stream location: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)");
          _locationDataController.add(position);
          _sendLocationUpdate(position);
          
          // Check geofence if campaign is active
          if (_activeCampaignId != null) {
            _checkGeofenceStatus(_activeCampaignId!);
          }
        },
        onError: (e) {
          logger.e("Location stream error: $e");
        },
      );
      
      logger.i('Location streaming started (works in background).');
    } catch (e) {
      logger.e('Failed to start location stream: $e');
      
      // Fallback to timer-based approach
      _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
        _fetchAndProcessLocation();
      });
      logger.i('Fallback to timer-based location tracking.');
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    
    setActiveCampaign(null);
    logger.i('Location tracking stopped.');
  }

  Future<void> _fetchAndProcessLocation() async {
    try {
      logger.i("Attempting to get current location...");
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high, // Changed from bestForNavigation for emulator compatibility
        timeLimit: const Duration(seconds: 10), // Increased timeout for emulator
      );
      
      logger.i("Location obtained: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)");
      _locationDataController.add(position);
      await _sendLocationUpdate(position);
      
      // We only have one active campaign at a time, so we check it here.
      if (_activeCampaignId != null) {
        await _checkGeofenceStatus(_activeCampaignId!);
      }
    } catch (e) {
      logger.e("Could not get/process current position: $e");
      
      // For debugging: try to get last known position as fallback
      try {
        final Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          logger.i("Using last known position: ${lastPosition.latitude}, ${lastPosition.longitude}");
          _locationDataController.add(lastPosition);
          await _sendLocationUpdate(lastPosition);
        } else {
          logger.w("No last known position available");
        }
      } catch (fallbackError) {
        logger.e("Failed to get last known position: $fallbackError");
      }
    }
  }

  Future<void> _sendLocationUpdate(Position position) async {
    if (position.accuracy > 75) return;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final locationString = 'POINT(${position.longitude} ${position.latitude})';
    try {
      await supabase.from('location_history').insert({
        'user_id': userId,
        'location': locationString,
        'accuracy': position.accuracy,
        'speed': position.speed,
      });
    } catch (e) {
      logger.e('Failed to send location update: $e');
    }
  }

  Future<void> _checkGeofenceStatus(String campaignId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final bool isInside = await supabase.rpc('check_agent_in_campaign_geofence', params: {
        'p_agent_id': userId,
        'p_campaign_id': campaignId,
      });
      _geofenceStatusController.add(GeofenceStatus(campaignId: campaignId, isInside: isInside));
    } catch (e) {
      logger.e('Failed to check geofence status for $campaignId: $e');
    }
  }

  Future<bool> _handlePermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      logger.i('Location service enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        logger.w('Location service is not enabled');
        return false;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      logger.i('Current location permission: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        logger.i('Permission after request: $permission');
        if (permission == LocationPermission.denied) {
          logger.w('Location permission denied by user');
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        logger.w('Location permission denied forever');
        return false;
      }
      
      // Request background location permission for Android
      try {
        final backgroundStatus = await Permission.locationAlways.status;
        logger.i('Background location permission status: $backgroundStatus');
        
        if (backgroundStatus.isDenied) {
          final result = await Permission.locationAlways.request();
          logger.i('Background permission after request: $result');
          if (result.isDenied) {
            logger.w('Background location permission denied - continuing with foreground only');
          }
        }
      } catch (e) {
        logger.w('Failed to request background permission: $e');
        // Continue anyway - foreground tracking will still work
      }
      
      logger.i('Location permissions successfully configured');
      return true;
    } catch (e) {
      logger.e('Error handling location permissions: $e');
      return false;
    }
  }
}
