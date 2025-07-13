// lib/services/persistent_service_manager.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'background_location_service.dart';
import 'user_status_service.dart';
import '../utils/constants.dart';

class PersistentServiceManager {
  static const String _channelId = 'al_tijwal_persistent_service';
  static const String _channelName = 'Al-Tijwal Service';
  static const int _notificationId = 999;
  
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // Initialize the persistent service
  static Future<void> initialize() async {
    // Initialize notifications first
    await _initializeNotifications();
    
    // Then initialize background service
    await BackgroundLocationService.initialize();
    
    // Check if services are already running and show notification if needed
    await _checkAndShowExistingNotification();
  }
  
  // Check if services are running and show notification if needed
  static Future<void> _checkAndShowExistingNotification() async {
    try {
      final isRunning = await areServicesRunning();
      if (isRunning) {
        // Check if notification is already showing to avoid duplicates
        final activeNotifications = await _notifications.getActiveNotifications();
        final hasActiveNotification = activeNotifications.any((n) => n.id == _notificationId);
        
        if (!hasActiveNotification) {
          debugPrint('✅ Services running but no notification found - showing persistent notification');
          await _showPersistentNotification();
        } else {
          debugPrint('✅ Services running and notification already active - skipping');
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking existing service status: $e');
    }
  }
  
  static Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    
    // Create notification channel with high importance
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Keeps Al-Tijwal services running in background',
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
      showBadge: true,
    );
    
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }
  
  // Handle notification taps and actions
  static void _handleNotificationResponse(NotificationResponse response) {
    if (response.actionId == 'stop_service') {
      stopAllServices();
    }
  }
  
  // Start all services with persistent notification
  static Future<bool> startAllServices(BuildContext context) async {
    try {
      // Check permissions first
      final locationPermission = await Permission.locationAlways.status;
      if (!locationPermission.isGranted) {
        final result = await Permission.locationAlways.request();
        if (!result.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission is required for background tracking'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      }
      
      // Check notification permission (Android 13+)
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      
      // Show persistent notification
      await _showPersistentNotification();
      
      // Start background location service
      await BackgroundLocationService.startLocationTracking();
      
      // Initialize user status service if not already done
      await UserStatusService().initialize();
      
      // Store service state
      await supabase.auth.currentUser?.userMetadata?['service_active'] ?? true;
      
      debugPrint('✅ All services started with persistent notification');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting services: $e');
      return false;
    }
  }
  
  // Stop all services
  static Future<void> stopAllServices() async {
    try {
      // Stop location tracking
      await BackgroundLocationService.stopLocationTracking();
      
      // Dispose user status service
      UserStatusService().dispose();
      
      // Cancel persistent notification
      await _notifications.cancel(_notificationId);
      
      // Update service state
      await supabase.auth.currentUser?.userMetadata?['service_active'] ?? false;
      
      debugPrint('✅ All services stopped');
    } catch (e) {
      debugPrint('❌ Error stopping services: $e');
    }
  }
  
  // Show persistent notification with action buttons
  static Future<void> _showPersistentNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Keeps Al-Tijwal services running in background',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true, // Can't be swiped away
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      usesChronometer: false, // Remove time counter
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        'Location tracking and online status are active. Your location is being shared with your manager.',
        contentTitle: 'Al-Tijwal Services Running',
        summaryText: 'Tap to open app',
      ),
      // Add action button
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'stop_service',
          'Stop Services',
          icon: DrawableResourceAndroidBitmap('ic_stop'),
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
      // Custom small icon
      icon: 'ic_notification',
      // Color
      color: primaryColor,
      colorized: true,
      // Group
      groupKey: 'al_tijwal_services',
      setAsGroupSummary: true,
      // Full screen intent for importance
      fullScreenIntent: true,
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
      ),
    );
    
    await _notifications.show(
      _notificationId,
      'Al-Tijwal Services Running',
      'Location tracking and online status active',
      notificationDetails,
      payload: 'service_notification',
    );
  }
  
  // Update notification with new information
  static Future<void> updateNotification({
    String? title,
    String? body,
    String? summaryText,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Keeps Al-Tijwal services running in background',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      usesChronometer: false,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        body ?? 'Location tracking and online status are active',
        contentTitle: title ?? 'Al-Tijwal Services Running',
        summaryText: summaryText ?? 'Tap to open app',
      ),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'stop_service',
          'Stop Services',
          icon: DrawableResourceAndroidBitmap('ic_stop'),
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
      icon: 'ic_notification',
      color: primaryColor,
      colorized: true,
    );
    
    final notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    
    await _notifications.show(
      _notificationId,
      title ?? 'Al-Tijwal Services Running',
      body ?? 'Location tracking and online status active',
      notificationDetails,
      payload: 'service_notification',
    );
  }
  
  // Check if services are running
  static Future<bool> areServicesRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }
  
  // Get service status
  static Future<Map<String, dynamic>> getServiceStatus() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    
    return {
      'isRunning': isRunning,
      'locationTracking': isRunning,
      'statusTracking': UserStatusService().isActive,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }
  
  // Public method to restore notification if services are running
  static Future<void> restoreNotificationIfNeeded() async {
    await _checkAndShowExistingNotification();
  }
}