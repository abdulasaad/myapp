// lib/screens/admin/gps_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/settings_service.dart';
import '../../services/profile_service.dart';
import '../../utils/constants.dart';

class GpsSettingsScreen extends StatefulWidget {
  const GpsSettingsScreen({super.key});

  @override
  State<GpsSettingsScreen> createState() => _GpsSettingsScreenState();
}

class _GpsSettingsScreenState extends State<GpsSettingsScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _originalValues = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    _loadSettings();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _checkAdminAccess() {
    if (ProfileService.instance.role != 'admin') {
      Navigator.of(context).pop();
      context.showSnackBar('Admin access required', isError: true);
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      await SettingsService.instance.loadSettings();
      final gpsSettings = SettingsService.instance.gpsSettings;
      final backgroundSetting = SettingsService.instance.allSettings['background_accuracy_threshold'];
      
      _controllers.clear();
      _originalValues.clear();

      // Add GPS settings
      for (final setting in gpsSettings.values) {
        _controllers[setting.key] = TextEditingController(text: setting.value);
        _originalValues[setting.key] = setting.value;
      }

      // Add background setting
      if (backgroundSetting != null) {
        _controllers[backgroundSetting.key] = TextEditingController(text: backgroundSetting.value);
        _originalValues[backgroundSetting.key] = backgroundSetting.value;
      }

      // Listen for changes
      for (final controller in _controllers.values) {
        controller.addListener(_onTextChanged);
      }

    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to load GPS settings: $e', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onTextChanged() {
    bool hasChanges = false;
    for (final entry in _controllers.entries) {
      if (entry.value.text != _originalValues[entry.key]) {
        hasChanges = true;
        break;
      }
    }
    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final updates = <String, String>{};
      for (final entry in _controllers.entries) {
        if (entry.value.text != _originalValues[entry.key]) {
          updates[entry.key] = entry.value.text;
        }
      }

      if (updates.isNotEmpty) {
        final success = await SettingsService.instance.updateSettings(updates);
        if (success) {
          // Update original values
          for (final key in updates.keys) {
            _originalValues[key] = _controllers[key]!.text;
          }
          setState(() => _hasChanges = false);
          if (mounted) {
            context.showSnackBar('GPS settings saved successfully');
          }
        } else {
          if (mounted) {
            context.showSnackBar('Failed to save some GPS settings', isError: true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error saving GPS settings: $e', isError: true);
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset GPS Settings'),
        content: const Text('Are you sure you want to reset all GPS settings to their default values? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      
      try {
        final defaultUpdates = <String, String>{
          'gps_ping_interval': '30',
          'gps_accuracy_threshold': '75',
          'gps_distance_filter': '10',
          'gps_timeout': '30',
          'gps_accuracy_level': 'medium',
          'gps_speed_threshold': '1.0',
          'gps_angle_threshold': '15',
          'background_accuracy_threshold': '100',
        };

        final success = await SettingsService.instance.updateSettings(defaultUpdates);
        if (success) {
          _loadSettings(); // Reload to update UI
          if (mounted) {
            context.showSnackBar('GPS settings reset to defaults');
          }
        } else {
          if (mounted) {
            context.showSnackBar('Failed to reset GPS settings', isError: true);
          }
        }
      } catch (e) {
        if (mounted) {
          context.showSnackBar('Error resetting GPS settings: $e', isError: true);
        }
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS & Location Settings'),
        actions: [
          IconButton(
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to Defaults',
          ),
        ],
      ),
      body: _isLoading
          ? preloader
          : Column(
              children: [
                Expanded(child: _buildGpsSettingsForm()),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildGpsSettingsForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Location Tracking', 'Configure GPS tracking behavior'),
          const SizedBox(height: 16),
          _buildNumberField('gps_ping_interval', 'Ping Interval (seconds)', 'How often to request location updates', 10, 300),
          const SizedBox(height: 12),
          _buildNumberField('gps_accuracy_threshold', 'Accuracy Threshold (meters)', 'Reject location updates with accuracy worse than this', 10, 200),
          const SizedBox(height: 12),
          _buildNumberField('gps_distance_filter', 'Distance Filter (meters)', 'Minimum distance before sending location update', 5, 100),
          const SizedBox(height: 12),
          _buildNumberField('gps_timeout', 'GPS Timeout (seconds)', 'How long to wait for GPS fix', 10, 60),
          const SizedBox(height: 12),
          _buildDropdownField('gps_accuracy_level', 'Accuracy Level', 'GPS accuracy setting', ['low', 'medium', 'high', 'best']),
          
          const SizedBox(height: 24),
          _buildSectionHeader('Movement Detection', 'Configure movement and direction tracking'),
          const SizedBox(height: 16),
          _buildDecimalField('gps_speed_threshold', 'Speed Threshold (m/s)', 'Minimum speed to consider as movement', 0.1, 5.0),
          const SizedBox(height: 12),
          _buildNumberField('gps_angle_threshold', 'Angle Threshold (degrees)', 'Minimum angle change to update direction', 5, 45),
          
          const SizedBox(height: 24),
          _buildSectionHeader('Background Service', 'Background location tracking settings'),
          const SizedBox(height: 16),
          _buildNumberField('background_accuracy_threshold', 'Background Accuracy (meters)', 'Accuracy threshold for background service', 10, 200),
          
          const SizedBox(height: 24),
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }

  Widget _buildNumberField(String key, String label, String hint, int min, int max) {
    final controller = _controllers[key];
    if (controller == null) return const SizedBox.shrink();

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: 'Range: $min - $max',
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.settings),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        final intValue = int.tryParse(value);
        if (intValue == null) return 'Must be a number';
        if (intValue < min || intValue > max) return 'Must be between $min and $max';
        return null;
      },
    );
  }

  Widget _buildDecimalField(String key, String label, String hint, double min, double max) {
    final controller = _controllers[key];
    if (controller == null) return const SizedBox.shrink();

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: 'Range: ${min.toStringAsFixed(1)} - ${max.toStringAsFixed(1)}',
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.speed),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        final doubleValue = double.tryParse(value);
        if (doubleValue == null) return 'Must be a decimal number';
        if (doubleValue < min || doubleValue > max) return 'Must be between ${min.toStringAsFixed(1)} and ${max.toStringAsFixed(1)}';
        return null;
      },
    );
  }

  Widget _buildDropdownField(String key, String label, String hint, List<String> options) {
    final controller = _controllers[key];
    if (controller == null) return const SizedBox.shrink();

    return DropdownButtonFormField<String>(
      value: options.contains(controller.text) ? controller.text : options.first,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.gps_fixed),
      ),
      items: options.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(option.toUpperCase()),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          controller.text = value;
        }
      },
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue.withAlpha(25),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Important Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('• Changes apply to all users immediately after saving'),
            const Text('• Lower ping intervals provide more accurate tracking but use more battery'),
            const Text('• Higher accuracy thresholds filter out inaccurate GPS readings'),
            const Text('• Background service uses separate accuracy threshold for battery optimization'),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_hasChanges) ...[
            Icon(Icons.edit, color: Colors.orange[700], size: 16),
            const SizedBox(width: 4),
            Text(
              'Unsaved changes',
              style: TextStyle(
                color: Colors.orange[700],
                fontSize: 12,
              ),
            ),
          ] else ...[
            Icon(Icons.check_circle, color: Colors.green[700], size: 16),
            const SizedBox(width: 4),
            Text(
              'All settings saved',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 12,
              ),
            ),
          ],
          const Spacer(),
          if (_hasChanges) ...[
            OutlinedButton(
              onPressed: () => _loadSettings(),
              child: const Text('Discard'),
            ),
            const SizedBox(width: 8),
          ],
          ElevatedButton(
            onPressed: _hasChanges && !_isSaving ? _saveSettings : null,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}