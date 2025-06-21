// lib/services/background_location_service.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

final logger = Logger();

@pragma('vm:entry-point')
class BackgroundLocationService {
  static const String _channelId = 'al_tijwal_location_service';

  @pragma('vm:entry-point')
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'Al-Tijwal Location Service',
        initialNotificationContent: 'Initializing location tracking...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<void> startLocationTracking() async {
    final service = FlutterBackgroundService();
    
    // Check if service is already running
    bool isRunning = await service.isRunning();
    if (!isRunning) {
      service.startService();
    }
  }

  @pragma('vm:entry-point')
  static Future<void> stopLocationTracking() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }

  @pragma('vm:entry-point')
  static Future<void> setActiveCampaign(String? campaignId) async {
    final service = FlutterBackgroundService();
    service.invoke('setActiveCampaign', {'campaignId': campaignId});
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
      
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
      
      // Set as foreground service immediately with notification
      service.setForegroundNotificationInfo(
        title: 'Al-Tijwal Location Service',
        content: 'Tracking location in background',
      );
    }

    String? activeCampaignId;
    Timer? locationTimer;

    // Use existing Supabase instance or initialize if needed
    late SupabaseClient supabase;
    try {
      supabase = Supabase.instance.client;
    } catch (e) {
      // Initialize if not already initialized
      await Supabase.initialize(
        url: 'https://jnuzpixgfskjcoqmgkxb.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpudXpwaXhnZnNramNvcW1na3hiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkyODI4NTksImV4cCI6MjA2NDg1ODg1OX0.9H9ukV77BtyfX8Vhnlz2KqJeqPv-hxIhGeZdNsOeaPk',
      );
      supabase = Supabase.instance.client;
    }

    Future<void> fetchAndSendLocation() async {
      try {
        // Check permissions
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied || 
            permission == LocationPermission.deniedForever) {
          logger.w('Location permission denied in background service');
          return;
        }

        // Get current position
        final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );

        // Only send if accuracy is good enough
        if (position.accuracy > 100) {
          logger.w('Location accuracy too low: ${position.accuracy}m');
          return;
        }

        // Get current user ID from stored session
        final currentUser = supabase.auth.currentUser;
        if (currentUser == null) {
          logger.w('No authenticated user in background service');
          return;
        }

        // Send location to database
        final locationString = 'POINT(${position.longitude} ${position.latitude})';
        await supabase.from('location_history').insert({
          'user_id': currentUser.id,
          'location': locationString,
          'accuracy': position.accuracy,
          'speed': position.speed,
        });

        logger.i('Background location sent: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');

        // Check geofence if campaign is active
        if (activeCampaignId != null) {
          try {
            final bool isInside = await supabase.rpc('check_agent_in_campaign_geofence', params: {
              'p_agent_id': currentUser.id,
              'p_campaign_id': activeCampaignId,
            });
            logger.i('Geofence check for campaign $activeCampaignId: $isInside');
          } catch (e) {
            logger.e('Failed to check geofence in background: $e');
          }
        }

        // Update notification with latest location info
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'Al-Tijwal Location Service',
            content: 'Last update: ${DateTime.now().toString().substring(11, 16)} (${position.accuracy.toStringAsFixed(0)}m accuracy)',
          );
        }

      } catch (e) {
        logger.e('Error in background location fetch: $e');
      }
    }

    // Start location tracking timer
    void startLocationTracking() {
      locationTimer?.cancel();
      locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        fetchAndSendLocation();
      });
      logger.i('Background location tracking started');
    }

    // Listen for service commands
    service.on('start').listen((event) {
      startLocationTracking();
    });

    service.on('stop').listen((event) {
      locationTimer?.cancel();
      service.stopSelf();
      logger.i('Background location tracking stopped');
    });

    service.on('setActiveCampaign').listen((event) {
      activeCampaignId = event?['campaignId'];
      logger.i('Active campaign set to: $activeCampaignId');
    });

    // Auto-start location tracking
    startLocationTracking();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }
}