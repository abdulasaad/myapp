// lib/services/group_service.dart

import 'package:flutter/foundation.dart';
import '../models/group.dart';
import '../models/app_user.dart';
import '../utils/constants.dart';

class GroupWithMembers {
  final Group group;
  final List<AppUser> members;
  final AppUser? manager;

  GroupWithMembers({
    required this.group,
    required this.members,
    this.manager,
  });

  int get memberCount => members.length;
}

class UserGroupAssignment {
  final String id;
  final String userId;
  final String groupId;
  final DateTime createdAt;

  UserGroupAssignment({
    required this.id,
    required this.userId,
    required this.groupId,
    required this.createdAt,
  });

  factory UserGroupAssignment.fromJson(Map<String, dynamic> json) {
    return UserGroupAssignment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      groupId: json['group_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class GroupService {
  static final GroupService _instance = GroupService._internal();
  factory GroupService() => _instance;
  GroupService._internal();

  // Get all groups with optional filtering by manager
  Future<List<Group>> getGroups({String? managerId}) async {
    try {
      var query = supabase.from('groups').select('*');
      
      if (managerId != null) {
        query = query.eq('manager_id', managerId);
      }
      
      final response = await query.order('created_at', ascending: false);
      
      return response.map((json) => Group.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching groups: $e');
      throw Exception('Failed to fetch groups: $e');
    }
  }

  // Get group with its members and manager details
  Future<GroupWithMembers> getGroupWithMembers(String groupId) async {
    try {
      // Get group details
      final groupResponse = await supabase
          .from('groups')
          .select('*')
          .eq('id', groupId)
          .single();

      debugPrint('Group response: $groupResponse');

      if (groupResponse.isEmpty || groupResponse['id'] == null) {
        throw Exception('Group not found or access denied');
      }

      final group = Group.fromJson(groupResponse);
      
      // Get manager info if manager_id exists
      AppUser? manager;
      if (groupResponse['manager_id'] != null) {
        try {
          final managerResponse = await supabase
              .from('profiles')
              .select('*')
              .eq('id', groupResponse['manager_id'])
              .single();
          manager = AppUser.fromJson(managerResponse);
        } catch (e) {
          debugPrint('Warning: Could not fetch manager details: $e');
          // Continue without manager info
        }
      }

      // Get group members
      final membersResponse = await supabase
          .from('user_groups')
          .select('''
            profiles!user_id(
              id,
              full_name,
              username,
              role,
              status,
              agent_creation_limit,
              created_at
            )
          ''')
          .eq('group_id', groupId);

      debugPrint('Members response: $membersResponse');

      final members = membersResponse
          .where((item) => item['profiles'] != null && item['profiles']['id'] != null)
          .map((item) {
            try {
              return AppUser.fromJson(item['profiles']);
            } catch (e) {
              debugPrint('Error parsing member: ${item['profiles']}, error: $e');
              return null;
            }
          })
          .where((member) => member != null)
          .cast<AppUser>()
          .toList();

      return GroupWithMembers(
        group: group,
        members: members,
        manager: manager,
      );
    } catch (e) {
      debugPrint('Error fetching group with members: $e');
      throw Exception('Failed to fetch group details: $e');
    }
  }

  // Create a new group
  Future<Group> createGroup({
    required String name,
    String? description,
    String? managerId,
    List<String> memberIds = const [],
  }) async {
    try {
      // Create the group
      final groupResponse = await supabase
          .from('groups')
          .insert({
            'name': name,
            'description': description,
            'manager_id': managerId,
          })
          .select()
          .single();

      final group = Group.fromJson(groupResponse);

      // Add members if provided
      if (memberIds.isNotEmpty) {
        await addMembersToGroup(group.id, memberIds);
      }

      return group;
    } catch (e) {
      debugPrint('Error creating group: $e');
      throw Exception('Failed to create group: $e');
    }
  }

  // Update group details
  Future<Group> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? managerId,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (managerId != null) updateData['manager_id'] = managerId;
      updateData['updated_at'] = DateTime.now().toIso8601String();

      final response = await supabase
          .from('groups')
          .update(updateData)
          .eq('id', groupId)
          .select()
          .single();

      return Group.fromJson(response);
    } catch (e) {
      debugPrint('Error updating group: $e');
      throw Exception('Failed to update group: $e');
    }
  }

  // Delete a group
  Future<void> deleteGroup(String groupId) async {
    try {
      // First remove all members from the group
      await supabase
          .from('user_groups')
          .delete()
          .eq('group_id', groupId);

      // Then delete the group
      await supabase
          .from('groups')
          .delete()
          .eq('id', groupId);
    } catch (e) {
      debugPrint('Error deleting group: $e');
      throw Exception('Failed to delete group: $e');
    }
  }

  // Add members to a group
  Future<void> addMembersToGroup(String groupId, List<String> userIds) async {
    try {
      if (userIds.isEmpty) return;

      final assignments = userIds.map((userId) => {
        'user_id': userId,
        'group_id': groupId,
      }).toList();

      await supabase.from('user_groups').insert(assignments);
    } catch (e) {
      debugPrint('Error adding members to group: $e');
      throw Exception('Failed to add members to group: $e');
    }
  }

  // Remove members from a group
  Future<void> removeMembersFromGroup(String groupId, List<String> userIds) async {
    try {
      if (userIds.isEmpty) return;

      for (final userId in userIds) {
        await supabase
            .from('user_groups')
            .delete()
            .eq('group_id', groupId)
            .eq('user_id', userId);
      }
    } catch (e) {
      debugPrint('Error removing members from group: $e');
      throw Exception('Failed to remove members from group: $e');
    }
  }

  // Get all users not in a specific group (for adding new members)
  Future<List<AppUser>> getAvailableUsers(String groupId) async {
    try {
      // For agents, use the special logic (one group only)
      // For other roles, use the original logic
      final availableAgents = await getAvailableAgentsForGroup(groupId);
      
      // Get non-agent users who are not in this group
      final response = await supabase
          .from('profiles')
          .select('*')
          .neq('role', 'agent')
          .not('id', 'in', '(${await _getGroupMemberIds(groupId)})');
      
      final nonAgentUsers = response.map((json) => AppUser.fromJson(json)).toList();
      
      // Combine agents and non-agents
      return [...availableAgents, ...nonAgentUsers];
    } catch (e) {
      debugPrint('Error fetching available users: $e');
      throw Exception('Failed to fetch available users: $e');
    }
  }

  // Get user's groups
  Future<List<Group>> getUserGroups(String userId) async {
    try {
      final response = await supabase
          .from('user_groups')
          .select('''
            groups(
              id,
              name,
              description,
              created_by,
              created_at,
              updated_at
            )
          ''')
          .eq('user_id', userId);

      return response
          .where((item) => item['groups'] != null)
          .map((item) => Group.fromJson(item['groups']))
          .toList();
    } catch (e) {
      debugPrint('Error fetching user groups: $e');
      throw Exception('Failed to fetch user groups: $e');
    }
  }

  // Get all managers for group assignment
  Future<List<AppUser>> getManagers() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('*')
          .eq('role', 'manager')
          .eq('status', 'active')
          .order('full_name');

      return response.map((json) => AppUser.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching managers: $e');
      throw Exception('Failed to fetch managers: $e');
    }
  }

  // Get all agents for group assignment
  Future<List<AppUser>> getAgents() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('*')
          .eq('role', 'agent')
          .order('full_name');

      return response.map((json) => AppUser.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching agents: $e');
      throw Exception('Failed to fetch agents: $e');
    }
  }

  // Get only unassigned agents (not in any group)
  Future<List<AppUser>> getUnassignedAgents() async {
    try {
      // First get all agents
      final allAgents = await supabase
          .from('profiles')
          .select('*')
          .eq('role', 'agent')
          .order('full_name');
      
      // Get all user_group assignments
      final assignedAgentIds = await supabase
          .from('user_groups')
          .select('user_id');
      
      final assignedIds = assignedAgentIds.map((item) => item['user_id'] as String).toSet();
      
      // Filter out assigned agents
      final unassignedAgents = allAgents
          .where((agent) => !assignedIds.contains(agent['id']))
          .map((json) => AppUser.fromJson(json))
          .toList();
      
      return unassignedAgents;
    } catch (e) {
      debugPrint('Error fetching unassigned agents: $e');
      throw Exception('Failed to fetch unassigned agents: $e');
    }
  }

  // Get agents available for a specific group (unassigned + already in this group)
  Future<List<AppUser>> getAvailableAgentsForGroup(String? groupId) async {
    try {
      // First get all agents
      final allAgents = await supabase
          .from('profiles')
          .select('*')
          .eq('role', 'agent')
          .order('full_name');
      
      if (groupId == null) {
        // For new groups, return only unassigned agents
        return getUnassignedAgents();
      }
      
      // Get all user_group assignments
      final assignedAgentIds = await supabase
          .from('user_groups')
          .select('user_id, group_id');
      
      // Filter agents: only those not assigned OR assigned to this specific group
      final availableAgents = allAgents.where((agent) {
        final agentId = agent['id'] as String;
        final assignments = assignedAgentIds.where((a) => a['user_id'] == agentId);
        
        // Agent is available if:
        // 1. Not assigned to any group, OR
        // 2. Only assigned to the current group
        return assignments.isEmpty || 
               (assignments.length == 1 && assignments.first['group_id'] == groupId);
      }).map((json) => AppUser.fromJson(json)).toList();
      
      return availableAgents;
    } catch (e) {
      debugPrint('Error fetching available agents for group: $e');
      throw Exception('Failed to fetch available agents: $e');
    }
  }

  // Get members (agents and managers) available for a specific group
  Future<List<AppUser>> getAvailableMembersForGroup(String? groupId) async {
    try {
      // Get all agents and managers
      final allMembers = await supabase
          .from('profiles')
          .select('*')
          .or('role.eq.agent,role.eq.manager')
          .order('role,full_name');
      
      if (groupId == null) {
        // For new groups, return only unassigned members
        final assignedUserIds = await supabase
            .from('user_groups')
            .select('user_id');
        
        final assignedIds = assignedUserIds.map((item) => item['user_id'] as String).toSet();
        
        return allMembers
            .where((member) => !assignedIds.contains(member['id']))
            .map((json) => AppUser.fromJson(json))
            .toList();
      }
      
      // Get all user_group assignments
      final assignments = await supabase
          .from('user_groups')
          .select('user_id, group_id');
      
      // Filter members: only those not assigned OR assigned to this specific group
      final availableMembers = allMembers.where((member) {
        final memberId = member['id'] as String;
        final userAssignments = assignments.where((a) => a['user_id'] == memberId);
        
        // Member is available if:
        // 1. Not assigned to any group, OR
        // 2. Only assigned to the current group
        return userAssignments.isEmpty || 
               (userAssignments.length == 1 && userAssignments.first['group_id'] == groupId);
      }).map((json) => AppUser.fromJson(json)).toList();
      
      return availableMembers;
    } catch (e) {
      debugPrint('Error fetching available members for group: $e');
      throw Exception('Failed to fetch available members: $e');
    }
  }

  // Helper method to get member IDs of a group
  Future<String> _getGroupMemberIds(String groupId) async {
    final response = await supabase
        .from('user_groups')
        .select('user_id')
        .eq('group_id', groupId);
    
    final userIds = response.map((item) => "'${item['user_id']}'").join(',');
    return userIds.isEmpty ? "''" : userIds;
  }

  // Get group statistics
  Future<Map<String, int>> getGroupStatistics() async {
    try {
      final groupsResponse = await supabase
          .from('groups')
          .select('id');

      final membershipsResponse = await supabase
          .from('user_groups')
          .select('id');

      return {
        'totalGroups': groupsResponse.length,
        'totalMemberships': membershipsResponse.length,
      };
    } catch (e) {
      debugPrint('Error fetching group statistics: $e');
      return {'totalGroups': 0, 'totalMemberships': 0};
    }
  }
}