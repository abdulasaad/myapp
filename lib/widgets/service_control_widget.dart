// lib/widgets/service_control_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/persistent_service_manager.dart';
import '../l10n/app_localizations.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';

class ServiceControlWidget extends StatefulWidget {
  final bool isCompact;
  
  const ServiceControlWidget({super.key, this.isCompact = false});

  @override
  State<ServiceControlWidget> createState() => _ServiceControlWidgetState();
}

class _ServiceControlWidgetState extends State<ServiceControlWidget> {
  bool _isServiceRunning = false;
  bool _isLoading = true;
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    // Start periodic status checks
    _startPeriodicStatusCheck();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicStatusCheck() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _checkServiceStatus();
      }
    });
  }

  Future<void> _checkServiceStatus() async {
    try {
      final isRunning = await PersistentServiceManager.areServicesRunning();
      if (mounted && (_isServiceRunning != isRunning || _isLoading)) {
        setState(() {
          _isServiceRunning = isRunning;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleService() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isServiceRunning) {
        // Show confirmation dialog before stopping
        final shouldStop = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.stopServicesQuestion),
            content: Text(
              AppLocalizations.of(context)!.stopServicesWarning,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: Text(AppLocalizations.of(context)!.stopServices),
              ),
            ],
          ),
        );

        if (shouldStop == true) {
          await PersistentServiceManager.stopAllServices();
          if (mounted) {
            context.showAdvancedNotification(
              AppLocalizations.of(context)!.backgroundServicesStopped,
              title: AppLocalizations.of(context)!.servicesDisabled,
              isWarning: true,
              customIcon: Icons.pause_circle,
            );
          }
        }
      } else {
        // Start services
        final started = await PersistentServiceManager.startAllServices(context);
        if (mounted) {
          if (started) {
            context.showAdvancedNotification(
              AppLocalizations.of(context)!.servicesActiveMessage,
              title: AppLocalizations.of(context)!.servicesStarted,
              customIcon: Icons.play_circle,
            );
          } else {
            context.showAdvancedNotification(
              AppLocalizations.of(context)!.failedToStartServices,
              title: AppLocalizations.of(context)!.serviceError,
              isError: true,
              customIcon: Icons.error_outline,
            );
          }
        }
      }

      // Force immediate status check after service change
      await Future.delayed(const Duration(milliseconds: 500));
      await _checkServiceStatus();
    } catch (e) {
      if (mounted) {
        context.showAdvancedNotification(
          '${AppLocalizations.of(context)!.unableToToggleServices}: ${e.toString()}',
          title: AppLocalizations.of(context)!.serviceError,
          isError: true,
          customIcon: Icons.error_outline,
          duration: const Duration(seconds: 6),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactWidget(context);
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isServiceRunning 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isServiceRunning ? Icons.gps_fixed : Icons.gps_off,
                    color: _isServiceRunning ? Colors.green : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.backgroundServices,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isServiceRunning 
                            ? AppLocalizations.of(context)!.locationTrackingActive
                            : AppLocalizations.of(context)!.servicesAreStopped,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _isServiceRunning 
                              ? Colors.green 
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value: _isServiceRunning,
                        onChanged: (value) => _toggleService(),
                        activeColor: Colors.green,
                      ),
              ],
            ),
            if (_isServiceRunning) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A persistent notification is active. You can stop services '
                        'from the notification or by turning off the switch above.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.serviceDetails,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, dynamic>>(
              future: PersistentServiceManager.getServiceStatus(),
              builder: (context, snapshot) {
                final serviceStatus = snapshot.data;
                final locationActive = serviceStatus?['locationTracking'] ?? _isServiceRunning;
                final statusActive = serviceStatus?['statusTracking'] ?? _isServiceRunning;
                
                return Column(
                  children: [
                    _buildServiceDetail(
                      icon: Icons.location_on,
                      title: AppLocalizations.of(context)!.locationTracking,
                      status: locationActive ? AppLocalizations.of(context)!.active : AppLocalizations.of(context)!.inactive,
                      isActive: locationActive,
                    ),
                    const SizedBox(height: 8),
                    _buildServiceDetail(
                      icon: Icons.wifi,
                      title: AppLocalizations.of(context)!.onlineStatus,
                      status: statusActive ? AppLocalizations.of(context)!.broadcasting : AppLocalizations.of(context)!.offline,
                      isActive: statusActive,
                    ),
                    const SizedBox(height: 8),
                    _buildServiceDetail(
                      icon: Icons.favorite,
                      title: AppLocalizations.of(context)!.heartbeat,
                      status: _isServiceRunning ? AppLocalizations.of(context)!.every30s : AppLocalizations.of(context)!.stopped,
                      isActive: _isServiceRunning,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactWidget(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isServiceRunning
              ? [
                  Colors.green.withOpacity(0.1),
                  Colors.green.withOpacity(0.05),
                ]
              : [
                  Colors.grey.withOpacity(0.1),
                  Colors.grey.withOpacity(0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isServiceRunning 
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isServiceRunning 
                    ? Colors.green.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isServiceRunning ? Icons.gps_fixed : Icons.gps_off,
                color: _isServiceRunning ? Colors.green : Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            
            // Status Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.backgroundServices,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isServiceRunning ? AppLocalizations.of(context)!.active : AppLocalizations.of(context)!.disabled,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _isServiceRunning ? Colors.green : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Toggle Switch
            _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _isServiceRunning,
                      onChanged: (value) => _toggleService(),
                      activeColor: Colors.green,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceDetail({
    required IconData icon,
    required String title,
    required String status,
    required bool isActive,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isActive ? primaryColor : Colors.grey,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          status,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.green : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}