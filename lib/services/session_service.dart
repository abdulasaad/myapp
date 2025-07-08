// lib/services/session_service.dart
//
// Improved Session Management:
// - Prevents multiple simultaneous logins per user
// - Shows user-friendly dialog when login conflict occurs
// - Reduces aggressive validation to prevent network-related logouts
// - Validates every 5 minutes instead of 30 seconds
// - Handles network errors gracefully without forcing logout

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';
import 'notification_service.dart';

final logger = Logger();

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  static const String _sessionIdKey = 'current_session_id';
  Timer? _validationTimer;
  Timer? _frequentValidationTimer;
  
  // Callback for when session becomes invalid
  Function()? _onSessionInvalid;

  /// Store session ID locally after successful login
  Future<void> storeSessionId(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionIdKey, sessionId);
      logger.d('Session ID stored locally: $sessionId');
    } catch (e) {
      logger.e('Failed to store session ID: $e');
    }
  }

  /// Get locally stored session ID
  Future<String?> getStoredSessionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_sessionIdKey);
    } catch (e) {
      logger.e('Failed to get stored session ID: $e');
      return null;
    }
  }

  /// Clear locally stored session ID
  Future<void> clearStoredSessionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionIdKey);
      logger.d('Session ID cleared locally');
    } catch (e) {
      logger.e('Failed to clear session ID: $e');
    }
  }

  /// Validate if the current session is still active in database
  Future<bool> isSessionValid() async {
    final sessionId = await getStoredSessionId();
    if (sessionId == null) {
      logger.w('No stored session ID found');
      return false;
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      logger.w('No authenticated user found');
      return false;
    }

    try {
      // Check if session exists and is active in database
      final response = await supabase
          .from('sessions')
          .select('is_active')
          .eq('id', sessionId)
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      final isValid = response != null;
      logger.d('Session validation result: $isValid for session $sessionId');
      return isValid;
    } catch (e) {
      // Check if this is a network error - if so, throw the exception so calling methods can handle it
      if (e.toString().contains('AuthRetryableFetchException') ||
          e.toString().contains('ClientException') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname') ||
          e.toString().contains('Network is unreachable') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Connection timed out')) {
        logger.w('Network error during session validation - rethrowing: $e');
        rethrow; // Let calling methods handle network errors
      } else {
        // Non-network error - treat as invalid session
        logger.e('Session validation failed with non-network error: $e');
        return false;
      }
    }
  }

  /// Invalidate current session in database
  Future<void> invalidateCurrentSession() async {
    try {
      final sessionId = await getStoredSessionId();
      if (sessionId == null) {
        logger.w('No session ID to invalidate');
        return;
      }

      await supabase
          .from('sessions')
          .update({'is_active': false})
          .eq('id', sessionId);

      logger.d('Session invalidated in database: $sessionId');
      await clearStoredSessionId();
    } catch (e) {
      logger.e('Failed to invalidate session: $e');
    }
  }

  /// Set callback for when session becomes invalid
  void setSessionInvalidCallback(Function() callback) {
    _onSessionInvalid = callback;
  }

  /// Trigger an immediate validation check (useful for testing or manual checks)
  Future<void> checkSessionNow() async {
    await validateSessionImmediately();
  }

  /// Validate session immediately and handle invalid session
  Future<void> validateSessionImmediately() async {
    try {
      final isValid = await isSessionValid();
      if (!isValid) {
        logger.w('Immediate validation: Session became invalid - logged in from another device');
        await forceLogout();
        _onSessionInvalid?.call();
      } else {
        logger.d('Immediate validation: Session is still valid');
      }
    } catch (e) {
      logger.i('Immediate session validation caught exception: ${e.runtimeType}: $e');
      
      // More specific type checking for network errors
      bool isNetworkError = false;
      
      if (e.toString().contains('AuthRetryableFetchException') ||
          e.toString().contains('ClientException') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname') ||
          e.toString().contains('Network is unreachable') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Connection timed out')) {
        isNetworkError = true;
      }
      
      if (isNetworkError) {
        // Network issue - don't logout
        logger.w('🌐 Immediate session validation failed due to network issue - keeping session active: $e');
      } else {
        // Possible real auth issue - be more cautious during immediate validation
        logger.w('🔒 Immediate session validation failed - possible auth issue: $e');
        // Could add additional checks here if needed
      }
    }
  }

  /// Start periodic session validation with smart error handling
  void startPeriodicValidation({Duration interval = const Duration(seconds: 60)}) {
    _validationTimer?.cancel();
    _frequentValidationTimer?.cancel();
    
    // Start frequent validation for first 3 minutes to catch conflicts quickly
    _frequentValidationTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      await _performValidationCheck();
    });
    
    // Stop frequent validation after 3 minutes and switch to normal interval
    Timer(const Duration(minutes: 3), () {
      _frequentValidationTimer?.cancel();
      _frequentValidationTimer = null;
      logger.d('Switched from frequent to normal session validation');
    });
    
    // Start normal validation
    _validationTimer = Timer.periodic(interval, (timer) async {
      await _performValidationCheck();
    });
    
    logger.d('Started session validation: 15s for 3min, then ${interval.inSeconds}s');
  }

  /// Perform the actual validation check with error handling
  Future<void> _performValidationCheck() async {
    try {
      final isValid = await isSessionValid();
      if (!isValid) {
        logger.w('Session became invalid - logged in from another device');
        await forceLogout();
        _onSessionInvalid?.call();
      }
    } catch (e) {
      logger.i('Session validation caught exception: ${e.runtimeType}: $e');
      
      // More specific type checking for network errors
      bool isNetworkError = false;
      
      if (e.toString().contains('AuthRetryableFetchException') ||
          e.toString().contains('ClientException') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname') ||
          e.toString().contains('Network is unreachable') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Connection timed out')) {
        isNetworkError = true;
      }
      
      if (isNetworkError) {
        // Network issue - don't logout, just log
        logger.w('🌐 Session validation failed due to network issue - keeping session active: $e');
      } else {
        // Likely a real session/auth issue - logout
        logger.w('🔒 Session validation failed - possible auth issue - logging out: $e');
        await forceLogout();
        _onSessionInvalid?.call();
      }
    }
  }

  /// Stop periodic session validation
  void stopPeriodicValidation() {
    _validationTimer?.cancel();
    _validationTimer = null;
    _frequentValidationTimer?.cancel();
    _frequentValidationTimer = null;
    logger.d('Stopped periodic session validation');
  }

  /// Force logout when session becomes invalid (silent logout without navigation)
  Future<void> forceLogout() async {
    try {
      stopPeriodicValidation();
      await clearStoredSessionId();
      
      // Clear FCM token to prevent cross-user notifications
      try {
        await NotificationService().clearFCMToken();
      } catch (e) {
        logger.w('Failed to clear FCM token during force logout: $e');
      }
      
      await supabase.auth.signOut();
      logger.i('Forced logout completed');
    } catch (e) {
      // Check if this is a network error during logout
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('network') || 
          errorString.contains('timeout') || 
          errorString.contains('connection') ||
          errorString.contains('offline') ||
          errorString.contains('failed host lookup') ||
          errorString.contains('no address associated with hostname') ||
          errorString.contains('socketexception') ||
          errorString.contains('clientexception') ||
          errorString.contains('authretryablefetchexception')) {
        // Network issue during logout - local cleanup is enough
        logger.w('Network error during logout - local cleanup completed: $e');
      } else {
        logger.e('Failed during forced logout: $e');
      }
    }
  }

  /// Check if user has any active sessions
  Future<bool> hasActiveSession(String userId) async {
    try {
      final response = await supabase
          .from('sessions')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      final hasActive = response != null;
      logger.d('User $userId has active session: $hasActive');
      return hasActive;
    } catch (e) {
      logger.e('Failed to check active sessions: $e');
      return false;
    }
  }

  /// Invalidate all active sessions for a specific user
  Future<void> invalidateAllUserSessions(String userId) async {
    try {
      await supabase
          .from('sessions')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('is_active', true);

      logger.d('Invalidated all sessions for user: $userId');
    } catch (e) {
      logger.e('Failed to invalidate user sessions: $e');
      rethrow;
    }
  }

  /// Create a new session for user
  Future<String> createNewSession(String userId) async {
    try {
      final sessionId = const Uuid().v4();
      await supabase.from('sessions').insert({
        'id': sessionId,
        'user_id': userId,
        'is_active': true,
      });

      await storeSessionId(sessionId);
      logger.d('Created new session: $sessionId for user: $userId');
      return sessionId;
    } catch (e) {
      logger.e('Failed to create new session: $e');
      rethrow;
    }
  }

  /// Complete logout process (invalidate database session + Supabase auth)
  Future<void> logout() async {
    try {
      stopPeriodicValidation();
      _frequentValidationTimer?.cancel();
      _frequentValidationTimer = null;
      await invalidateCurrentSession();
      
      // Clear FCM token to prevent cross-user notifications
      try {
        await NotificationService().clearFCMToken();
      } catch (e) {
        logger.w('Failed to clear FCM token during logout: $e');
      }
      
      await supabase.auth.signOut();
      logger.i('Complete logout successful');
    } catch (e) {
      logger.e('Logout failed: $e');
      rethrow;
    }
  }
}