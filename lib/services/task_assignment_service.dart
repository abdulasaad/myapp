// lib/services/task_assignment_service.dart

import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

class TaskAssignmentService {
  static final TaskAssignmentService _instance = TaskAssignmentService._internal();
  factory TaskAssignmentService() => _instance;
  TaskAssignmentService._internal();

  /// Get pending task assignments for manager approval
  Future<List<PendingTaskAssignment>> getPendingAssignments() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return [];

    // Get current user's role
    final userProfile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', currentUserId)
        .single();
    
    final isManager = userProfile['role'] == 'manager';
    
    // If manager, filter by group assignments
    if (isManager) {
      // Get manager's groups
      final managerGroups = await supabase
          .from('user_groups')
          .select('group_id')
          .eq('user_id', currentUserId);
      
      if (managerGroups.isEmpty) {
        return [];
      }
      
      final groupIds = managerGroups.map((g) => g['group_id']).toList();
      
      // Get agents in manager's groups
      final groupAgents = await supabase
          .from('user_groups')
          .select('user_id')
          .inFilter('group_id', groupIds);
      
      if (groupAgents.isEmpty) {
        return [];
      }
      
      final agentIds = groupAgents.map((g) => g['user_id']).toList();
      
      // Get pending assignments from these agents only
      final response = await supabase
          .from('task_assignments')
          .select('''
            id,
            status,
            agent_id,
            tasks!inner(
              id,
              title,
              description,
              points,
              location_name,
              required_evidence_count
            ),
            profiles!inner(
              id,
              full_name
            )
          ''')
          .eq('status', 'pending')
          .inFilter('agent_id', agentIds);

      return response.map((json) => PendingTaskAssignment.fromJson(json)).toList();
    } else {
      // Admin sees all pending assignments
      final response = await supabase
          .from('task_assignments')
          .select('''
            id,
            status,
            agent_id,
            tasks!inner(
              id,
              title,
              description,
              points,
              location_name,
              required_evidence_count
            ),
            profiles!inner(
              id,
              full_name
            )
          ''')
          .eq('status', 'pending');

      return response.map((json) => PendingTaskAssignment.fromJson(json)).toList();
    }
  }

  /// Approve a pending task assignment
  Future<void> approveAssignment(String assignmentId) async {
    await supabase
        .from('task_assignments')
        .update({
          'status': 'assigned',
          'started_at': DateTime.now().toIso8601String(),
        })
        .eq('id', assignmentId);
  }

  /// Reject a pending task assignment
  Future<void> rejectAssignment(String assignmentId, String? reason) async {
    // Simply delete the assignment - don't try to log to assignment_rejections table
    await supabase.from('task_assignments').delete().eq('id', assignmentId);
  }

  /// Auto-approve assignments based on criteria
  Future<void> autoApproveAssignments({
    String? agentId,
    int? maxPointsThreshold,
  }) async {
    var query = supabase
        .from('task_assignments')
        .update({
          'status': 'assigned',
          'started_at': DateTime.now().toIso8601String(),
        })
        .eq('status', 'pending');

    if (agentId != null) {
      query = query.eq('agent_id', agentId);
    }

    await query;
  }

  /// Check if assignment needs automatic status update
  Future<void> updateAssignmentStatusOnEvidence(String taskAssignmentId) async {
    // Get current status
    final assignment = await supabase
        .from('task_assignments')
        .select('status')
        .eq('id', taskAssignmentId)
        .single();

    // If assigned, move to in_progress when first evidence is submitted
    if (assignment['status'] == 'assigned') {
      await supabase
          .from('task_assignments')
          .update({'status': 'in_progress'})
          .eq('id', taskAssignmentId);
    }
  }

  /// Check if agent can access a task (campaign assignment or approved task assignment)
  Future<bool> canAgentAccessTask(String taskId, String agentId) async {
    try {
      // First check if agent is assigned to the campaign containing this task
      final taskData = await supabase
          .from('tasks')
          .select('campaign_id')
          .eq('id', taskId)
          .single();
      
      final campaignId = taskData['campaign_id'];
      
      // If task belongs to a campaign, check if agent is assigned to that campaign
      if (campaignId != null) {
        final campaignAssignment = await supabase
            .from('campaign_agents')
            .select('campaign_id')
            .eq('campaign_id', campaignId)
            .eq('agent_id', agentId)
            .maybeSingle();
        
        // If agent is assigned to the campaign, they have direct access
        if (campaignAssignment != null) {
          debugPrint('✅ Agent $agentId has campaign access to task $taskId via campaign $campaignId');
          return true;
        }
      }
      
      // Fall back to checking individual task assignment for standalone tasks
      final assignment = await supabase
          .from('task_assignments')
          .select('status')
          .eq('task_id', taskId)
          .eq('agent_id', agentId)
          .maybeSingle();
      
      // No assignment means no access
      if (assignment == null) {
        debugPrint('❌ Agent $agentId has no access to task $taskId (no assignment)');
        return false;
      }
      
      // Can access if status is anything except 'pending'
      final status = assignment['status'] as String;
      final hasAccess = status != 'pending';
      debugPrint('${hasAccess ? '✅' : '❌'} Agent $agentId task assignment status: $status');
      return hasAccess;
    } catch (e) {
      debugPrint('❌ Error checking task access: $e');
      // If any error, deny access for safety
      return false;
    }
  }

  /// Get agent's task assignment status (campaign assignment returns 'assigned')
  Future<String?> getTaskAssignmentStatus(String taskId, String agentId) async {
    try {
      // First check if agent is assigned to the campaign containing this task
      final taskData = await supabase
          .from('tasks')
          .select('campaign_id')
          .eq('id', taskId)
          .single();
      
      final campaignId = taskData['campaign_id'];
      
      // If task belongs to a campaign, check if agent is assigned to that campaign
      if (campaignId != null) {
        final campaignAssignment = await supabase
            .from('campaign_agents')
            .select('campaign_id')
            .eq('campaign_id', campaignId)
            .eq('agent_id', agentId)
            .maybeSingle();
        
        // If agent is assigned to the campaign, return 'assigned' status
        if (campaignAssignment != null) {
          return 'assigned';
        }
      }
      
      // Fall back to checking individual task assignment
      final assignment = await supabase
          .from('task_assignments')
          .select('status')
          .eq('task_id', taskId)
          .eq('agent_id', agentId)
          .maybeSingle();
      
      return assignment?['status'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Check if task should be auto-completed based on evidence count
  Future<void> checkTaskCompletion(String taskAssignmentId) async {
    final assignmentData = await supabase
        .from('task_assignments')
        .select('''
          id,
          status,
          tasks!inner(required_evidence_count)
        ''')
        .eq('id', taskAssignmentId)
        .single();

    if (assignmentData['status'] == 'completed') return;

    final requiredCount = assignmentData['tasks']['required_evidence_count'] ?? 1;
    
    final evidenceResponse = await supabase
        .from('evidence')
        .select('id')
        .eq('task_assignment_id', taskAssignmentId)
        .eq('status', 'approved');
    
    final evidenceCount = evidenceResponse.length;

    if (evidenceCount >= requiredCount) {
      await supabase
          .from('task_assignments')
          .update({
            'status': 'completed',
          })
          .eq('id', taskAssignmentId);
    }
  }
}

class PendingTaskAssignment {
  final String id;
  final String taskId;
  final String taskTitle;
  final String? taskDescription;
  final int points;
  final String? locationName;
  final int requiredEvidenceCount;
  final String agentId;
  final String agentName;

  PendingTaskAssignment({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    this.taskDescription,
    required this.points,
    this.locationName,
    required this.requiredEvidenceCount,
    required this.agentId,
    required this.agentName,
  });

  factory PendingTaskAssignment.fromJson(Map<String, dynamic> json) {
    final task = json['tasks'];
    final profile = json['profiles'];

    return PendingTaskAssignment(
      id: json['id'],
      taskId: task['id'],
      taskTitle: task['title'],
      taskDescription: task['description'],
      points: task['points'] ?? 0,
      locationName: task['location_name'],
      requiredEvidenceCount: task['required_evidence_count'] ?? 1,
      agentId: json['agent_id'] ?? profile['id'],
      agentName: profile['full_name'] ?? 'Unknown Agent',
    );
  }
}