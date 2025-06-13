// lib/screens/tasks/standalone_tasks_screen.dart

import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';
import './standalone_task_detail_screen.dart';
// --- FIX: Import the new creation screen we will be navigating to ---
import './create_evidence_task_screen.dart'; 

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
    final response = await supabase
        .from('tasks')
        .select()
        .filter('campaign_id', 'is', null) 
        .order('created_at', ascending: false);
    return response.map((json) => Task.fromJson(json)).toList();
  }

  // --- NEW: A menu to choose which task template to use ---
  // This replaces the old _showCreateTaskDialog method entirely.
  void _showCreateTaskMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.file_present_rounded),
              title: const Text('Evidence Submission Task'),
              subtitle: const Text('Agent uploads files and can be geofenced.'),
              onTap: () async {
                Navigator.pop(context); // Close the sheet first
                
                // Navigate to the new, detailed creation screen
                await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreateEvidenceTaskScreen()));
                
                // After returning from the creation screen, refresh the list
                setState(() { _tasksFuture = _fetchTasks(); });
              },
            ),
            // You can add more ListTile widgets here for other task templates in the future
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Task>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return preloader;
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) return const Center(child: Text('No standalone tasks found. Create one!'));

          return RefreshIndicator(
            onRefresh: () async { setState(() { _tasksFuture = _fetchTasks(); }); },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.assignment_turned_in),
                    title: Text(task.title),
                    subtitle: Text('${task.points} points'),
                    trailing: PopupMenuButton<String>(
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
                              title: const Text('Confirm Delete'),
                              content: const Text('Are you sure you want to delete this task?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
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
                            child: Text('Edit Task Details'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete Task'),
                          ),
                        ];
                      },
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (context) => StandaloneTaskDetailScreen(task: task)));
                      setState(() { _tasksFuture = _fetchTasks(); });
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        // --- FIX: The button now calls the correct menu function ---
        onPressed: _showCreateTaskMenu,
        label: const Text('New Task'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await supabase.from('task_assignments').delete().eq('task_id', task.id);
      await supabase.from('evidence').delete().eq('task_assignment_id', task.id);
      await supabase.from('tasks').delete().eq('id', task.id);
      if (mounted) context.showSnackBar('Task deleted successfully.');
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to delete task: $e', isError: true);
    }
  }
}
