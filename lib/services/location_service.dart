// lib/services/location_service.dart

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';
import 'settings_service.dart';

final logger = Logger();

class GeofenceStatus {
  final String campaignId;
  final bool isInside;
  GeofenceStatus({required this.campaignId, required this.isInside});
}

class LocationService {
  Timer? _timer;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<Map<String, AppSetting>>? _settingsSubscription;
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
    stop();
    
    final hasPermission = await _handlePermission();
    if (!hasPermission) {
      logger.e("❌ Location permission denied");
      return;
    }
    
    // Subscribe to settings changes to restart tracking with new settings
    _settingsSubscription = SettingsService.instance.settingsStream.listen((settings) {
      logger.i('Settings changed, restarting location tracking');
      _restartLocationTracking();
    });
    
    _startLocationTracking();
  }

  void _startLocationTracking() async {
    // Get current settings
    final distanceFilter = SettingsService.instance.gpsDistanceFilter;
    final timeout = SettingsService.instance.gpsTimeout;
    final accuracyLevel = _getLocationAccuracy(SettingsService.instance.gpsAccuracyLevel);
    
    // Start location stream for continuous tracking (works in background)
    try {
      final LocationSettings locationSettings = LocationSettings(
        accuracy: accuracyLevel,
        distanceFilter: distanceFilter,
        timeLimit: Duration(seconds: timeout),
      );
      
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _locationDataController.add(position);
          _sendLocationUpdate(position);
          
          // Check geofence if campaign is active
          if (_activeCampaignId != null) {
            _checkGeofenceStatus(_activeCampaignId!);
          }
        },
        onError: (e) {
          _startTimerBasedTracking();
        },
      );
    } catch (e) {
      _startTimerBasedTracking();
    }
  }

  void _startTimerBasedTracking() {
    _timer?.cancel();
    final pingInterval = SettingsService.instance.gpsPingInterval;
    _timer = Timer.periodic(Duration(seconds: pingInterval), (timer) {
      _fetchAndProcessLocation();
    });
  }

  void _restartLocationTracking() {
    _positionStreamSubscription?.cancel();
    _timer?.cancel();
    _startLocationTracking();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    
    _settingsSubscription?.cancel();
    _settingsSubscription = null;
    
    setActiveCampaign(null);
    logger.i('Location tracking stopped.');
  }

  Future<void> _fetchAndProcessLocation() async {
    try {
      final accuracyLevel = _getLocationAccuracy(SettingsService.instance.gpsAccuracyLevel);
      final timeout = SettingsService.instance.gpsTimeout;
      
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracyLevel,
        timeLimit: Duration(seconds: timeout),
      );
      
      _locationDataController.add(position);
      await _sendLocationUpdate(position);
      
      if (_activeCampaignId != null) {
        await _checkGeofenceStatus(_activeCampaignId!);
      }
    } catch (e) {
      // Try last known position as fallback
      try {
        final Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          _locationDataController.add(lastPosition);
          await _sendLocationUpdate(lastPosition);
          
          if (_activeCampaignId != null) {
            await _checkGeofenceStatus(_activeCampaignId!);
          }
        }
      } catch (fallbackError) {
        // Silent fail
      }
    }
  }

  Future<void> _sendLocationUpdate(Position position) async {
    final accuracyThreshold = SettingsService.instance.gpsAccuracyThreshold;
    if (position.accuracy > accuracyThreshold) return;
    
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
      // Only log successful database inserts to verify it's working
      logger.i("📍 ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)} → DB ✅");
    } catch (e) {
      logger.e('❌ DB error: $e');
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

  /// Check if agent is within task geofence for evidence upload validation
  Future<bool> isAgentInTaskGeofence(String taskId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      // Get current location
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      // Check if task has geofence and if agent is inside
      final result = await supabase.rpc('check_agent_in_task_geofence', params: {
        'p_agent_id': userId,
        'p_task_id': taskId,
        'p_agent_lat': position.latitude,
        'p_agent_lng': position.longitude,
      });
      
      return result as bool;
    } catch (e) {
      logger.e('Failed to check task geofence for $taskId: $e');
      return false;
    }
  }

  /// Get current location for geofence validation
  Future<Position?> getCurrentLocation() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return position;
    } catch (e) {
      logger.e('Failed to get current location: $e');
      return null;
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

  LocationAccuracy _getLocationAccuracy(String accuracyLevel) {
    switch (accuracyLevel.toLowerCase()) {
      case 'low':
        return LocationAccuracy.low;
      case 'medium':
        return LocationAccuracy.medium;
      case 'high':
        return LocationAccuracy.high;
      case 'best':
        return LocationAccuracy.best;
      default:
        return LocationAccuracy.medium;
    }
  }
}
