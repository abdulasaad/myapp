// lib/services/campaign_geofence_service.dart

import 'package:flutter/foundation.dart';
import '../models/campaign_geofence.dart';
import '../models/agent_geofence_assignment.dart';
import '../models/agent_location_tracking.dart';
import '../utils/constants.dart';

class CampaignGeofenceService {
  static final CampaignGeofenceService _instance = CampaignGeofenceService._internal();
  factory CampaignGeofenceService() => _instance;
  CampaignGeofenceService._internal();

  /// Get all geofences for a campaign with capacity information
  Future<List<CampaignGeofence>> getAvailableGeofencesForCampaign(String campaignId) async {
    try {
      final response = await supabase
          .rpc('get_available_geofences_for_campaign', params: {
        'p_campaign_id': campaignId,
      });

      debugPrint('📍 Fetched ${response.length} geofences for campaign $campaignId');
      
      return response
          .map<CampaignGeofence>((json) => CampaignGeofence.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching geofences for campaign: $e');
      rethrow;
    }
  }

  /// Create a new geofence for a campaign
  Future<CampaignGeofence> createCampaignGeofence({
    required String campaignId,
    required String name,
    String? description,
    required String areaText,
    required int maxAgents,
    required String color,
  }) async {
    try {
      final response = await supabase
          .rpc('create_campaign_geofence', params: {
            'p_campaign_id': campaignId,
            'p_name': name,
            'p_area_text': areaText,
            'p_max_agents': maxAgents,
            'p_color': color,
            'p_description': description,
            'p_created_by': supabase.auth.currentUser?.id,
          });

      debugPrint('✅ Created geofence: $name for campaign $campaignId');
      return CampaignGeofence.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error creating geofence: $e');
      rethrow;
    }
  }

  /// Update an existing geofence
  Future<CampaignGeofence> updateCampaignGeofence({
    required String geofenceId,
    String? name,
    String? description,
    String? areaText,
    int? maxAgents,
    String? color,
    bool? isActive,
  }) async {
    try {
      final response = await supabase
          .rpc('update_campaign_geofence', params: {
            'p_geofence_id': geofenceId,
            'p_name': name,
            'p_description': description,
            'p_area_text': areaText,
            'p_max_agents': maxAgents,
            'p_color': color,
            'p_is_active': isActive,
          });

      debugPrint('✅ Updated geofence: $geofenceId');
      return CampaignGeofence.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error updating geofence: $e');
      rethrow;
    }
  }

  /// Delete a geofence
  Future<void> deleteCampaignGeofence(String geofenceId) async {
    try {
      await supabase
          .from('campaign_geofences')
          .delete()
          .eq('id', geofenceId);

      debugPrint('✅ Deleted geofence: $geofenceId');
    } catch (e) {
      debugPrint('❌ Error deleting geofence: $e');
      rethrow;
    }
  }

  /// Assign an agent to a geofence
  Future<Map<String, dynamic>> assignAgentToGeofence({
    required String campaignId,
    required String geofenceId,
    required String agentId,
  }) async {
    try {
      final response = await supabase
          .rpc('assign_agent_to_geofence', params: {
        'p_campaign_id': campaignId,
        'p_geofence_id': geofenceId,
        'p_agent_id': agentId,
      });

      debugPrint('📍 Assignment result: $response');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('❌ Error assigning agent to geofence: $e');
      rethrow;
    }
  }

  /// Get agent's current geofence assignment for a campaign
  Future<AgentGeofenceAssignment?> getAgentCurrentAssignment({
    required String campaignId,
    required String agentId,
  }) async {
    try {
      final response = await supabase
          .from('agent_geofence_assignments')
          .select('''
            *,
            campaign_geofences!inner(name)
          ''')
          .eq('campaign_id', campaignId)
          .eq('agent_id', agentId)
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) return null;

      // Add geofence name to the response
      final assignment = Map<String, dynamic>.from(response);
      assignment['geofence_name'] = response['campaign_geofences']['name'];

      return AgentGeofenceAssignment.fromJson(assignment);
    } catch (e) {
      debugPrint('❌ Error getting agent assignment: $e');
      rethrow;
    }
  }

  /// Cancel agent's current assignment
  Future<void> cancelAgentAssignment({
    required String assignmentId,
  }) async {
    try {
      await supabase
          .from('agent_geofence_assignments')
          .update({
            'status': 'cancelled',
            'exit_time': DateTime.now().toIso8601String(),
          })
          .eq('id', assignmentId);

      debugPrint('✅ Cancelled assignment: $assignmentId');
    } catch (e) {
      debugPrint('❌ Error cancelling assignment: $e');
      rethrow;
    }
  }

  /// Get all assignments for a geofence
  Future<List<AgentGeofenceAssignment>> getGeofenceAssignments(String geofenceId) async {
    try {
      final response = await supabase
          .from('agent_geofence_assignments')
          .select('''
            *,
            profiles!inner(full_name)
          ''')
          .eq('geofence_id', geofenceId)
          .eq('status', 'active')
          .order('assigned_at', ascending: false);

      return response.map<AgentGeofenceAssignment>((json) {
        final assignment = Map<String, dynamic>.from(json);
        assignment['agent_name'] = json['profiles']['full_name'];
        return AgentGeofenceAssignment.fromJson(assignment);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting geofence assignments: $e');
      rethrow;
    }
  }

  /// Track agent location within geofence
  Future<void> trackAgentLocation({
    required String agentId,
    required String geofenceId,
    required double latitude,
    required double longitude,
    double? accuracy,
    required bool isInsideGeofence,
  }) async {
    try {
      await supabase
          .rpc('update_agent_geofence_status', params: {
        'p_agent_id': agentId,
        'p_geofence_id': geofenceId,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_is_inside': isInsideGeofence,
      });

      debugPrint('📍 Updated location for agent $agentId: ($latitude, $longitude) - Inside: $isInsideGeofence');
    } catch (e) {
      debugPrint('❌ Error tracking agent location: $e');
      rethrow;
    }
  }

  /// Get agent location history for a geofence
  Future<List<AgentLocationTracking>> getAgentLocationHistory({
    required String agentId,
    required String geofenceId,
    int limit = 50,
  }) async {
    try {
      final response = await supabase
          .from('agent_location_tracking')
          .select('*')
          .eq('agent_id', agentId)
          .eq('geofence_id', geofenceId)
          .order('recorded_at', ascending: false)
          .limit(limit);

      return response
          .map<AgentLocationTracking>((json) => AgentLocationTracking.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting location history: $e');
      rethrow;
    }
  }

  /// Get current agents inside a geofence
  Future<List<AgentLocationTracking>> getCurrentAgentsInGeofence(String geofenceId) async {
    try {
      final response = await supabase
          .from('agent_location_tracking')
          .select('''
            *,
            profiles!inner(full_name)
          ''')
          .eq('geofence_id', geofenceId)
          .eq('is_inside_geofence', true)
          .gte('recorded_at', DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String())
          .order('recorded_at', ascending: false);

      return response.map<AgentLocationTracking>((json) {
        final tracking = Map<String, dynamic>.from(json);
        tracking['agent_name'] = json['profiles']['full_name'];
        return AgentLocationTracking.fromJson(tracking);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting current agents in geofence: $e');
      rethrow;
    }
  }

  /// Get geofence capacity information
  Future<Map<String, dynamic>> getGeofenceCapacity(String geofenceId) async {
    try {
      final response = await supabase
          .rpc('check_geofence_capacity', params: {
        'p_geofence_id': geofenceId,
      });

      if (response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      }
      
      return {
        'current_agents': 0,
        'max_agents': 1,
        'is_full': false,
        'available_spots': 1,
      };
    } catch (e) {
      debugPrint('❌ Error getting geofence capacity: $e');
      rethrow;
    }
  }

  /// Complete agent assignment
  Future<void> completeAgentAssignment(String assignmentId) async {
    try {
      await supabase
          .from('agent_geofence_assignments')
          .update({
            'status': 'completed',
            'exit_time': DateTime.now().toIso8601String(),
          })
          .eq('id', assignmentId);

      debugPrint('✅ Completed assignment: $assignmentId');
    } catch (e) {
      debugPrint('❌ Error completing assignment: $e');
      rethrow;
    }
  }

  /// Check if agent can be assigned to geofence
  Future<bool> canAssignAgentToGeofence(String geofenceId) async {
    try {
      final capacity = await getGeofenceCapacity(geofenceId);
      return !(capacity['is_full'] ?? false);
    } catch (e) {
      debugPrint('❌ Error checking assignment eligibility: $e');
      return false;
    }
  }
}