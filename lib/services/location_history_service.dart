// lib/services/location_history_service.dart

import 'package:logger/logger.dart';
import '../models/location_history.dart';
import '../utils/constants.dart';

class LocationHistoryService {
  static final LocationHistoryService _instance = LocationHistoryService._();
  static LocationHistoryService get instance => _instance;
  LocationHistoryService._();

  final Logger _logger = Logger();

  /// Fetches agents that can be tracked by the current user (group-filtered for managers)
  Future<List<AgentInfo>> getAllAgents() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      // Get current user's role
      final userRoleResponse = await supabase
          .from('profiles')
          .select('role')
          .eq('id', currentUser.id)
          .single();
      
      final userRole = userRoleResponse['role'] as String;

      if (userRole == 'admin') {
        // Admins can see all agents and managers
        final response = await supabase
            .from('profiles')
            .select('id, full_name, role')
            .inFilter('role', ['agent', 'manager'])
            .order('full_name');

        return response
            .map<AgentInfo>((json) => AgentInfo.fromJson(json))
            .toList();
      } else if (userRole == 'manager') {
        // Managers can only see agents in their shared groups
        
        // Get current manager's groups
        final userGroupsResponse = await supabase
            .from('user_groups')
            .select('group_id')
            .eq('user_id', currentUser.id);
        
        final userGroupIds = userGroupsResponse
            .map((item) => item['group_id'] as String)
            .toList();
        
        _logger.i('Manager ${currentUser.id} has access to groups: $userGroupIds');
        
        if (userGroupIds.isEmpty) {
          _logger.w('Manager has no group assignments');
          return [];
        }

        // Get all users in the same groups (including other managers)
        final groupMembersResponse = await supabase
            .from('user_groups')
            .select('user_id')
            .inFilter('group_id', userGroupIds);
        
        final memberIds = groupMembersResponse
            .map((item) => item['user_id'] as String)
            .toSet()
            .toList();
        
        if (memberIds.isEmpty) {
          return [];
        }

        // Get profiles for these group members
        final response = await supabase
            .from('profiles')
            .select('id, full_name, role')
            .inFilter('id', memberIds)
            .inFilter('role', ['agent', 'manager'])
            .order('full_name');

        final result = response
            .map<AgentInfo>((json) => AgentInfo.fromJson(json))
            .toList();
        
        _logger.i('Manager can view location history for ${result.length} users in their groups');
        return result;
      } else {
        // Regular agents can't access location history of others
        _logger.w('Agent role attempting to access location history');
        return [];
      }
    } catch (e) {
      _logger.e('Failed to fetch agents: $e');
      throw Exception('Failed to load agents: $e');
    }
  }

  /// Fetches location history for a specific agent within a date range
  Future<List<LocationHistoryEntry>> getAgentLocationHistory({
    required String agentId,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 1000,
  }) async {
    try {
      // Use the RPC function to get location history with converted coordinates
      final adjustedStartDate = DateTime(startDate.year, startDate.month, startDate.day);
      final adjustedEndDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      final response = await supabase.rpc('get_agent_location_history', params: {
        'p_agent_id': agentId,
        'p_start_date': adjustedStartDate.toIso8601String(),
        'p_end_date': adjustedEndDate.toIso8601String(),
        'p_limit': limit,
      });

      return response
          .map<LocationHistoryEntry>((json) => LocationHistoryEntry.fromRpcResult(json))
          .toList();
    } catch (e) {
      _logger.e('Failed to fetch location history for agent $agentId: $e');
      
      // Fallback: try direct table access with recorded_at column
      try {
        _logger.i('Trying fallback method...');
        final adjustedStartDate = DateTime(startDate.year, startDate.month, startDate.day);
        final adjustedEndDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

        final response = await supabase
            .from('location_history')
            .select('*')
            .eq('user_id', agentId)
            .gte('recorded_at', adjustedStartDate.toIso8601String())
            .lte('recorded_at', adjustedEndDate.toIso8601String())
            .order('recorded_at', ascending: false)
            .limit(limit);

        return response
            .map<LocationHistoryEntry>((json) => LocationHistoryEntry.fromJson(json))
            .toList();
      } catch (fallbackError) {
        _logger.e('Fallback also failed: $fallbackError');
        throw Exception('Failed to load location history: $e');
      }
    }
  }

  /// Gets location statistics for an agent within a date range
  Future<Map<String, dynamic>> getLocationStatistics({
    required String agentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Just get recent records for statistics, don't filter by date for now
      final response = await supabase
          .from('location_history')
          .select('*')
          .eq('user_id', agentId)
          .limit(1000);

      if (response.isEmpty) {
        return {
          'totalEntries': 0,
          'averageAccuracy': 0.0,
          'averageSpeed': 0.0,
          'firstEntry': null,
          'lastEntry': null,
        };
      }

      final totalEntries = response.length;
      final accuracies = response
          .map<double>((r) => (r['accuracy'] ?? 0.0).toDouble())
          .toList();
      final speeds = response
          .where((r) => r['speed'] != null)
          .map<double>((r) => r['speed'].toDouble())
          .toList();

      final averageAccuracy = accuracies.isNotEmpty
          ? accuracies.reduce((a, b) => a + b) / accuracies.length
          : 0.0;

      final averageSpeed = speeds.isNotEmpty
          ? speeds.reduce((a, b) => a + b) / speeds.length
          : 0.0;

      // Try to extract timestamps from any available timestamp column
      final timestamps = <DateTime>[];
      for (final record in response) {
        try {
          if (record['recorded_at'] != null) {
            timestamps.add(DateTime.parse(record['recorded_at']));
          } else if (record['created_at'] != null) {
            timestamps.add(DateTime.parse(record['created_at']));
          } else if (record['inserted_at'] != null) {
            timestamps.add(DateTime.parse(record['inserted_at']));
          }
        } catch (e) {
          // Skip invalid timestamps
        }
      }
      timestamps.sort();

      return {
        'totalEntries': totalEntries,
        'averageAccuracy': averageAccuracy,
        'averageSpeed': averageSpeed * 3.6, // Convert m/s to km/h
        'firstEntry': timestamps.isNotEmpty ? timestamps.first : null,
        'lastEntry': timestamps.isNotEmpty ? timestamps.last : null,
      };
    } catch (e) {
      _logger.e('Failed to fetch location statistics for agent $agentId: $e');
      throw Exception('Failed to load location statistics: $e');
    }
  }

  /// Gets hourly location summaries for an agent within a date range
  Future<List<HourlyLocationSummary>> getAgentLocationHistoryHourly({
    required String agentId,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 1000,
  }) async {
    try {
      // Get all location history for the period
      final locations = await getAgentLocationHistory(
        agentId: agentId,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );

      // Group by hour and return summaries
      return HourlyLocationSummary.groupLocationsByHour(locations);
    } catch (e) {
      _logger.e('Failed to fetch hourly location history for agent $agentId: $e');
      throw Exception('Failed to load hourly location history: $e');
    }
  }

  /// Gets the most recent location for an agent
  Future<LocationHistoryEntry?> getLastKnownLocation(String agentId) async {
    try {
      final response = await supabase
          .from('location_history')
          .select('*')
          .eq('user_id', agentId)
          .order('recorded_at', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;

      return LocationHistoryEntry.fromJson(response.first);
    } catch (e) {
      _logger.e('Failed to fetch last known location for agent $agentId: $e');
      return null;
    }
  }
}
