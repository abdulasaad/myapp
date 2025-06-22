// lib/widgets/session_conflict_dialog.dart

import 'package:flutter/material.dart';

class SessionConflictDialog extends StatelessWidget {
  final VoidCallback onLogoutOtherDevice;
  final VoidCallback onCancel;
  
  const SessionConflictDialog({
    super.key,
    required this.onLogoutOtherDevice,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          SizedBox(width: 8),
          Text('Another Device Active'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your account is currently logged in on another device.',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 12),
          Text(
            'To continue logging in on this device, you need to logout from the other device first.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: onLogoutOtherDevice,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Logout Other Device'),
        ),
      ],
    );
  }

  /// Show the session conflict dialog
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must make a choice
      builder: (context) => SessionConflictDialog(
        onLogoutOtherDevice: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }
}