// lib/screens/agent/evidence_submission_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';
import '../../services/profile_service.dart';
import '../full_screen_image_viewer.dart';

class Evidence {
  final String id;
  final String title;
  final String fileUrl;

  Evidence({required this.id, required this.title, required this.fileUrl});

  factory Evidence.fromJson(Map<String, dynamic> json) => Evidence(
      id: json['id'], title: json['title'], fileUrl: json['file_url']);
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
  String _assignmentStatus = 'pending';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
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
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error loading task assignment: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _evidenceFuture = _fetchEvidence();
    }
  }

  Future<List<Evidence>> _fetchEvidence() async {
    final isManager = ProfileService.instance.canManageCampaigns;
    var query = supabase
        .from('evidence')
        .select('id, title, file_url');

    if (!isManager) {
      query = query.eq('task_assignment_id', _taskAssignmentId);
    } else {
      query = query.eq('task_id', widget.task.id);
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List<dynamic>).map<Evidence>((json) => Evidence.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> _deleteEvidence(Evidence evidence) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "${evidence.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(evidence.fileUrl);
      final filePath = uri.pathSegments.sublist(uri.pathSegments.indexOf('task-evidence') + 1).join('/');
      await supabase.storage.from('task-evidence').remove([filePath]);
      await supabase.from('evidence').delete().eq('id', evidence.id);
      
      if (mounted) {
        context.showSnackBar('Evidence deleted successfully.');
        final remainingEvidence = await _fetchEvidence();
        if (remainingEvidence.isEmpty && _assignmentStatus == 'completed') {
          await supabase.from('task_assignments').update({
            'status': 'pending',
            'completed_at': null,
          }).eq('id', _taskAssignmentId);

          if (mounted) {
            context.showSnackBar('Task status reverted to pending.');
            setState(() {
              _assignmentStatus = 'pending';
              _evidenceFuture = Future.value(remainingEvidence);
            });
          }
        } else {
           setState(() {
            _evidenceFuture = Future.value(remainingEvidence);
           });
        }
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to delete evidence: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markTaskAsCompleted() async {
    final shouldComplete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Completion'),
        content: const Text(
            'Are you sure you want to mark this task as done? This cannot be undone.'),
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

      if (mounted) {
        context.showSnackBar('Task marked as completed!');
        setState(() {
          _assignmentStatus = 'completed';
        });
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    await _showConfirmUploadDialog(imageFile);
  }

  Future<void> _showConfirmUploadDialog(XFile file) async {
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

  Future<void> _uploadEvidence(String title, XFile xFile) async {
    setState(() => _isLoading = true);
    try {
      final fileBytes = await xFile.readAsBytes();
      final mimeType = lookupMimeType(xFile.name, headerBytes: fileBytes);
      final fileExt = extensionFromMime(mimeType ?? 'image/jpeg');
      final fileName = '${supabase.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('task-evidence').uploadBinary(
            fileName,
            fileBytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
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
        setState(() {
          _evidenceFuture = _fetchEvidence();
        });
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
                final requiredCount = widget.task.requiredEvidenceCount!;
                final taskIsCompleted = _assignmentStatus == 'completed';

                final progressValue =
                    requiredCount > 0 ? evidenceList.length / requiredCount : 1.0;
                    
                // ===================================================================
                // THE FIX: Move the "Mark as Done" button to the bottomNavigationBar
                // of the Scaffold to prevent it from overlapping with the FAB.
                // ===================================================================
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
                    Text('Is Manager: ${ProfileService.instance.canManageCampaigns}'),
                    Expanded(
                      child: evidenceList.isEmpty
                          ? const Center(
                              child: Text('No evidence submitted yet.'))
                          : ListView.builder(
                              itemCount: evidenceList.length,
                              itemBuilder: (context, index) {
                                final evidence = evidenceList[index];
                                return ListTile(
                                  leading:
                                      const Icon(Icons.file_present_rounded),
                                  title: Text(evidence.title),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                            Icons.visibility_outlined),
                                        tooltip: 'View Evidence',
                                        onPressed: () {
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
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline,
                                            color: Colors.red[300]),
                                        tooltip: 'Delete Evidence',
                                        onPressed: () =>
                                            _deleteEvidence(evidence),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: FutureBuilder<List<Evidence>>(
        future: _evidenceFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink(); // Return nothing while loading
          }
          final evidenceList = snapshot.data!;
          final requiredCount = widget.task.requiredEvidenceCount!;
          final evidenceComplete = evidenceList.length >= requiredCount;
          final taskIsCompleted = _assignmentStatus == 'completed';

          if (evidenceComplete && !taskIsCompleted) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton.icon(
                onPressed: _markTaskAsCompleted,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark as Done'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                ),
              ),
            );
          }
          return const SizedBox.shrink(); // Return an empty box if conditions aren't met
        },
      ),
      floatingActionButton: _assignmentStatus == 'completed'
          ? null
          : FloatingActionButton.extended(
              onPressed: _pickFileAndShowUploadDialog,
              label: const Text('Upload Evidence'),
              icon: const Icon(Icons.upload_file),
            ),
    );
  }
}
