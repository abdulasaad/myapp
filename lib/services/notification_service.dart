// lib/services/notification_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../utils/constants.dart';
import '../widgets/modern_notification.dart';

class NotificationModel {
  final String id;
  final String recipientId;
  final String? senderId;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationModel({
    required this.id,
    required this.recipientId,
    this.senderId,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      recipientId: json['recipient_id'],
      senderId: json['sender_id'],
      type: json['type'],
      title: json['title'],
      message: json['message'],
      data: json['data'] as Map<String, dynamic>? ?? {},
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  bool get isRead => readAt != null;
  bool get isUnread => readAt == null;

  // Get notification icon based on type
  IconData get icon {
    switch (type) {
      case 'campaign_assignment':
        return Icons.campaign;
      case 'task_assignment':
        return Icons.assignment;
      case 'route_assignment':
        return Icons.route;
      case 'place_approval':
        return Icons.place;
      case 'task_completion':
        return Icons.check_circle;
      case 'evidence_review':
        return Icons.photo_library;
      default:
        return Icons.notifications;
    }
  }

  // Get notification color based on type
  Color get color {
    switch (type) {
      case 'campaign_assignment':
        return Colors.blue;
      case 'task_assignment':
        return Colors.green;
      case 'route_assignment':
        return Colors.orange;
      case 'place_approval':
        return Colors.purple;
      case 'task_completion':
        return Colors.teal;
      case 'evidence_review':
        return Colors.indigo;
      default:
        return primaryColor;
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  String? _fcmToken;

  // Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Firebase
      await Firebase.initializeApp();
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Request permissions
      await requestPermissions();
      
      // Set up FCM
      await _setupFCM();
      
      _initialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  // Set up Firebase Cloud Messaging
  Future<void> _setupFCM() async {
    try {
      // Get FCM token
      _fcmToken = await _fcm.getToken();
      debugPrint('FCM Token: $_fcmToken');
      
      // Store token in user profile
      if (_fcmToken != null) {
        await _storeFCMToken(_fcmToken!);
      }
      
      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _storeFCMToken(newToken);
      });
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
      
      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      
    } catch (e) {
      debugPrint('Error setting up FCM: $e');
    }
  }

  // Store FCM token in user profile
  Future<void> _storeFCMToken(String token) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        debugPrint('📱 Storing FCM token for user: $userId');
        debugPrint('📱 Token: ${token.substring(0, 20)}...');
        
        await supabase
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', userId);
            
        debugPrint('✅ FCM token stored successfully');
      }
    } catch (e) {
      debugPrint('❌ Error storing FCM token: $e');
    }
  }

  // Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      // Request FCM permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted FCM permissions');
        
        // Request local notification permissions for Android
        if (Platform.isAndroid) {
          final Permission notificationPermission = Permission.notification;
          await notificationPermission.request();
        }
        
        return true;
      } else {
        debugPrint('User declined FCM permissions');
        return false;
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.messageId}');
    
    // Show in-app notification
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ModernNotification.show(
        context,
        message: message.notification?.body ?? 'New notification',
        type: NotificationType.info,
        subtitle: message.notification?.title,
        duration: const Duration(seconds: 5),
      );
    }
    
    // Also show local notification
    await _showLocalNotification(message);
  }

  // Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Received background message: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    
    // Show local notification when app is in background
    try {
      final localNotifications = FlutterLocalNotificationsPlugin();
      
      // Initialize local notifications for background context
      const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInitSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidInitSettings,
        iOS: iosInitSettings,
      );
      
      await localNotifications.initialize(initSettings);
      
      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'admin_notifications',
          'Admin Notifications',
          channelDescription: 'Notifications sent by administrators',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      
      await localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'New Notification',
        message.notification?.body ?? 'You have a new message',
        notificationDetails,
        payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
      );
      
      debugPrint('Background notification displayed successfully');
    } catch (e) {
      debugPrint('Error displaying background notification: $e');
    }
  }

  // Handle notification tap
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    debugPrint('Notification tapped: ${message.messageId}');
    
    // Navigate to appropriate screen based on notification data
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      await _navigateBasedOnNotification(context, message.data);
    }
  }

  // Handle local notification tap
  Future<void> _onNotificationTapped(NotificationResponse response) async {
    debugPrint('Local notification tapped: ${response.id}');
    
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted && response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        await _navigateBasedOnNotification(context, data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  // Navigate based on notification data
  Future<void> _navigateBasedOnNotification(BuildContext context, Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    
    switch (type) {
      case 'campaign_assignment':
        // Navigate to campaign detail
        break;
      case 'task_assignment':
        // Navigate to task detail
        break;
      case 'route_assignment':
        // Navigate to route detail
        break;
      case 'place_approval':
        // Navigate to place detail
        break;
      case 'task_completion':
        // Navigate to task completion screen
        break;
      case 'evidence_review':
        // Navigate to evidence screen
        break;
      default:
        // Navigate to notifications list
        break;
    }
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      channelDescription: 'Default notification channel',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? 'You have a new notification',
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }

  // Get notifications from database
  Future<List<NotificationModel>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await supabase
          .from('notifications')
          .select('*')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map((json) => NotificationModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }

  // Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final count = await supabase.rpc('get_unread_notification_count', params: {
        'user_id': supabase.auth.currentUser?.id,
      });
      return count ?? 0;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  // Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      final result = await supabase.rpc('mark_notification_read', params: {
        'notification_id': notificationId,
      });
      return result == true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  // Mark all notifications as read
  Future<int> markAllAsRead() async {
    try {
      final count = await supabase.rpc('mark_all_notifications_read');
      return count ?? 0;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return 0;
    }
  }

  // Create manual notification (for testing or admin use)
  Future<void> createNotification({
    required String recipientId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final senderId = supabase.auth.currentUser?.id;
      
      debugPrint('🔔 Creating notification:');
      debugPrint('   From: $senderId');
      debugPrint('   To: $recipientId');
      debugPrint('   Type: $type');
      debugPrint('   Title: $title');
      debugPrint('   Message: $message');
      
      // First create the notification in database
      await supabase.rpc('create_notification', params: {
        'p_recipient_id': recipientId,
        'p_sender_id': senderId,
        'p_type': type,
        'p_title': title,
        'p_message': message,
        'p_data': data ?? {},
      });
      
      debugPrint('✅ Database notification created successfully');
      
      // Get recipient's FCM token
      final recipientProfile = await supabase
          .from('profiles')
          .select('fcm_token, email, full_name')
          .eq('id', recipientId)
          .single();
      
      final recipientFcmToken = recipientProfile['fcm_token'] as String?;
      final recipientEmail = recipientProfile['email'] as String?;
      final recipientName = recipientProfile['full_name'] as String?;
      
      debugPrint('📱 Recipient info:');
      debugPrint('   ID: $recipientId');
      debugPrint('   Name: $recipientName');
      debugPrint('   Email: $recipientEmail');
      debugPrint('   Has FCM Token: ${recipientFcmToken != null && recipientFcmToken.isNotEmpty}');
      debugPrint('   FCM Token: ${recipientFcmToken?.substring(0, 20) ?? 'null'}...');

      // Also check sender's FCM token for comparison
      final senderProfile = await supabase
          .from('profiles')
          .select('fcm_token, email, full_name')
          .eq('id', senderId!)
          .single();
      
      final senderFcmToken = senderProfile['fcm_token'] as String?;
      final senderEmail = senderProfile['email'] as String?;
      final senderName = senderProfile['full_name'] as String?;
      
      debugPrint('📤 Sender info:');
      debugPrint('   ID: $senderId');
      debugPrint('   Name: $senderName');
      debugPrint('   Email: $senderEmail');
      debugPrint('   Has FCM Token: ${senderFcmToken != null && senderFcmToken.isNotEmpty}');
      debugPrint('   FCM Token: ${senderFcmToken?.substring(0, 20) ?? 'null'}...');
      debugPrint('   Same Token? ${recipientFcmToken == senderFcmToken}');
      
      if (recipientFcmToken != null && recipientFcmToken.isNotEmpty) {
        // Prepare push notification for server-side sending
        await _sendPushNotification(
          token: recipientFcmToken,
          title: title,
          body: message,
          data: data ?? {},
        );
      } else {
        debugPrint('⚠️  No FCM token for recipient - notification available via in-app polling only');
      }
      
    } catch (e) {
      debugPrint('❌ Error creating notification: $e');
    }
  }

  // Send push notification via multiple methods
  Future<void> _sendPushNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    debugPrint('📨 Sending push notification:');
    debugPrint('   FCM Token: ${token.substring(0, 20)}...');
    debugPrint('   Title: $title');
    debugPrint('   Body: $body');
    debugPrint('   Data: $data');
    
    // Try multiple methods in order of preference
    bool success = false;
    
    // Method 1: Try Supabase Edge Function first
    try {
      debugPrint('📡 Method 1: Trying edge function...');
      
      final response = await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'recipientId': '',
          'title': title,
          'message': body,
          'data': data,
          'fcmToken': token,
        },
      );
      
      if (response.status == 200) {
        debugPrint('✅ Push notification sent via edge function');
        success = true;
      } else {
        throw Exception('Edge function failed: ${response.status}');
      }
    } catch (e) {
      debugPrint('❌ Edge function failed: $e');
    }
    
    // Method 2: Direct FCM HTTP API (fallback)
    if (!success) {
      try {
        debugPrint('📡 Method 2: Trying direct FCM API...');
        await _sendDirectFCMNotification(token, title, body, data);
        debugPrint('✅ Push notification sent via direct FCM');
        success = true;
      } catch (e) {
        debugPrint('❌ Direct FCM failed: $e');
      }
    }
    
    // Method 3: Local notification fallback
    if (!success) {
      debugPrint('📡 Method 3: Showing local notification as fallback...');
      // This will only show on current device, but at least provides some notification
      await _showLocalFallbackNotification(title, body, data);
      debugPrint('⚠️  Showed local notification as fallback');
    }
    
    if (!success) {
      debugPrint('❌ All notification methods failed');
      debugPrint('✅ Recipient will receive notification via in-app polling');
    }
  }

  // Direct FCM HTTP API call
  Future<void> _sendDirectFCMNotification(
    String token,
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    // FCM Server Key - this should be stored securely
    // For now, we'll use the new Firebase v1 API with service account
    
    // Note: This requires Firebase project configuration
    // Since we can't store server keys client-side securely,
    // this will throw an error but demonstrates the approach
    
    throw Exception('Direct FCM requires server-side implementation for security');
  }

  // Local notification fallback
  Future<void> _showLocalFallbackNotification(
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'admin_notifications',
          'Admin Notifications',
          channelDescription: 'Notifications sent by administrators',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  // Get FCM token
  String? get fcmToken => _fcmToken;

  // Clear FCM token on logout
  Future<void> clearFCMToken() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        debugPrint('🧹 Clearing FCM token for user: $userId');
        
        await supabase
            .from('profiles')
            .update({'fcm_token': null})
            .eq('id', userId);
            
        _fcmToken = null;
        debugPrint('✅ FCM token cleared successfully');
      }
    } catch (e) {
      debugPrint('❌ Error clearing FCM token: $e');
    }
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  // Subscribe to topic (for broadcast notifications)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }
}