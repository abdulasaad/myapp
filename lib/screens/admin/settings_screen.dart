// lib/screens/admin/settings_screen.dart

import 'package:flutter/material.dart';
import '../../services/profile_service.dart';
import '../../utils/constants.dart';
import 'gps_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  void _checkAdminAccess() {
    if (ProfileService.instance.role != 'admin') {
      Navigator.of(context).pop();
      context.showSnackBar('Admin access required', isError: true);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _buildSettingsForm(),
    );
  }

  Widget _buildSettingsForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMainSectionHeader('Application Settings', 'Configure app behavior and preferences'),
          const SizedBox(height: 20),
          
          _buildSettingsCategory(
            'GPS & Location',
            'Configure location tracking and GPS behavior',
            Icons.gps_fixed,
            () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const GpsSettingsScreen()),
            ),
          ),
          const SizedBox(height: 16),
          
          // Future setting categories
          _buildSettingsCategory(
            'Notifications',
            'Configure app notifications and alerts',
            Icons.notifications,
            () {
              // TODO: Navigate to notifications settings
              context.showSnackBar('Notifications settings coming soon');
            },
          ),
          const SizedBox(height: 16),
          
          _buildSettingsCategory(
            'Security',
            'Configure security and privacy settings',
            Icons.security,
            () {
              // TODO: Navigate to security settings
              context.showSnackBar('Security settings coming soon');
            },
          ),
          const SizedBox(height: 16),
          
          _buildSettingsCategory(
            'App Preferences',
            'Configure general app preferences',
            Icons.tune,
            () {
              // TODO: Navigate to app preferences
              context.showSnackBar('App preferences coming soon');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCategory(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withAlpha(50),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildMainSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

}