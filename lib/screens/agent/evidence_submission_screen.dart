// lib/screens/agent/evidence_submission_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';
// --- NEW: Import the full-screen viewer ---
import '../full_screen_image_viewer.dart'; 

// This model is correct and remains unchanged.
class Evidence {
  final String title;
  final String fileUrl;
  Evidence({required this.title, required this.fileUrl});
  factory Evidence.fromJson(Map<String, dynamic> json) => Evidence(title: json['title'], fileUrl: json['file_url']);
}

class EvidenceSubmissionScreen extends StatefulWidget {
  final Task task;
  const EvidenceSubmissionScreen({super.key, required this.task});

  @override
  State<EvidenceSubmissionScreen> createState() => _EvidenceSubmissionScreenState();
}

class _EvidenceSubmissionScreenState extends State<EvidenceSubmissionScreen> {
  late Future<List<Evidence>> _evidenceFuture;
  String _taskAssignmentId = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final assignment = await supabase.from('task_assignments').select('id').match({'task_id': widget.task.id, 'agent_id': supabase.auth.currentUser!.id}).single();
      _taskAssignmentId = assignment['id'];
      _evidenceFuture = _fetchEvidence();
    } catch(e) {
      if (mounted) context.showSnackBar('Error loading task assignment: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Evidence>> _fetchEvidence() async {
    final response = await supabase.from('evidence').select('title, file_url').eq('task_assignment_id', _taskAssignmentId).order('created_at', ascending: false);
    return response.map((json) => Evidence.fromJson(json)).toList();
  }

  // This entire method is correct and remains unchanged from your version.
  Future<void> _showUploadDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    File? imageFile;
    final BuildContext dialogContext = context;
    await showDialog(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Upload Evidence'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: titleController, decoration: const InputDecoration(labelText: 'Evidence Title'), validator: (v) => v!.isEmpty ? 'Required' : null),
                formSpacer,
                if (imageFile != null) Text('Selected: ${imageFile?.path.split('/').last}', style: const TextStyle(fontSize: 12)),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                    if (pickedFile != null) {
                      setDialogState(() => imageFile = File(pickedFile.path));
                    }
                  },
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach File'),
                ),
              ],
            ),
          )
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            if (formKey.currentState!.validate() && imageFile != null) {
              _uploadEvidence(titleController.text, imageFile!);
              Navigator.of(context).pop();
            }
          }, child: const Text('Upload')),
        ],
      ),
    );
  }
  
  // This method is also correct and remains unchanged.
  Future<void> _uploadEvidence(String title, File file) async {
    setState(() => _isLoading = true);
    try {
      final mimeType = lookupMimeType(file.path, headerBytes: await file.readAsBytes());
      final fileExt = extensionFromMime(mimeType ?? 'image/jpeg');
      final fileName = '${supabase.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      await supabase.storage.from('task-evidence').upload(fileName, file, fileOptions: FileOptions(contentType: mimeType));
      final fileUrl = supabase.storage.from('task-evidence').getPublicUrl(fileName);
      await supabase.from('evidence').insert({
        'task_assignment_id': _taskAssignmentId,
        'uploader_id': supabase.auth.currentUser!.id,
        'title': title,
        'file_url': fileUrl,
      });
      if(mounted) {
        context.showSnackBar('Evidence uploaded successfully.');
        setState(() => _evidenceFuture = _fetchEvidence());
      }
    } catch(e) {
      if (mounted) context.showSnackBar('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.task.title)),
      body: _isLoading ? preloader : FutureBuilder<List<Evidence>>(
        future: _evidenceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return preloader;
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final evidenceList = snapshot.data ?? [];
          final requiredCount = widget.task.requiredEvidenceCount ?? 1;
          final isComplete = evidenceList.length >= requiredCount;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.task.description ?? 'No description.'),
                    formSpacer,
                    Text('Location: ${widget.task.locationName ?? 'No location name'}'),
                    formSpacer,
                    LinearProgressIndicator(value: evidenceList.length / requiredCount),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('Progress: ${evidenceList.length} of $requiredCount uploaded'),
                    ),
                    if (isComplete)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('Task Complete!', style: TextStyle(color: Colors.green[400], fontWeight: FontWeight.bold)),
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
                        // --- THE FIX: The ListTile now navigates on tap ---
                        return ListTile(
                          leading: const Icon(Icons.file_present_rounded),
                          title: Text(evidence.title),
                          trailing: const Icon(Icons.visibility_outlined),
                          onTap: () {
                            // This is where we open the new screen
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => FullScreenImageViewer(
                                  imageUrl: evidence.fileUrl,
                                  // The heroTag must be unique per image
                                  heroTag: evidence.fileUrl, 
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadDialog,
        label: const Text('Upload Evidence'),
        icon: const Icon(Icons.upload_file),
      ),
    );
  }
}
