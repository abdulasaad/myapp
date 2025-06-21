// lib/screens/agent/agent_task_list_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';
import '../../models/campaign.dart';
import '../../utils/constants.dart';

class AgentTask {
  final String taskId;
  final String title;
  final String? description;
  final int points;
  final String status;
  final List<String> evidenceUrls;

  AgentTask.fromJson(Map<String, dynamic> json)
      : taskId = json['task_id'],
        title = json['title'],
        description = json['description'],
        points = json['points'] ?? 0,
        status = json['assignment_status'],
        evidenceUrls = List<String>.from(json['evidence_urls'] ?? []);
}

class AgentTaskListScreen extends StatefulWidget {
  final Campaign campaign;
  const AgentTaskListScreen({super.key, required this.campaign});

  @override
  State<AgentTaskListScreen> createState() => _AgentTaskListScreenState();
}

class _AgentTaskListScreenState extends State<AgentTaskListScreen> {
  late Future<List<AgentTask>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _tasksFuture = _fetchAgentTasks();
  }

  Future<List<AgentTask>> _fetchAgentTasks() {
    return supabase.rpc('get_agent_tasks_for_campaign', params: {'p_campaign_id': widget.campaign.id})
      .then((response) {
        final data = response as List;
        return data.map((json) => AgentTask.fromJson(json.cast<String, dynamic>())).toList();
      });
  }

  void _refreshTasks() {
    setState(() {
      _tasksFuture = _fetchAgentTasks();
    });
  }

  Future<void> _uploadEvidence(AgentTask task) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    XFile? selectedFile;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Upload Evidence'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Evidence Name',
                    hintText: 'Enter evidence name',
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Evidence name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final imageFile = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                          );
                          if (imageFile != null) {
                            setState(() {
                              selectedFile = imageFile;
                            });
                          }
                        },
                        icon: const Icon(Icons.attach_file),
                        label: Text(selectedFile == null
                            ? 'Select File'
                            : 'Change File'),
                      ),
                    ),
                  ],
                ),
                if (selectedFile != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedFile!.name,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedFile == null
                  ? null
                  : () {
                      if (formKey.currentState!.validate()) {
                        final title = titleController.text;
                        Navigator.of(context).pop();
                        _performUpload(task, title, selectedFile!);
                      }
                    },
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performUpload(AgentTask task, String title, XFile imageFile) async {
    try {
      final fileBytes = await imageFile.readAsBytes();
      final mimeType = lookupMimeType(imageFile.path, headerBytes: fileBytes);
      final fileExt = extensionFromMime(mimeType ?? 'image/jpeg');
      final fileName = '${supabase.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('task-evidence').uploadBinary(
        fileName, fileBytes, fileOptions: FileOptions(contentType: mimeType ?? 'image/jpeg'));
      
      final imageUrl = supabase.storage.from('task-evidence').getPublicUrl(fileName);
      
      // Get the task assignment ID for the evidence table
      final taskAssignmentResponse = await supabase
          .from('task_assignments')
          .select('id')
          .match({'task_id': task.taskId, 'agent_id': supabase.auth.currentUser!.id})
          .maybeSingle();
      
      final taskAssignmentId = taskAssignmentResponse?['id'];
      
      if (taskAssignmentId != null) {
        // Store evidence with custom title in evidence table
        await supabase.from('evidence').insert({
          'task_assignment_id': taskAssignmentId,
          'uploader_id': supabase.auth.currentUser!.id,
          'title': title,
          'file_url': imageUrl,
        });
      }
      
      // Also update the evidence_urls for backward compatibility
      final updatedUrls = List<String>.from(task.evidenceUrls)..add(imageUrl);
      await supabase.from('task_assignments').update({'evidence_urls': updatedUrls})
          .match({'task_id': task.taskId, 'agent_id': supabase.auth.currentUser!.id});
      
      if(mounted) context.showSnackBar('Evidence "$title" uploaded successfully!');
      _refreshTasks();
    } catch (e) {
      if(mounted) context.showSnackBar('Failed to upload evidence: $e', isError: true);
    }
  }

  Future<void> _markTaskAsCompleted(AgentTask task) async {
    final shouldComplete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Completion'),
        content: const Text('Are you sure you want to mark this task as complete?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirm')),
        ],
      ),
    );

    if (shouldComplete != true) {
      return;
    }

    try {
      await supabase.from('task_assignments')
          .update({'status': 'completed', 'completed_at': DateTime.now().toIso8601String()})
          .match({'task_id': task.taskId, 'agent_id': supabase.auth.currentUser!.id});
      
      if(mounted) context.showSnackBar('Task marked as completed!');
      _refreshTasks();

    } catch (e) {
      if(mounted) context.showSnackBar('Failed to update task: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.campaign.name)),
      body: Column(
        children: [
          _buildInfoCard(),
          const Divider(),
          Expanded(
            child: FutureBuilder<List<AgentTask>>(
              future: _tasksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return preloader;
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                
                // --- THE FIX: Check for data presence and emptiness BEFORE declaring the variable ---
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No tasks found for this campaign.'));
                }

                // Now it's safe to declare and use the 'tasks' variable
                final tasks = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: () async => _refreshTasks(),
                  child: ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final isCompleted = task.status == 'completed';
                      return _buildTaskTile(task, isCompleted);
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

  Widget _buildTaskTile(AgentTask task, bool isCompleted) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isCompleted ? Colors.green.withAlpha(50) : null,
      child: ExpansionTile(
        leading: Icon(
          isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isCompleted ? Colors.green : Colors.grey,
        ),
        title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${task.points} points'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.description != null && task.description!.isNotEmpty)
                  Text(task.description!),
                const SizedBox(height: 16),
                Text('Status: ${task.status.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (task.evidenceUrls.isNotEmpty) ...[
                  const Text('Uploaded Evidence:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: task.evidenceUrls.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Image.network(task.evidenceUrls[index], width: 80, height: 80, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Upload Evidence'),
                        onPressed: isCompleted ? null : () => _uploadEvidence(task),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isCompleted ? null : () => _markTaskAsCompleted(task),
                        child: const Text('Mark Done'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Campaign Details', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(widget.campaign.description ?? 'No description available.'),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.calendar_today, size: 16),
              const SizedBox(height: 4),
              Text(DateFormat.yMMMd().format(widget.campaign.endDate)),
            ],
          )
        ],
      ),
    );
  }
}
