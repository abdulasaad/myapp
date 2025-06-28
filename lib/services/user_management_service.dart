// lib/services/user_management_service.dart

import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../models/group.dart';
import '../utils/constants.dart';

class UserManagementService {
  static final UserManagementService _instance = UserManagementService._internal();
  factory UserManagementService() => _instance;
  UserManagementService._internal();

  /// Get current user's role for permission checking
  Future<String?> getCurrentUserRole() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;
      
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      
      return response?['role'] as String?;
    } catch (e) {
      debugPrint('Error getting current user role: $e');
      return null;
    }
  }

  /// Get groups that the current user (manager) belongs to
  Future<List<Group>> getCurrentUserGroups() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return [];
      
      final response = await supabase
          .from('user_groups')
          .select('''
            groups!inner(
              id,
              name,
              description,
              manager_id,
              created_at
            )
          ''')
          .eq('user_id', user.id);

      return response
          .map<Group>((item) => Group.fromJson(item['groups']))
          .toList();
    } catch (e) {
      debugPrint('Error fetching current user groups: $e');
      return [];
    }
  }

  /// Get all users with optional filtering and pagination (with group isolation)
  Future<List<AppUser>> getUsers({
    String? searchQuery,
    String? roleFilter,
    String? statusFilter,
    String? groupFilter,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final currentUserRole = await getCurrentUserRole();
      
      // Get all users first, then filter by groups at application level
      var query = supabase
          .from('profiles')
          .select('''
            id,
            full_name,
            username,
            email,
            role,
            status,
            agent_creation_limit,
            default_group_id,
            created_by,
            created_at,
            updated_at
          ''');

      // Apply basic filters
      if (roleFilter != null && roleFilter.isNotEmpty) {
        query = query.eq('role', roleFilter);
      }
      
      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.eq('status', statusFilter);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('full_name.ilike.%$searchQuery%,email.ilike.%$searchQuery%,username.ilike.%$searchQuery%');
      }

      final response = await query.order('created_at', ascending: false);
      List<AppUser> allUsers = response.map<AppUser>((json) => AppUser.fromJson(json)).toList();
      
      // Apply group isolation at application level
      if (currentUserRole == 'manager') {
        allUsers = await _filterUsersBySharedGroups(allUsers);
      }
      // Admins see all users, no filtering needed
      
      // Apply pagination after filtering
      final startIndex = offset;
      final endIndex = (offset + limit).clamp(0, allUsers.length);
      
      if (startIndex >= allUsers.length) {
        return [];
      }
      
      return allUsers.sublist(startIndex, endIndex);
    } catch (e) {
      debugPrint('Error fetching users: $e');
      rethrow;
    }
  }

  /// Filter users to only those in shared groups with current user
  Future<List<AppUser>> _filterUsersBySharedGroups(List<AppUser> users) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return [];
      
      // Get current user's groups
      final userGroupsResponse = await supabase
          .from('user_groups')
          .select('group_id')
          .eq('user_id', user.id);
      
      final userGroupIds = userGroupsResponse
          .map((item) => item['group_id'] as String)
          .toSet();
      
      if (userGroupIds.isEmpty) {
        return []; // Manager not in any groups, can't see anyone
      }
      
      // Get all user-group assignments for users in the list
      final userIds = users.map((u) => u.id).toList();
      final allUserGroupsResponse = await supabase
          .from('user_groups')
          .select('user_id, group_id')
          .inFilter('user_id', userIds);
      
      // Build a map of user -> their group IDs
      final Map<String, Set<String>> userToGroups = {};
      for (final item in allUserGroupsResponse) {
        final userId = item['user_id'] as String;
        final groupId = item['group_id'] as String;
        userToGroups.putIfAbsent(userId, () => <String>{}).add(groupId);
      }
      
      // Filter users who share at least one group with current user
      return users.where((user) {
        // Always include the current user
        if (user.id == supabase.auth.currentUser?.id) return true;
        
        final userGroups = userToGroups[user.id] ?? <String>{};
        return userGroups.any((groupId) => userGroupIds.contains(groupId));
      }).toList();
    } catch (e) {
      debugPrint('Error filtering users by groups: $e');
      return users; // Return all users if filtering fails
    }
  }

  /// Get user count with optional filtering
  Future<int> getUserCount({
    String? searchQuery,
    String? roleFilter,
    String? statusFilter,
    String? groupFilter,
  }) async {
    try {
      var query = supabase
          .from('profiles')
          .select('id');

      // Apply same filters as getUsers
      if (roleFilter != null && roleFilter.isNotEmpty) {
        query = query.eq('role', roleFilter);
      }
      
      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.eq('status', statusFilter);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('full_name.ilike.%$searchQuery%,email.ilike.%$searchQuery%,username.ilike.%$searchQuery%');
      }

      final response = await query;
      return response.length;
    } catch (e) {
      debugPrint('Error getting user count: $e');
      return 0;
    }
  }

  /// Get a single user by ID
  Future<AppUser?> getUserById(String userId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select('''
            id,
            full_name,
            username,
            email,
            role,
            status,
            agent_creation_limit,
            default_group_id,
            created_by,
            created_at,
            updated_at
          ''')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return AppUser.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching user by ID: $e');
      return null;
    }
  }

  /// Create a new user using the Supabase Edge function
  Future<Map<String, dynamic>> createUser({
    required String email,
    required String fullName,
    required String role,
    String? username,
    String? password,
    int? agentCreationLimit,
    List<String>? groupIds,
  }) async {
    try {
      // Validate required fields based on role
      if (role == 'agent' && (username == null || username.isEmpty)) {
        throw Exception('Username is required for agent role');
      }

      // Generate password if not provided
      final userPassword = password ?? _generatePassword();

      // Call the Supabase Edge function
      final response = await supabase.functions.invoke(
        'create-user-admin',
        body: {
          'emailForAuth': email,
          'password': userPassword,
          'fullNameForProfile': fullName,
          'roleForProfile': role,
          if (username != null) 'usernameForProfile': username,
          'emailForProfile': email,
          if (agentCreationLimit != null) 'agentCreationLimit': agentCreationLimit,
        },
      );

      if (response.status != 200 && response.status != 201) {
        throw Exception('Failed to create user: ${response.data}');
      }

      final responseData = response.data as Map<String, dynamic>;
      final userId = responseData['userId'] as String;

      // Assign user to groups if provided
      if (groupIds != null && groupIds.isNotEmpty) {
        await _assignUserToGroups(userId, groupIds);
      }

      return {
        'success': true,
        'userId': userId,
        'password': userPassword,
        'message': responseData['message'] ?? 'User created successfully',
      };
    } catch (e) {
      debugPrint('Error creating user: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Update user profile
  Future<bool> updateUser({
    required String userId,
    String? fullName,
    String? email,
    String? username,
    String? role,
    String? status,
    int? agentCreationLimit,
    List<String>? groupIds,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (fullName != null) updateData['full_name'] = fullName;
      if (email != null) updateData['email'] = email;
      if (username != null) updateData['username'] = username;
      if (role != null) updateData['role'] = role;
      if (status != null) updateData['status'] = status;
      if (agentCreationLimit != null) updateData['agent_creation_limit'] = agentCreationLimit;
      
      updateData['updated_at'] = DateTime.now().toIso8601String();

      await supabase
          .from('profiles')
          .update(updateData)
          .eq('id', userId);

      // Update group assignments if provided
      if (groupIds != null) {
        await _updateUserGroups(userId, groupIds);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating user: $e');
      return false;
    }
  }

  /// Delete user (soft delete by changing status to inactive)
  Future<bool> deleteUser(String userId) async {
    try {
      await supabase
          .from('profiles')
          .update({
            'status': 'offline',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Remove from all groups
      await supabase
          .from('user_groups')
          .delete()
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('Error deleting user: $e');
      return false;
    }
  }

  /// Change user status
  Future<bool> changeUserStatus(String userId, String status) async {
    try {
      await supabase
          .from('profiles')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('Error changing user status: $e');
      return false;
    }
  }

  /// Get user groups
  Future<List<Group>> getUserGroups(String userId) async {
    try {
      final response = await supabase
          .from('user_groups')
          .select('''
            groups!inner(
              id,
              name,
              description,
              manager_id,
              created_at
            )
          ''')
          .eq('user_id', userId);

      return response
          .map<Group>((item) => Group.fromJson(item['groups']))
          .toList();
    } catch (e) {
      debugPrint('Error fetching user groups: $e');
      return [];
    }
  }

  /// Get all available groups (filtered by user role and permissions)
  Future<List<Group>> getAllGroups() async {
    try {
      final userRole = await getCurrentUserRole();
      
      if (userRole == 'admin') {
        // Admins can see all groups
        final response = await supabase
            .from('groups')
            .select('*')
            .order('name');

        return response.map<Group>((json) => Group.fromJson(json)).toList();
      } else if (userRole == 'manager') {
        // Managers can only see groups they belong to
        return await getCurrentUserGroups();
      } else {
        // Agents typically don't manage groups, but return their groups if needed
        return await getCurrentUserGroups();
      }
    } catch (e) {
      debugPrint('Error fetching groups: $e');
      return [];
    }
  }

  /// Get user statistics
  Future<Map<String, int>> getUserStatistics() async {
    try {
      final totalUsers = await supabase
          .from('profiles')
          .select('id');

      final activeUsers = await supabase
          .from('profiles')
          .select('id')
          .eq('status', 'active');

      final adminCount = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'admin');

      final managerCount = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'manager');

      final agentCount = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'agent');

      // Get new users this week
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final newUsersThisWeek = await supabase
          .from('profiles')
          .select('id')
          .gte('created_at', weekAgo.toIso8601String());

      return {
        'totalUsers': totalUsers.length,
        'activeUsers': activeUsers.length,
        'adminCount': adminCount.length,
        'managerCount': managerCount.length,
        'agentCount': agentCount.length,
        'newUsersThisWeek': newUsersThisWeek.length,
      };
    } catch (e) {
      debugPrint('Error fetching user statistics: $e');
      return {
        'totalUsers': 0,
        'activeUsers': 0,
        'adminCount': 0,
        'managerCount': 0,
        'agentCount': 0,
        'newUsersThisWeek': 0,
      };
    }
  }

  /// Private helper methods

  Future<void> _assignUserToGroups(String userId, List<String> groupIds) async {
    try {
      final assignments = groupIds.map((groupId) => {
        'user_id': userId,
        'group_id': groupId,
        'created_at': DateTime.now().toIso8601String(),
      }).toList();

      await supabase.from('user_groups').insert(assignments);
    } catch (e) {
      debugPrint('Error assigning user to groups: $e');
      // Don't throw - user creation should succeed even if group assignment fails
    }
  }

  Future<void> _updateUserGroups(String userId, List<String> groupIds) async {
    try {
      // Remove existing group assignments
      await supabase
          .from('user_groups')
          .delete()
          .eq('user_id', userId);

      // Add new group assignments
      if (groupIds.isNotEmpty) {
        await _assignUserToGroups(userId, groupIds);
      }
    } catch (e) {
      debugPrint('Error updating user groups: $e');
    }
  }

  /// Reset password directly for a user (manager can reset passwords for agents in their groups)
  Future<bool> resetPasswordDirect(String userId, String newPassword) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Not authenticated');
      }

      // Validate the new password
      final passwordValidation = validatePassword(newPassword);
      if (passwordValidation != null) {
        throw Exception('Password validation failed: $passwordValidation');
      }

      // Call the database function to reset the password
      final result = await supabase.rpc('reset_user_password_direct', params: {
        'target_user_id': userId,
        'new_password': newPassword,
      });

      if (result == null) {
        throw Exception('No response from password reset function');
      }

      final response = result as Map<String, dynamic>;
      
      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Unknown error occurred');
      }

      debugPrint('Password reset successful for user: $userId');
      return true;
    } catch (e) {
      debugPrint('Error resetting password: $e');
      rethrow;
    }
  }

  /// Update agent name using secure database function (manager can update names for agents in their groups)
  Future<bool> updateAgentName(String userId, String newFullName) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Not authenticated');
      }

      // Validate the new name
      final nameValidation = validateFullName(newFullName);
      if (nameValidation != null) {
        throw Exception('Name validation failed: $nameValidation');
      }

      // Call the secure database function to update the name
      final result = await supabase.rpc('update_agent_name_secure', params: {
        'target_user_id': userId,
        'new_full_name': newFullName.trim(),
      });

      if (result == null) {
        throw Exception('No response from name update function');
      }

      final response = result as Map<String, dynamic>;
      
      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Unknown error occurred');
      }

      debugPrint('Agent name updated successfully for user: $userId');
      return true;
    } catch (e) {
      debugPrint('Error updating agent name: $e');
      rethrow;
    }
  }

  /// Validate full name
  String? validateFullName(String fullName) {
    final trimmedName = fullName.trim();
    if (trimmedName.isEmpty) {
      return 'Full name is required';
    }
    if (trimmedName.length < 2) {
      return 'Full name must be at least 2 characters long';
    }
    if (trimmedName.length > 100) {
      return 'Full name must be less than 100 characters';
    }
    // Check for valid characters (letters, spaces, hyphens, apostrophes)
    if (!RegExp(r'^[a-zA-Z\s\-\.\,]+$').hasMatch(trimmedName)) {
      return 'Full name can only contain letters, spaces, hyphens, periods, and commas';
    }
    // Check that it contains at least one letter
    if (!RegExp(r'[a-zA-Z]').hasMatch(trimmedName)) {
      return 'Full name must contain at least one letter';
    }
    return null; // Name is valid
  }

  /// Validate password strength
  String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'^(?=.*[a-z])').hasMatch(password)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'^(?=.*[A-Z])').hasMatch(password)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'^(?=.*\d)').hasMatch(password)) {
      return 'Password must contain at least one number';
    }
    if (password.length > 128) {
      return 'Password must be less than 128 characters';
    }
    return null; // Password is valid
  }

  String _generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(12, (index) => chars[(random + index) % chars.length]).join();
  }
}