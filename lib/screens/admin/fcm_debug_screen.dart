// lib/screens/admin/fcm_debug_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/constants.dart';
import '../../services/notification_service.dart';

class FCMDebugScreen extends StatefulWidget {
  const FCMDebugScreen({super.key});

  @override
  State<FCMDebugScreen> createState() => _FCMDebugScreenState();
}

class _FCMDebugScreenState extends State<FCMDebugScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _currentUserToken;

  @override
  void initState() {
    super.initState();
    _loadUserTokens();
  }

  Future<void> _loadUserTokens() async {
    try {
      setState(() => _isLoading = true);
      
      // Get current user's FCM token
      final currentUserId = supabase.auth.currentUser?.id;
      
      // Load all users with their FCM tokens
      final response = await supabase
          .from('profiles')
          .select('id, full_name, role, email, fcm_token, created_at, updated_at')
          .order('full_name');

      final users = List<Map<String, dynamic>>.from(response);
      
      // Find current user's token
      for (final user in users) {
        if (user['id'] == currentUserId) {
          _currentUserToken = user['fcm_token'];
          break;
        }
      }

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showSnackBar('Error loading user tokens: $e', isError: true);
      }
    }
  }

  Future<void> _testNotificationForUser(Map<String, dynamic> user) async {
    try {
      debugPrint('🧪 Testing notification for user: ${user['email']}');
      
      // Create a test notification
      await supabase.rpc('create_notification', params: {
        'p_recipient_id': user['id'],
        'p_sender_id': supabase.auth.currentUser?.id,
        'p_type': 'admin_message',
        'p_title': 'Test Notification',
        'p_message': 'This is a test notification from FCM Debug Screen',
        'p_data': {'test': true, 'timestamp': DateTime.now().toIso8601String()},
      });

      // Also try to send push notification via edge function
      final response = await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'recipientId': user['id'],
          'title': 'Test Notification',
          'message': 'This is a test notification from FCM Debug Screen',
          'data': {'test': true, 'timestamp': DateTime.now().toIso8601String()},
        },
      );

      if (mounted) {
        if (response.status == 200) {
          context.showSnackBar('Test notification sent successfully to ${user['full_name']}');
        } else {
          context.showSnackBar('Failed to send test notification: ${response.status}', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error testing notification: $e', isError: true);
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    context.showSnackBar('Copied to clipboard');
  }

  Future<void> _refreshCurrentUserToken() async {
    try {
      final newToken = await NotificationService().forceRefreshFCMToken();
      if (newToken != null) {
        setState(() {
          _currentUserToken = newToken;
        });
        context.showSnackBar('FCM token refreshed successfully');
        
        // Reload user data to see if it was updated
        _loadUserTokens();
      } else {
        context.showSnackBar('Failed to refresh FCM token', isError: true);
      }
    } catch (e) {
      context.showSnackBar('Error refreshing FCM token: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('FCM Token Debug'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadUserTokens,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bug_report, color: primaryColor),
                            const SizedBox(width: 8),
                            const Text(
                              'FCM Token Debug Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Total Users: ${_users.length}'),
                        Text('Users with FCM Token: ${_users.where((u) => u['fcm_token'] != null && u['fcm_token'].toString().isNotEmpty).length}'),
                        Text('Users without FCM Token: ${_users.where((u) => u['fcm_token'] == null || u['fcm_token'].toString().isEmpty).length}'),
                        const SizedBox(height: 8),
                        if (_currentUserToken != null) ...[
                          const Text('Current User Token:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _copyToClipboard(_currentUserToken!),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${_currentUserToken!.substring(0, 20)}...',
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _refreshCurrentUserToken,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Refresh My Token'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // User List
                ...(_users.map((user) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: user['fcm_token'] != null && user['fcm_token'].toString().isNotEmpty
                          ? Colors.green
                          : Colors.red,
                      child: Text(
                        user['role'].toString().substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(user['full_name'] ?? 'Unknown'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${user['role']} - ${user['email']}'),
                        Text(
                          user['fcm_token'] != null && user['fcm_token'].toString().isNotEmpty
                              ? 'Has FCM Token'
                              : 'No FCM Token',
                          style: TextStyle(
                            color: user['fcm_token'] != null && user['fcm_token'].toString().isNotEmpty
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User Details
                            Text('User ID: ${user['id']}'),
                            Text('Created: ${user['created_at']}'),
                            Text('Updated: ${user['updated_at']}'),
                            const SizedBox(height: 12),
                            
                            // FCM Token
                            if (user['fcm_token'] != null && user['fcm_token'].toString().isNotEmpty) ...[
                              const Text('FCM Token:', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => _copyToClipboard(user['fcm_token']),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    user['fcm_token'],
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Token Length: ${user['fcm_token'].toString().length}'),
                              Text('Same as Current User: ${user['fcm_token'] == _currentUserToken}'),
                            ] else ...[
                              const Text(
                                'No FCM Token Available',
                                style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
                              ),
                            ],
                            
                            const SizedBox(height: 12),
                            
                            // Test Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: user['fcm_token'] != null && user['fcm_token'].toString().isNotEmpty
                                    ? () => _testNotificationForUser(user)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Send Test Notification'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ))),
              ],
            ),
    );
  }
}