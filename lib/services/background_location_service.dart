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
        isForegroundMode: true,  // Enable foreground service for background protection
        notificationChannelId: _channelId,
        initialNotificationTitle: 'Al-Tijwal Location',
        initialNotificationContent: 'Tracking location for active tasks',
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
        logger.i('🚀 Starting background location service...');
        bool started = await service.startService();
        logger.i('📱 Background service start result: $started');
        
        // Wait a moment for service to initialize
        await Future.delayed(const Duration(seconds: 1));
        
        // Verify it's running
        isRunning = await service.isRunning();
        logger.i('📊 Background service running status: $isRunning');
      } else {
        logger.i('✅ Background location service already running');
      }
    } catch (e) {
      logger.e('❌ Failed to start background location service: $e');
      rethrow;
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
      // Keep as foreground service for background protection
      service.setAsForegroundService();
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

    // Helper functions
    Future<T> getSettingValue<T>(String key, T defaultValue) async {
      try {
        final response = await supabase
            .from('app_settings')
            .select('setting_value')
            .eq('setting_key', key)
            .maybeSingle();
        
        if (response != null) {
          final value = response['setting_value'];
          if (T == int) {
            return (int.tryParse(value) ?? defaultValue) as T;
          } else if (T == double) {
            return (double.tryParse(value) ?? defaultValue) as T;
          } else if (T == String) {
            return value as T;
          }
        }
      } catch (e) {
        // Silent fail, use default
      }
      return defaultValue;
    }

    LocationAccuracy getLocationAccuracy(String accuracyLevel) {
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

    Future<void> fetchAndSendLocation() async {
      try {
        // Check permissions
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied || 
            permission == LocationPermission.deniedForever) {
          return;
        }

        // Get settings
        final accuracyLevel = await getSettingValue('gps_accuracy_level', 'medium');
        final timeout = await getSettingValue('gps_timeout', 30);
        
        // Get current position
        final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: getLocationAccuracy(accuracyLevel),
          timeLimit: Duration(seconds: timeout),
        );

        // Get accuracy threshold from settings
        final accuracyThreshold = await getSettingValue('background_accuracy_threshold', 100);
        if (position.accuracy > accuracyThreshold) {
          return;
        }

        // Get current user ID from stored session
        final currentUser = supabase.auth.currentUser;
        if (currentUser == null) {
          // No authenticated user - stop the service
          locationTimer?.cancel();
          service.stopSelf();
          return;
        }

        // Send location to database
        final locationString = 'POINT(${position.longitude} ${position.latitude})';
        
        // Use server-side timestamp to avoid clock sync issues
        await supabase.rpc('insert_location_update', params: {
          'p_user_id': currentUser.id,
          'p_location': locationString,
          'p_accuracy': position.accuracy,
          'p_speed': position.speed,
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

        // Location tracking continues silently in background

      } catch (e) {
        // Silent fail for background errors
      }
    }


    // Start location tracking timer
    void startLocationTracking() async {
      locationTimer?.cancel();
      final pingInterval = await getSettingValue('gps_ping_interval', 30);
      locationTimer = Timer.periodic(Duration(seconds: pingInterval), (timer) {
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
    
    // Listen for interval updates
    service.on('updateInterval').listen((event) {
      final newInterval = event?['interval'] as int?;
      if (newInterval != null && newInterval > 0) {
        logger.i('📊 Updating tracking interval to ${newInterval}s');
        locationTimer?.cancel();
        locationTimer = Timer.periodic(Duration(seconds: newInterval), (timer) {
          fetchAndSendLocation();
        });
      }
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