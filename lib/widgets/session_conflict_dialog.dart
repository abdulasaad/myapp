// lib/widgets/session_conflict_dialog.dart

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

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
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          const SizedBox(width: 8),
          Text(AppLocalizations.of(context)!.anotherDeviceActive),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.accountLoggedInElsewhere,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.logoutOtherDeviceInstruction,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(
            AppLocalizations.of(context)!.cancel,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: onLogoutOtherDevice,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: Text(AppLocalizations.of(context)!.logoutOtherDevice),
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