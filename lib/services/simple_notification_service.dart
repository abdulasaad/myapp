// lib/services/simple_notification_service.dart

import 'package:flutter/material.dart';
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

class SimpleNotificationService {
  static final SimpleNotificationService _instance = SimpleNotificationService._internal();
  factory SimpleNotificationService() => _instance;
  SimpleNotificationService._internal();

  bool _initialized = false;

  // Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('SimpleNotificationService initialized successfully');
      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing SimpleNotificationService: $e');
    }
  }

  // Show in-app notification
  void showInAppNotification(BuildContext context, {
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
  }) {
    ModernNotification.show(
      context,
      message: message,
      type: type,
      subtitle: title,
      duration: const Duration(seconds: 5),
    );
  }

  // Get notifications from database
  Future<List<NotificationModel>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await supabase
          .from('notifications')
          .select('*')
          .eq('recipient_id', userId)
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
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return 0;
      
      debugPrint('Getting unread count for user: $userId');
      final count = await supabase.rpc('get_unread_notification_count', params: {
        'user_id': userId,
      });
      debugPrint('Unread count result: $count');
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
      debugPrint('Creating notification: recipient=$recipientId, type=$type, title=$title');
      debugPrint('Current user: ${supabase.auth.currentUser?.id}');
      
      final result = await supabase.rpc('create_notification', params: {
        'p_recipient_id': recipientId,
        'p_type': type,
        'p_title': title,
        'p_message': message,
        'p_sender_id': supabase.auth.currentUser?.id,
        'p_data': data ?? {},
      });
      
      debugPrint('Notification created successfully. Result: $result');
    } catch (e) {
      debugPrint('Error creating notification: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      rethrow; // Re-throw to see the error in campaign assignment
    }
  }

  // Check if notifications are enabled (simplified version)
  Future<bool> areNotificationsEnabled() async {
    // For the simple version, we'll assume notifications are always enabled
    return true;
  }
}