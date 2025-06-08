// lib/screens/agent/agent_campaign_view_screen.dart

import 'package:flutter/material.dart';
import 'package:myapp/models/campaign.dart';
import 'package:myapp/models/task_assignment.dart';
import 'package:myapp/utils/constants.dart';

class AgentCampaignViewScreen extends StatefulWidget {
  final Campaign campaign;
  const AgentCampaignViewScreen({super.key, required this.campaign});

  @override
  State<AgentCampaignViewScreen> createState() =>
      _AgentCampaignViewScreenState();
}

class _AgentCampaignViewScreenState extends State<AgentCampaignViewScreen> {
  late Future<List<TaskAssignment>> _myAssignmentsFuture;

  @override
  void initState() {
    super.initState();
    _myAssignmentsFuture = _fetchMyAssignments();
  }

  // Fetches the tasks assigned specifically to the current user for this campaign.
  Future<List<TaskAssignment>> _fetchMyAssignments() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return [];

    // This is a powerful Supabase query. It fetches from 'task_assignments'
    // but also includes all columns from the linked 'tasks' table.
    final response = await supabase
        .from('task_assignments')
        .select(
          '*, tasks(*)',
        ) // The magic part: select all from this table AND the linked task
        .eq('agent_id', currentUser.id)
        .eq('tasks.campaign_id', widget.campaign.id); // Filter by the campaign

    return response.map((json) => TaskAssignment.fromJson(json)).toList();
  }

  // Updates the status of a specific task assignment.
  Future<void> _updateTaskStatus(String assignmentId, String newStatus) async {
    try {
      await supabase
          .from('task_assignments')
          .update({'status': newStatus})
          .eq('id', assignmentId);

      if (mounted) {
        context.showSnackBar('Task status updated!');
        // Refresh the list to show the change
        setState(() {
          _myAssignmentsFuture = _fetchMyAssignments();
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to update status.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.campaign.name)),
      body: FutureBuilder<List<TaskAssignment>>(
        future: _myAssignmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return preloader;
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'You have not been assigned any tasks for this campaign.',
              ),
            );
          }

          final assignments = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final assignment = assignments[index];
              final isCompleted = assignment.status == 'completed';

              return Card(
                elevation: isCompleted ? 1 : 4,
                color: isCompleted ? Colors.grey[800] : cardBackgroundColor,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  leading: Icon(
                    isCompleted
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: isCompleted ? Colors.green : primaryColor,
                  ),
                  title: Text(
                    assignment.task.title,
                    style: TextStyle(
                      decoration:
                          isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                      color: isCompleted ? Colors.grey[400] : Colors.white,
                    ),
                  ),
                  subtitle:
                      assignment.task.description != null &&
                              assignment.task.description!.isNotEmpty
                          ? Text(assignment.task.description!)
                          : null,
                  trailing: Text('${assignment.task.points} pts'),
                  onTap: () {
                    // Simple toggle logic
                    final newStatus = isCompleted ? 'pending' : 'completed';
                    _updateTaskStatus(assignment.id, newStatus);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
