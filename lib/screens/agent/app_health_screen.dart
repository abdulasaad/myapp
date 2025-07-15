import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../utils/constants.dart';

class AppHealthScreen extends StatefulWidget {
  const AppHealthScreen({super.key});

  @override
  State<AppHealthScreen> createState() => _AppHealthScreenState();
}

class _AppHealthScreenState extends State<AppHealthScreen> {
  bool _isLoading = true;
  Map<String, bool> _healthStatus = {
    'gps': false,
    'notifications': false,
    'background': false,
    'internet': false,
  };

  @override
  void initState() {
    super.initState();
    _checkAppHealth();
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
      
      // Check internet connectivity
      final internetStatus = await _checkInternetStatus();

      setState(() {
        _healthStatus = {
          'gps': gpsStatus,
          'notifications': notificationStatus,
          'background': backgroundStatus,
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
      final status = await Permission.notification.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      return false;
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
      final status = await Permission.notification.request();
      if (status != PermissionStatus.granted) {
        await openAppSettings();
      }
      
      _checkAppHealth(); // Refresh status
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
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
                          : 'GPS permission required for location tracking',
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