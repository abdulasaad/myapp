// lib/services/location_service.dart

import 'dart:async'; // <-- FIX: Corrected import from 'dart.async' to 'dart:async'
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import '../utils/constants.dart';

final logger = Logger();

class GeofenceStatus {
  final String campaignId;
  final bool isInside;
  GeofenceStatus({required this.campaignId, required this.isInside});
}

class LocationService {
  // --- FIX: The Timer class is now correctly recognized ---
  Timer? _timer;
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
  }

  Future<void> start() async {
    logger.i("Attempting to start LocationService...");
    stop();
    final hasPermission = await _handlePermission();
    if (!hasPermission) return;
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchAndProcessLocation();
    });
    logger.i('Assertive high-accuracy service started.');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    setActiveCampaign(null);
  }

  Future<void> _fetchAndProcessLocation() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 8),
      );
      _locationDataController.add(position);
      await _sendLocationUpdate(position);
      // We only have one active campaign at a time, so we check it here.
      if (_activeCampaignId != null) {
        await _checkGeofenceStatus(_activeCampaignId!);
      }
    } catch (e) {
      logger.e("Could not get/process current position: $e");
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
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }
}
