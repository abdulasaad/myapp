// lib/services/user_status_service.dart

import 'dart:async';
import 'package:logger/logger.dart';
import '../utils/constants.dart';
import 'connectivity_service.dart';

final logger = Logger();

enum UserStatus {
  active,   // Logged in + has internet
  away,     // Logged in + no internet for >1 minute
  offline,  // Logged out OR no internet for >15 minutes
}

class UserStatusService {
  static final UserStatusService _instance = UserStatusService._internal();
  factory UserStatusService() => _instance;
  UserStatusService._internal();

  // Service state
  Timer? _heartbeatTimer;
  Timer? _statusCheckTimer;
  UserStatus _currentStatus = UserStatus.offline;
  DateTime? _lastInternetTime;
  DateTime? _lastHeartbeatTime;
  bool _isInitialized = false;
  bool _isLoggedIn = false;

  // Configuration
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _awayThreshold = Duration(minutes: 1);
  static const Duration _offlineThreshold = Duration(minutes: 15);
  static const Duration _statusCheckInterval = Duration(seconds: 10);

  // Getters
  UserStatus get currentStatus => _currentStatus;
  bool get isActive => _currentStatus == UserStatus.active;
  bool get isAway => _currentStatus == UserStatus.away;
  bool get isOffline => _currentStatus == UserStatus.offline;

  /// Initialize the status service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      logger.i('🔄 Initializing UserStatusService...');
      
      // Check if user is logged in
      final currentUser = supabase.auth.currentUser;
      _isLoggedIn = currentUser != null;
      
      if (!_isLoggedIn) {
        _currentStatus = UserStatus.offline;
        logger.i('📴 User not logged in - Status: offline');
        return;
      }

      // Initialize connectivity service if not already done
      await ConnectivityService().initialize();
      
      // Set initial status based on connectivity
      final isConnected = ConnectivityService().isOnline;
      _lastInternetTime = isConnected ? DateTime.now() : null;
      _currentStatus = isConnected ? UserStatus.active : UserStatus.away;
      
      // Listen to connectivity changes
      ConnectivityService().connectivityStream.listen(_onConnectivityChanged);
      
      // Start periodic status checks
      _startStatusMonitoring();
      
      // Start heartbeat if we're active
      if (_currentStatus == UserStatus.active) {
        _startHeartbeat();
      }
      
      _isInitialized = true;
      logger.i('✅ UserStatusService initialized - Status: ${_currentStatus.name}');
      
    } catch (e) {
      logger.e('❌ Failed to initialize UserStatusService: $e');
      _currentStatus = UserStatus.offline;
    }
  }

  /// Handle user login
  Future<void> onUserLogin() async {
    logger.i('🔐 User logged in - Starting status service');
    _isLoggedIn = true;
    
    if (!_isInitialized) {
      await initialize();
    } else {
      // Update status based on current connectivity
      final isConnected = ConnectivityService().isOnline;
      _lastInternetTime = isConnected ? DateTime.now() : null;
      await _updateStatus(isConnected ? UserStatus.active : UserStatus.away);
      
      if (_currentStatus == UserStatus.active) {
        _startHeartbeat();
      }
    }
  }

  /// Handle user logout
  Future<void> onUserLogout() async {
    logger.i('🚪 User logged out - Stopping status service');
    _isLoggedIn = false;
    await _updateStatus(UserStatus.offline);
    _stopAllTimers();
  }

  /// Start heartbeat mechanism
  void _startHeartbeat() {
    _stopHeartbeat();
    
    logger.i('💓 Starting heartbeat (${_heartbeatInterval.inSeconds}s intervals)');
    
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) async {
      if (_isLoggedIn && _currentStatus == UserStatus.active) {
        await _sendHeartbeat();
      }
    });
  }

  /// Stop heartbeat mechanism
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Start status monitoring
  void _startStatusMonitoring() {
    _stopStatusMonitoring();
    
    logger.d('👁️ Starting status monitoring (${_statusCheckInterval.inSeconds}s intervals)');
    
    _statusCheckTimer = Timer.periodic(_statusCheckInterval, (timer) async {
      await _checkAndUpdateStatus();
    });
  }

  /// Stop status monitoring
  void _stopStatusMonitoring() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
  }

  /// Stop all timers
  void _stopAllTimers() {
    _stopHeartbeat();
    _stopStatusMonitoring();
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(bool isConnected) async {
    logger.i('🌐 Connectivity changed: ${isConnected ? 'ONLINE' : 'OFFLINE'}');
    
    if (isConnected) {
      _lastInternetTime = DateTime.now();
      if (_isLoggedIn) {
        await _updateStatus(UserStatus.active);
        _startHeartbeat();
      }
    } else {
      _stopHeartbeat();
      // Don't immediately change status - wait for thresholds
    }
  }

  /// Check and update status based on thresholds
  Future<void> _checkAndUpdateStatus() async {
    if (!_isLoggedIn) {
      if (_currentStatus != UserStatus.offline) {
        await _updateStatus(UserStatus.offline);
      }
      return;
    }

    final now = DateTime.now();
    final isConnected = ConnectivityService().isOnline;

    if (isConnected) {
      _lastInternetTime = now;
      if (_currentStatus != UserStatus.active) {
        await _updateStatus(UserStatus.active);
        _startHeartbeat();
      }
      return;
    }

    // No internet connection
    if (_lastInternetTime == null) {
      // Never had internet this session
      await _updateStatus(UserStatus.away);
      return;
    }

    final timeSinceInternet = now.difference(_lastInternetTime!);

    if (timeSinceInternet >= _offlineThreshold) {
      // Offline threshold reached
      if (_currentStatus != UserStatus.offline) {
        await _updateStatus(UserStatus.offline);
        _stopHeartbeat();
      }
    } else if (timeSinceInternet >= _awayThreshold) {
      // Away threshold reached
      if (_currentStatus != UserStatus.away) {
        await _updateStatus(UserStatus.away);
        _stopHeartbeat();
      }
    }
  }

  /// Send heartbeat to server
  Future<void> _sendHeartbeat() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        logger.w('💓 Heartbeat skipped - no authenticated user');
        return;
      }

      await supabase.rpc('update_user_heartbeat', params: {
        'p_user_id': currentUser.id,
      });

      _lastHeartbeatTime = DateTime.now();
      logger.d('💓 Heartbeat sent - Status: ${_currentStatus.name}');
      
    } catch (e) {
      logger.w('💓 Heartbeat failed: $e');
      // Don't change status on heartbeat failure - could be temporary network issue
    }
  }

  /// Update current status
  Future<void> _updateStatus(UserStatus newStatus) async {
    if (_currentStatus == newStatus) return;

    final previousStatus = _currentStatus;
    _currentStatus = newStatus;
    
    logger.i('📊 Status changed: ${previousStatus.name} → ${newStatus.name}');

    // Update database immediately for status changes
    await _sendStatusUpdate();

    // Notify listeners if needed (could add a stream controller here)
  }

  /// Send status update to database
  Future<void> _sendStatusUpdate() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      await supabase
          .from('profiles')
          .update({
            'connection_status': _currentStatus.name,
            'last_heartbeat': DateTime.now().toIso8601String(),
          })
          .eq('id', currentUser.id);

      logger.d('📊 Status updated in database: ${_currentStatus.name}');
      
    } catch (e) {
      logger.w('📊 Failed to update status in database: $e');
    }
  }

  /// Get status summary for debugging
  Map<String, dynamic> getStatusSummary() {
    return {
      'currentStatus': _currentStatus.name,
      'isLoggedIn': _isLoggedIn,
      'isConnected': ConnectivityService().isOnline,
      'lastInternetTime': _lastInternetTime?.toIso8601String(),
      'lastHeartbeatTime': _lastHeartbeatTime?.toIso8601String(),
      'isInitialized': _isInitialized,
    };
  }

  /// Dispose the service
  void dispose() {
    logger.i('🗑️ Disposing UserStatusService');
    _stopAllTimers();
    _isInitialized = false;
  }
}