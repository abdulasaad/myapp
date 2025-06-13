// lib/screens/agent/evidence_submission_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';
import '../full_screen_image_viewer.dart';

class Evidence {
  final String title;
  final String fileUrl;
  Evidence({required this.title, required this.fileUrl});
  factory Evidence.fromJson(Map<String, dynamic> json) =>
      Evidence(title: json['title'], fileUrl: json['file_url']);
}

class EvidenceSubmissionScreen extends StatefulWidget {
  final Task task;
  const EvidenceSubmissionScreen({super.key, required this.task});

  @override
  State<EvidenceSubmissionScreen> createState() =>
      _EvidenceSubmissionScreenState();
}

class _EvidenceSubmissionScreenState extends State<EvidenceSubmissionScreen> {
  late Future<List<Evidence>> _evidenceFuture;
  String _taskAssignmentId = '';
  // ===================================================================
  // NEW: State variables to track assignment status
  // ===================================================================
  String _assignmentStatus = 'pending';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Also fetch the 'status' of the assignment
      final assignment = await supabase
          .from('task_assignments')
          .select('id, status')
          .match({
            'task_id': widget.task.id,
            'agent_id': supabase.auth.currentUser!.id
          })
          .single();
          
      _taskAssignmentId = assignment['id'];
      _assignmentStatus = assignment['status'];
      _evidenceFuture = _fetchEvidence();

    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error loading task assignment: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Evidence>> _fetchEvidence() async {
    final response = await supabase
        .from('evidence')
        .select('title, file_url')
        .eq('task_assignment_id', _taskAssignmentId)
        .order('created_at', ascending: false);
    return response.map((json) => Evidence.fromJson(json)).toList();
  }
  
  // ===================================================================
  // NEW: Function to mark the task as completed in the database
  // ===================================================================
  Future<void> _markTaskAsCompleted() async {
    final shouldComplete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Completion'),
        content: const Text('Are you sure you want to mark this task as done? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (shouldComplete != true || !mounted) {
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await supabase.from('task_assignments').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', _taskAssignmentId);

      if(mounted) {
        context.showSnackBar('Task marked as completed!');
        setState(() {
          _assignmentStatus = 'completed';
        });
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to update task: $e', isError: true);
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFileAndShowUploadDialog() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );

    if (imageFile == null || !mounted) return;
    await _showConfirmUploadDialog(imageFile); // Pass XFile directly
  }

  Future<void> _showConfirmUploadDialog(XFile file) async { // Accept XFile
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final dialogContext = context;

    await showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Add Evidence Title'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Evidence Title'),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final title = titleController.text;
                Navigator.of(context).pop();
                _uploadEvidence(title, file);
              }
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadEvidence(String title, XFile xFile) async { // Accept XFile
    setState(() => _isLoading = true);
    try {
      final fileBytes = await xFile.readAsBytes();
      String? mimeType = xFile.mimeType; // Provided by image_picker

      if (mimeType == null || mimeType.isEmpty) {
        // Fallback if image_picker doesn't provide it
        List<int> headerBytes = fileBytes.length > 256 ? fileBytes.sublist(0, 256) : fileBytes;
        mimeType = lookupMimeType(xFile.name, headerBytes: headerBytes);
      }
      
      final String finalMimeType = mimeType ?? 'image/jpeg'; // Default to image/jpeg

      String fileExt = extensionFromMime(finalMimeType); // Analyzer indicates extensionFromMime(finalMimeType) is not null.
      if (fileExt.isEmpty) { // If the result is an empty string, default to 'jpg'.
        fileExt = 'jpg'; // Ensure not empty and provide default.
      }
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt'; // Simplified filename

      await supabase.storage.from('task-evidence').uploadBinary(
            fileName,
            fileBytes,
            fileOptions: FileOptions(
                contentType: finalMimeType, 
                upsert: false, 
                cacheControl: 'max-age=3600'
            ),
          );

      final fileUrl =
          supabase.storage.from('task-evidence').getPublicUrl(fileName);

      await supabase.from('evidence').insert({
        'task_assignment_id': _taskAssignmentId,
        'uploader_id': supabase.auth.currentUser!.id,
        'title': title,
        'file_url': fileUrl,
      });

      if (mounted) {
        context.showSnackBar('Evidence uploaded successfully.');
        
        // Re-fetch evidence to update the list and count for UI
        List<Evidence> updatedEvidenceList = await _fetchEvidence();
        _evidenceFuture = Future.value(updatedEvidenceList);
        
        // Check if task completion criteria are met after upload
        final requiredCount = widget.task.requiredEvidenceCount ?? 1;
        final bool evidenceNowComplete = updatedEvidenceList.length >= requiredCount;
        
        // If all evidence is uploaded and task is not yet marked completed in DB, mark it.
        if (evidenceNowComplete && _assignmentStatus != 'completed') {
          // Call _markTaskAsCompleted but without the dialog, as this is an automatic step.
          // We need to inline the core logic of _markTaskAsCompleted or refactor it.
          // For now, let's inline the DB update part.
          // Note: _markTaskAsCompleted shows a dialog, which we don't want here.
          // We'll directly update the status.
          try {
            await supabase.from('task_assignments').update({
              'status': 'completed',
              'completed_at': DateTime.now().toIso8601String(),
            }).eq('id', _taskAssignmentId);
            _assignmentStatus = 'completed'; // Update local status
            // No separate snackbar here, as _markTaskAsCompleted might show its own if called manually.
          } catch (e) {
            // Log or handle error if automatic status update fails
            if (mounted) context.showSnackBar('Failed to auto-update task status: $e', isError: true);
          }
        }
        setState(() {}); // Trigger a rebuild to update the UI
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.task.title)),
      body: _isLoading
          ? preloader
          : FutureBuilder<List<Evidence>>(
              future: _evidenceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return preloader;
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final evidenceList = snapshot.data ?? [];
                final requiredCount = widget.task.requiredEvidenceCount ?? 1;
                // Evidence upload is complete
                final evidenceComplete = evidenceList.length >= requiredCount;
                // The entire task assignment is marked as completed in the DB
                final taskIsCompleted = _assignmentStatus == 'completed';

                final progressValue = requiredCount > 0
                    ? evidenceList.length / requiredCount
                    : 1.0;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.task.description ?? 'No description.'),
                          formSpacer,
                          Text(
                              'Location: ${widget.task.locationName ?? 'No location name'}'),
                          formSpacer,
                          LinearProgressIndicator(value: progressValue),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                                'Progress: ${evidenceList.length} of $requiredCount uploaded'),
                          ),
                          if (taskIsCompleted)
                             Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('Status: Completed',
                                  style: TextStyle(
                                      color: Colors.green[400],
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: evidenceList.isEmpty
                          ? const Center(child: Text('No evidence submitted yet.'))
                          : ListView.builder(
                              itemCount: evidenceList.length,
                              itemBuilder: (context, index) {
                                final evidence = evidenceList[index];
                                return ListTile(
                                  leading:
                                      const Icon(Icons.file_present_rounded),
                                  title: Text(evidence.title),
                                  trailing:
                                      const Icon(Icons.visibility_outlined),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            FullScreenImageViewer(
                                          imageUrl: evidence.fileUrl,
                                          heroTag: evidence.fileUrl,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                    // ===================================================================
                    // NEW: Conditionally show the "Mark as Done" button
                    // ===================================================================
                    if (evidenceComplete && !taskIsCompleted)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton.icon(
                          onPressed: _markTaskAsCompleted,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Mark as Done'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.green,
                          ),
                        ),
                      )
                  ],
                );
              },
            ),
      floatingActionButton: _assignmentStatus == 'completed'
        ? null // Hide FAB if task is already completed
        : FloatingActionButton.extended(
            onPressed: _pickFileAndShowUploadDialog,
            label: const Text('Upload Evidence'),
            icon: const Icon(Icons.upload_file),
          ),
    );
  }
}
