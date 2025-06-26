// lib/screens/tasks/standalone_tasks_screen.dart

import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';
import './standalone_task_detail_screen.dart';
// --- FIX: Import the new creation screen we will be navigating to ---
import './create_evidence_task_screen.dart';
import './template_categories_screen.dart'; 

class StandaloneTasksScreen extends StatefulWidget {
  const StandaloneTasksScreen({super.key});

  @override
  State<StandaloneTasksScreen> createState() => _StandaloneTasksScreenState();
}

class _StandaloneTasksScreenState extends State<StandaloneTasksScreen> {
  late Future<List<Task>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _tasksFuture = _fetchTasks();
  }

  Future<List<Task>> _fetchTasks() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return [];

    try {
      // Get current user's role
      final userRoleResponse = await supabase
          .from('profiles')
          .select('role')
          .eq('id', currentUser.id)
          .single();
      
      final userRole = userRoleResponse['role'] as String;

      if (userRole == 'admin') {
        // Admins can see all standalone tasks
        final response = await supabase
            .from('tasks')
            .select()
            .filter('campaign_id', 'is', null) 
            .order('created_at', ascending: false);
        return response.map((json) => Task.fromJson(json)).toList();
      } else if (userRole == 'manager') {
        // Managers can only see standalone tasks created by users in their shared groups
        // Get current manager's groups
        final userGroupsResponse = await supabase
            .from('user_groups')
            .select('group_id')
            .eq('user_id', currentUser.id);
        
        final userGroupIds = userGroupsResponse
            .map((item) => item['group_id'] as String)
            .toSet();
        
        if (userGroupIds.isEmpty) {
          // Manager not in any groups, can only see tasks they created
          final response = await supabase
              .from('tasks')
              .select()
              .filter('campaign_id', 'is', null)
              .eq('created_by', currentUser.id)
              .order('created_at', ascending: false);
          return response.map((json) => Task.fromJson(json)).toList();
        }

        // Get all users in the same groups (including the manager)
        final usersInGroupsResponse = await supabase
            .from('user_groups')
            .select('user_id')
            .inFilter('group_id', userGroupIds.toList());
        
        final allowedUserIds = usersInGroupsResponse
            .map((item) => item['user_id'] as String)
            .toSet();
        
        // Always include the current manager
        allowedUserIds.add(currentUser.id);

        if (allowedUserIds.isEmpty) {
          return [];
        }

        // Get standalone tasks created by users in the same groups
        final response = await supabase
            .from('tasks')
            .select()
            .filter('campaign_id', 'is', null)
            .inFilter('created_by', allowedUserIds.toList())
            .order('created_at', ascending: false);
        
        return response.map((json) => Task.fromJson(json)).toList();
      } else {
        // Other roles (agents) typically don't manage standalone tasks
        return [];
      }
    } catch (e) {
      debugPrint('Error filtering standalone tasks: $e');
      // Return empty list on error rather than throwing
      return [];
    }
  }

  // --- NEW: A menu to choose how to create a task ---
  void _showCreateTaskMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Create New Task',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                _buildCreateOption(
                  icon: Icons.category,
                  title: 'From Template',
                  subtitle: 'Choose from professional task templates by category',
                  color: primaryColor,
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const TemplateCategoriesScreen()
                    ));
                    setState(() { _tasksFuture = _fetchTasks(); });
                  },
                ),
                const SizedBox(height: 12),
                _buildCreateOption(
                  icon: Icons.file_present_rounded,
                  title: 'Custom Task',
                  subtitle: 'Create a custom task with specific requirements',
                  color: secondaryColor,
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const CreateEvidenceTaskScreen()
                    ));
                    setState(() { _tasksFuture = _fetchTasks(); });
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: textSecondaryColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Task Management'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<List<Task>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading tasks',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() { _tasksFuture = _fetchTasks(); }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: Icon(
                      Icons.assignment,
                      size: 60,
                      color: primaryColor.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Tasks Yet',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first task to get started with task management',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: textSecondaryColor,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _showCreateTaskMenu,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Task'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async { setState(() { _tasksFuture = _fetchTasks(); }); },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: surfaceColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => StandaloneTaskDetailScreen(task: task)
                        ));
                        setState(() { _tasksFuture = _fetchTasks(); });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.assignment_turned_in,
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
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
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.stars,
                                        size: 16,
                                        color: secondaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${task.points} points',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: textSecondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => CreateEvidenceTaskScreen(task: task),
                                    ),
                                  );
                                  setState(() {
                                    _tasksFuture = _fetchTasks();
                                  });
                                } else if (value == 'delete') {
                                  final shouldDelete = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: const Text('Confirm Delete'),
                                      content: const Text('Are you sure you want to delete this task? This action cannot be undone.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(foregroundColor: errorColor),
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (shouldDelete == true) {
                                    await _deleteTask(task);
                                    setState(() {
                                      _tasksFuture = _fetchTasks();
                                    });
                                  }
                                }
                              },
                              itemBuilder: (BuildContext context) {
                                return [
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
                                        Icon(Icons.delete, size: 18, color: errorColor),
                                        SizedBox(width: 8),
                                        Text('Delete Task', style: TextStyle(color: errorColor)),
                                      ],
                                    ),
                                  ),
                                ];
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.more_vert,
                                  size: 18,
                                  color: textSecondaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTaskMenu,
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  Future<void> _deleteTask(Task task) async {
    try {
      // First get all task assignment IDs for this task
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
      
      if (mounted) context.showSnackBar('Task deleted successfully.');
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to delete task: $e', isError: true);
    }
  }
}
