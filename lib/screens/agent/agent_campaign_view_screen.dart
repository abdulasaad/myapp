// lib/screens/agent/agent_campaign_view_screen.dart

import 'dart:io'; // NEW IMPORT for file handling
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // NEW IMPORT for picking images
import 'package:myapp/models/campaign.dart';
import 'package:myapp/models/task_assignment.dart';
import 'package:myapp/utils/constants.dart';

class AgentCampaignViewScreen extends StatefulWidget {
  final Campaign campaign;
  const AgentCampaignViewScreen({super.key, required this.campaign});

  @override
  State<AgentCampaignViewScreen> createState() =>
      _AgentCampaignViewScreenState();
}

class _AgentCampaignViewScreenState extends State<AgentCampaignViewScreen> {
  late Future<List<TaskAssignment>> _myAssignmentsFuture;
  // NEW state variable to manage the loading overlay
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _myAssignmentsFuture = _fetchMyAssignments();
  }

  // This method is unchanged from your version
  Future<List<TaskAssignment>> _fetchMyAssignments() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return [];
    final response = await supabase
        .from('task_assignments')
        .select('*, tasks(*)')
        .eq('agent_id', currentUser.id)
        .eq('tasks.campaign_id', widget.campaign.id);
    return response.map((json) => TaskAssignment.fromJson(json)).toList();
  }

  // This method is unchanged from your version
  Future<void> _updateTaskStatus(String assignmentId, String newStatus) async {
    try {
      await supabase
          .from('task_assignments')
          .update({'status': newStatus})
          .eq('id', assignmentId);

      if (mounted) {
        context.showSnackBar('Task status updated!');
        setState(() {
          _myAssignmentsFuture = _fetchMyAssignments();
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to update status.', isError: true);
      }
    }
  }

  // ===============================================
  //  NEW METHOD: UPLOAD EVIDENCE
  // ===============================================
  Future<void> _uploadEvidence(String assignmentId) async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery, // Or use ImageSource.camera
      maxWidth: 800,
      imageQuality: 85,
    );

    if (imageFile == null) return; // User cancelled the picker

    setState(() => _isUploading = true);

    try {
      final file = File(imageFile.path);
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      // The path in the bucket uses the assignmentId as a folder.
      // This is secure because our RLS policies check this folder name.
      final filePath = '$assignmentId/$fileName';

      await supabase.storage.from('task-evidence').upload(filePath, file);

      // Get the public URL and update the task_assignments table.
      final imageUrl = supabase.storage.from('task-evidence').getPublicUrl(filePath);

      final currentAssignment = await supabase.from('task_assignments').select('evidence_urls').eq('id', assignmentId).single();
      final existingUrls = (currentAssignment['evidence_urls'] as List?)?.cast<String>() ?? [];
      existingUrls.add(imageUrl);

      await supabase
          .from('task_assignments')
          .update({'evidence_urls': existingUrls})
          .eq('id', assignmentId);
      
      if (mounted) context.showSnackBar('Evidence uploaded successfully!');

    } catch (e) {
      if (mounted) context.showSnackBar('Error uploading evidence: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.campaign.name)),
      // NEW: A Stack allows us to place the loading indicator ON TOP of the list
      body: Stack(
        children: [
          FutureBuilder<List<TaskAssignment>>(
            future: _myAssignmentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return preloader;
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'You have not been assigned any tasks for this campaign.',
                  ),
                );
              }

              final assignments = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: assignments.length,
                itemBuilder: (context, index) {
                  final assignment = assignments[index];
                  final isCompleted = assignment.status == 'completed';

                  // ===============================================
                  //  MODIFIED: The ListTile now has an upload button
                  // ===============================================
                  return Card(
                    elevation: isCompleted ? 1 : 4,
                    color: isCompleted ? Colors.grey[800] : cardBackgroundColor,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      // Using a Checkbox is more intuitive for status changes
                      leading: Checkbox(
                        value: isCompleted,
                        onChanged: (bool? value) {
                           final newStatus = (value ?? false) ? 'completed' : 'pending';
                           _updateTaskStatus(assignment.id, newStatus);
                        },
                        activeColor: Colors.green,
                        side: const BorderSide(color: Colors.white),
                      ),
                      title: Text(assignment.task.title),
                      subtitle: Text('${assignment.task.points} pts'),
                      // The upload button is now the trailing widget
                      trailing: IconButton(
                        icon: const Icon(Icons.upload_file),
                        tooltip: 'Upload Evidence',
                        onPressed: () => _uploadEvidence(assignment.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          // NEW: The loading indicator overlay
          if (_isUploading)
            Container(
              color: Colors.black.withValues(red: 0, green: 0, blue: 0, alpha: 0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Uploading evidence...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
