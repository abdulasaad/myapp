// lib/services/profile_service.dart

import 'package:logger/logger.dart';
import '../utils/constants.dart';

// A simple data class for our profile
class UserProfile {
  final String id;
  final String fullName;
  final String role;

  UserProfile({required this.id, required this.fullName, required this.role});
}

// This is a singleton service for managing the user's profile state
class ProfileService {
  // Private constructor
  ProfileService._();

  // The single, shared instance of the service
  static final instance = ProfileService._();

  UserProfile? _currentUser;

  // Getter to easily access the current user's role
  String? get role => _currentUser?.role;

  // Fetches the profile from Supabase and stores it locally
  Future<void> loadProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response =
          await supabase
              .from('profiles')
              .select('id, full_name, role')
              .eq('id', userId)
              .single(); // .single() is important, it expects exactly one row

      _currentUser = UserProfile(
        id: response['id'],
        fullName: response['full_name'],
        role: response['role'],
      );
    } catch (e) {
      // Handle cases where the profile might not exist yet
      final logger = Logger();
      logger.e('Error loading profile', error: e);
      _currentUser = null;
    }
  }

  // Clears the profile on logout
  void clearProfile() {
    _currentUser = null;
  }
}
