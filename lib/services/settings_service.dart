// lib/services/settings_service.dart

import 'dart:async';
import 'package:logger/logger.dart';
import '../utils/constants.dart';

class AppSetting {
  final String key;
  final String value;
  final String type;
  final String? description;
  final double? minValue;
  final double? maxValue;

  AppSetting({
    required this.key,
    required this.value,
    required this.type,
    this.description,
    this.minValue,
    this.maxValue,
  });

  factory AppSetting.fromJson(Map<String, dynamic> json) {
    return AppSetting(
      key: json['setting_key'] ?? '',
      value: json['setting_value'] ?? '',
      type: json['setting_type'] ?? 'string',
      description: json['description'],
      minValue: json['min_value']?.toDouble(),
      maxValue: json['max_value']?.toDouble(),
    );
  }

  // Type-safe value getters
  int get intValue => int.tryParse(value) ?? 0;
  double get doubleValue => double.tryParse(value) ?? 0.0;
  bool get boolValue => value.toLowerCase() == 'true';
  String get stringValue => value;

  // Validation
  bool isValid() {
    switch (type) {
      case 'number':
        final numValue = double.tryParse(value);
        if (numValue == null) return false;
        if (minValue != null && numValue < minValue!) return false;
        if (maxValue != null && numValue > maxValue!) return false;
        return true;
      case 'boolean':
        return value.toLowerCase() == 'true' || value.toLowerCase() == 'false';
      default:
        return value.isNotEmpty;
    }
  }
}

class SettingsService {
  SettingsService._();
  static final instance = SettingsService._();

  final Logger _logger = Logger();
  final Map<String, AppSetting> _settings = {};
  Timer? _refreshTimer;
  final StreamController<Map<String, AppSetting>> _settingsController = 
      StreamController<Map<String, AppSetting>>.broadcast();

  // Stream to listen for settings changes
  Stream<Map<String, AppSetting>> get settingsStream => _settingsController.stream;

  // Default values as fallback
  static const Map<String, dynamic> _defaultValues = {
    'gps_ping_interval': 30,
    'gps_accuracy_threshold': 75,
    'gps_distance_filter': 10,
    'gps_timeout': 30,
    'gps_accuracy_level': 'medium',
    'gps_speed_threshold': 1.0,
    'gps_angle_threshold': 15,
    'background_accuracy_threshold': 100,
  };

  // Initialize settings service
  Future<void> initialize() async {
    await loadSettings();
    
    // Set up periodic refresh every 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      loadSettings();
    });
  }

  // Load settings from Supabase
  Future<void> loadSettings() async {
    try {
      final response = await supabase
          .from('app_settings')
          .select('setting_key, setting_value, setting_type, description, min_value, max_value');

      _settings.clear();
      for (final row in response) {
        final setting = AppSetting.fromJson(row);
        if (setting.isValid()) {
          _settings[setting.key] = setting;
        } else {
          _logger.w('Invalid setting value for ${setting.key}: ${setting.value}');
        }
      }

      _settingsController.add(Map.from(_settings));
      _logger.i('Settings loaded successfully: ${_settings.length} settings');
    } catch (e) {
      _logger.e('Failed to load settings: $e');
      // Continue with existing settings or defaults
    }
  }

  // Get setting value with type safety and fallback
  T getSetting<T>(String key) {
    final setting = _settings[key];
    
    if (setting != null) {
      try {
        switch (T) {
          case int:
            return setting.intValue as T;
          case double:
            return setting.doubleValue as T;
          case bool:
            return setting.boolValue as T;
          case String:
            return setting.stringValue as T;
        }
      } catch (e) {
        _logger.w('Failed to parse setting $key as ${T.toString()}: $e');
      }
    }

    // Fallback to default value
    final defaultValue = _defaultValues[key];
    if (defaultValue is T) {
      return defaultValue;
    }

    // Final fallback based on type
    switch (T) {
      case int:
        return 0 as T;
      case double:
        return 0.0 as T;
      case bool:
        return false as T;
      case String:
        return '' as T;
      default:
        throw ArgumentError('Unsupported setting type: ${T.toString()}');
    }
  }

  // GPS-specific getters for convenience
  int get gpsPingInterval => getSetting<int>('gps_ping_interval');
  int get gpsAccuracyThreshold => getSetting<int>('gps_accuracy_threshold');
  int get gpsDistanceFilter => getSetting<int>('gps_distance_filter');
  int get gpsTimeout => getSetting<int>('gps_timeout');
  String get gpsAccuracyLevel => getSetting<String>('gps_accuracy_level');
  double get gpsSpeedThreshold => getSetting<double>('gps_speed_threshold');
  int get gpsAngleThreshold => getSetting<int>('gps_angle_threshold');
  int get backgroundAccuracyThreshold => getSetting<int>('background_accuracy_threshold');

  // Update setting (admin only)
  Future<bool> updateSetting(String key, String value) async {
    try {
      // Validate the new value before saving
      final existingSetting = _settings[key];
      if (existingSetting != null) {
        final tempSetting = AppSetting(
          key: key,
          value: value,
          type: existingSetting.type,
          minValue: existingSetting.minValue,
          maxValue: existingSetting.maxValue,
        );
        
        if (!tempSetting.isValid()) {
          _logger.w('Invalid value for setting $key: $value');
          return false;
        }
      }

      await supabase
          .from('app_settings')
          .update({'setting_value': value})
          .eq('setting_key', key);

      // Reload settings to get the updated value
      await loadSettings();
      
      _logger.i('Setting $key updated to: $value');
      return true;
    } catch (e) {
      _logger.e('Failed to update setting $key: $e');
      return false;
    }
  }

  // Batch update settings (admin only)
  Future<bool> updateSettings(Map<String, String> updates) async {
    try {
      for (final entry in updates.entries) {
        await supabase
            .from('app_settings')
            .update({'setting_value': entry.value})
            .eq('setting_key', entry.key);
      }

      await loadSettings();
      _logger.i('Batch updated ${updates.length} settings');
      return true;
    } catch (e) {
      _logger.e('Failed to batch update settings: $e');
      return false;
    }
  }

  // Get all settings for admin interface
  Map<String, AppSetting> get allSettings => Map.from(_settings);

  // Get settings by category (for UI organization)
  Map<String, AppSetting> getSettingsByPrefix(String prefix) {
    return Map.fromEntries(
      _settings.entries.where((entry) => entry.key.startsWith(prefix))
    );
  }

  // GPS settings specifically
  Map<String, AppSetting> get gpsSettings => getSettingsByPrefix('gps_');

  // Dispose resources
  void dispose() {
    _refreshTimer?.cancel();
    _settingsController.close();
  }
}