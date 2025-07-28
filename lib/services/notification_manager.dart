// lib/services/notification_manager.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart';
import '../widgets/modern_notification.dart';

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  String? _fcmToken;
  
  // Callback for when notification count changes
  Function(int)? _onNotificationCountChanged;
  
  // Callback for when notification received while app is active
  Function(String title, String message, String type)? _onNotificationReceived;
  
  // Realtime subscription for notifications
  RealtimeChannel? _notificationChannel;

  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('Initializing NotificationManager...');
    
    // First, setup realtime listener (this always works)
    try {
      await _setupRealtimeListener();
      debugPrint('Realtime notification listener setup successfully');
    } catch (e) {
      debugPrint('Failed to setup realtime listener: $e');
    }

    // Try to initialize Firebase (optional - for system notifications)
    try {
      await Firebase.initializeApp();
      debugPrint('Firebase initialized successfully');
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      debugPrint('Local notifications initialized');
      
      // Setup FCM
      await _setupFCM();
      debugPrint('FCM setup completed');
    } catch (firebaseError) {
      debugPrint('Firebase/FCM setup failed (continuing with realtime notifications only): $firebaseError');
      // Continue without Firebase - we'll still have realtime notifications
    }
    
    _initialized = true;
    debugPrint('NotificationManager initialization completed');
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@drawable/notification_icon');
    
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'al_tijwal_notifications',
      'AL-Tijwal Notifications',
      description: 'Notifications for campaigns, tasks, and assignments',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _setupFCM() async {
    // Initialize FirebaseMessaging instance
    _firebaseMessaging = FirebaseMessaging.instance;
    
    // Request permission
    NotificationSettings settings = await _firebaseMessaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');
      
      // Get FCM token
      _fcmToken = await _firebaseMessaging!.getToken();
      debugPrint('FCM Token: $_fcmToken');
      
      // Save token to user profile
      await _saveFCMToken();
      
      // Handle token refresh
      _firebaseMessaging!.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFCMToken();
      });
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
      
      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      
    } else {
      debugPrint('User denied notification permission');
    }
  }

  Future<void> _setupRealtimeListener() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    debugPrint('🔄 Setting up notification polling for user: $userId');
    debugPrint('ℹ️ Realtime not available, using polling every 5 seconds');
    
    // Use polling instead of realtime since realtime is not available
    _startNotificationPolling();
    
    debugPrint('✅ Notification polling setup completed');
  }

  Timer? _pollingTimer;
  Set<String> _processedNotificationIds = {};

  void _startNotificationPolling() {
    // Initialize processed IDs with existing read notifications
    _initializeProcessedNotifications();
    
    // Poll every 5 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkForNewNotifications();
    });
    
    // Do an immediate check
    _checkForNewNotifications();
  }

  Future<void> _initializeProcessedNotifications() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      // Get all read notifications to avoid re-showing them
      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('recipient_id', userId)
          .not('read_at', 'is', null);
      
      final notifications = response as List<dynamic>;
      for (final notification in notifications) {
        _processedNotificationIds.add(notification['id']);
      }
      
      debugPrint('📋 Initialized with ${_processedNotificationIds.length} already read notifications');
    } catch (e) {
      debugPrint('❌ Error initializing processed notifications: $e');
    }
  }

  Future<void> _checkForNewNotifications() async {
    try {
      debugPrint('🔍 Polling for notifications...');
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('❌ No user ID found');
        return;
      }
      
      // Get all unread notifications
      final response = await supabase
          .from('notifications')
          .select('*')
          .eq('recipient_id', userId)
          .isFilter('read_at', null)
          .order('created_at', ascending: false);

      final notifications = response as List<dynamic>;
      debugPrint('📊 Found ${notifications.length} unread notifications');
      
      // Process any new unread notifications
      for (final notification in notifications) {
        final notificationId = notification['id'];
        
        // Skip if already processed
        if (_processedNotificationIds.contains(notificationId)) {
          continue;
        }
        
        debugPrint('🆕 New notification detected: ${notification['title']}');
        _processedNotificationIds.add(notificationId);
        
        final title = notification['title'] ?? 'New Notification';
        final message = notification['message'] ?? '';
        final type = notification['type'] ?? 'general';
        
        debugPrint('📱 Showing notification: $title - $message');
        
        // Show local system notification
        await _showLocalNotification(title, message, type);
        
        // Trigger callback for in-app notification (only for non-assignment types)
        if (_onNotificationReceived != null && _shouldShowModernNotification(type)) {
          debugPrint('🎯 Triggering in-app notification callback');
          _onNotificationReceived!(title, message, type);
        } else if (!_shouldShowModernNotification(type)) {
          debugPrint('📱 Assignment notification - showing only system notification (no modern popup)');
        } else {
          debugPrint('❌ No in-app notification callback set');
        }
      }
      
      // Always update badge count based on total unread
      await _updateBadgeCount();
      
    } catch (e) {
      debugPrint('❌ Error checking for new notifications: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _saveFCMToken() async {
    if (_fcmToken == null) return;
    
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      await supabase
          .from('profiles')
          .update({'fcm_token': _fcmToken})
          .eq('id', userId);
      
      debugPrint('FCM token saved to user profile');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    try {
      debugPrint('Received foreground message: ${message.notification?.title}');
      
      final title = message.notification?.title ?? 'New Notification';
      final body = message.notification?.body ?? '';
      final type = message.data['type'] ?? 'general';
      
      // Show local notification
      _showLocalNotification(title, body, type);
      
      // Trigger callback for in-app notification (only for non-assignment types)
      if (_onNotificationReceived != null && _shouldShowModernNotification(type)) {
        _onNotificationReceived!(title, body, type);
      }
      
      // Update badge count
      _updateBadgeCount();
    } catch (e) {
      debugPrint('Error handling foreground message: $e');
    }
  }


  Future<void> _showLocalNotification(String title, String body, String type) async {
    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'al_tijwal_notifications',
        'AL-Tijwal Notifications',
        channelDescription: 'Notifications for campaigns, tasks, and assignments',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/notification_icon',
        enableVibration: true,
        playSound: true,
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: type,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
      // Continue without local notification
    }
  }

  Future<void> _updateBadgeCount() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      final count = await supabase.rpc('get_unread_notification_count', params: {
        'user_id': userId,
      });
      
      if (_onNotificationCountChanged != null) {
        _onNotificationCountChanged!(count ?? 0);
      }
      
      debugPrint('Badge count updated: $count');
    } catch (e) {
      debugPrint('Error updating badge count: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap - could navigate to specific screen
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped from background: ${message.data}');
    // Handle notification tap from background
  }

  // Set callbacks
  void setOnNotificationCountChanged(Function(int) callback) {
    debugPrint('🔗 Setting notification count changed callback');
    _onNotificationCountChanged = callback;
  }

  void setOnNotificationReceived(Function(String, String, String) callback) {
    debugPrint('🔗 Setting notification received callback');
    _onNotificationReceived = callback;
  }

  // Show in-app notification
  void showInAppNotification(BuildContext context, {
    required String title,
    required String message,
    required String type,
  }) {
    final notificationType = _getNotificationType(type);
    
    ModernNotification.show(
      context,
      message: message,
      type: notificationType,
      subtitle: title,
      duration: const Duration(seconds: 4),
    );
  }

  NotificationType _getNotificationType(String type) {
    switch (type) {
      case 'campaign_assignment':
      case 'task_assignment':
      case 'route_assignment':
        return NotificationType.success;
      case 'evidence_review':
        return NotificationType.warning;
      case 'task_completion':
        return NotificationType.success;
      default:
        return NotificationType.info;
    }
  }
  
  bool _shouldShowModernNotification(String type) {
    // Don't show modern notifications for assignment types - only system notifications
    switch (type) {
      case 'campaign_assignment':
      case 'task_assignment':
      case 'route_assignment':
        return false;
      default:
        return true; // Show modern notifications for all other types
    }
  }

  // Cleanup
  void dispose() {
    _notificationChannel?.unsubscribe();
    _pollingTimer?.cancel();
    _processedNotificationIds.clear();
    _initialized = false;
  }

  // Get FCM token for testing
  String? get fcmToken => _fcmToken;
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  debugPrint('Background message received: ${message.notification?.title}');
}