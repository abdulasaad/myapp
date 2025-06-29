// lib/services/smart_location_manager.dart

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'location_service.dart';
import 'background_location_service.dart';
import 'settings_service.dart';
import 'offline_location_queue.dart';
import 'connectivity_service.dart';
import '../utils/constants.dart';

final logger = Logger();

enum LocationTrackingMode {
  foreground,  // App is active - use foreground service
  background,  // App is backgrounded - use background service
  stopped,     // No tracking
}

class SmartLocationManager {
  static final SmartLocationManager _instance = SmartLocationManager._internal();
  factory SmartLocationManager() => _instance;
  SmartLocationManager._internal();

  final LocationService _foregroundService = LocationService();
  final OfflineLocationQueue _offlineQueue = OfflineLocationQueue();
  LocationTrackingMode _currentMode = LocationTrackingMode.stopped;
  String? _activeCampaignId;
  bool _isInitialized = false;
  Timer? _modeTransitionTimer;
  Timer? _healthCheckTimer;
  
  // Battery optimization settings
  bool _isMoving = false;
  DateTime? _lastMovementTime;
  Position? _lastKnownPosition;
  
  // Adaptive update intervals
  Timer? _adaptiveTimer;
  int _currentUpdateInterval = 30; // seconds
  double _currentMovementSpeed = 0.0; // m/s
  int _stationaryDuration = 0; // minutes
  
  // Error handling and recovery
  int _consecutiveFailures = 0;
  DateTime? _lastSuccessfulUpdate;
  bool _isRecovering = false;
  
  // Streams
  Stream<Position> get locationStream => _foregroundService.locationStream;
  Stream<GeofenceStatus> get geofenceStatusStream => _foregroundService.geofenceStatusStream;
  
  /// Initialize the smart location manager
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      logger.i('🧠 Initializing Smart Location Manager...');
      
      // Check permissions first
      final hasPermission = await _checkLocationPermissions();
      if (!hasPermission) {
        logger.w('❌ Location permissions denied');
        return false;
      }
      
      // Initialize background service (but don't start it yet)
      await BackgroundLocationService.initialize();
      
      // Initialize offline queue
      await _offlineQueue.initialize();
      
      // Start with foreground mode
      await _switchToForegroundMode();
      
      _isInitialized = true;
      logger.i('✅ Smart Location Manager initialized successfully');
      return true;
    } catch (e) {
      logger.e('❌ Failed to initialize Smart Location Manager: $e');
      return false;
    }
  }
  
  /// Start location tracking in smart mode
  Future<void> startTracking() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return;
    }
    
    logger.i('🚀 Starting smart location tracking...');
    
    // Start background service first to ensure continuity
    await BackgroundLocationService.startLocationTracking();
    
    // Then start foreground mode
    await _switchToForegroundMode();
    
    // Start health monitoring
    _startHealthCheck();
    
    // Start adaptive interval management
    _startAdaptiveIntervals();
  }
  
  /// Stop all location tracking
  Future<void> stopTracking() async {
    logger.i('🛑 Stopping smart location tracking...');
    
    _modeTransitionTimer?.cancel();
    _healthCheckTimer?.cancel();
    _adaptiveTimer?.cancel();
    _foregroundService.stop();
    await BackgroundLocationService.stopLocationTracking();
    _offlineQueue.dispose();
    
    _currentMode = LocationTrackingMode.stopped;
    _activeCampaignId = null;
    _isMoving = false;
    _lastMovementTime = null;
    _lastKnownPosition = null;
    _currentUpdateInterval = 30;
    _currentMovementSpeed = 0.0;
    _stationaryDuration = 0;
    _consecutiveFailures = 0;
    _lastSuccessfulUpdate = null;
    _isRecovering = false;
  }
  
  /// Set active campaign for geofence tracking
  void setActiveCampaign(String? campaignId) {
    _activeCampaignId = campaignId;
    _foregroundService.setActiveCampaign(campaignId);
    BackgroundLocationService.setActiveCampaign(campaignId);
    
    if (campaignId != null) {
      logger.i('📍 Active campaign set: $campaignId');
    } else {
      logger.i('📍 Active campaign cleared');
    }
  }
  
  /// Handle app lifecycle changes
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        logger.i('📱 App resumed - switching to foreground tracking');
        _scheduleMode(LocationTrackingMode.foreground, const Duration(seconds: 2));
        break;
        
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        logger.i('📱 App backgrounded - switching to background tracking immediately');
        _scheduleMode(LocationTrackingMode.background, const Duration(seconds: 2));
        break;
        
      case AppLifecycleState.detached:
        logger.i('📱 App detached - maintaining background tracking');
        // Keep background tracking active
        break;
        
      case AppLifecycleState.inactive:
        // Brief inactive state - don't change tracking mode
        break;
    }
  }
  
  /// Schedule a mode transition with delay
  void _scheduleMode(LocationTrackingMode newMode, Duration delay) {
    _modeTransitionTimer?.cancel();
    _modeTransitionTimer = Timer(delay, () {
      _transitionToMode(newMode);
    });
  }
  
  /// Transition to a new tracking mode
  Future<void> _transitionToMode(LocationTrackingMode newMode) async {
    if (_currentMode == newMode) return;
    
    logger.i('🔄 Transitioning from $_currentMode to $newMode');
    
    switch (newMode) {
      case LocationTrackingMode.foreground:
        await _switchToForegroundMode();
        break;
        
      case LocationTrackingMode.background:
        await _switchToBackgroundMode();
        break;
        
      case LocationTrackingMode.stopped:
        await stopTracking();
        break;
    }
  }
  
  /// Switch to foreground-only tracking
  Future<void> _switchToForegroundMode() async {
    try {
      // Keep background service running but start foreground as primary
      // This ensures continuity if app is quickly backgrounded again
      
      // Start/restart foreground service
      await _foregroundService.start();
      
      _currentMode = LocationTrackingMode.foreground;
      logger.i('✅ Switched to FOREGROUND tracking mode (background still active)');
      
      // Listen to location updates for movement detection
      _foregroundService.locationStream.listen(
        _handleLocationUpdate,
        onError: (error) {
          _recordFailedUpdate();
          logger.e('❌ Foreground location stream error: $error');
        },
      );
      
    } catch (e) {
      _recordFailedUpdate();
      logger.e('❌ Failed to switch to foreground mode: $e');
      rethrow;
    }
  }
  
  /// Switch to background-only tracking
  Future<void> _switchToBackgroundMode() async {
    try {
      // Ensure background service is running
      await BackgroundLocationService.startLocationTracking();
      
      // Now stop foreground service (background takes over)
      _foregroundService.stop();
      
      _currentMode = LocationTrackingMode.background;
      logger.i('✅ Switched to BACKGROUND tracking mode');
      
    } catch (e) {
      _recordFailedUpdate();
      logger.e('❌ Failed to switch to background mode: $e');
      // Fallback to foreground if background fails
      try {
        logger.i('🔄 Falling back to foreground mode');
        await _switchToForegroundMode();
      } catch (fallbackError) {
        logger.e('❌ Fallback to foreground also failed: $fallbackError');
        rethrow;
      }
    }
  }
  
  /// Handle location updates for movement detection and speed calculation
  void _handleLocationUpdate(Position position) async {
    final now = DateTime.now();
    
    try {
      // Record successful update
      _recordSuccessfulUpdate();
      
      // Calculate movement metrics
      if (_lastKnownPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastKnownPosition!.latitude,
          _lastKnownPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        
        // Calculate speed using timestamps (Position always has timestamp)
        final timeDiff = position.timestamp.difference(_lastKnownPosition!.timestamp).inSeconds;
        
        if (timeDiff > 0) {
          _currentMovementSpeed = distance / timeDiff; // m/s
        }
        
        final movementThreshold = SettingsService.instance.gpsDistanceFilter.toDouble();
        
        if (distance > movementThreshold) {
          _isMoving = true;
          _lastMovementTime = now;
          _stationaryDuration = 0;
          logger.d('🚶 Agent moving: ${distance.toStringAsFixed(1)}m, ${(_currentMovementSpeed * 3.6).toStringAsFixed(1)} km/h');
        } else {
          // Update stationary duration
          if (_lastMovementTime != null) {
            _stationaryDuration = now.difference(_lastMovementTime!).inMinutes;
            if (_stationaryDuration > 5) {
              _isMoving = false;
              logger.d('🛏️ Agent stationary for $_stationaryDuration minutes');
            }
          }
        }
        
        // Update adaptive interval based on movement
        _updateAdaptiveInterval();
      }
      
      _lastKnownPosition = position;
      
      // Send location update (with offline resilience)
      await _sendLocationWithOfflineSupport(position);
      
    } catch (e) {
      _recordFailedUpdate();
      logger.e('❌ Error handling location update: $e');
    }
  }
  
  /// Send location update with offline support
  Future<void> _sendLocationWithOfflineSupport(Position position) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      // Use offline queue which handles online/offline scenarios automatically
      await _offlineQueue.queueLocationUpdate(position, userId);
      
    } catch (e) {
      _recordFailedUpdate();
      logger.e('❌ Error sending location update: $e');
    }
  }
  
  /// Check and request location permissions
  Future<bool> _checkLocationPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        logger.w('📍 Location services are disabled');
        return false;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          logger.w('📍 Location permission denied');
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        logger.w('📍 Location permission permanently denied');
        return false;
      }
      
      logger.i('✅ Location permissions granted');
      return true;
    } catch (e) {
      logger.e('❌ Error checking location permissions: $e');
      return false;
    }
  }
  
  /// Get current tracking status
  LocationTrackingMode get currentMode => _currentMode;
  
  /// Check if tracking is active
  bool get isTracking => _currentMode != LocationTrackingMode.stopped;
  
  /// Check if agent is currently moving
  bool get isMoving => _isMoving;
  
  /// Get battery optimization status
  Map<String, dynamic> getBatteryOptimizationStatus() {
    final queueStats = _offlineQueue.getQueueStats();
    
    return {
      'currentMode': _currentMode.toString(),
      'isMoving': _isMoving,
      'lastMovement': _lastMovementTime?.toIso8601String(),
      'foregroundActive': _currentMode == LocationTrackingMode.foreground,
      'backgroundActive': _currentMode == LocationTrackingMode.background,
      'batteryFriendly': _currentMode == LocationTrackingMode.background && !_isMoving,
      'adaptiveInterval': _currentUpdateInterval,
      'intervalReason': _getIntervalReason(),
      'movementSpeed': _currentMovementSpeed,
      'stationaryDuration': _stationaryDuration,
      'batteryOptimized': !_isMoving && _stationaryDuration > 5,
      'offlineQueue': queueStats,
      'isOnline': ConnectivityService().isOnline,
    };
  }
  
  /// Force refresh location (for immediate needs)
  Future<Position?> getCurrentLocation() async {
    return await _foregroundService.getCurrentLocation();
  }
  
  /// Check if agent is in task geofence
  Future<bool> isAgentInTaskGeofence(String taskId) async {
    return await _foregroundService.isAgentInTaskGeofence(taskId);
  }
  
  /// Force sync all queued offline updates
  Future<int> syncOfflineUpdates() async {
    return await _offlineQueue.syncQueuedUpdates();
  }
  
  /// Update background service tracking interval dynamically
  void _updateBackgroundServiceInterval(int intervalSeconds) {
    try {
      // Send command to background service to update interval
      final service = FlutterBackgroundService();
      service.invoke('updateInterval', {
        'interval': intervalSeconds,
      });
      logger.i('📡 Updated background service interval to ${intervalSeconds}s');
    } catch (e) {
      logger.e('❌ Failed to update background interval: $e');
    }
  }
  
  /// Update foreground service tracking interval
  void _updateForegroundServiceInterval(int intervalSeconds) {
    try {
      // Update the foreground service timer interval
      _foregroundService.updatePingInterval(intervalSeconds);
      logger.i('📱 Updated foreground service interval to ${intervalSeconds}s');
    } catch (e) {
      logger.e('❌ Failed to update foreground interval: $e');
    }
  }
  
  /// Get offline queue statistics
  Map<String, dynamic> getOfflineQueueStats() {
    return _offlineQueue.getQueueStats();
  }
  
  /// Clear the offline queue (for testing/debugging)
  Future<void> clearOfflineQueue() async {
    await _offlineQueue.clearQueue();
  }
  
  /// Start adaptive interval management
  void _startAdaptiveIntervals() {
    _adaptiveTimer?.cancel();
    // Check for interval updates every 30 seconds for faster response
    _adaptiveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateAdaptiveInterval();
    });
  }
  
  /// Update tracking interval based on movement patterns
  void _updateAdaptiveInterval() {
    int newInterval = _calculateOptimalInterval();
    
    if (newInterval != _currentUpdateInterval) {
      _currentUpdateInterval = newInterval;
      logger.i('⏱️ Adaptive interval updated: ${_currentUpdateInterval}s (${_getIntervalReason()})');
      
      // Apply new interval to services if needed
      _applyAdaptiveInterval();
    }
  }
  
  /// Calculate optimal update interval based on current conditions
  int _calculateOptimalInterval() {
    final baseInterval = SettingsService.instance.gpsPingInterval;
    
    // Fast updates for moving agents
    if (_isMoving) {
      final speedKmh = _currentMovementSpeed * 3.6; // Convert m/s to km/h
      
      if (speedKmh > 50) {
        return (baseInterval * 0.5).round(); // 50% faster for fast movement (vehicles)
      } else if (speedKmh > 10) {
        return (baseInterval * 0.75).round(); // 25% faster for moderate movement (cycling)
      } else if (speedKmh > 3) {
        return baseInterval; // Normal interval for walking speed
      }
    }
    
    // Slower updates for stationary agents
    if (_stationaryDuration > 30) {
      return (baseInterval * 6).round(); // 6x slower for long stationary periods (3+ minutes)
    } else if (_stationaryDuration > 15) {
      return (baseInterval * 4).round(); // 4x slower for moderate stationary periods (2+ minutes)
    } else if (_stationaryDuration > 5) {
      return (baseInterval * 2).round(); // 2x slower for short stationary periods (1+ minute)
    }
    
    return baseInterval; // Default interval
  }
  
  /// Apply the adaptive interval to location services
  void _applyAdaptiveInterval() {
    logger.d('📊 Current tracking metrics: '
        'Speed: ${(_currentMovementSpeed * 3.6).toStringAsFixed(1)}km/h, '
        'Stationary: ${_stationaryDuration}min, '
        'Interval: ${_currentUpdateInterval}s');
    
    // Apply adaptive interval to background service
    if (_currentMode == LocationTrackingMode.background) {
      _updateBackgroundServiceInterval(_currentUpdateInterval);
    }
    
    // Update foreground service interval if needed
    if (_currentMode == LocationTrackingMode.foreground) {
      _updateForegroundServiceInterval(_currentUpdateInterval);
    }
  }
  
  /// Get human-readable reason for current interval
  String _getIntervalReason() {
    if (_isMoving) {
      final speedKmh = _currentMovementSpeed * 3.6;
      if (speedKmh > 50) return 'fast movement detected';
      if (speedKmh > 10) return 'moderate movement detected'; 
      if (speedKmh > 3) return 'walking speed detected';
    }
    
    if (_stationaryDuration > 30) return 'long stationary period';
    if (_stationaryDuration > 15) return 'moderate stationary period';
    if (_stationaryDuration > 5) return 'short stationary period';
    
    return 'normal activity';
  }
  
  /// Get current movement metrics
  Map<String, dynamic> getMovementMetrics() {
    return {
      'isMoving': _isMoving,
      'currentSpeed': _currentMovementSpeed,
      'speedKmh': _currentMovementSpeed * 3.6,
      'stationaryDuration': _stationaryDuration,
      'currentInterval': _currentUpdateInterval,
      'intervalReason': _getIntervalReason(),
      'lastMovement': _lastMovementTime?.toIso8601String(),
    };
  }
  
  /// Start health monitoring for location services
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _performHealthCheck();
    });
  }
  
  /// Perform health check and recovery if needed
  Future<void> _performHealthCheck() async {
    final now = DateTime.now();
    
    // Check if we haven't received location updates in too long
    if (_lastSuccessfulUpdate != null) {
      final timeSinceLastUpdate = now.difference(_lastSuccessfulUpdate!);
      
      if (timeSinceLastUpdate.inMinutes > 5) {
        logger.w('⚠️ No location updates for ${timeSinceLastUpdate.inMinutes} minutes');
        await _attemptRecovery();
      }
    }
    
    // Check consecutive failures
    if (_consecutiveFailures > 3) {
      logger.w('⚠️ Too many consecutive failures: $_consecutiveFailures');
      await _attemptRecovery();
    }
  }
  
  /// Attempt to recover from location tracking failures
  Future<void> _attemptRecovery() async {
    if (_isRecovering) return; // Prevent multiple recovery attempts
    
    _isRecovering = true;
    logger.i('🔧 Attempting location tracking recovery...');
    
    try {
      // Stop current tracking
      _foregroundService.stop();
      await BackgroundLocationService.stopLocationTracking();
      
      // Wait a moment
      await Future.delayed(const Duration(seconds: 3));
      
      // Restart tracking based on current mode
      if (_currentMode == LocationTrackingMode.foreground) {
        await _switchToForegroundMode();
      } else if (_currentMode == LocationTrackingMode.background) {
        await _switchToBackgroundMode();
      }
      
      // Reset failure counter
      _consecutiveFailures = 0;
      logger.i('✅ Location tracking recovery completed');
      
    } catch (e) {
      logger.e('❌ Location tracking recovery failed: $e');
      _consecutiveFailures++;
    } finally {
      _isRecovering = false;
    }
  }
  
  /// Record successful location update
  void _recordSuccessfulUpdate() {
    _lastSuccessfulUpdate = DateTime.now();
    _consecutiveFailures = 0;
  }
  
  /// Record failed location update
  void _recordFailedUpdate() {
    _consecutiveFailures++;
    logger.w('❌ Location update failed (consecutive failures: $_consecutiveFailures)');
  }
}