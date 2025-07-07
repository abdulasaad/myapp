// lib/screens/agent/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/simple_notification_service.dart';
import '../../utils/constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SimpleNotificationService _notificationService = SimpleNotificationService();
  late Future<List<NotificationModel>> _notificationsFuture;
  String _filter = 'all'; // 'all', 'unread', 'read'

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() {
      _notificationsFuture = _notificationService.getNotifications(limit: 50).then((notifications) {
        debugPrint('Loaded ${notifications.length} notifications');
        for (var n in notifications) {
          debugPrint('Notification: ${n.type} - ${n.title} - ${n.message}');
        }
        return notifications;
      });
    });
  }

  List<NotificationModel> _filterNotifications(List<NotificationModel> notifications) {
    switch (_filter) {
      case 'unread':
        return notifications.where((n) => n.isUnread).toList();
      case 'read':
        return notifications.where((n) => n.isRead).toList();
      default:
        return notifications;
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;

    final success = await _notificationService.markAsRead(notification.id);
    if (success) {
      _loadNotifications();
    }
  }

  Future<void> _markAllAsRead() async {
    final count = await _notificationService.markAllAsRead();
    if (count > 0) {
      _loadNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked $count notifications as read')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: Colors.black87,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'mark_all_read') {
                _markAllAsRead();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read),
                    SizedBox(width: 8),
                    Text('Mark All Read'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Unread', 'unread'),
                const SizedBox(width: 8),
                _buildFilterChip('Read', 'read'),
              ],
            ),
          ),
          
          // Notifications list
          Expanded(
            child: FutureBuilder<List<NotificationModel>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading notifications',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadNotifications,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final notifications = _filterNotifications(snapshot.data ?? []);

                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _filter == 'all' ? 'No notifications yet' : 'No $_filter notifications',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'ll see notifications here when there are updates',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _loadNotifications();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _buildNotificationCard(notification);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filter = value;
        });
      },
      selectedColor: primaryColor.withValues(alpha: 0.2),
      checkmarkColor: primaryColor,
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: notification.isUnread ? 2 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: notification.isUnread
              ? BorderSide(color: primaryColor.withValues(alpha: 0.3), width: 1)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _markAsRead(notification),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: notification.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    notification.icon,
                    color: notification.color,
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and time
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: notification.isUnread ? FontWeight.bold : FontWeight.w600,
                                color: textPrimaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(notification.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Message
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: notification.isUnread ? textPrimaryColor : Colors.grey[700],
                          height: 1.3,
                        ),
                      ),
                      
                      // Type badge
                      if (notification.type != 'general') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: notification.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getTypeDisplayName(notification.type),
                            style: TextStyle(
                              fontSize: 12,
                              color: notification.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Unread indicator
                if (notification.isUnread) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'campaign_assignment':
        return 'Campaign';
      case 'task_assignment':
        return 'Task';
      case 'route_assignment':
        return 'Route';
      case 'place_approval':
        return 'Place';
      case 'task_completion':
        return 'Completion';
      case 'evidence_review':
        return 'Evidence';
      default:
        return 'General';
    }
  }
}