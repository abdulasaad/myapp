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
  static const String _channelName = 'Al-Tijwal Location Service';

  @pragma('vm:entry-point')
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: _channelName,
        initialNotificationContent: 'Initializing location tracking...',
        foregroundServiceNotificationId: 888,
        autoStartOnBoot: false,
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
    try {
      final service = FlutterBackgroundService();
      
      // Check if service is already running
      bool isRunning = await service.isRunning();
      if (!isRunning) {
        logger.i('Starting background location service...');
        service.startService();
      } else {
        logger.i('Background location service already running');
      }
    } catch (e) {
      logger.e('Failed to start background location service: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> stopLocationTracking() async {
    try {
      final service = FlutterBackgroundService();
      logger.i('Stopping background location service...');
      service.invoke('stop');
    } catch (e) {
      logger.e('Failed to stop background location service: $e');
    }
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
      
      // Set as foreground service with proper notification after a small delay
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          service.setForegroundNotificationInfo(
            title: _channelName,
            content: 'Initializing location tracking...',
          );
          logger.i('Foreground notification set successfully');
        } catch (e) {
          logger.e('Failed to set foreground notification: $e');
        }
      });
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
          return;
        }

        // Get current position
        final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 30),
        );

        // Only send if accuracy is good enough
        if (position.accuracy > 100) {
          return;
        }

        // Get current user ID from stored session
        final currentUser = supabase.auth.currentUser;
        if (currentUser == null) {
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

        logger.i('📍 BG: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)} → DB ✅');

        // Check geofence if campaign is active
        if (activeCampaignId != null) {
          try {
            await supabase.rpc('check_agent_in_campaign_geofence', params: {
              'p_agent_id': currentUser.id,
              'p_campaign_id': activeCampaignId,
            });
          } catch (e) {
            // Silent fail
          }
        }

        // Update notification with latest location info
        if (service is AndroidServiceInstance) {
          try {
            service.setForegroundNotificationInfo(
              title: _channelName,
              content: 'Last update: ${DateTime.now().toString().substring(11, 16)} (${position.accuracy.toStringAsFixed(0)}m)',
            );
          } catch (e) {
            // Silently ignore notification errors
          }
        }

      } catch (e) {
        // Silent fail for background errors
      }
    }

    // Start location tracking timer
    void startLocationTracking() {
      locationTimer?.cancel();
      locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        fetchAndSendLocation();
      });
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