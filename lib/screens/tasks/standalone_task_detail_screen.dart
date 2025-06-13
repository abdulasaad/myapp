// lib/screens/tasks/standalone_task_detail_screen.dart

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';

class StandaloneTaskDetailScreen extends StatefulWidget {
  final Task task;
  const StandaloneTaskDetailScreen({super.key, required this.task});

  @override
  State<StandaloneTaskDetailScreen> createState() => _StandaloneTaskDetailScreenState();
}

class _StandaloneTaskDetailScreenState extends State<StandaloneTaskDetailScreen> {
  late Future<List<AppUser>> _assignedAgentsFuture;

  @override
  void initState() {
    super.initState();
    _assignedAgentsFuture = _fetchAssignedAgents();
  }

  void _refresh() {
    setState(() { _assignedAgentsFuture = _fetchAssignedAgents(); });
  }

  Future<List<AppUser>> _fetchAssignedAgents() async {
    final response = await supabase.from('task_assignments').select('profiles(id, full_name)').eq('task_id', widget.task.id);
    return response.map((data) => AppUser.fromJson(data['profiles'])).toList();
  }

  Future<void> _showAssignAgentDialog() async {
    final allAgentsResponse = await supabase.from('profiles').select('id, full_name').eq('role', 'agent');
    final allAgents = allAgentsResponse.map((json) => AppUser.fromJson(json)).toList();
    
    if (!mounted) { return; }

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
              return ListTile(title: Text(agent.fullName), onTap: () => Navigator.of(context).pop(agent));
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
      ),
    );

    if (selectedAgent == null || !mounted) { return; }

    try {
      await supabase.from('task_assignments').insert({'task_id': widget.task.id, 'agent_id': selectedAgent.id});
      if (mounted) { context.showSnackBar('Agent assigned successfully.'); }
      _refresh();
    } catch (e) {
      if (mounted) { context.showSnackBar('Failed to assign agent: $e', isError: true); }
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
            Text('Assigned Agents', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<AppUser>>(
                future: _assignedAgentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) { return preloader; }
                  if (snapshot.hasError) { return Center(child: Text('Error: ${snapshot.error}')); }
                  final agents = snapshot.data ?? [];
                  if (agents.isEmpty) { return const Center(child: Text('No agents assigned to this task yet.')); }
                  
                  return ListView.builder(
                    itemCount: agents.length,
                    itemBuilder: (context, index) {
                      final agent = agents[index];
                      return Card(child: ListTile(title: Text(agent.fullName), leading: const Icon(Icons.person)));
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
}
