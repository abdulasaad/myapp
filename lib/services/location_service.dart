// lib/services/location_service.dart

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

final logger = Logger();
final supabase = Supabase.instance.client;

class LocationService {
  // --- THE NEW STRATEGY: Use a Timer to trigger one-time requests ---
  Timer? _timer;

  final StreamController<Position> _locationDataController = StreamController<Position>.broadcast();
  Stream<Position> get locationStream => _locationDataController.stream;

  Future<void> start() async {
    logger.i("Attempting to start LocationService (Assertive Fetch Version)...");
    
    stop(); // Stop any existing services

    final hasPermission = await _handlePermission();
    if (!hasPermission) {
      logger.e('Permissions not granted. Service cannot start.');
      return;
    }

    // This timer will fire every 10 seconds.
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchAndBroadcastLocation();
    });

    // Also listen internally to send data to Supabase.
    locationStream.listen(_sendLocationUpdate);

    logger.i('Assertive high-accuracy service started.');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// This is the core logic, adapted from your working sample code.
  /// It makes an assertive request for a fresh, high-accuracy location.
  Future<void> _fetchAndBroadcastLocation() async {
    try {
      // The key call: this waits for a good quality fix.
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        // Add a time limit to prevent it from getting stuck indefinitely.
        timeLimit: const Duration(seconds: 8),
      );

      // If successful, broadcast the high-quality position.
      _locationDataController.add(position);
      
    } catch (e) {
      logger.e("Could not get current position: $e");
    }
  }

  /// Sends the location update to Supabase. (No changes needed here)
  void _sendLocationUpdate(Position position) {
    if (position.accuracy > 75) {
      logger.w('Ignored location update due to poor accuracy: ${position.accuracy}m');
      return;
    }
    
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final locationString = 'POINT(${position.longitude} ${position.latitude})';

    supabase.from('location_history').insert({
      'user_id': userId,
      'location': locationString,
      'accuracy': position.accuracy,
      'speed': position.speed,
    }).catchError((e) {
      logger.e('Failed to send location update: $e');
    });

    logger.i('Assertive location sent (Accuracy: ${position.accuracy}m).');
  }

  /// Handles checking and requesting permissions. (No changes needed here)
  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      logger.e('Location services are disabled.');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        logger.e('Location permissions are denied.');
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      logger.e('Location permissions are permanently denied.');
      return false;
    } 
    
    return true;
  }
}