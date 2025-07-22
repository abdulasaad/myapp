// lib/screens/tasks/standalone_tasks_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';
import './standalone_task_detail_screen.dart';
// --- FIX: Import the new creation screen we will be navigating to ---
import './create_evidence_task_screen.dart';
import './template_categories_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/modern_notification.dart';
import '../../services/profile_service.dart'; 

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
            .select('*, created_at')
            .filter('campaign_id', 'is', null) 
            .order('created_at', ascending: false);
        return response.map((json) => Task.fromJson(json)).toList();
      } else if (userRole == 'manager') {
        // Managers can see:
        // 1. Standalone tasks assigned to them directly (assigned_manager_id)
        // 2. Standalone tasks created by users in their shared groups
        
        // First, get tasks assigned directly to this manager
        final assignedTasksResponse = await supabase
            .from('tasks')
            .select('*, created_at')
            .filter('campaign_id', 'is', null)
            .eq('assigned_manager_id', currentUser.id)
            .order('created_at', ascending: false);
        
        final assignedTasks = assignedTasksResponse.map((json) => Task.fromJson(json)).toList();
        
        // Then get current manager's groups for group-based tasks
        final userGroupsResponse = await supabase
            .from('user_groups')
            .select('group_id')
            .eq('user_id', currentUser.id);
        
        final userGroupIds = userGroupsResponse
            .map((item) => item['group_id'] as String)
            .toSet();
        
        List<Task> groupTasks = [];
        
        if (userGroupIds.isNotEmpty) {
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

          if (allowedUserIds.isNotEmpty) {
            // Get standalone tasks created by users in the same groups
            final groupTasksResponse = await supabase
                .from('tasks')
                .select('*, created_at')
                .filter('campaign_id', 'is', null)
                .inFilter('created_by', allowedUserIds.toList())
                .order('created_at', ascending: false);
            
            groupTasks = groupTasksResponse.map((json) => Task.fromJson(json)).toList();
          }
        }
        
        // Combine assigned tasks and group tasks, removing duplicates
        final allTasks = <String, Task>{};
        
        // Add assigned tasks first (higher priority)
        for (final task in assignedTasks) {
          allTasks[task.id] = task;
        }
        
        // Add group tasks (won't overwrite assigned tasks due to map)
        for (final task in groupTasks) {
          allTasks[task.id] = task;
        }
        
        // Convert back to list and sort by creation date
        final resultTasks = allTasks.values.toList();
        resultTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        return resultTasks;
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
                Text(
                  AppLocalizations.of(context)!.createNewTask,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                _buildCreateOption(
                  icon: Icons.category,
                  title: AppLocalizations.of(context)!.fromTemplate,
                  subtitle: AppLocalizations.of(context)!.chooseFromProfessionalTemplates,
                  color: primaryColor,
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const TemplateCategoriesScreen()
                    ));
                    if (mounted) {
                      setState(() { _tasksFuture = _fetchTasks(); });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildCreateOption(
                  icon: Icons.file_present_rounded,
                  title: AppLocalizations.of(context)!.customTask,
                  subtitle: AppLocalizations.of(context)!.createCustomTaskDescription,
                  color: secondaryColor,
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const CreateEvidenceTaskScreen()
                    ));
                    if (mounted) {
                      setState(() { _tasksFuture = _fetchTasks(); });
                    }
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppLocalizations.of(context)!.taskManagement,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<Task>>(
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
                    AppLocalizations.of(context)!.errorLoadingTasks,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() { _tasksFuture = _fetchTasks(); }),
                    child: Text(AppLocalizations.of(context)!.retry),
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
                    AppLocalizations.of(context)!.noTasksYet,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.createFirstTaskToGetStarted,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: textSecondaryColor,
                      height: 1.5,
                    ),
                  ),
                  // Removed center creation button - using only FAB for consistency
                  // const SizedBox(height: 32),
                  // ElevatedButton.icon(
                  //   onPressed: _showCreateTaskMenu,
                  //   icon: const Icon(Icons.add),
                  //   label: const Text('Create Task'),
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: primaryColor,
                  //     foregroundColor: Colors.white,
                  //     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  //     shape: RoundedRectangleBorder(
                  //       borderRadius: BorderRadius.circular(12),
                  //     ),
                  //     elevation: 2,
                  //   ),
                  // ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async { setState(() { _tasksFuture = _fetchTasks(); }); },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                        if (mounted) {
                          setState(() { _tasksFuture = _fetchTasks(); });
                        }
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
                                        AppLocalizations.of(context)!.pointsFormat(task.points.toString()),
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
                                  if (mounted) {
                                    setState(() {
                                      _tasksFuture = _fetchTasks();
                                    });
                                  }
                                } else if (value == 'delete') {
                                  final shouldDelete = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: Text(AppLocalizations.of(context)!.confirmDelete),
                                      content: Text(AppLocalizations.of(context)!.confirmDeleteTaskMessage),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: Text(AppLocalizations.of(context)!.cancel),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(foregroundColor: errorColor),
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: Text(AppLocalizations.of(context)!.delete),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (shouldDelete == true) {
                                    await _deleteTask(task);
                                    if (mounted) {
                                      setState(() {
                                        _tasksFuture = _fetchTasks();
                                      });
                                    }
                                  }
                                }
                              },
                              itemBuilder: (BuildContext context) {
                                return [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit, size: 18),
                                        const SizedBox(width: 8),
                                        Text(AppLocalizations.of(context)!.editTask),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete, size: 18, color: errorColor),
                                        const SizedBox(width: 8),
                                        Text(AppLocalizations.of(context)!.deleteTask, style: const TextStyle(color: errorColor)),
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
          ),
        ],
      ),
      // Hide floating action button for client users (read-only access)
      floatingActionButton: ProfileService.instance.canEditData 
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: FloatingActionButton.extended(
                onPressed: _showCreateTaskMenu,
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context)!.newTask),
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 4,
              ),
            )
          : null, // Hide for clients
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
      
      if (mounted) {
        ModernNotification.success(
          context,
          message: AppLocalizations.of(context)!.taskDeletedSuccessfully,
        );
      }
    } catch (e) {
      if (mounted) {
        ModernNotification.error(
          context,
          message: AppLocalizations.of(context)!.failedToDeleteTask,
          subtitle: e.toString(),
        );
      }
    }
  }
}
