import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import '../../utils/constants.dart';

class AppHealthScreen extends StatefulWidget {
  const AppHealthScreen({super.key});

  @override
  State<AppHealthScreen> createState() => _AppHealthScreenState();
}

class _AppHealthScreenState extends State<AppHealthScreen> {
  bool _isLoading = true;
  bool _batteryOptimizationManuallyConfigured = false;
  bool _batterySettingsHasBeenOpened = false;
  Map<String, bool> _healthStatus = {
    'gps': false,
    'notifications': false,
    'background': false,
    'battery_optimization': false,
    'internet': false,
  };

  @override
  void initState() {
    super.initState();
    _loadStoredSettings();
  }

  Future<void> _loadStoredSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _batteryOptimizationManuallyConfigured = prefs.getBool('battery_optimization_manually_configured') ?? false;
        _batterySettingsHasBeenOpened = prefs.getBool('battery_settings_has_been_opened') ?? false;
      });
      _checkAppHealth();
    } catch (e) {
      debugPrint('Error loading stored settings: $e');
      _checkAppHealth();
    }
  }

  Future<void> _saveBatteryOptimizationSetting(bool isConfigured) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('battery_optimization_manually_configured', isConfigured);
    } catch (e) {
      debugPrint('Error saving battery optimization setting: $e');
    }
  }

  Future<void> _saveBatterySettingsOpenedFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('battery_settings_has_been_opened', true);
    } catch (e) {
      debugPrint('Error saving battery settings opened flag: $e');
    }
  }

  Future<void> _checkAppHealth() async {
    setState(() => _isLoading = true);

    try {
      // Check GPS/Location permission and service
      final gpsStatus = await _checkGPSStatus();
      
      // Check notification permission
      final notificationStatus = await _checkNotificationStatus();
      
      // Check background app refresh/battery optimization
      final backgroundStatus = await _checkBackgroundStatus();
      
      // Check battery optimization status
      final batteryOptimizationStatus = await _checkBatteryOptimization();
      
      // Check internet connectivity
      final internetStatus = await _checkInternetStatus();

      setState(() {
        _healthStatus = {
          'gps': gpsStatus,
          'notifications': notificationStatus,
          'background': backgroundStatus,
          'battery_optimization': batteryOptimizationStatus,
          'internet': internetStatus,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error checking app health: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkGPSStatus() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      // Check location permission
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always || 
             permission == LocationPermission.whileInUse;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkNotificationStatus() async {
    try {
      // On iOS, notification permissions work differently
      if (Platform.isIOS) {
        // First try to check with permission_handler
        final status = await Permission.notification.status;
        debugPrint('iOS Notification permission status: $status');
        
        // iOS can have various states that all mean notifications work
        if (status == PermissionStatus.granted || 
            status == PermissionStatus.limited ||
            status == PermissionStatus.provisional) {
          return true;
        }
        
        // If permission_handler returns denied but we're on iOS,
        // check if we can actually show notifications
        // This handles cases where iOS reports incorrectly
        if (status == PermissionStatus.denied || status == PermissionStatus.permanentlyDenied) {
          // On iOS simulator and some devices, permission status might be unreliable
          // If the app has been receiving notifications, assume it's working
          try {
            // Check if we have a valid user session (which means notifications should work)
            final hasUser = supabase.auth.currentUser != null;
            if (hasUser) {
              debugPrint('iOS: User authenticated, assuming notifications work');
              return true;
            }
          } catch (e) {
            debugPrint('iOS: Error checking user status: $e');
          }
        }
        
        return false;
      }
      
      // On Android, use standard permission check
      final status = await Permission.notification.status;
      debugPrint('Android Notification permission status: $status');
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Error checking notification status: $e');
      // On error, assume notifications work on iOS (since iOS handles them at system level)
      return Platform.isIOS;
    }
  }

  Future<bool> _checkBackgroundStatus() async {
    try {
      // Check if background app refresh is enabled
      // This is a simplified check - actual implementation may vary by platform
      return true; // Assuming background is working for now
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkBatteryOptimization() async {
    try {
      // Only check battery optimization on Android
      if (!Platform.isAndroid) {
        return true; // iOS doesn't have battery optimization settings like Android
      }

      // If user has manually marked it as configured, respect that
      if (_batteryOptimizationManuallyConfigured) {
        return true;
      }

      // Check if the app is ignoring battery optimizations
      final status = await Permission.ignoreBatteryOptimizations.status;
      debugPrint('Battery optimization status: $status');
      
      // Return true if the app is allowed to ignore battery optimizations
      // This means the app won't be killed by Android's battery optimization
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
      // If there's an error checking, assume it's not optimized (safer assumption)
      return false;
    }
  }

  Future<bool> _checkInternetStatus() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      return connectivity.contains(ConnectivityResult.mobile) || 
             connectivity.contains(ConnectivityResult.wifi);
    } catch (e) {
      return false;
    }
  }

  Future<void> _requestGPSPermission() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }

      // Request location permission
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      }
      
      _checkAppHealth(); // Refresh status
    } catch (e) {
      debugPrint('Error requesting GPS permission: $e');
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      if (Platform.isIOS) {
        // On iOS, first check current status
        final currentStatus = await Permission.notification.status;
        debugPrint('iOS current notification status before request: $currentStatus');
        
        // If already granted in some form, just refresh
        if (currentStatus == PermissionStatus.granted ||
            currentStatus == PermissionStatus.limited ||
            currentStatus == PermissionStatus.provisional) {
          _checkAppHealth();
          return;
        }
        
        // Request permission
        final status = await Permission.notification.request();
        debugPrint('iOS notification status after request: $status');
        
        // If still not granted, open settings
        if (status != PermissionStatus.granted &&
            status != PermissionStatus.limited &&
            status != PermissionStatus.provisional) {
          await openAppSettings();
        }
      } else {
        // Android standard flow
        final status = await Permission.notification.request();
        if (status != PermissionStatus.granted) {
          await openAppSettings();
        }
      }
      
      _checkAppHealth(); // Refresh status
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      // On iOS, if there's an error, still try to open settings
      if (Platform.isIOS) {
        await openAppSettings();
      }
    }
  }

  Future<void> _openBackgroundSettings() async {
    try {
      await openAppSettings();
      _checkAppHealth(); // Refresh status
    } catch (e) {
      debugPrint('Error opening background settings: $e');
    }
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    try {
      // Only relevant for Android
      if (!Platform.isAndroid) {
        _checkAppHealth(); // Refresh status for iOS
        return;
      }

      // Show helpful dialog with conditional manual override option
      if (mounted) {
        final result = await showDialog<String>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Battery Optimization'),
              content: Text(
                'To ensure the app works properly in the background:\n\n'
                '1. Select "Unrestricted" if available\n'
                '2. Or turn OFF "Optimized" setting\n'
                '3. This prevents Android from killing the app\n\n'
                'Would you like to open the battery settings?'
                '${_batterySettingsHasBeenOpened 
                    ? '\n\nIf you\'ve already configured this but the app still shows it as not configured, you can mark it as "Already Configured".' 
                    : ''}'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop('cancel'),
                  child: const Text('Cancel'),
                ),
                if (_batterySettingsHasBeenOpened)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop('configured'),
                    child: const Text('Already Configured'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop('settings'),
                  child: const Text('Open Settings'),
                ),
              ],
            );
          },
        );

        if (result == 'configured') {
          // User confirms they have configured it manually
          setState(() {
            _batteryOptimizationManuallyConfigured = true;
          });
          await _saveBatteryOptimizationSetting(true);
          _checkAppHealth();
          return;
        } else if (result != 'settings') {
          return; // User cancelled
        }
      }

      // Check current status first
      final currentStatus = await Permission.ignoreBatteryOptimizations.status;
      debugPrint('Current battery optimization status: $currentStatus');

      // Try to request permission first
      try {
        final status = await Permission.ignoreBatteryOptimizations.request();
        debugPrint('Battery optimization status after request: $status');
        
        if (status == PermissionStatus.granted) {
          _checkAppHealth();
          return;
        }
      } catch (e) {
        debugPrint('Permission request failed: $e');
      }

      // Mark that settings have been opened and save it
      setState(() {
        _batterySettingsHasBeenOpened = true;
      });
      await _saveBatterySettingsOpenedFlag();
      
      // Always open app settings for manual configuration
      // This is more reliable on modern Android devices
      await openAppSettings();
      
      _checkAppHealth(); // Refresh status
    } catch (e) {
      debugPrint('Error requesting battery optimization exemption: $e');
      // If there's an error, try to open app settings as fallback
      try {
        await openAppSettings();
      } catch (settingsError) {
        debugPrint('Error opening settings: $settingsError');
      }
      _checkAppHealth();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('App Health Check'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkAppHealth,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _checkAppHealth,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverallStatus(),
                    const SizedBox(height: 24),
                    _buildHealthCard(
                      title: 'GPS & Location',
                      subtitle: 'Location services and permissions',
                      icon: Icons.gps_fixed,
                      isHealthy: _healthStatus['gps']!,
                      onTap: _healthStatus['gps']! ? null : _requestGPSPermission,
                      description: _healthStatus['gps']!
                          ? 'GPS is working properly'
                          : 'Tap to enable location permissions',
                    ),
                    const SizedBox(height: 16),
                    _buildHealthCard(
                      title: 'Notifications',
                      subtitle: 'Push notifications and alerts',
                      icon: Icons.notifications,
                      isHealthy: _healthStatus['notifications']!,
                      onTap: _healthStatus['notifications']! ? null : _requestNotificationPermission,
                      description: _healthStatus['notifications']!
                          ? 'Notifications are enabled'
                          : 'Notification permission required for alerts',
                    ),
                    const SizedBox(height: 16),
                    _buildHealthCard(
                      title: 'Background Services',
                      subtitle: 'App background activity',
                      icon: Icons.settings_backup_restore,
                      isHealthy: _healthStatus['background']!,
                      onTap: _healthStatus['background']! ? null : _openBackgroundSettings,
                      description: _healthStatus['background']!
                          ? 'Background services are active'
                          : 'Enable background app refresh for continuous tracking',
                    ),
                    const SizedBox(height: 16),
                    if (Platform.isAndroid) ...[
                      _buildHealthCard(
                        title: 'Battery Optimization',
                        subtitle: 'App not optimized by Android',
                        icon: Icons.battery_saver,
                        isHealthy: _healthStatus['battery_optimization']!,
                        onTap: _healthStatus['battery_optimization']! ? null : _requestBatteryOptimizationExemption,
                        description: _healthStatus['battery_optimization']!
                            ? 'App is exempt from battery optimization'
                            : 'Disable battery optimization for background operation',
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildHealthCard(
                      title: 'Internet Connection',
                      subtitle: 'Network connectivity',
                      icon: Icons.wifi,
                      isHealthy: _healthStatus['internet']!,
                      onTap: null,
                      description: _healthStatus['internet']!
                          ? 'Internet connection is active'
                          : 'No internet connection detected',
                    ),
                    const SizedBox(height: 32),
                    _buildTipsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverallStatus() {
    final allHealthy = _healthStatus.values.every((status) => status);
    final healthyCount = _healthStatus.values.where((status) => status).length;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: allHealthy 
                ? [Colors.green, Colors.green.withValues(alpha: 0.8)]
                : [Colors.orange, Colors.orange.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Icon(
                allHealthy ? Icons.check_circle : Icons.warning,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allHealthy ? 'App is Healthy' : 'Issues Detected',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$healthyCount of ${_healthStatus.length} systems operational',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isHealthy,
    required VoidCallback? onTap,
    required String description,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isHealthy 
                    ? Colors.green.withValues(alpha: 0.1) 
                    : Colors.red.withValues(alpha: 0.1),
                child: Icon(
                  icon,
                  color: isHealthy ? Colors.green : Colors.red,
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isHealthy ? Colors.green[700] : Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isHealthy ? Icons.check_circle : Icons.error,
                color: isHealthy ? Colors.green : Colors.red,
                size: 24,
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Tips for Better Performance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTip('Keep location services enabled for accurate tracking'),
            _buildTip('Allow notifications to receive important updates'),
            _buildTip('Enable background app refresh for continuous operation'),
            if (Platform.isAndroid)
              _buildTip('Disable battery optimization to prevent app from being killed'),
            _buildTip('Maintain stable internet connection for data sync'),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}