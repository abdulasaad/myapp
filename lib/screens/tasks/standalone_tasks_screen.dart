// lib/screens/tasks/standalone_tasks_screen.dart

import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';
import './standalone_task_detail_screen.dart';

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
        // --- FIX: Use the correct .filter() syntax for NULL checks ---
        .filter('campaign_id', 'is', null) 
        .order('created_at', ascending: false);
    return response.map((json) => Task.fromJson(json)).toList();
  }

  Future<void> _showCreateTaskDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final pointsController = TextEditingController();
    final descriptionController = TextEditingController();

    // Show the dialog and wait for it to pop with a true/false result
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Standalone Task'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: titleController, decoration: const InputDecoration(labelText: 'Task Title'), validator: (v) => v!.isEmpty ? 'Required' : null),
              formSpacer,
              TextFormField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description (Optional)')),
              formSpacer,
              TextFormField(controller: pointsController, decoration: const InputDecoration(labelText: 'Points'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await supabase.from('tasks').insert({
                  'title': titleController.text,
                  'description': descriptionController.text,
                  'points': int.parse(pointsController.text),
                  'created_by': supabase.auth.currentUser!.id,
                });
                // Ensure the context is still valid before popping.
                if (mounted && context.mounted) Navigator.of(context).pop(true);
              }
            },
            child: const Text('Create Task'),
          )
        ],
      ),
    );

    // --- FIX: Check for the result AND if the widget is still mounted ---
    // This resolves the "Don't use 'BuildContext's across async gaps" warning.
    if (result == true && mounted) {
      context.showSnackBar('Task created successfully!');
      setState(() { _tasksFuture = _fetchTasks(); });
    }
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
                    title: Text(task.title),
                    subtitle: Text('${task.points} points'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      // It's safe to use context before an await
                      await Navigator.of(context).push(MaterialPageRoute(builder: (context) => StandaloneTaskDetailScreen(task: task)));
                      // Refresh list when returning
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
        onPressed: _showCreateTaskDialog,
        label: const Text('New Task'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
