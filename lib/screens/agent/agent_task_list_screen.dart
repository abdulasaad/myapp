// lib/screens/agent/agent_task_list_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';
import '../../models/campaign.dart';
import '../../utils/constants.dart';
import 'dart:io'; // For XFile if not already imported, though image_picker brings it.

// New class to hold structured evidence details
class EvidenceDetails {
  final String title;
  final String url;
  // final String? id; // Optional: if you need to reference the evidence record's ID

  EvidenceDetails({required this.title, required this.url});

  factory EvidenceDetails.fromJson(Map<String, dynamic> json) {
    return EvidenceDetails(
      title: json['title'] ?? 'Untitled Evidence', // Provide a default if title is missing
      url: json['file_url'] ?? json['url'] ?? '', // Support 'file_url' or 'url'
      // id: json['id'],
    );
  }
}

class AgentTask {
  final String taskId;
  final String? taskAssignmentId; // Important for linking to evidence table directly if needed
  final String title;
  final String? description;
  final int points;
  final String status;
  final List<EvidenceDetails> evidenceItems; // Changed from List<String>

  AgentTask.fromJson(Map<String, dynamic> json)
      : taskId = json['task_id'],
        taskAssignmentId = json['task_assignment_id'], // Expecting this from RPC
        title = json['title'],
        description = json['description'],
        points = json['points'] ?? 0,
        status = json['assignment_status'],
        // Assuming 'evidence_items' is now a list of JSON objects from the RPC
        evidenceItems = (json['evidence_items'] as List<dynamic>?)
                ?.map((item) => EvidenceDetails.fromJson(item as Map<String, dynamic>))
                .toList() ??
            []; // Default to empty list if null
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

  Future<String?> _getTaskAssignmentId(String taskId) async {
    try {
      final response = await supabase
          .from('task_assignments')
          .select('id')
          .match({'task_id': taskId, 'agent_id': supabase.auth.currentUser!.id})
          .single(); // Assuming one assignment per agent per task
      return response['id'] as String?;
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error fetching task assignment ID: $e', isError: true);
      }
      return null;
    }
  }

  Future<String?> _showEvidenceNameDialog(XFile file) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    // Use a local variable for context to avoid issues if the widget is disposed during async gaps.
    final dialogContext = context;

    return await showDialog<String>(
      context: dialogContext,
      barrierDismissible: false, // User must explicitly cancel or submit
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Name Your Evidence'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Evidence Name/Title'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name for the evidence.';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(null); // Return null when cancelled
              },
            ),
            ElevatedButton(
              child: const Text('Confirm & Upload'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(titleController.text); // Return the title
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadEvidence(AgentTask task) async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (imageFile == null || !mounted) return;

    // Get the name for the evidence
    final String? evidenceName = await _showEvidenceNameDialog(imageFile);
    if (evidenceName == null || evidenceName.isEmpty || !mounted) {
      // User cancelled or dialog returned no name
      return;
    }

    // Get task_assignment_id
    final String? taskAssignmentId = await _getTaskAssignmentId(task.taskId);
    if (taskAssignmentId == null || !mounted) {
        context.showSnackBar('Could not find task assignment. Upload failed.', isError: true);
        return;
    }

    try {
      final fileBytes = await imageFile.readAsBytes();
      final mimeType = lookupMimeType(imageFile.path, headerBytes: fileBytes);
      final fileExt = extensionFromMime(mimeType ?? 'image/jpeg');
      // Using a more unique filename, though title is stored in DB.
      final fileName = 'evidence/${taskAssignmentId}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('task-evidence').uploadBinary(
        fileName, fileBytes, fileOptions: FileOptions(contentType: mimeType ?? 'image/jpeg'));
      
      final imageUrl = supabase.storage.from('task-evidence').getPublicUrl(fileName);

      // Insert into evidence table instead of updating task_assignments.evidence_urls
      await supabase.from('evidence').insert({
        'task_assignment_id': taskAssignmentId,
        'uploader_id': supabase.auth.currentUser!.id,
        'title': evidenceName,
        'file_url': imageUrl,
        // 'task_id': task.taskId, // Add if your 'evidence' table schema requires it directly
      });
      
      if(mounted) context.showSnackBar('Evidence "$evidenceName" uploaded successfully!');
      _refreshTasks(); // This will eventually need to re-fetch evidence from the new table structure
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
                if (task.evidenceItems.isNotEmpty) ...[
                  const Text('Uploaded Evidence:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120, // Increased height to accommodate title and image
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: task.evidenceItems.length,
                      itemBuilder: (context, index) {
                        final evidence = task.evidenceItems[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12.0), // Added some spacing
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center, // Center title below image
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // Optional: Implement full-screen image view if needed
                                  // Consider using the existing FullScreenImageViewer if available
                                  // Example: if (FullScreenImageViewer != null) {
                                  //   Navigator.of(context).push(MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: evidence.url, heroTag: evidence.url)));
                                  // }
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.network(
                                    evidence.url,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 80, height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8.0),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.error_outline, color: Colors.red[300], size: 24),
                                            const SizedBox(height:4),
                                            Text("No Preview", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                          ],
                                        )
                                      ),
                                    loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 80, height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8.0),
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.0,
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 80, // Match image width
                                child: Text(
                                  evidence.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2, // Allow title to wrap to two lines
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Upload Evidence'),
                      onPressed: isCompleted ? null : () => _uploadEvidence(task),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isCompleted ? null : () => _markTaskAsCompleted(task),
                      child: const Text('Mark Done'),
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