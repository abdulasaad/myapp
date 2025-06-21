// lib/services/profile_service.dart

import 'package:logger/logger.dart';
import '../utils/constants.dart';

// A simple data class for our profile
class UserProfile {
  final String id;
  final String fullName;
  final String role;
  String status; // Make status mutable

  UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.status,
  });
}

// This is a singleton service for managing the user's profile state
class ProfileService {
  ProfileService._();
  static final instance = ProfileService._();
  UserProfile? _currentUser;

  // Getters for easy access
  String? get role => _currentUser?.role;
  String? get status => _currentUser?.status;
  UserProfile? get currentUser => _currentUser;

  bool get canManageCampaigns {
    return _currentUser?.role == 'admin' || _currentUser?.role == 'manager';
  }

  // Fetches the profile from Supabase and stores it locally
  Future<void> loadProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await supabase
          .from('profiles')
          .select('id, full_name, role, status') // <-- Fetch status
          .eq('id', userId)
          .single();

      _currentUser = UserProfile(
        id: response['id'],
        fullName: response['full_name'],
        role: response['role'],
        status: response['status'], // <-- Store status
      );
    } catch (e) {
      final logger = Logger();
      logger.e('Error loading profile', error: e);
      _currentUser = null;
    }
  }

  /// NEW: Updates the current user's status in the database.
  Future<void> updateUserStatus(String newStatus) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase
          .from('profiles')
          .update({'status': newStatus})
          .eq('id', userId);

      // Update the local profile object as well
      _currentUser?.status = newStatus;
    } catch (e) {
      final logger = Logger();
      logger.e('Error updating user status', error: e);
    }
  }

  // Clears the profile on logout
  void clearProfile() {
    _currentUser = null;
  }
}
