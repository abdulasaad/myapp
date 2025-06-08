// lib/screens/campaigns/campaign_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../models/task.dart';
import '../../services/profile_service.dart';
import '../../models/campaign.dart';
import '../../utils/constants.dart';

class CampaignDetailScreen extends StatefulWidget {
  final Campaign campaign;
  const CampaignDetailScreen({super.key, required this.campaign});

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  late Future<List<AppUser>> _assignedAgentsFuture;
  late Future<List<Task>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _assignedAgentsFuture = _fetchAssignedAgents();
    _tasksFuture = _fetchTasks();
  }

  // ==========================================================
  //  THIS IS THE ONLY METHOD THAT CHANGES
  // ==========================================================
  Future<List<AppUser>> _fetchAssignedAgents() async {
    // We now make a single call to our new database function (RPC).
    final response = await supabase.rpc(
      'get_assigned_agents',
      params: {'p_campaign_id': widget.campaign.id},
    );

    // The rest of the logic is the same: convert the list of maps to a list of AppUser objects.
    return response.map<AppUser>((json) => AppUser.fromJson(json)).toList();
  }
  // ==========================================================

  Future<List<Task>> _fetchTasks() async {
    final response = await supabase
        .from('tasks')
        .select()
        .eq('campaign_id', widget.campaign.id)
        .order('created_at', ascending: true);
    return response.map((json) => Task.fromJson(json)).toList();
  }

  // The rest of the file is exactly the same as before.
  // All the dialogs and UI building logic remains unchanged.

  Future<void> _showAssignAgentDialog() async {
    final allAgentsResponse = await supabase
        .from('profiles')
        .select('id, full_name')
        .eq('role', 'agent');
    final allAgents =
        allAgentsResponse.map((json) => AppUser.fromJson(json)).toList();
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Assign an Agent'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allAgents.length,
                itemBuilder: (context, index) {
                  final agent = allAgents[index];
                  return ListTile(
                    title: Text(agent.fullName),
                    onTap: () => Navigator.of(context).pop(agent),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
    ).then((selectedAgent) {
      if (selectedAgent != null) {
        _assignAgent(selectedAgent.id);
      }
    });
  }

  Future<void> _assignAgent(String agentId) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;
      await supabase.from('campaign_agents').insert({
        'campaign_id': widget.campaign.id,
        'agent_id': agentId,
        'assigned_by': currentUserId,
      });
      if (mounted) {
        context.showSnackBar('Agent assigned successfully!');
        setState(() => _assignedAgentsFuture = _fetchAssignedAgents());
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          'Failed to assign agent. They may already be assigned.',
          isError: true,
        );
      }
    }
  }

  Future<void> _showAddTaskDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final pointsController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Task'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                      ),
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Required'
                                  : null,
                    ),
                    formSpacer,
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    formSpacer,
                    TextFormField(
                      controller: pointsController,
                      decoration: const InputDecoration(labelText: 'Points'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (int.tryParse(value) == null)
                          return 'Must be a number';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(context).pop();
                    await _addTask(
                      title: titleController.text,
                      description: descriptionController.text,
                      points: int.parse(pointsController.text),
                    );
                  }
                },
                child: const Text('Add Task'),
              ),
            ],
          ),
    );
  }

  Future<void> _addTask({
    required String title,
    String? description,
    required int points,
  }) async {
    try {
      await supabase.from('tasks').insert({
        'campaign_id': widget.campaign.id,
        'title': title,
        'description': description,
        'points': points,
      });
      if (mounted) {
        context.showSnackBar('Task added successfully!');
        setState(() => _tasksFuture = _fetchTasks());
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to add task.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager =
        ProfileService.instance.role == 'manager' ||
        ProfileService.instance.role == 'admin';

    return Scaffold(
      appBar: AppBar(title: Text(widget.campaign.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildSectionHeader(
              'Tasks',
              onPressed: isManager ? _showAddTaskDialog : null,
              buttonLabel: 'Add Task',
            ),
            _buildTasksList(),
            const SizedBox(height: 24),
            _buildSectionHeader(
              'Assigned Agents',
              onPressed: isManager ? _showAssignAgentDialog : null,
              buttonLabel: 'Assign Agent',
            ),
            _buildAssignedAgentsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    VoidCallback? onPressed,
    required String buttonLabel,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (onPressed != null)
          TextButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
            label: Text(buttonLabel),
          ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.campaign.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (widget.campaign.description != null &&
                widget.campaign.description!.isNotEmpty) ...[
              formSpacer,
              Text(widget.campaign.description!),
            ],
            formSpacer,
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat.yMMMd().format(widget.campaign.startDate)} - ${DateFormat.yMMMd().format(widget.campaign.endDate)}',
                ),
              ],
            ),
            formSpacer,
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 8),
                Text('Status: ${widget.campaign.status}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksList() {
    return FutureBuilder<List<Task>>(
      future: _tasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return preloader;
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        final tasks = snapshot.data!;
        if (tasks.isEmpty)
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No tasks created for this campaign yet.'),
            ),
          );

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.check_box_outline_blank),
                title: Text(task.title),
                subtitle:
                    task.description != null && task.description!.isNotEmpty
                        ? Text(task.description!)
                        : null,
                trailing: Text('${task.points} pts'),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAssignedAgentsList() {
    return FutureBuilder<List<AppUser>>(
      future: _assignedAgentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return preloader;
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        final agents = snapshot.data!;
        if (agents.isEmpty)
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No agents assigned to this campaign yet.'),
            ),
          );

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: agents.length,
          itemBuilder: (context, index) {
            final agent = agents[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(agent.fullName.substring(0, 1).toUpperCase()),
                ),
                title: Text(agent.fullName),
              ),
            );
          },
        );
      },
    );
  }
}
