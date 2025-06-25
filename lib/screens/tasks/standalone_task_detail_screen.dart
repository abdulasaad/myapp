// lib/screens/tasks/standalone_task_detail_screen.dart

import 'package:flutter/material.dart';
import '../../models/app_user.dart'; // Will keep for _showAssignAgentDialog for now
import '../../models/task.dart';
import '../../models/agent_task_progress.dart'; // New model
import '../../utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For Supabase.instance.client

class StandaloneTaskDetailScreen extends StatefulWidget {
  final Task task;
  const StandaloneTaskDetailScreen({super.key, required this.task});

  @override
  State<StandaloneTaskDetailScreen> createState() =>
      _StandaloneTaskDetailScreenState();
}

class _StandaloneTaskDetailScreenState
    extends State<StandaloneTaskDetailScreen> {
  late Future<List<AgentTaskProgress>> _agentProgressFuture; // Changed type

  @override
  void initState() {
    super.initState();
    _agentProgressFuture = _fetchAgentProgress(); // Renamed method
  }

  void _refresh() {
    setState(() {
      _agentProgressFuture = _fetchAgentProgress(); // Renamed method
    });
  }

  Future<List<AgentTaskProgress>> _fetchAgentProgress() async {
    try {
      // Use a single RPC call to get all agent progress for this task
      final response = await supabase.rpc('get_task_agent_progress_batch', params: {
        'p_task_id': widget.task.id,
      });

      final List<AgentTaskProgress> progressList = [];
      for (final item in response as List) {
        try {
          progressList.add(AgentTaskProgress.fromJson(item, item['agent_id']));
        } catch (e) {
          debugPrint('Error parsing agent progress: $e');
        }
      }
      
      return progressList;
    } catch (e) {
      // Fallback to the old method if new RPC doesn't exist
      debugPrint('Batch RPC not available, falling back to individual calls: $e');
      return _fetchAgentProgressFallback();
    }
  }

  Future<List<AgentTaskProgress>> _fetchAgentProgressFallback() async {
    // 1. Fetch agent_ids assigned to the task
    final assignmentsResponse = await supabase
        .from('task_assignments')
        .select('agent_id')
        .eq('task_id', widget.task.id);

    final List<String> agentIds = assignmentsResponse
        .map((assignment) => assignment['agent_id'] as String)
        .toList();

    // 2. Loop through IDs and call RPC for each one
    final List<AgentTaskProgress> progressList = [];
    for (String agentId in agentIds) {
      try {
        final rpcResponse = await Supabase.instance.client.rpc(
          'get_agent_progress_for_task',
          params: {'p_task_id': widget.task.id, 'p_agent_id': agentId},
        ).single(); // Expecting a single record per agent

        progressList.add(AgentTaskProgress.fromJson(rpcResponse, agentId));
      } catch (e) {
        // Log error or handle missing agent progress data
        if (mounted) {
          debugPrint('Error fetching progress for agent $agentId: $e');
        }
      }
    }
    return progressList;
  }

  Future<void> _showAssignAgentDialog() async {
    final allAgentsResponse =
        await supabase.from('profiles').select('id, full_name').eq('role', 'agent');
    final allAgents =
        allAgentsResponse.map((json) => AppUser.fromJson(json)).toList();

    if (!mounted) {
      return;
    }

    final selectedAgent = await showDialog<AppUser>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Agent to Task'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: allAgents.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final agent = allAgents[index];
              return ListTile(
                  title: Text(agent.fullName),
                  onTap: () => Navigator.of(context).pop(agent));
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'))
        ],
      ),
    );

    if (selectedAgent == null || !mounted) {
      return;
    }

    try {
      await supabase
          .from('task_assignments')
          .insert({'task_id': widget.task.id, 'agent_id': selectedAgent.id});
      if (mounted) {
        context.showSnackBar('Agent assigned successfully.');
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to assign agent: $e', isError: true);
      }
    }
  }

  // ===================================================================
  // MODIFIED FUNCTION: To handle agent removal from a standalone task
  // Now takes AgentTaskProgress as input
  // ===================================================================
  Future<void> _removeAgent(AgentTaskProgress agentProgress) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Removal'),
        content:
            Text('Are you sure you want to unassign ${agentProgress.agentName} from this task?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldRemove != true || !mounted) {
      return;
    }

    try {
      await supabase.from('task_assignments').delete().match({
        'task_id': widget.task.id,
        'agent_id': agentProgress.agentId, // Use agentId from AgentTaskProgress
      });

      if (mounted) {
        context.showSnackBar('Agent unassigned successfully.');
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to unassign agent: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.task.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agent Progress & Payments', // Updated title
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<AgentTaskProgress>>( // Changed type
                future: _agentProgressFuture, // Changed variable
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return preloader;
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error fetching agent progress: ${snapshot.error}'));
                  }
                  final agentProgressList = snapshot.data ?? [];
                  if (agentProgressList.isEmpty) {
                    return const Center(
                        child: Text('No agents assigned to this task yet.'));
                  }
                  return ListView.builder(
                    itemCount: agentProgressList.length,
                    itemBuilder: (context, index) {
                      final agentProgress = agentProgressList[index];
                      final progressPercentage = agentProgress.progressPercentage;
                      final canPay = agentProgress.assignmentStatus == 'completed' &&
                                     agentProgress.outstandingBalance > 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    agentProgress.agentName,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.person_remove_outlined),
                                    color: Colors.red[400],
                                    tooltip: 'Unassign Agent',
                                    onPressed: () => _removeAgent(agentProgress),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Status: ${agentProgress.assignmentStatus.capitalize()}'),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: progressPercentage,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progressPercentage >= 1.0 ? Colors.green : Colors.blue,
                                ),
                                minHeight: 10,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  'Evidence: ${agentProgress.evidenceUploaded} / ${agentProgress.evidenceRequired}'),
                              const SizedBox(height: 8),
                              Text('Total Points for Task: ${agentProgress.pointsTotal} pts'),
                              Text('Points Paid: ${agentProgress.pointsPaid} pts'),
                              Text(
                                'Outstanding Balance: ${agentProgress.outstandingBalance} pts',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: agentProgress.outstandingBalance > 0 ? Colors.orange[700] : Colors.green,
                                ),
                              ),
                              if (canPay) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.payment),
                                    label: Text('Pay ${agentProgress.outstandingBalance} pts'),
                                    onPressed: () {
                                      // Call _recordPayment - to be implemented in next step
                                      _recordPayment(agentProgress.agentId, agentProgress.outstandingBalance);
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAssignAgentDialog,
        label: const Text('Assign Agent'),
        icon: const Icon(Icons.person_add),
      ),
    );
  }

  // Step 3.4: Implement Payment Logic
  Future<void> _recordPayment(String agentId, int amount) async {
    if (!mounted) return;

    final confirmPayment = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Payment'),
          content: Text('Are you sure you want to record a payment of $amount pts to this agent for this task?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // User canceled
              },
            ),
            ElevatedButton(
              child: const Text('Confirm Payment'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // User confirmed
              },
            ),
          ],
        );
      },
    );

    if (confirmPayment != true) {
      return; // User cancelled or dialog dismissed
    }

    // Show loading indicator or disable button here if desired
    // For simplicity, directly proceeding with Supabase call

    final managerId = supabase.auth.currentUser?.id;
    if (managerId == null) {
      if (mounted) {
        context.showSnackBar('Error: Could not identify the paying manager. Please re-authenticate.', isError: true);
      }
      return;
    }

    try {
      await supabase.from('payments').insert({
        'paid_by_manager_id': managerId, // Added manager ID
        'agent_id': agentId,
        'amount': amount,
        'task_id': widget.task.id, // Crucial: link payment to the task
        'payment_type': 'task_completion', // Optional: categorize payment
        'notes': 'Payment for task: ${widget.task.title}', // Optional
        // 'campaign_id' will be null for task-specific payments
      });

      if (mounted) {
        context.showSnackBar('Payment of $amount pts recorded successfully.', isError: false);
        _refresh(); // Refresh the list to show updated balances
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to record payment: $e', isError: true);
      }
    } finally {
      // Hide loading indicator here if shown
    }
  }
}

// Helper extension for capitalizing strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) {
      return this;
    }
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
