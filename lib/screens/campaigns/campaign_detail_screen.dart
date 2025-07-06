// lib/screens/campaigns/campaign_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../../models/app_user.dart';
import '../../models/campaign.dart';
import '../../models/task.dart';
import '../../services/profile_service.dart';
import '../../utils/constants.dart';
import 'geofence_editor_screen.dart';
import 'agent_campaign_progress_screen.dart';

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

  void _refreshAll() {
    setState(() {
      _assignedAgentsFuture = _fetchAssignedAgents();
      _tasksFuture = _fetchTasks();
    });
  }

  // --- DATA FETCHING ---
  Future<List<AppUser>> _fetchAssignedAgents() async {
    final agentIdsResponse = await supabase
        .from('campaign_agents')
        .select('agent_id')
        .eq('campaign_id', widget.campaign.id);

    final agentIds =
        agentIdsResponse.map((map) => map['agent_id'] as String).toList();

    if (agentIds.isEmpty) {
      return [];
    }
    
    // ========== THE DEFINITIVE FIX IS HERE: Use the correct 'in' filter ==========
    final agentsResponse = await supabase
        .from('profiles')
        .select('id, full_name')
        .filter('id', 'in', '(${agentIds.join(',')})');
    // =========================================================================

    return agentsResponse.map((json) => AppUser.fromJson(json)).toList();
  }

  Future<List<Task>> _fetchTasks() async {
    final response = await supabase
        .from('tasks')
        .select()
        .eq('campaign_id', widget.campaign.id)
        .order('created_at', ascending: true);
    return response.map((json) => Task.fromJson(json)).toList();
  }

  // --- All other functions and build methods in this file are correct ---
  // --- No other changes are needed below this line for this file ---

  Future<void> _addTask(
      {required String title, String? description, required int points}) async {
    try {
      // Create the task
      final taskResponse = await supabase.from('tasks').insert({
        'campaign_id': widget.campaign.id,
        'title': title,
        'description': description,
        'points': points,
        'created_by': supabase.auth.currentUser!.id,
      }).select().single();
      
      final taskId = taskResponse['id'];
      
      // Get all agents assigned to this campaign
      final campaignAgents = await supabase
          .from('campaign_agents')
          .select('agent_id')
          .eq('campaign_id', widget.campaign.id);
      
      // Auto-assign the task to all campaign agents
      for (final agent in campaignAgents) {
        try {
          await supabase.from('task_assignments').insert({
            'task_id': taskId,
            'agent_id': agent['agent_id'],
            'status': 'assigned',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          Logger().e('Failed to assign task to agent ${agent['agent_id']}: $e');
        }
      }
      
      if (mounted) {
        context.showSnackBar('Task added and assigned to all campaign agents!');
        _refreshAll();
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to add task: $e', isError: true);
    }
  }

  Future<void> _showAddTaskDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final pointsController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Task'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null),
              formSpacer,
              TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description')),
              formSpacer,
              TextFormField(
                  controller: pointsController,
                  decoration: const InputDecoration(labelText: 'Points'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (int.tryParse(v) == null) return 'Must be a number';
                    return null;
                  }),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _addTask(
                    title: titleController.text,
                    description: descriptionController.text,
                    points: int.parse(pointsController.text));
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add Task'),
          )
        ],
      ),
    );
  }

  Future<void> _assignAgent(String agentId) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;
      await supabase.from('campaign_agents').upsert({
        'campaign_id': widget.campaign.id,
        'agent_id': agentId,
        'assigned_by': currentUserId
      }); 

      // Auto-assign all campaign tasks to the agent
      final tasks = await supabase
          .from('tasks')
          .select('id')
          .eq('campaign_id', widget.campaign.id);
      
      for (final task in tasks) {
        try {
          // Check if assignment already exists
          final existingAssignment = await supabase
              .from('task_assignments')
              .select('id, status')
              .eq('task_id', task['id'])
              .eq('agent_id', agentId)
              .maybeSingle();
          
          if (existingAssignment == null) {
            // Create new assignment with 'assigned' status
            await supabase.from('task_assignments').insert({
              'task_id': task['id'],
              'agent_id': agentId,
              'status': 'assigned',
              'created_at': DateTime.now().toIso8601String(),
            });
          } else if (existingAssignment['status'] == 'pending') {
            // Update pending assignments to assigned
            await supabase
                .from('task_assignments')
                .update({'status': 'assigned'})
                .eq('id', existingAssignment['id']);
          }
        } catch (e) {
          Logger().e('Failed to assign task ${task['id']} to agent: $e');
        }
      }

      if (mounted) {
        context.showSnackBar(
            'Agent assigned to campaign. All tasks have been assigned.');
        _refreshAll();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
            'Failed to assign agent: $e',
            isError: true);
      }
    }
  }

  Future<void> _editTask(Task task) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description ?? '');
    final pointsController = TextEditingController(text: task.points.toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v!.isEmpty ? 'Title is required' : null,
              ),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              TextFormField(
                controller: pointsController,
                decoration: const InputDecoration(labelText: 'Points'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v!.isEmpty) return 'Points are required';
                  if (int.tryParse(v) == null) return 'Invalid number';
                  return null;
                },
              ),
            ],
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
                Navigator.of(context).pop(); // Close dialog first
                
                try {
                  await supabase.from('tasks').update({
                    'title': titleController.text,
                    'description': descriptionController.text.isEmpty ? null : descriptionController.text,
                    'points': int.parse(pointsController.text),
                  }).eq('id', task.id);
                  
                  if (mounted) {
                    context.showSnackBar('Task updated successfully!');
                    _refreshAll();
                  }
                } catch (e) {
                  if (mounted) {
                    context.showSnackBar('Failed to update task: $e', isError: true);
                  }
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTask(Task task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"? This will also remove all assignments and evidence for this task.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        // Get all task assignment IDs for this task
        final assignmentIds = await supabase
            .from('task_assignments')
            .select('id')
            .eq('task_id', task.id);
        
        // Delete evidence for each assignment
        for (final assignment in assignmentIds) {
          await supabase.from('evidence').delete().eq('task_assignment_id', assignment['id']);
        }
        
        // Delete task assignments
        await supabase.from('task_assignments').delete().eq('task_id', task.id);
        
        // Delete geofences associated with this task
        await supabase.from('geofences').delete().eq('task_id', task.id);
        
        // Delete the task itself
        await supabase.from('tasks').delete().eq('id', task.id);
        
        if (mounted) {
          context.showSnackBar('Task deleted successfully!');
          _refreshAll();
        }
      } catch (e) {
        if (mounted) {
          context.showSnackBar('Failed to delete task: $e', isError: true);
        }
      }
    }
  }

  Future<void> _showAssignAgentDialog() async {
    final allAgentsResponse =
        await supabase.from('profiles').select('id, full_name').eq('role', 'agent');
    final allAgents =
        allAgentsResponse.map((json) => AppUser.fromJson(json)).toList();
    if (!mounted) return;

    final selectedAgent = await showDialog<AppUser>(
      context: context,
      builder: (context) => AlertDialog(
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

    if (selectedAgent != null) {
      _assignAgent(selectedAgent.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.campaign.name)),
      body: RefreshIndicator(
        onRefresh: () async => _refreshAll(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(),
              const SizedBox(height: 24),
              _buildSectionHeader('Tasks',
                  onPressed: _showAddTaskDialog, buttonLabel: 'Add Task'),
              _buildTasksList(),
              const SizedBox(height: 24),
              _buildSectionHeader('Assigned Agents',
                  onPressed: _showAssignAgentDialog, buttonLabel: 'Assign Agent'),
              _buildAssignedAgentsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title,
      {required VoidCallback onPressed, required String buttonLabel}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        TextButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
            label: Text(buttonLabel)),
      ],
    );
  }

  Widget _buildTasksList() {
    return FutureBuilder<List<Task>>(
      future: _tasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return preloader;
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        final tasks = snapshot.data!;
        if (tasks.isEmpty) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No tasks created yet.')));
        }
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task.description != null && task.description!.isNotEmpty)
                      Text(task.description!),
                    const SizedBox(height: 4),
                    Text(
                      '${task.points} points',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                trailing: ProfileService.instance.canManageCampaigns
                    ? PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _editTask(task);
                          } else if (value == 'delete') {
                            _deleteTask(task);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : null,
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
        if (snapshot.connectionState == ConnectionState.waiting) return preloader;
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final agents = snapshot.data!;
        if (agents.isEmpty) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No agents assigned yet.')));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: agents.length,
          itemBuilder: (context, index) {
            final agent = agents[index];
            return AgentEarningTile(
              agent: agent,
              campaignId: widget.campaign.id,
              campaign: widget.campaign,
              onAgentRemoved: () {
                setState(() {
                  _assignedAgentsFuture = _fetchAssignedAgents();
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.campaign.name,
              style: Theme.of(context).textTheme.headlineMedium),
          if (widget.campaign.description != null &&
              widget.campaign.description!.isNotEmpty) ...[
            formSpacer,
            Text(widget.campaign.description!),
          ],
          formSpacer,
          Row(children: [
            const Icon(Icons.calendar_today, size: 16),
            const SizedBox(width: 8),
            Text(
                '${DateFormat.yMMMd().format(widget.campaign.startDate)} - ${DateFormat.yMMMd().format(widget.campaign.endDate)}'),
          ]),
          formSpacer,
          Row(children: [
            const Icon(Icons.info_outline, size: 16),
            const SizedBox(width: 8),
            Text('Status: ${widget.campaign.status}'),
          ]),
          if (ProfileService.instance.canManageCampaigns) ...[
            formSpacer,
            ElevatedButton.icon(
              icon: const Icon(Icons.map_outlined, color: Colors.white),
              label: const Text(
                'Manage Geofences',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => GeofenceEditorScreen(campaign: widget.campaign),
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class AgentEarningTile extends StatefulWidget {
  final AppUser agent;
  final String campaignId;
  final VoidCallback onAgentRemoved;
  final Campaign campaign;

  const AgentEarningTile(
      {super.key,
      required this.agent,
      required this.campaignId,
      required this.onAgentRemoved,
      required this.campaign});

  @override
  State<AgentEarningTile> createState() => _AgentEarningTileState();
}

class _AgentEarningTileState extends State<AgentEarningTile> {
  final logger = Logger();
  Map<String, dynamic>? _earningsData;

  @override
  void initState() {
    super.initState();
    _fetchEarnings();
  }

  Future<void> _fetchEarnings() async {
    try {
      final data = await supabase.rpc('get_agent_earnings_for_campaign',
          params: {
            'p_agent_id': widget.agent.id,
            'p_campaign_id': widget.campaignId
          }).single();
      if (mounted) setState(() => _earningsData = data);
    } catch (e) {
      logger.e("Error fetching earnings for agent ${widget.agent.id}: $e");
    }
  }

  Future<void> _removeAgent() async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: Text(
            'Are you sure you want to remove ${widget.agent.fullName} from this campaign?'),
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

    if (shouldRemove != true || !mounted) return;

    try {
      await supabase.from('campaign_agents').delete().match({
        'campaign_id': widget.campaignId,
        'agent_id': widget.agent.id,
      });

      if (mounted) {
        context.showSnackBar('Agent removed successfully.');
        widget.onAgentRemoved();
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to remove agent: $e', isError: true);
    }
  }

  Future<void> _showRecordPaymentDialog() async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final outstandingBalance = _earningsData?['outstanding_balance'] ?? 0;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pay ${widget.agent.fullName}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: amountController,
            decoration:
                const InputDecoration(labelText: 'Amount Paid', prefixText: 'Pts '),
            keyboardType: TextInputType.number,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              final enteredAmount = int.tryParse(value);
              if (enteredAmount == null || enteredAmount <= 0) return 'Must be a positive number';
              if (enteredAmount > outstandingBalance) return 'Cannot pay more than the balance of $outstandingBalance';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _recordPayment(amount: int.parse(amountController.text));
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Confirm Payment'),
          )
        ],
      ),
    );
    if (result == true) _fetchEarnings();
  }

  Future<void> _recordPayment({required int amount}) async {
    try {
      await supabase.from('payments').insert({
        'campaign_id': widget.campaignId,
        'agent_id': widget.agent.id,
        'paid_by_manager_id': supabase.auth.currentUser!.id,
        'amount': amount,
        'paid_at': DateTime.now().toIso8601String(),
      });
      if (mounted) context.showSnackBar('Payment recorded successfully!');
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to record payment: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _earningsData?['outstanding_balance'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
            child: Text(widget.agent.fullName.substring(0, 1).toUpperCase())),
        title: Text(widget.agent.fullName),
        subtitle: _earningsData == null
            ? const Text('Loading earnings...')
            : Text('Outstanding Balance: $balance points'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: balance > 0 ? _showRecordPaymentDialog : null,
              child: const Text('PAY'),
            ),
            IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              color: Colors.red[300],
              tooltip: 'Remove Agent',
              onPressed: _removeAgent,
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => AgentCampaignProgressScreen(
              campaign: widget.campaign,
              agent: widget.agent,
            ),
          ));
        },
      ),
    );
  }
}
