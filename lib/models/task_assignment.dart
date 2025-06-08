// lib/models/task_assignment.dart

import 'package:myapp/models/task.dart';

class TaskAssignment {
  final String id; // The ID of the assignment itself
  final String agentId;
  final String status;
  final Task task; // The nested Task object with details like title

  TaskAssignment({
    required this.id,
    required this.agentId,
    required this.status,
    required this.task,
  });

  factory TaskAssignment.fromJson(Map<String, dynamic> json) {
    return TaskAssignment(
      id: json['id'],
      agentId: json['agent_id'],
      status: json['status'],
      // Supabase's join syntax puts the joined table data in a nested map.
      // We parse the nested Task object from here.
      task: Task.fromJson(json['tasks']),
    );
  }
}
