// lib/screens/admin/send_notification_screen.dart

import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../services/notification_service.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _selectedUser;
  String _selectedRole = 'all';
  bool _isLoading = false;
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() => _isLoadingUsers = true);
      
      final response = await supabase
          .from('profiles')
          .select('id, full_name, role, email')
          .neq('role', 'admin') // Don't show admins in the list
          .order('full_name');

      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() => _isLoadingUsers = false);
      if (mounted) {
        context.showSnackBar('Error loading users: $e', isError: true);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_selectedRole == 'all') return _users;
    return _users.where((user) => user['role'] == _selectedRole).toList();
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate() || _selectedUser == null) {
      context.showSnackBar('Please fill in all fields and select a user', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await NotificationService().createNotification(
        recipientId: _selectedUser!['id'],
        type: 'admin_message',
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        data: {
          'source': 'admin_notification',
          'priority': 'high',
        },
      );

      if (mounted) {
        context.showSnackBar('Notification sent successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error sending notification: $e', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Send Notification'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingUsers
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notifications, color: primaryColor, size: 24),
                              const SizedBox(width: 12),
                              const Text(
                                'Send Custom Notification',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Send a custom notification to any manager or agent in the system.',
                            style: TextStyle(color: textSecondaryColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // User Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Recipient',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Role Filter
                          Row(
                            children: [
                              const Text('Filter by role: '),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedRole,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                                    DropdownMenuItem(value: 'manager', child: Text('Managers Only')),
                                    DropdownMenuItem(value: 'agent', child: Text('Agents Only')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedRole = value!;
                                      _selectedUser = null; // Reset selection
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // User Selection
                          DropdownButtonFormField<Map<String, dynamic>>(
                            value: _selectedUser,
                            decoration: const InputDecoration(
                              labelText: 'Select User',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            hint: Text('Choose a ${_selectedRole == 'all' ? 'user' : _selectedRole}...'),
                            items: _filteredUsers.map((user) {
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: user,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      user['full_name'] ?? 'Unknown User',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      '${user['role']?.toString().toUpperCase() ?? 'UNKNOWN'} • ${user['email'] ?? 'No email'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedUser = value);
                            },
                            validator: (value) {
                              if (value == null) return 'Please select a user';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Message Content
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notification Content',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Title
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Notification Title',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.title),
                              hintText: 'Enter a clear, descriptive title...',
                            ),
                            maxLength: 100,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a title';
                              }
                              if (value.trim().length < 3) {
                                return 'Title must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Message
                          TextFormField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              labelText: 'Message',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.message),
                              hintText: 'Enter your message here...',
                              alignLabelWithHint: true,
                            ),
                            maxLines: 4,
                            maxLength: 500,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a message';
                              }
                              if (value.trim().length < 10) {
                                return 'Message must be at least 10 characters';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Preview Card
                  if (_selectedUser != null && _titleController.text.isNotEmpty && _messageController.text.isNotEmpty)
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.preview, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'Preview',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.notifications, size: 20, color: primaryColor),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _titleController.text,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(_messageController.text),
                                  const SizedBox(height: 8),
                                  Text(
                                    'To: ${_selectedUser!['full_name']} (${_selectedUser!['role']?.toString().toUpperCase()})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 30),
                  
                  // Send Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _sendNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(_isLoading ? 'Sending...' : 'Send Notification'),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}