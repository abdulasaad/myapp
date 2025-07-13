// lib/services/connectivity_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  
  // Stream controller for connectivity changes
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    try {
      // Check initial connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      _isOnline = _isConnected(connectivityResults);
      
      // Notify initial state
      _connectivityController.add(_isOnline);
      
      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          final wasOnline = _isOnline;
          _isOnline = _isConnected(results);
          
          if (wasOnline != _isOnline) {
            logger.i('🌐 Connectivity changed: ${_isOnline ? 'ONLINE' : 'OFFLINE'}');
            _connectivityController.add(_isOnline);
          }
        },
        onError: (error) {
          logger.w('🌐 Connectivity monitoring error: $error');
          // Assume offline if monitoring fails
          _isOnline = false;
          _connectivityController.add(false);
        },
      );
      
      logger.i('🌐 ConnectivityService initialized - Status: ${_isOnline ? 'ONLINE' : 'OFFLINE'}');
    } catch (e) {
      logger.w('🌐 ConnectivityService initialization failed: $e');
      // Default to offline if initialization fails
      _isOnline = false;
      // Still try to notify listeners that we're offline
      _connectivityController.add(false);
    }
  }

  /// Check if any of the connectivity results indicate a connection
  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((result) => 
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet ||
      result == ConnectivityResult.vpn
    );
  }

  /// Dispose the service
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }
  
  /// Show a user-friendly message for network errors
  static String getNetworkErrorMessage() {
    return 'No internet connection. Please check your network settings and try again.';
  }
  
  /// Check if an exception is a network error
  static bool isNetworkError(dynamic error) {
    if (error == null) return false;
    
    final errorString = error.toString().toLowerCase();
    return errorString.contains('authretryablefetchexception') ||
           errorString.contains('clientexception') ||
           errorString.contains('socketexception') ||
           errorString.contains('failed host lookup') ||
           errorString.contains('no address associated with hostname') ||
           errorString.contains('network is unreachable') ||
           errorString.contains('connection refused') ||
           errorString.contains('connection timed out') ||
           errorString.contains('connection closed');
  }
}