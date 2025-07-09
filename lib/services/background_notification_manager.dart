// lib/services/background_notification_manager.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'notification_service.dart';

class BackgroundNotificationManager {
  static final BackgroundNotificationManager _instance = BackgroundNotificationManager._internal();
  factory BackgroundNotificationManager() => _instance;
  BackgroundNotificationManager._internal();

  bool _isInitialized = false;
  Timer? _initializationTimer;

  /// Initialize background notification management
  /// This runs automatically when users are authenticated
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔄 Initializing background notification manager...');
      
      // Wait a bit for the app to settle, then initialize notifications
      await Future.delayed(const Duration(seconds: 2));
      
      // Check if user is authenticated
      if (supabase.auth.currentUser != null) {
        await _initializeNotificationService();
        _startBackgroundMonitoring();
      }
      
      _isInitialized = true;
      debugPrint('✅ Background notification manager initialized');
    } catch (e) {
      debugPrint('❌ Background notification manager initialization failed: $e');
    }
  }

  /// Initialize notification service in the background
  Future<void> _initializeNotificationService() async {
    try {
      debugPrint('🔄 Background: Initializing notification service...');
      await NotificationService().initialize();
      debugPrint('✅ Background: Notification service initialized');
    } catch (e) {
      debugPrint('❌ Background: Notification service initialization failed: $e');
    }
  }

  /// Start background monitoring for FCM token health
  void _startBackgroundMonitoring() {
    // Cancel existing timer
    _initializationTimer?.cancel();
    
    // Monitor FCM token health every 5 minutes in background
    _initializationTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      try {
        final currentUser = supabase.auth.currentUser;
        if (currentUser != null) {
          debugPrint('🔄 Background: Checking FCM token health...');
          
          // Silently ensure FCM token is valid
          await NotificationService().initialize();
          
          debugPrint('✅ Background: FCM token health check completed');
        } else {
          // User logged out, stop monitoring
          debugPrint('🛑 Background: User logged out, stopping FCM monitoring');
          timer.cancel();
          _isInitialized = false;
        }
      } catch (e) {
        debugPrint('❌ Background: FCM token health check failed: $e');
      }
    });
    
    debugPrint('✅ Background: FCM monitoring started (every 5 minutes)');
  }

  /// Stop background monitoring
  void stop() {
    _initializationTimer?.cancel();
    _initializationTimer = null;
    _isInitialized = false;
    debugPrint('🛑 Background notification manager stopped');
  }

  /// Manual refresh for testing
  Future<void> forceRefresh() async {
    debugPrint('🔄 Background: Force refreshing FCM token...');
    await _initializeNotificationService();
  }
}