// lib/services/offline_location_queue.dart

import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../utils/constants.dart';
import 'connectivity_service.dart';

final logger = Logger();

class QueuedLocationUpdate {
  final String userId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? speed;
  final DateTime recordedAt;
  final String id;

  QueuedLocationUpdate({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.speed,
    required this.recordedAt,
    required this.id,
  });

  factory QueuedLocationUpdate.fromPosition(Position position, String userId) {
    // Ensure recorded timestamp is not in the future
    final now = DateTime.now();
    var recordedTime = now;
    
    // If position has a timestamp, use it but validate it's not in the future
    if (position.timestamp.isAfter(now.add(const Duration(minutes: 1)))) {
      // If timestamp is more than 1 minute in the future, use current time
      logger.w('⚠️ Position timestamp is in the future, using current time instead');
      recordedTime = now;
    } else {
      recordedTime = position.timestamp;
    }
    
    return QueuedLocationUpdate(
      userId: userId,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      recordedAt: recordedTime,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'location': 'POINT($longitude $latitude)',
      'accuracy': accuracy,
      'speed': speed,
      'recorded_at': recordedAt.toIso8601String(),
      // Remove 'id' field - let database auto-generate UUID
    };
  }

  Map<String, dynamic> toStorageJson() {
    return {
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'recordedAt': recordedAt.toIso8601String(),
      'id': id,
    };
  }

  factory QueuedLocationUpdate.fromStorageJson(Map<String, dynamic> json) {
    return QueuedLocationUpdate(
      userId: json['userId'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      accuracy: json['accuracy'],
      speed: json['speed'],
      recordedAt: DateTime.parse(json['recordedAt']),
      id: json['id'],
    );
  }
}

class OfflineLocationQueue {
  static final OfflineLocationQueue _instance = OfflineLocationQueue._internal();
  factory OfflineLocationQueue() => _instance;
  OfflineLocationQueue._internal();

  static const String _queueKey = 'offline_location_queue';
  static const int _maxQueueSize = 1000; // Maximum stored updates
  static const int _maxRetries = 3;
  static const Duration _syncInterval = Duration(minutes: 2);

  Timer? _syncTimer;
  bool _isSyncing = false;
  List<QueuedLocationUpdate> _queue = [];
  StreamSubscription? _connectivitySubscription;

  /// Initialize the offline queue
  Future<void> initialize() async {
    await _loadQueueFromStorage();
    _startConnectivityMonitoring();
    _startPeriodicSync();
    logger.i('📱 Offline location queue initialized with ${_queue.length} pending updates');
  }

  /// Add a location update to the queue
  Future<void> queueLocationUpdate(Position position, String userId) async {
    try {
      final update = QueuedLocationUpdate.fromPosition(position, userId);
      
      // Try to send immediately if online
      if (ConnectivityService().isOnline) {
        final success = await _sendLocationUpdate(update);
        if (success) {
          logger.d('📤 Location sent immediately (online)');
          return;
        }
      }
      
      // Add to queue if offline or immediate send failed
      _queue.add(update);
      
      // Limit queue size to prevent excessive storage usage
      if (_queue.length > _maxQueueSize) {
        _queue.removeAt(0); // Remove oldest update
        logger.w('⚠️ Queue size limit reached, removed oldest update');
      }
      
      await _saveQueueToStorage();
      logger.d('📱 Location queued for later sync (${_queue.length} pending)');
      
    } catch (e) {
      logger.e('❌ Error queuing location update: $e');
    }
  }

  /// Force sync all queued updates
  Future<int> syncQueuedUpdates() async {
    if (_isSyncing || _queue.isEmpty) {
      return 0;
    }

    if (!ConnectivityService().isOnline) {
      logger.d('📴 Cannot sync: device is offline');
      return 0;
    }

    _isSyncing = true;
    int successCount = 0;
    List<QueuedLocationUpdate> failedUpdates = [];

    logger.i('🔄 Syncing ${_queue.length} queued location updates...');

    try {
      // Process updates in batches of 10
      const batchSize = 10;
      for (int i = 0; i < _queue.length; i += batchSize) {
        final batch = _queue.skip(i).take(batchSize).toList();
        
        for (final update in batch) {
          final success = await _sendLocationUpdate(update);
          if (success) {
            successCount++;
          } else {
            failedUpdates.add(update);
          }
          
          // Small delay between sends to avoid overwhelming server
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        // Larger delay between batches
        if (i + batchSize < _queue.length) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      // Update queue with only failed updates
      _queue = failedUpdates;
      await _saveQueueToStorage();

      if (successCount > 0) {
        logger.i('✅ Successfully synced $successCount location updates');
      }
      
      if (failedUpdates.isNotEmpty) {
        logger.w('⚠️ ${failedUpdates.length} updates failed to sync, kept in queue');
      }

    } catch (e) {
      logger.e('❌ Error during queue sync: $e');
    } finally {
      _isSyncing = false;
    }

    return successCount;
  }

  /// Get queue statistics
  Map<String, dynamic> getQueueStats() {
    final now = DateTime.now();
    final oldestUpdate = _queue.isNotEmpty 
        ? _queue.reduce((a, b) => a.recordedAt.isBefore(b.recordedAt) ? a : b)
        : null;
    
    return {
      'queueSize': _queue.length,
      'isSyncing': _isSyncing,
      'isOnline': ConnectivityService().isOnline,
      'oldestUpdateAge': oldestUpdate != null 
          ? now.difference(oldestUpdate.recordedAt).inMinutes
          : null,
      'maxQueueSize': _maxQueueSize,
      'syncInterval': _syncInterval.inMinutes,
    };
  }

  /// Clear the queue (for testing or reset purposes)
  Future<void> clearQueue() async {
    _queue.clear();
    await _saveQueueToStorage();
    logger.i('🗑️ Location queue cleared');
  }

  /// Stop the offline queue service
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    logger.i('📱 Offline location queue disposed');
  }

  // Private methods

  Future<void> _loadQueueFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      
      if (queueJson != null) {
        final List<dynamic> queueList = jsonDecode(queueJson);
        _queue = queueList
            .map((item) => QueuedLocationUpdate.fromStorageJson(item))
            .toList();
      }
    } catch (e) {
      logger.e('❌ Error loading queue from storage: $e');
      _queue = [];
    }
  }

  Future<void> _saveQueueToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_queue.map((update) => update.toStorageJson()).toList());
      await prefs.setString(_queueKey, queueJson);
    } catch (e) {
      logger.e('❌ Error saving queue to storage: $e');
    }
  }

  Future<bool> _sendLocationUpdate(QueuedLocationUpdate update) async {
    try {
      // Check if user is still authenticated before sending
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null || currentUser.id != update.userId) {
        logger.d('❌ User not authenticated, skipping location update');
        return false;
      }
      
      // Use server-side timestamp to avoid clock sync issues
      await supabase.rpc('insert_location_update', params: {
        'p_user_id': update.userId,
        'p_location': 'POINT(${update.longitude} ${update.latitude})',
        'p_accuracy': update.accuracy,
        'p_speed': update.speed,
      });
      return true;
    } catch (e) {
      logger.d('❌ Failed to send location update: $e');
      return false;
    }
  }

  void _startConnectivityMonitoring() {
    _connectivitySubscription = ConnectivityService().connectivityStream.listen((isOnline) {
      if (isOnline && _queue.isNotEmpty) {
        logger.i('📶 Network restored, triggering sync of ${_queue.length} queued updates');
        // Delay sync slightly to allow network to stabilize
        Timer(const Duration(seconds: 3), () {
          syncQueuedUpdates();
        });
      }
    });
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      if (_queue.isNotEmpty && ConnectivityService().isOnline) {
        syncQueuedUpdates();
      }
    });
  }
}