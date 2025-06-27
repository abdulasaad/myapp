// lib/screens/agent/agent_standalone_tasks_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';
import '../agent/task_execution_router.dart';
import '../agent/task_location_viewer_screen.dart';

class AgentStandaloneTasksScreen extends StatefulWidget {
  const AgentStandaloneTasksScreen({super.key});

  @override
  State<AgentStandaloneTasksScreen> createState() => _AgentStandaloneTasksScreenState();
}

class _AgentStandaloneTasksScreenState extends State<AgentStandaloneTasksScreen> {
  late Future<List<TaskWithAssignment>> _tasksFuture;
  String _filterStatus = 'all'; // all, available, assigned, completed
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _tasksFuture = _fetchTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<TaskWithAssignment>> _fetchTasks() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // Get all standalone tasks with assignment info, geofence data, and creator info for current agent
    final response = await supabase
        .from('tasks')
        .select('''
          *,
          task_assignments!left(
            id,
            status,
            agent_id
          ),
          geofences!left(
            id
          ),
          profiles!inner(
            id,
            role
          )
        ''')
        .filter('campaign_id', 'is', null)
        .filter('status', 'eq', 'active')
        .order('created_at', ascending: false);

    final tasks = <TaskWithAssignment>[];
    for (final taskData in response) {
      final task = Task.fromJson(taskData);
      
      // Get creator role
      final creatorProfile = taskData['profiles'] as Map<String, dynamic>?;
      final creatorRole = creatorProfile?['role'] as String?;
      
      // Filter out admin-created tasks that don't have an assigned manager
      if (creatorRole == 'admin') {
        final assignedManagerId = taskData['assigned_manager_id'];
        if (assignedManagerId == null) {
          // Skip admin tasks without assigned manager
          continue;
        }
      }
      
      // Find assignment for current agent
      final assignments = taskData['task_assignments'] as List<dynamic>? ?? [];
      final userAssignment = assignments.firstWhere(
        (assignment) => assignment['agent_id'] == userId,
        orElse: () => null,
      );

      // Check if task has geofences
      final geofences = taskData['geofences'] as List<dynamic>? ?? [];
      final hasGeofences = geofences.isNotEmpty;

      tasks.add(TaskWithAssignment(
        task: task,
        assignmentId: userAssignment?['id'],
        assignmentStatus: userAssignment?['status'],
        isAssigned: userAssignment != null,
        hasGeofences: hasGeofences,
      ));
    }

    return tasks;
  }

  List<TaskWithAssignment> _filterTasks(List<TaskWithAssignment> tasks) {
    var filteredTasks = tasks;

    // Apply status filter
    switch (_filterStatus) {
      case 'available':
        filteredTasks = filteredTasks.where((t) => !t.isAssigned).toList();
        break;
      case 'assigned':
        filteredTasks = filteredTasks.where((t) => t.isAssigned && t.assignmentStatus != 'completed').toList();
        break;
      case 'completed':
        filteredTasks = filteredTasks.where((t) => t.assignmentStatus == 'completed').toList();
        break;
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredTasks = filteredTasks.where((t) {
        final title = t.task.title.toLowerCase();
        final description = (t.task.description ?? '').toLowerCase();
        final locationName = (t.task.locationName ?? '').toLowerCase();
        
        return title.contains(query) || 
               description.contains(query) || 
               locationName.contains(query);
      }).toList();
    }

    return filteredTasks;
  }

  void _showPendingStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Assignment Pending'),
          ],
        ),
        content: const Text(
          'Your assignment request for this task is currently pending approval from a manager. You cannot start work until it is approved.\n\nPlease check back later or contact your manager for more information.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestTaskAssignment(Task task) async {
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Task Assignment'),
        content: Text('Do you want to request assignment to "${task.title}"? This will notify the manager.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Request'),
          ),
        ],
      ),
    );

    if (shouldRequest != true || !mounted) return;

    try {
      await supabase.from('task_assignments').insert({
        'task_id': task.id,
        'agent_id': supabase.auth.currentUser!.id,
        'status': 'pending',
      });

      if (mounted) {
        context.showSnackBar('Task assignment requested successfully!');
        setState(() {
          _tasksFuture = _fetchTasks();
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to request assignment: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _showSearchBar 
            ? TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search tasks...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text('Available Tasks'),
        actions: [
          IconButton(
            icon: Icon(_showSearchBar ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _filterStatus = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Tasks')),
              const PopupMenuItem(value: 'available', child: Text('Available')),
              const PopupMenuItem(value: 'assigned', child: Text('My Tasks')),
              const PopupMenuItem(value: 'completed', child: Text('Completed')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filterStatus != 'all' || _searchQuery.isNotEmpty)
            _buildFilterIndicator(),
          Expanded(
            child: FutureBuilder<List<TaskWithAssignment>>(
              future: _tasksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return preloader;
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allTasks = snapshot.data ?? [];
                final filteredTasks = _filterTasks(allTasks);

                if (filteredTasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _getEmptyMessage(),
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _tasksFuture = _fetchTasks();
                    });
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTasks.length,
                    itemBuilder: (context, index) {
                      final taskWithAssignment = filteredTasks[index];
                      return _buildTaskCard(taskWithAssignment);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterIndicator() {
    final chips = <Widget>[];
    
    if (_filterStatus != 'all') {
      String filterText;
      switch (_filterStatus) {
        case 'available':
          filterText = 'Available';
          break;
        case 'assigned':
          filterText = 'My Tasks';
          break;
        case 'completed':
          filterText = 'Completed';
          break;
        default:
          filterText = _filterStatus;
      }
      
      chips.add(
        Chip(
          label: Text(filterText),
          onDeleted: () {
            setState(() {
              _filterStatus = 'all';
            });
          },
          deleteIcon: const Icon(Icons.close, size: 18),
        ),
      );
    }
    
    if (_searchQuery.isNotEmpty) {
      chips.add(
        Chip(
          label: Text('Search: "$_searchQuery"'),
          onDeleted: () {
            setState(() {
              _searchQuery = '';
              _searchController.clear();
            });
          },
          deleteIcon: const Icon(Icons.close, size: 18),
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
      ),
      child: Wrap(
        spacing: 8,
        children: [
          ...chips,
          if (chips.length > 1)
            ActionChip(
              label: const Text('Clear All'),
              onPressed: () {
                setState(() {
                  _filterStatus = 'all';
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
        ],
      ),
    );
  }

  String _getEmptyMessage() {
    if (_searchQuery.isNotEmpty) {
      return 'No tasks found matching "$_searchQuery".\nTry adjusting your search terms.';
    }
    
    switch (_filterStatus) {
      case 'available':
        return 'No available tasks at the moment.\nCheck back later for new opportunities.';
      case 'assigned':
        return 'You have no assigned tasks.\nRequest assignment to available tasks.';
      case 'completed':
        return 'You haven\'t completed any tasks yet.\nStart working on your assigned tasks.';
      default:
        return 'No tasks found.\nStandalone tasks will appear here when created.';
    }
  }

  Widget _buildTaskCard(TaskWithAssignment taskWithAssignment) {
    final task = taskWithAssignment.task;
    final isExpired = task.endDate != null && task.endDate!.isBefore(DateTime.now());
    final isPending = taskWithAssignment.assignmentStatus == 'pending';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: isPending 
            ? () => _showPendingStatusDialog() 
            : () => _openTaskDetail(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(taskWithAssignment),
                ],
              ),
              if (task.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  task.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              _buildTaskInfo(task),
              if (isExpired) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'EXPIRED',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _buildActionButtons(taskWithAssignment, isExpired),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(TaskWithAssignment taskWithAssignment) {
    String text;
    Color color;

    if (!taskWithAssignment.isAssigned) {
      text = 'Available';
      color = Colors.green;
    } else {
      switch (taskWithAssignment.assignmentStatus) {
        case 'pending':
          text = 'Requested';
          color = Colors.orange;
          break;
        case 'in_progress':
          text = 'In Progress';
          color = Colors.blue;
          break;
        case 'completed':
          text = 'Completed';
          color = Colors.green;
          break;
        default:
          text = 'Assigned';
          color = Colors.purple;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTaskInfo(Task task) {
    return Row(
      children: [
        Icon(Icons.stars, size: 16, color: Colors.amber[600]),
        const SizedBox(width: 4),
        Text('${task.points} points'),
        const SizedBox(width: 16),
        Icon(Icons.upload_file, size: 16, color: Colors.blue[600]),
        const SizedBox(width: 4),
        Text('${task.requiredEvidenceCount ?? 1} evidence'),
        if (task.endDate != null) ...[
          const SizedBox(width: 16),
          Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            'Due ${DateFormat.MMMd().format(task.endDate!)}',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(TaskWithAssignment taskWithAssignment, bool isExpired) {
    if (isExpired) {
      return const SizedBox.shrink();
    }

    if (!taskWithAssignment.isAssigned) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _requestTaskAssignment(taskWithAssignment.task),
          icon: const Icon(Icons.add_task),
          label: const Text('Request Assignment'),
        ),
      );
    }

    if (taskWithAssignment.assignmentStatus == 'pending') {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_empty, color: Colors.orange[700], size: 16),
                const SizedBox(width: 8),
                Text(
                  'Assignment request pending approval',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You cannot start work on this task until your assignment request is approved by a manager.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    // Check if task has location data or geofences
    final hasLocationName = taskWithAssignment.task.locationName != null && 
                           taskWithAssignment.task.locationName!.isNotEmpty;
    final hasLocation = hasLocationName || taskWithAssignment.hasGeofences;
    
    return Row(
      children: [
        if (hasLocation) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openLocationViewer(taskWithAssignment.task),
              icon: const Icon(Icons.location_on),
              label: const Text('View Location'),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          flex: hasLocation ? 1 : 2,
          child: ElevatedButton.icon(
            onPressed: () => _openTaskDetail(taskWithAssignment.task),
            icon: const Icon(Icons.upload),
            label: const Text('Submit Evidence'),
          ),
        ),
      ],
    );
  }

  void _openTaskDetail(Task task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskExecutionRouter(task: task),
      ),
    );
  }

  void _openLocationViewer(Task task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskLocationViewerScreen(task: task),
      ),
    );
  }
}

class TaskWithAssignment {
  final Task task;
  final String? assignmentId;
  final String? assignmentStatus;
  final bool isAssigned;
  final bool hasGeofences;

  TaskWithAssignment({
    required this.task,
    this.assignmentId,
    this.assignmentStatus,
    required this.isAssigned,
    required this.hasGeofences,
  });
}