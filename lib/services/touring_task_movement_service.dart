// lib/services/touring_task_movement_service.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/touring_task.dart';
import '../models/touring_task_session.dart';
import '../services/touring_task_service.dart';
import '../services/location_service.dart';

class TouringTaskMovementService extends ChangeNotifier {
  final TouringTaskService _touringTaskService = TouringTaskService();
  final LocationService _locationService = LocationService();

  // Current session state
  TouringTask? _currentTask;
  TouringTaskSession? _currentSession;
  Timer? _sessionTimer;
  Timer? _locationTimer;
  Timer? _movementCheckTimer;

  // Movement tracking
  Position? _lastPosition;
  DateTime? _lastMovementTime;
  bool _isMoving = false;
  bool _isInGeofence = false;
  bool _isTimerRunning = false;
  bool _isSessionActive = false;

  // Getters
  TouringTask? get currentTask => _currentTask;
  TouringTaskSession? get currentSession => _currentSession;
  bool get isMoving => _isMoving;
  bool get isInGeofence => _isInGeofence;
  bool get isTimerRunning => _isTimerRunning;
  bool get isSessionActive => _isSessionActive;

  // Current elapsed time in seconds
  int _elapsedSeconds = 0;
  int get elapsedSeconds => _elapsedSeconds;

  // Formatted elapsed time
  String get formattedElapsedTime {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  // Progress percentage (0.0 to 1.0)
  double get progressPercentage {
    if (_currentTask == null) return 0.0;
    final requiredSeconds = _currentTask!.requiredTimeMinutes * 60;
    return math.min(_elapsedSeconds / requiredSeconds, 1.0);
  }

  // Remaining time in seconds
  int get remainingSeconds {
    if (_currentTask == null) return 0;
    final requiredSeconds = _currentTask!.requiredTimeMinutes * 60;
    return math.max(requiredSeconds - _elapsedSeconds, 0);
  }

  bool get isCompleted => remainingSeconds <= 0;

  // Start a touring task session
  Future<bool> startTouringTaskSession(TouringTask task, String agentId) async {
    try {
      // Check if there's already an active session
      final existingSession = await _touringTaskService.getActiveSession(task.id, agentId);
      
      if (existingSession != null) {
        // Resume existing session
        _currentTask = task;
        _currentSession = existingSession;
        _elapsedSeconds = existingSession.elapsedSeconds;
      } else {
        // Create new session
        _currentTask = task;
        _currentSession = await _touringTaskService.startTouringTaskSession(
          touringTaskId: task.id,
          agentId: agentId,
        );
        _elapsedSeconds = 0;
      }

      _isSessionActive = true;
      await _startLocationTracking();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to start touring task session: $e');
      return false;
    }
  }

  // Stop the current session
  Future<void> stopTouringTaskSession() async {
    if (_currentSession != null) {
      try {
        await _touringTaskService.stopTouringTaskSession(_currentSession!.id);
      } catch (e) {
        debugPrint('Failed to stop session: $e');
      }
    }

    _stopAllTimers();
    _currentTask = null;
    _currentSession = null;
    _elapsedSeconds = 0;
    _isSessionActive = false;
    _isTimerRunning = false;
    _isMoving = false;
    _isInGeofence = false;
    notifyListeners();
  }

  // Start location tracking and movement detection
  Future<void> _startLocationTracking() async {
    if (_currentTask == null) return;

    // Start location updates every 5 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _updateLocation();
    });

    // Start movement check every second
    _movementCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _checkMovementStatus();
    });

    // Start the session timer (updates every second)
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      // CRITICAL: Timer only counts when agent is inside geofence AND moving AND session is active
      if (_isTimerRunning && _isInGeofence && _isMoving && _isSessionActive) {
        _elapsedSeconds++;
        // Debug log every 10 seconds to confirm timer is running
        if (_elapsedSeconds % 10 == 0) {
          debugPrint('⏱️ Timer COUNTING: ${_elapsedSeconds}s elapsed (In geofence: $_isInGeofence, Moving: $_isMoving)');
        }
        notifyListeners();

        // Check if task is completed
        if (isCompleted) {
          await _completeTask();
        } else {
          // Save progress every 10 seconds
          if (_elapsedSeconds % 10 == 0) {
            await _saveProgress();
          }
        }
      }
    });

    // Initial location check
    await _updateLocation();
  }

  // Update current location and check geofence
  Future<void> _updateLocation() async {
    if (_currentTask == null || _currentSession == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Check if agent is in geofence
      final wasInGeofence = _isInGeofence;
      debugPrint('🔍 Checking geofence for coordinates: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');
      debugPrint('🔍 Geofence ID: ${_currentTask!.geofenceId}');
      
      _isInGeofence = await _locationService.isLocationInCampaignGeofence(
        position.latitude,
        position.longitude,
        _currentTask!.geofenceId,
      );
      
      debugPrint('🔍 Geofence check result: $_isInGeofence');
      
      // Debug log when geofence status changes
      if (wasInGeofence != _isInGeofence) {
        if (_isInGeofence) {
          debugPrint('🟢 ENTERED geofence: Lat ${position.latitude.toStringAsFixed(6)}, Lng ${position.longitude.toStringAsFixed(6)}');
        } else {
          debugPrint('🔴 EXITED geofence: Lat ${position.latitude.toStringAsFixed(6)}, Lng ${position.longitude.toStringAsFixed(6)}');
        }
      }

      // Update session with current location
      await _touringTaskService.updateTouringTaskSession(
        sessionId: _currentSession!.id,
        lastLatitude: position.latitude,
        lastLongitude: position.longitude,
      );

      // Check movement
      if (_lastPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        if (distance >= _currentTask!.minMovementThreshold) {
          if (!_isMoving) {
            debugPrint('🚶 MOVEMENT detected: ${distance.toStringAsFixed(2)}m (threshold: ${_currentTask!.minMovementThreshold}m)');
          }
          _lastMovementTime = DateTime.now();
          _isMoving = true;
        }
      } else {
        _lastMovementTime = DateTime.now();
        _isMoving = true;
      }

      _lastPosition = position;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to update location: $e');
    }
  }

  // Check movement status and control timer
  Future<void> _checkMovementStatus() async {
    if (_currentTask == null || _currentSession == null) return;

    final now = DateTime.now();
    
    // Check if agent has been stationary too long
    if (_lastMovementTime != null) {
      final timeSinceMovement = now.difference(_lastMovementTime!);
      final timeoutDuration = Duration(seconds: _currentTask!.movementTimeoutSeconds);

      if (timeSinceMovement > timeoutDuration) {
        if (_isMoving) {
          debugPrint('🚫 MOVEMENT stopped: No movement for ${timeSinceMovement.inSeconds}s (timeout: ${_currentTask!.movementTimeoutSeconds}s)');
        }
        _isMoving = false;
      }
    }

    // Determine if timer should be running - ALL CONDITIONS MUST BE TRUE
    final shouldRun = _isInGeofence && _isMoving && _isSessionActive;
    
    if (_isTimerRunning != shouldRun) {
      _isTimerRunning = shouldRun;
      
      // Update session with pause reason if stopping
      if (!shouldRun) {
        String pauseReason;
        if (!_isInGeofence) {
          pauseReason = 'Outside geofence';
          debugPrint('🚫 Timer STOPPED: Agent left the geofence');
        } else if (!_isMoving) {
          pauseReason = 'Not moving';
          debugPrint('⏸️ Timer PAUSED: Agent stopped moving');
        } else {
          pauseReason = 'Session paused';
          debugPrint('⏸️ Timer PAUSED: Session inactive');
        }

        await _touringTaskService.updateTouringTaskSession(
          sessionId: _currentSession!.id,
          isPaused: true,
          pauseReason: pauseReason,
          lastMovementTime: _lastMovementTime,
        );
      } else {
        // Resume timer
        debugPrint('▶️ Timer STARTED: Agent in geofence and moving');
        await _touringTaskService.updateTouringTaskSession(
          sessionId: _currentSession!.id,
          isPaused: false,
          pauseReason: null,
          lastMovementTime: _lastMovementTime,
        );
      }
      
      notifyListeners();
    }
  }

  // Save current progress to database
  Future<void> _saveProgress() async {
    if (_currentSession == null) return;

    try {
      await _touringTaskService.updateTouringTaskSession(
        sessionId: _currentSession!.id,
        elapsedSeconds: _elapsedSeconds,
        lastMovementTime: _lastMovementTime,
      );
    } catch (e) {
      debugPrint('Failed to save progress: $e');
    }
  }

  // Complete the task
  Future<void> _completeTask() async {
    if (_currentSession == null) return;

    try {
      await _touringTaskService.updateTouringTaskSession(
        sessionId: _currentSession!.id,
        elapsedSeconds: _elapsedSeconds,
        isCompleted: true,
        lastMovementTime: _lastMovementTime,
      );

      _stopAllTimers();
      _isSessionActive = false;
      _isTimerRunning = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to complete task: $e');
    }
  }

  // Stop all timers
  void _stopAllTimers() {
    _sessionTimer?.cancel();
    _locationTimer?.cancel();
    _movementCheckTimer?.cancel();
    _sessionTimer = null;
    _locationTimer = null;
    _movementCheckTimer = null;
  }

  // Get current status text
  String get statusText {
    if (!_isSessionActive) return 'Not Started';
    if (isCompleted) return 'Completed';
    if (!_isInGeofence) return 'Outside Work Zone - Timer Stopped';
    if (!_isMoving) return 'Not Moving - Timer Paused';
    if (_isTimerRunning && _isInGeofence && _isMoving) return 'Active - Timer Running';
    return 'Timer Paused';
  }

  // Get status color
  Color get statusColor {
    if (!_isSessionActive) return const Color(0xFF757575);
    if (isCompleted) return const Color(0xFF4CAF50);
    if (!_isInGeofence) return const Color(0xFFF44336);
    if (!_isMoving) return const Color(0xFFFF9800);
    if (_isTimerRunning) return const Color(0xFF4CAF50);
    return const Color(0xFFFF9800);
  }

  @override
  void dispose() {
    _stopAllTimers();
    super.dispose();
  }
}