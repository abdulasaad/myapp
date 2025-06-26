// lib/services/task_assignment_service.dart

import '../utils/constants.dart';

class TaskAssignmentService {
  static final TaskAssignmentService _instance = TaskAssignmentService._internal();
  factory TaskAssignmentService() => _instance;
  TaskAssignmentService._internal();

  /// Get pending task assignments for manager approval
  Future<List<PendingTaskAssignment>> getPendingAssignments() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return [];

    final response = await supabase
        .from('task_assignments')
        .select('''
          id,
          status,
          created_at,
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
        .order('created_at', ascending: false);

    return response.map((json) => PendingTaskAssignment.fromJson(json)).toList();
  }

  /// Approve a pending task assignment
  Future<void> approveAssignment(String assignmentId) async {
    await supabase
        .from('task_assignments')
        .update({
          'status': 'assigned',
          'assigned_at': DateTime.now().toIso8601String(),
        })
        .eq('id', assignmentId);
  }

  /// Reject a pending task assignment
  Future<void> rejectAssignment(String assignmentId, String? reason) async {
    await supabase.from('task_assignments').delete().eq('id', assignmentId);
    
    // Optionally log the rejection reason
    if (reason != null) {
      await supabase.from('assignment_rejections').insert({
        'assignment_id': assignmentId,
        'reason': reason,
        'rejected_by': supabase.auth.currentUser?.id,
        'rejected_at': DateTime.now().toIso8601String(),
      });
    }
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
          'assigned_at': DateTime.now().toIso8601String(),
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
            'completed_at': DateTime.now().toIso8601String(),
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
  final DateTime createdAt;

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
    required this.createdAt,
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
      agentId: profile['id'],
      agentName: profile['full_name'] ?? 'Unknown Agent',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}