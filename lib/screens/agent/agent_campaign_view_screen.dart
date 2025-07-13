// lib/screens/agent/agent_campaign_view_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/models/campaign.dart';
import 'package:myapp/models/task_assignment.dart';
import 'package:myapp/utils/constants.dart';
import '../../l10n/app_localizations.dart';
import 'agent_touring_task_list_screen.dart';

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
        context.showSnackBar(AppLocalizations.of(context)!.taskStatusUpdated);
        setState(() {
          _myAssignmentsFuture = _fetchMyAssignments();
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.failedToUpdateStatus, isError: true);
      }
    }
  }

  // ===============================================
  //  UPDATED METHOD: UPLOAD EVIDENCE WITH CUSTOM NAME
  // ===============================================
  Future<void> _uploadEvidence(String assignmentId) async {
    // Show dialog to get evidence name and file
    String? evidenceTitle;
    XFile? selectedFile;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final titleController = TextEditingController();
        final formKey = GlobalKey<FormState>();
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context)!.uploadEvidence),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.evidenceName,
                        hintText: AppLocalizations.of(context)!.enterEvidenceName,
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? AppLocalizations.of(context)!.evidenceNameRequired
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
                                imageQuality: 80,
                                maxWidth: 1024,
                              );
                              if (imageFile != null) {
                                setState(() {
                                  selectedFile = imageFile;
                                });
                              }
                            },
                            icon: const Icon(Icons.attach_file),
                            label: Text(selectedFile == null
                                ? AppLocalizations.of(context)!.selectFile
                                : AppLocalizations.of(context)!.changeFile),
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
                            const Icon(Icons.file_present, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedFile!.name,
                                style: const TextStyle(color: Colors.black87),
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
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate() && selectedFile != null) {
                      evidenceTitle = titleController.text.trim();
                      Navigator.of(context).pop(true);
                    } else if (selectedFile == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectFile)),
                      );
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.upload),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || evidenceTitle == null || selectedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final fileBytes = await selectedFile!.readAsBytes();
      final mimeType = lookupMimeType(selectedFile!.path, headerBytes: fileBytes);
      final fileExt = mimeType?.split('/').last ?? 'jpeg';
      final fileName = '${supabase.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('task-evidence').uploadBinary(
        fileName, fileBytes, fileOptions: FileOptions(contentType: mimeType ?? 'image/jpeg'));

      final imageUrl = supabase.storage.from('task-evidence').getPublicUrl(fileName);

      // Store evidence with custom title in evidence table
      await supabase.from('evidence').insert({
        'task_assignment_id': assignmentId,
        'uploader_id': supabase.auth.currentUser!.id,
        'title': evidenceTitle!,
        'file_url': imageUrl,
      });

      // Also update evidence_urls for backward compatibility
      final currentAssignment = await supabase.from('task_assignments').select('evidence_urls').eq('id', assignmentId).single();
      final existingUrls = (currentAssignment['evidence_urls'] as List?)?.cast<String>() ?? [];
      existingUrls.add(imageUrl);

      await supabase
          .from('task_assignments')
          .update({'evidence_urls': existingUrls})
          .eq('id', assignmentId);
      
      if (mounted) context.showSnackBar('${AppLocalizations.of(context)!.evidenceUploadedSuccess}: "$evidenceTitle"');

    } catch (e) {
      if (mounted) context.showSnackBar('${AppLocalizations.of(context)!.errorUploadingEvidence}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.campaign.name),
        actions: [
          Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AgentTouringTaskListScreen(
                      campaign: widget.campaign,
                      agentId: supabase.auth.currentUser!.id,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.directions_walk, color: Colors.white, size: 30),
              tooltip: 'Touring Tasks',
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AgentTouringTaskListScreen(
                campaign: widget.campaign,
                agentId: supabase.auth.currentUser!.id,
              ),
            ),
          );
        },
        backgroundColor: Colors.red,
        icon: const Icon(Icons.directions_walk, color: Colors.white),
        label: const Text('TOURING TASKS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
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
                return Center(child: Text('${AppLocalizations.of(context)!.error}: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.noTasksAssigned,
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AgentTouringTaskListScreen(
                                campaign: widget.campaign,
                                agentId: supabase.auth.currentUser!.id,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.directions_walk, color: Colors.white),
                        label: const Text('VIEW TOURING TASKS', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                      ),
                    ],
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
                      subtitle: Text(AppLocalizations.of(context)!.pointsFormat(assignment.task.points.toString())),
                      // The upload button is now the trailing widget
                      trailing: IconButton(
                        icon: const Icon(Icons.upload_file),
                        tooltip: AppLocalizations.of(context)!.uploadEvidence,
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
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context)!.uploadingEvidence, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
