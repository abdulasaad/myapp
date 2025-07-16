// lib/services/touring_task_service.dart

import 'package:flutter/material.dart';
import '../models/touring_task.dart';
import '../models/touring_task_session.dart';
import '../models/campaign_geofence.dart';
import '../utils/constants.dart';

class TouringTaskService {
  // Create a new touring task
  Future<TouringTask> createTouringTask({
    required String campaignId,
    required String geofenceId,
    required String title,
    String? description,
    required int requiredTimeMinutes,
    required int movementTimeoutSeconds,
    required double minMovementThreshold,
    required int points,
    bool? useSchedule,
    String? dailyStartTime,
    String? dailyEndTime,
  }) async {
    final response = await supabase.rpc('create_touring_task', params: {
      'p_campaign_id': campaignId,
      'p_geofence_id': geofenceId,
      'p_title': title,
      'p_description': description,
      'p_required_time_minutes': requiredTimeMinutes,
      'p_movement_timeout_seconds': movementTimeoutSeconds,
      'p_min_movement_threshold': minMovementThreshold,
      'p_points': points,
      'p_use_schedule': useSchedule ?? false,
      'p_daily_start_time': dailyStartTime,
      'p_daily_end_time': dailyEndTime,
    });

    if (response == null) {
      throw Exception('Failed to create touring task');
    }

    return TouringTask.fromJson(response);
  }

  // Get touring tasks for a campaign
  Future<List<TouringTask>> getTouringTasksForCampaign(String campaignId) async {
    final response = await supabase
        .from('touring_tasks')
        .select()
        .eq('campaign_id', campaignId)
        .order('created_at', ascending: false);

    return response.map((json) => TouringTask.fromJson(json)).toList();
  }

  // Get touring task with geofence info
  Future<Map<String, dynamic>> getTouringTaskWithGeofence(String taskId) async {
    final response = await supabase
        .from('touring_tasks')
        .select('''
          *,
          campaign_geofences!touring_tasks_geofence_id_fkey (
            id,
            name,
            area_text,
            color,
            max_agents
          )
        ''')
        .eq('id', taskId)
        .single();

    return {
      'task': TouringTask.fromJson(response),
      'geofence': CampaignGeofence.fromJson(response['campaign_geofences']),
    };
  }

  // Assign agents to touring task
  Future<void> assignAgentsToTouringTask(String taskId, List<String> agentIds) async {
    await supabase.rpc('assign_agents_to_touring_task', params: {
      'p_touring_task_id': taskId,
      'p_agent_ids': agentIds,
    });
  }

  // Get touring task assignments for an agent
  Future<List<Map<String, dynamic>>> getTouringTaskAssignmentsForAgent(String agentId) async {
    print('📊 Fetching assignments for agent: $agentId');
    
    try {
      final response = await supabase
          .from('touring_task_assignments')
          .select('''
            *,
            touring_tasks (
              *,
              campaign_geofences (
                id,
                name,
                area_text,
                color
              )
            )
          ''')
          .eq('agent_id', agentId)
          .eq('status', 'assigned')
          .order('assigned_at', ascending: false);
      
      print('✅ Response received: ${response.length} assignments');
      print('📝 Raw response: $response');
      
      return response.map((json) => {
        'assignment': json,
        'task': TouringTask.fromJson(json['touring_tasks']),
        'geofence': CampaignGeofence.fromJson(json['touring_tasks']['campaign_geofences']),
      }).toList();
    } catch (e) {
      print('❌ Error fetching assignments: $e');
      rethrow;
    }
  }

  // Get touring task assignments for agent filtered by campaign
  Future<List<Map<String, dynamic>>> getTouringTaskAssignmentsForAgentAndCampaign(String agentId, String campaignId) async {
    print('📊 DEBUG: Fetching assignments for agent: $agentId and campaign: $campaignId');
    
    // Let's also check what campaign ID the "tet" task actually has
    final allTasks = await supabase
        .from('touring_tasks')
        .select('id, title, campaign_id, status')
        .filter('status', 'in', '(active,pending)');
    
    print('📊 DEBUG: All touring tasks found:');
    for (final task in allTasks) {
      print('   📋 Task: ${task['title']} (Campaign: ${task['campaign_id']}, Status: ${task['status']})');
    }
    
    try {
      // TEMPORARY: Let's try getting touring tasks directly for this campaign and create mock assignments
      // This will help us test if the issue is missing tasks or missing assignments
      final tasksResponse = await supabase
          .from('touring_tasks')
          .select('''
            *,
            campaign_geofences (
              id,
              name,
              area_text,
              color
            )
          ''')
          .eq('campaign_id', campaignId)
          .filter('status', 'in', '(active,pending)');
      
      print('📊 DEBUG: Found ${tasksResponse.length} touring tasks for campaign');
      
      if (tasksResponse.isEmpty) {
        print('❌ DEBUG: No touring tasks found for campaign $campaignId');
        return [];
      }
      
      // Convert tasks to mock assignments for testing
      final mockAssignments = tasksResponse.map((taskJson) => {
        'assignment': {
          'id': 'mock-assignment',
          'agent_id': agentId,
          'touring_task_id': taskJson['id'],
          'status': 'assigned',
          'assigned_at': DateTime.now().toIso8601String(),
        },
        'task': TouringTask.fromJson(taskJson),
        'geofence': CampaignGeofence.fromJson(taskJson['campaign_geofences']),
      }).toList();
      
      print('✅ DEBUG: Created ${mockAssignments.length} mock assignments for testing');
      return mockAssignments;
      
    } catch (e) {
      print('❌ DEBUG: Error in campaign assignments: $e');
      rethrow;
    }
  }

  // Start a touring task session
  Future<TouringTaskSession> startTouringTaskSession({
    required String touringTaskId,
    required String agentId,
  }) async {
    // First check if there's already an active session
    final existingSessions = await supabase
        .from('touring_task_sessions')
        .select()
        .eq('touring_task_id', touringTaskId)
        .eq('agent_id', agentId)
        .eq('is_active', true);

    if (existingSessions.isNotEmpty) {
      return TouringTaskSession.fromJson(existingSessions.first);
    }

    // Create new session
    final response = await supabase
        .from('touring_task_sessions')
        .insert({
          'touring_task_id': touringTaskId,
          'agent_id': agentId,
          'is_active': true,
          'is_paused': false,
          'is_completed': false,
        })
        .select()
        .single();

    // Update assignment status
    await supabase
        .from('touring_task_assignments')
        .update({
          'status': 'in_progress',
          'started_at': DateTime.now().toIso8601String(),
        })
        .eq('touring_task_id', touringTaskId)
        .eq('agent_id', agentId);

    return TouringTaskSession.fromJson(response);
  }

  // Update touring task session
  Future<TouringTaskSession> updateTouringTaskSession({
    required String sessionId,
    int? elapsedSeconds,
    bool? isPaused,
    bool? isCompleted,
    DateTime? lastMovementTime,
    double? lastLatitude,
    double? lastLongitude,
    String? pauseReason,
  }) async {
    final updateData = <String, dynamic>{
      'last_location_update': DateTime.now().toIso8601String(),
    };

    if (elapsedSeconds != null) updateData['elapsed_seconds'] = elapsedSeconds;
    if (isPaused != null) updateData['is_paused'] = isPaused;
    if (isCompleted != null) {
      updateData['is_completed'] = isCompleted;
      if (isCompleted) {
        updateData['is_active'] = false;
        updateData['end_time'] = DateTime.now().toIso8601String();
      }
    }
    if (lastMovementTime != null) updateData['last_movement_time'] = lastMovementTime.toIso8601String();
    if (lastLatitude != null) updateData['last_latitude'] = lastLatitude;
    if (lastLongitude != null) updateData['last_longitude'] = lastLongitude;
    if (pauseReason != null) updateData['pause_reason'] = pauseReason;

    final response = await supabase
        .from('touring_task_sessions')
        .update(updateData)
        .eq('id', sessionId)
        .select()
        .single();

    // If completed, update assignment status
    if (isCompleted == true) {
      final session = TouringTaskSession.fromJson(response);
      await supabase
          .from('touring_task_assignments')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('touring_task_id', session.touringTaskId)
          .eq('agent_id', session.agentId);
    }

    return TouringTaskSession.fromJson(response);
  }

  // Get active session for agent and task
  Future<TouringTaskSession?> getActiveSession(String touringTaskId, String agentId) async {
    final response = await supabase
        .from('touring_task_sessions')
        .select()
        .eq('touring_task_id', touringTaskId)
        .eq('agent_id', agentId)
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) return null;
    return TouringTaskSession.fromJson(response);
  }

  // Stop touring task session
  Future<void> stopTouringTaskSession(String sessionId) async {
    await supabase
        .from('touring_task_sessions')
        .update({
          'is_active': false,
          'end_time': DateTime.now().toIso8601String(),
        })
        .eq('id', sessionId);
  }

  // Delete touring task
  Future<void> deleteTouringTask(String taskId) async {
    await supabase
        .from('touring_tasks')
        .delete()
        .eq('id', taskId);
  }

  // Update touring task
  Future<TouringTask> updateTouringTask({
    required String taskId,
    String? title,
    String? description,
    int? requiredTimeMinutes,
    int? movementTimeoutSeconds,
    double? minMovementThreshold,
    int? points,
    String? status,
    bool? useSchedule,
    String? dailyStartTime,
    String? dailyEndTime,
  }) async {
    final updateData = <String, dynamic>{};
    
    if (title != null) updateData['title'] = title;
    if (description != null) updateData['description'] = description;
    if (requiredTimeMinutes != null) updateData['required_time_minutes'] = requiredTimeMinutes;
    if (movementTimeoutSeconds != null) updateData['movement_timeout_seconds'] = movementTimeoutSeconds;
    if (minMovementThreshold != null) updateData['min_movement_threshold'] = minMovementThreshold;
    if (points != null) updateData['points'] = points;
    if (status != null) updateData['status'] = status;
    if (useSchedule != null) updateData['use_schedule'] = useSchedule;
    if (dailyStartTime != null) updateData['daily_start_time'] = dailyStartTime;
    if (dailyEndTime != null) updateData['daily_end_time'] = dailyEndTime;

    final response = await supabase
        .from('touring_tasks')
        .update(updateData)
        .eq('id', taskId)
        .select()
        .single();

    return TouringTask.fromJson(response);
  }

  // Get session statistics
  Future<Map<String, dynamic>> getSessionStatistics(String sessionId) async {
    final session = await supabase
        .from('touring_task_sessions')
        .select()
        .eq('id', sessionId)
        .single();

    final sessionData = TouringTaskSession.fromJson(session);
    final totalDuration = sessionData.endTime != null 
        ? sessionData.endTime!.difference(sessionData.startTime)
        : DateTime.now().difference(sessionData.startTime);

    return {
      'session': sessionData,
      'total_duration_seconds': totalDuration.inSeconds,
      'active_time_seconds': sessionData.elapsedSeconds,
      'pause_time_seconds': totalDuration.inSeconds - sessionData.elapsedSeconds,
      'completion_percentage': sessionData.elapsedSeconds / (30 * 60) * 100, // Default 30 minutes
    };
  }
  
  // Get all active sessions for an agent
  Future<List<TouringTaskSession>> getActiveSessionsForAgent(String agentId) async {
    final response = await supabase
        .from('touring_task_sessions')
        .select()
        .eq('agent_id', agentId)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return response.map((json) => TouringTaskSession.fromJson(json)).toList();
  }
  
  // Get touring task by ID
  Future<TouringTask?> getTouringTaskById(String taskId) async {
    try {
      final response = await supabase
          .from('touring_tasks')
          .select()
          .eq('id', taskId)
          .single();

      return TouringTask.fromJson(response);
    } catch (e) {
      return null;
    }
  }
  
  // Check if a touring task has been completed today
  Future<bool> isTaskCompletedToday(String touringTaskId, String agentId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
      
      final response = await supabase
          .from('touring_task_sessions')
          .select('id')
          .eq('touring_task_id', touringTaskId)
          .eq('agent_id', agentId)
          .eq('is_completed', true)
          .gte('end_time', startOfDay.toIso8601String())
          .lte('end_time', endOfDay.toIso8601String());
      
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking daily completion: $e');
      return false;
    }
  }
  
  // Get the latest completion time for a task
  Future<DateTime?> getLatestCompletionTime(String touringTaskId, String agentId) async {
    try {
      final response = await supabase
          .from('touring_task_sessions')
          .select('end_time')
          .eq('touring_task_id', touringTaskId)
          .eq('agent_id', agentId)
          .eq('is_completed', true)
          .order('end_time', ascending: false)
          .limit(1);
      
      if (response.isNotEmpty) {
        return DateTime.parse(response.first['end_time']);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting latest completion time: $e');
      return null;
    }
  }
}