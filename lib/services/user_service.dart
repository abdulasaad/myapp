// lib/services/user_service.dart

import 'profile_service.dart';

/// Service class for user-related functionality
class UserService {
  /// Checks if the current user can manage campaigns
  /// Returns true if the user has a manager or admin role
  static bool get canManageCampaigns {
    final role = ProfileService.instance.role;
    return role == 'manager' || role == 'admin';
  }
}
