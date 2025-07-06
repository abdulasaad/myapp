// lib/services/notification_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
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
        await supabase
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', userId);
      }
    } catch (e) {
      debugPrint('Error storing FCM token: $e');
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
    // Background message handling is limited
    // The actual notification display is handled by the system
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
      await supabase.rpc('create_notification', params: {
        'p_recipient_id': recipientId,
        'p_sender_id': supabase.auth.currentUser?.id,
        'p_type': type,
        'p_title': title,
        'p_message': message,
        'p_data': data ?? {},
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  // Get FCM token
  String? get fcmToken => _fcmToken;

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