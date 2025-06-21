// lib/services/session_service.dart

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../utils/constants.dart';

final logger = Logger();

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  static const String _sessionIdKey = 'current_session_id';
  Timer? _validationTimer;
  
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
    try {
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
      logger.e('Session validation failed: $e');
      return false;
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

  /// Validate session immediately and handle invalid session
  Future<void> validateSessionImmediately() async {
    final isValid = await isSessionValid();
    if (!isValid) {
      logger.w('Immediate session validation failed - handling logout');
      await forceLogout();
      _onSessionInvalid?.call();
    }
  }

  /// Start periodic session validation
  void startPeriodicValidation({Duration interval = const Duration(seconds: 30)}) {
    _validationTimer?.cancel();
    _validationTimer = Timer.periodic(interval, (timer) async {
      final isValid = await isSessionValid();
      if (!isValid) {
        logger.w('Periodic session validation failed - handling logout');
        await forceLogout();
        _onSessionInvalid?.call();
      }
    });
    logger.d('Started periodic session validation every ${interval.inSeconds} seconds');
  }

  /// Stop periodic session validation
  void stopPeriodicValidation() {
    _validationTimer?.cancel();
    _validationTimer = null;
    logger.d('Stopped periodic session validation');
  }

  /// Force logout when session becomes invalid (silent logout without navigation)
  Future<void> forceLogout() async {
    try {
      stopPeriodicValidation();
      await clearStoredSessionId();
      await supabase.auth.signOut();
      logger.i('Forced logout completed');
    } catch (e) {
      logger.e('Failed during forced logout: $e');
    }
  }

  /// Complete logout process (invalidate database session + Supabase auth)
  Future<void> logout() async {
    try {
      stopPeriodicValidation();
      await invalidateCurrentSession();
      await supabase.auth.signOut();
      logger.i('Complete logout successful');
    } catch (e) {
      logger.e('Logout failed: $e');
      rethrow;
    }
  }
}