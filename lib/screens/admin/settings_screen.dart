// lib/screens/admin/settings_screen.dart

import 'package:flutter/material.dart';
import '../../services/profile_service.dart';
import '../../utils/constants.dart';
import 'gps_settings_screen.dart';
import 'template_setup_screen.dart';

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
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
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
          
          _buildSettingsCategory(
            'Manager Template Access',
            'Assign task templates to managers',
            Icons.assignment_ind,
            () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const TemplateSetupScreen()),
            ),
          ),
          const SizedBox(height: 16),
          
          // Future setting categories
          _buildSettingsCategory(
            'Notifications',
            'Configure app notifications and alerts',
            Icons.notifications,
            () {
              // Feature coming soon - notifications settings will be implemented here
              context.showSnackBar('Notifications settings coming soon');
            },
          ),
          const SizedBox(height: 16),
          
          _buildSettingsCategory(
            'Security',
            'Configure security and privacy settings',
            Icons.security,
            () {
              // Feature coming soon - security settings will be implemented here
              context.showSnackBar('Security settings coming soon');
            },
          ),
          const SizedBox(height: 16),
          
          _buildSettingsCategory(
            'App Preferences',
            'Configure general app preferences',
            Icons.tune,
            () {
              // Feature coming soon - app preferences will be implemented here
              context.showSnackBar('App preferences coming soon');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCategory(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      color: surfaceColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: textSecondaryColor,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainSectionHeader(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.settings,
              color: primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}