// lib/screens/campaigns/campaign_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_user.dart';
import '../../models/campaign.dart';
import '../../models/campaign_geofence.dart';
import '../../models/agent_geofence_assignment.dart';
import '../../models/task.dart';
import '../../models/touring_task.dart';
import '../../services/touring_task_service.dart';
import '../../services/profile_service.dart';
import '../../services/simple_notification_service.dart';
import '../../services/campaign_geofence_service.dart';
import '../../utils/constants.dart';
import 'campaign_geofence_management_screen.dart';
import 'agent_campaign_progress_screen.dart';
import '../agent/geofence_selection_screen.dart';
import '../tasks/create_touring_task_screen.dart';

class CampaignDetailScreen extends StatefulWidget {
  final Campaign campaign;
  const CampaignDetailScreen({super.key, required this.campaign});

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  late Future<List<AppUser>> _assignedAgentsFuture;
  late Future<List<Task>> _tasksFuture;
  late Future<List<TouringTask>> _touringTasksFuture;
  late Future<List<CampaignGeofence>> _geofencesFuture;
  late Future<AgentGeofenceAssignment?> _currentAssignmentFuture;
  final SimpleNotificationService _notificationService = SimpleNotificationService();
  final CampaignGeofenceService _geofenceService = CampaignGeofenceService();
  final TouringTaskService _touringTaskService = TouringTaskService();

  @override
  void initState() {
    super.initState();
    _assignedAgentsFuture = _fetchAssignedAgents();
    _tasksFuture = _fetchTasks();
    _touringTasksFuture = _fetchTouringTasks();
    _geofencesFuture = _fetchGeofences();
    _currentAssignmentFuture = _fetchCurrentAssignment();
  }

  void _refreshAll() {
    setState(() {
      _assignedAgentsFuture = _fetchAssignedAgents();
      _tasksFuture = _fetchTasks();
      _touringTasksFuture = _fetchTouringTasks();
      _geofencesFuture = _fetchGeofences();
      _currentAssignmentFuture = _fetchCurrentAssignment();
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

  Future<List<TouringTask>> _fetchTouringTasks() async {
    try {
      return await _touringTaskService.getTouringTasksForCampaign(widget.campaign.id);
    } catch (e) {
      debugPrint('Error fetching touring tasks: $e');
      return [];
    }
  }

  Future<List<CampaignGeofence>> _fetchGeofences() async {
    try {
      return await _geofenceService.getAvailableGeofencesForCampaign(widget.campaign.id);
    } catch (e) {
      debugPrint('Error fetching geofences: $e');
      return [];
    }
  }

  Future<AgentGeofenceAssignment?> _fetchCurrentAssignment() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return null;
      
      return await _geofenceService.getAgentCurrentAssignment(
        campaignId: widget.campaign.id,
        agentId: currentUser.id,
      );
    } catch (e) {
      debugPrint('Error fetching current assignment: $e');
      return null;
    }
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
          
          // Send notification to agent about task assignment
          try {
            await supabase.from('notifications').insert({
              'recipient_id': agent['agent_id'],
              'title': AppLocalizations.of(context)!.newTaskAssigned,
              'message': 'You have been assigned a new task: $title',
              'type': 'task_assignment',
              'data': {
                'task_id': taskId,
                'campaign_id': widget.campaign.id,
                'campaign_name': widget.campaign.name,
              },
              'created_at': DateTime.now().toIso8601String(),
            });
            Logger().i('Task assignment notification sent to agent: ${agent['agent_id']}');
          } catch (notificationError) {
            Logger().e('Failed to send task assignment notification: $notificationError');
          }
        } catch (e) {
          Logger().e('Failed to assign task to agent ${agent['agent_id']}: $e');
        }
      }
      
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.taskAddedSuccess);
        _refreshAll();
      }
    } catch (e) {
      if (mounted) context.showSnackBar(AppLocalizations.of(context)!.taskAddFailed(e.toString()), isError: true);
    }
  }

  Future<void> _showAddTouringTaskDialog() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateTouringTaskScreen(campaign: widget.campaign),
      ),
    );
    
    if (result != null) {
      _refreshAll();
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
        title: Text(AppLocalizations.of(context)!.addNewTask),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.taskTitle),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? AppLocalizations.of(context)!.requiredField : null),
              formSpacer,
              TextFormField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.description)),
              formSpacer,
              TextFormField(
                  controller: pointsController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.points),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return AppLocalizations.of(context)!.requiredField;
                    if (int.tryParse(v) == null) return AppLocalizations.of(context)!.mustBeNumber;
                    return null;
                  }),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.cancel)),
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
            child: Text(AppLocalizations.of(context)!.addTask),
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

      // Send notification to the agent
      try {
        Logger().i('Sending notification to agent: $agentId for campaign: ${widget.campaign.name}');
        await _notificationService.createNotification(
          recipientId: agentId,
          title: AppLocalizations.of(context)!.campaignAssignment,
          message: 'You have been assigned to campaign "${widget.campaign.name}"',
          type: 'campaign_assignment',
          data: {
            'campaign_id': widget.campaign.id,
            'campaign_name': widget.campaign.name,
          },
        );
        Logger().i('Notification sent successfully to agent: $agentId');
      } catch (e) {
        Logger().e('Failed to send notification to agent: $e');
        Logger().e('Stack trace: ${StackTrace.current}');
      }

      if (mounted) {
        context.showSnackBar(
            AppLocalizations.of(context)!.agentAssignedSuccess);
        _refreshAll();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
            AppLocalizations.of(context)!.agentAssignFailed(e.toString()),
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
        title: Text(AppLocalizations.of(context)!.editTask),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.title),
                validator: (v) => v!.isEmpty ? AppLocalizations.of(context)!.requiredField : null,
              ),
              TextFormField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.description),
                maxLines: 3,
              ),
              TextFormField(
                controller: pointsController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.points),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v!.isEmpty) return AppLocalizations.of(context)!.requiredField;
                  if (int.tryParse(v) == null) return AppLocalizations.of(context)!.mustBeNumber;
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
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
                    context.showSnackBar(AppLocalizations.of(context)!.taskUpdatedSuccess);
                    _refreshAll();
                  }
                } catch (e) {
                  if (mounted) {
                    context.showSnackBar(AppLocalizations.of(context)!.taskUpdateFailed(e.toString()), isError: true);
                  }
                }
              }
            },
            child: Text(AppLocalizations.of(context)!.update),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTask(Task task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteTask),
        content: Text('Are you sure you want to delete "${task.title}"? This will also remove all assignments and evidence for this task.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
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
          context.showSnackBar(AppLocalizations.of(context)!.taskDeletedSuccess);
          _refreshAll();
        }
      } catch (e) {
        if (mounted) {
          context.showSnackBar(AppLocalizations.of(context)!.taskDeleteFailed(e.toString()), isError: true);
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
        title: Text(AppLocalizations.of(context)!.assignAnAgent),
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
              child: Text(AppLocalizations.of(context)!.cancel))
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
              _buildGeofenceSection(),
              const SizedBox(height: 24),
              _buildSectionHeader('Touring Tasks',
                  onPressed: _showAddTouringTaskDialog, buttonLabel: 'Add Touring Task'),
              _buildTouringTasksList(),
              const SizedBox(height: 24),
              _buildSectionHeader(AppLocalizations.of(context)!.assignedAgents,
                  onPressed: _showAssignAgentDialog, buttonLabel: AppLocalizations.of(context)!.assignAgent),
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

  Widget _buildTouringTasksList() {
    return FutureBuilder<List<TouringTask>>(
      future: _touringTasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return preloader;
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        final tasks = snapshot.data!;
        if (tasks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.tour, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No touring tasks created yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create touring tasks that use your work zones',
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return _buildTouringTaskCard(task);
          },
        );
      },
    );
  }

  Widget _buildTouringTaskCard(TouringTask task) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.tour, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimaryColor,
                          ),
                        ),
                        if (task.description != null && task.description!.isNotEmpty)
                          Text(
                            task.description!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: textSecondaryColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (ProfileService.instance.canManageCampaigns)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editTouringTask(task);
                        } else if (value == 'delete') {
                          _deleteTouringTask(task);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit Task'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete Task', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTaskInfoChip(
                    Icons.schedule,
                    task.formattedDuration,
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildTaskInfoChip(
                    Icons.directions_walk,
                    task.movementTimeoutText,
                    Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildTaskInfoChip(
                    Icons.stars,
                    '${task.points} pts',
                    Colors.green,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: task.status == 'active' ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: task.status == 'active' ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      task.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: task.status == 'active' ? Colors.green[700] : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editTouringTask(TouringTask task) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateTouringTaskScreen(
          campaign: widget.campaign,
          touringTask: task,
        ),
      ),
    );
    
    if (result != null) {
      _refreshAll();
    }
  }

  Future<void> _deleteTouringTask(TouringTask task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Touring Task'),
        content: Text('Are you sure you want to delete "${task.title}"? This action cannot be undone.'),
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
        await _touringTaskService.deleteTouringTask(task.id);
        if (mounted) {
          context.showSnackBar('Touring task deleted successfully');
          _refreshAll();
        }
      } catch (e) {
        if (mounted) {
          context.showSnackBar('Failed to delete touring task: $e', isError: true);
        }
      }
    }
  }

  Widget _buildTasksList() {
    return FutureBuilder<List<Task>>(
      future: _tasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return preloader;
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        final tasks = snapshot.data!;
        if (tasks.isEmpty) {
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(AppLocalizations.of(context)!.noTasksCreated)));
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
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text(AppLocalizations.of(context)!.editTask),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text(AppLocalizations.of(context)!.deleteTask, style: TextStyle(color: Colors.red)),
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
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(AppLocalizations.of(context)!.noAgentsAssigned)));
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
        ]),
      ),
    );
  }

  Widget _buildGeofenceSection() {
    return FutureBuilder<List<CampaignGeofence>>(
      future: _geofencesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: primaryColor),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context)!.geofences,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          );
        }

        final geofences = snapshot.data ?? [];
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: primaryColor),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.geofences,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    // Show different buttons based on user role
                    FutureBuilder<String>(
                      future: _getUserRole(),
                      builder: (context, roleSnapshot) {
                        final role = roleSnapshot.data ?? 'agent';
                        
                        if (role == 'agent') {
                          return _buildAgentGeofenceButton();
                        } else {
                          return ElevatedButton(
                            onPressed: () async {
                              await Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => CampaignGeofenceManagementScreen(campaign: widget.campaign),
                              ));
                              _refreshAll();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: const Size(100, 36),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.settings, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Manage',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (geofences.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No geofences created yet. Create geofences to define work areas for agents.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: geofences.map((geofence) => _buildGeofenceCard(geofence)).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgentGeofenceButton() {
    return FutureBuilder<AgentGeofenceAssignment?>(
      future: _currentAssignmentFuture,
      builder: (context, assignmentSnapshot) {
        final hasAssignment = assignmentSnapshot.data != null;
        
        return ElevatedButton.icon(
          onPressed: () async {
            final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
              builder: (context) => GeofenceSelectionScreen(campaign: widget.campaign),
            ));
            
            if (result == true) {
              _refreshAll();
            }
          },
          icon: Icon(hasAssignment ? Icons.swap_horiz : Icons.location_searching),
          label: Text(hasAssignment ? AppLocalizations.of(context)!.changeGeofence : AppLocalizations.of(context)!.selectZone),
          style: ElevatedButton.styleFrom(
            backgroundColor: hasAssignment ? Colors.orange : successColor,
            foregroundColor: Colors.white,
          ),
        );
      },
    );
  }

  Widget _buildGeofenceCard(CampaignGeofence geofence) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: geofence.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 40,
            decoration: BoxDecoration(
              color: geofence.color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  geofence.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
                if (geofence.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    geofence.description!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: textSecondaryColor,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: geofence.statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        geofence.capacityText,
                        style: TextStyle(
                          color: geofence.statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: geofence.statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        geofence.statusText,
                        style: TextStyle(
                          color: geofence.statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            geofence.statusIcon,
            color: geofence.statusColor,
            size: 20,
          ),
        ],
      ),
    );
  }

  Future<String> _getUserRole() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return 'agent';
      
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', currentUser.id)
          .single();
      
      return response['role'] ?? 'agent';
    } catch (e) {
      return 'agent';
    }
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
        title: Text(AppLocalizations.of(context)!.confirmRemoval),
        content: Text(
            AppLocalizations.of(context)!.removeAgentConfirmation(widget.agent.fullName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.remove, style: const TextStyle(color: Colors.red)),
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
        context.showSnackBar(AppLocalizations.of(context)!.agentRemovedSuccess);
        widget.onAgentRemoved();
      }
    } catch (e) {
      if (mounted) context.showSnackBar(AppLocalizations.of(context)!.agentRemoveFailed(e.toString()), isError: true);
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
            ? Text(AppLocalizations.of(context)!.loadingEarnings)
            : Text('${AppLocalizations.of(context)!.outstandingBalance}: ${balance.toString()} ${AppLocalizations.of(context)!.points}'),
        trailing: IconButton(
          icon: const Icon(Icons.person_remove_outlined),
          color: Colors.red[300],
          tooltip: AppLocalizations.of(context)!.removeAgent,
          onPressed: _removeAgent,
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
