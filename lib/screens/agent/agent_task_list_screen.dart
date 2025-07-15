// lib/screens/agent/agent_task_list_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';
import '../../models/campaign.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';
import '../../services/location_service.dart';
import '../../services/task_assignment_service.dart';
import '../../l10n/app_localizations.dart';
import 'guided_task_screen.dart';
import 'agent_touring_task_list_screen.dart';

class AgentTask {
  final String taskId;
  final String title;
  final String? description;
  final int points;
  final String status;
  final List<String> evidenceUrls;
  final bool? enforceGeofence;
  final int? requiredEvidenceCount;

  AgentTask.fromJson(Map<String, dynamic> json)
      : taskId = json['task_id'],
        title = json['title'],
        description = json['description'],
        points = json['points'] ?? 0,
        status = json['assignment_status'],
        evidenceUrls = List<String>.from(json['evidence_urls'] ?? []),
        enforceGeofence = json['enforce_geofence'],
        requiredEvidenceCount = json['required_evidence_count'];
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

  Future<List<AgentTask>> _fetchAgentTasks() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('No authenticated user');

      // First, get all tasks in this campaign
      final tasksResponse = await supabase
          .from('tasks')
          .select('''
            id,
            title,
            description,
            points,
            enforce_geofence,
            required_evidence_count
          ''')
          .eq('campaign_id', widget.campaign.id);

      final List<AgentTask> agentTasks = [];

      for (final taskData in tasksResponse) {
        final taskId = taskData['id'] as String;
        
        // Use TaskAssignmentService to check access and get status
        final canAccess = await TaskAssignmentService().canAgentAccessTask(taskId, userId);
        
        if (canAccess) {
          // Get the assignment status using the updated logic
          final status = await TaskAssignmentService().getTaskAssignmentStatus(taskId, userId) ?? 'not_assigned';
          
          // Get evidence URLs from task_assignments if they exist
          final assignmentResponse = await supabase
              .from('task_assignments')
              .select('evidence_urls')
              .eq('task_id', taskId)
              .eq('agent_id', userId)
              .maybeSingle();
          
          final evidenceUrls = assignmentResponse?['evidence_urls'] ?? [];

          agentTasks.add(AgentTask.fromJson({
            'task_id': taskId,
            'assignment_status': status,
            'evidence_urls': evidenceUrls,
            'title': taskData['title'],
            'description': taskData['description'],
            'points': taskData['points'] ?? 0,
            'enforce_geofence': taskData['enforce_geofence'],
            'required_evidence_count': taskData['required_evidence_count'],
          }));
        }
      }

      return agentTasks;
    } catch (e) {
      debugPrint('Error fetching agent tasks: $e');
      rethrow;
    }
  }

  void _refreshTasks() {
    setState(() {
      _tasksFuture = _fetchAgentTasks();
    });
  }

  Future<void> _uploadEvidence(AgentTask task) async {
    debugPrint('🔍 _uploadEvidence called for task: ${task.title}');
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    XFile? selectedFile;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                          debugPrint('📸 File picker button tapped');
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
              child: Text(AppLocalizations.of(context)!.cancel),
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
              child: Text(AppLocalizations.of(context)!.upload),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performUpload(AgentTask task, String title, XFile imageFile) async {
    try {
      // Check geofence validation if enforcement is enabled
      if (task.enforceGeofence == true) {
        if (mounted) {
          context.showSnackBar(AppLocalizations.of(context)!.checkingLocation, isError: false);
        }
        
        final locationService = LocationService();
        final isInGeofence = await locationService.isAgentInTaskGeofence(task.taskId);
        
        if (!isInGeofence) {
          if (mounted) {
            context.showSnackBar(
              AppLocalizations.of(context)!.geofenceValidationFailed,
              isError: true
            );
          }
          return;
        }
        
        if (mounted) {
          context.showSnackBar(AppLocalizations.of(context)!.locationVerified, isError: false);
        }
      }

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

        // Update assignment status to in_progress if it's currently assigned
        await TaskAssignmentService().updateAssignmentStatusOnEvidence(taskAssignmentId);
        
        // Check if task should be auto-completed
        await TaskAssignmentService().checkTaskCompletion(taskAssignmentId);
      }
      
      // Also update the evidence_urls for backward compatibility
      final updatedUrls = List<String>.from(task.evidenceUrls)..add(imageUrl);
      await supabase.from('task_assignments').update({'evidence_urls': updatedUrls})
          .match({'task_id': task.taskId, 'agent_id': supabase.auth.currentUser!.id});
      
      if(mounted) context.showSnackBar('${AppLocalizations.of(context)!.evidenceUploadedSuccess}: "$title"');
      _refreshTasks();
    } catch (e) {
      if(mounted) context.showSnackBar('Upload failed: $e', isError: true);
    }
  }

  Future<void> _markTaskAsCompleted(AgentTask task) async {
    // Check if evidence is required but not uploaded
    final requiredEvidence = task.requiredEvidenceCount ?? 0;
    final uploadedEvidence = task.evidenceUrls.length;
    
    if (requiredEvidence > 0 && uploadedEvidence < requiredEvidence) {
      // Show error dialog if evidence is missing
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.evidenceRequired),
          content: Text(
            AppLocalizations.of(context)!.evidenceRequiredMessage(requiredEvidence, uploadedEvidence)
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.ok),
            ),
          ],
        ),
      );
      return;
    }

    final shouldComplete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirmCompletion),
        content: Text(
          requiredEvidence > 0 
              ? 'You have uploaded $uploadedEvidence/$requiredEvidence required evidence files.\n\nAre you sure you want to mark this task as complete?'
              : 'Are you sure you want to mark this task as complete?'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: Text(AppLocalizations.of(context)!.confirm)),
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
      
      if(mounted) context.showSnackBar(AppLocalizations.of(context)!.taskCompletedSuccess);
      _refreshTasks();

    } catch (e) {
      if(mounted) context.showSnackBar('Failed to update task: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Modern Title Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  // Title Row with Back Button
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.campaign.name,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            _buildCampaignHeader(),
            Expanded(
            child: FutureBuilder<List<AgentTask>>(
              future: _tasksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(AppLocalizations.of(context)!.loading),
                      ],
                    ),
                  );
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text('${AppLocalizations.of(context)!.error}: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshTasks,
                          child: Text(AppLocalizations.of(context)!.retry),
                        ),
                      ],
                    ),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  // Automatically navigate to touring tasks if no regular tasks
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => AgentTouringTaskListScreen(
                          campaign: widget.campaign,
                          agentId: supabase.auth.currentUser!.id,
                        ),
                      ),
                    );
                  });
                  return const Center(child: CircularProgressIndicator());
                }

                final tasks = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: () async => _refreshTasks(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _buildModernTaskCard(task, index);
                    },
                  ),
                );
              },
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTaskCard(AgentTask task, int index) {
    final isCompleted = task.status == 'completed';
    final isPending = task.status == 'pending';
    final progress = _calculateTaskProgress(task);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isCompleted 
                ? LinearGradient(
                    colors: [Colors.green[50]!, Colors.green[100]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : isPending
                  ? LinearGradient(
                      colors: [Colors.orange[50]!, Colors.orange[100]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with task number and status
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCompleted 
                            ? Colors.green 
                            : isPending 
                                ? Colors.orange 
                                : Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: isCompleted 
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : isPending
                                ? const Icon(Icons.hourglass_empty, color: Colors.white, size: 18)
                                : Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? Colors.green[800] : Colors.black87,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.stars,
                                size: 16,
                                color: Colors.orange[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppLocalizations.of(context)!.pointsFormat(task.points.toString()),
                                style: TextStyle(
                                  color: Colors.orange[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(task.status).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getStatusColor(task.status).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  _getLocalizedStatus(task.status, context).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(task.status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Description
                if (task.description != null && task.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    task.description!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
                
                // Pending status warning
                if (isPending) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.taskAssignmentPendingApproval,
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Progress indicator (only show if not pending)
                if (!isPending) ...[
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.progress,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: progress == 1.0 ? Colors.green : Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress == 1.0 ? Colors.green : Theme.of(context).primaryColor,
                        ),
                        minHeight: 6,
                      ),
                    ],
                  ),
                ],
                
                // Evidence preview and requirements (only show if not pending)
                if (!isPending) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.photo_library, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        task.requiredEvidenceCount != null && task.requiredEvidenceCount! > 0
                            ? AppLocalizations.of(context)!.evidenceRequiredFormat(task.evidenceUrls.length.toString(), task.requiredEvidenceCount.toString())
                            : AppLocalizations.of(context)!.evidenceFilesFormat(task.evidenceUrls.length.toString()),
                        style: TextStyle(
                          fontSize: 12,
                          color: task.requiredEvidenceCount != null && 
                                 task.requiredEvidenceCount! > 0 && 
                                 task.evidenceUrls.length < task.requiredEvidenceCount!
                              ? Colors.orange[700]
                              : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (task.requiredEvidenceCount != null && 
                          task.requiredEvidenceCount! > 0 && 
                          task.evidenceUrls.length < task.requiredEvidenceCount!) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Colors.orange[700],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: task.evidenceUrls.length,
                      itemBuilder: (context, index) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            task.evidenceUrls[index],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[200],
                              child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                
                // Action buttons
                const SizedBox(height: 20),
                if (isPending) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hourglass_empty, color: Colors.orange[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.awaitingManagerApproval,
                          style: TextStyle(
                            color: Colors.orange[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isCompleted) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.taskCompleted,
                          style: TextStyle(
                            color: Colors.green[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (!isCompleted) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GuidedTaskScreen(
                              task: Task(
                                id: task.taskId,
                                title: task.title,
                                description: task.description,
                                points: task.points,
                                status: task.status,
                                createdAt: DateTime.now(), // Use current time as fallback
                                campaignId: widget.campaign.id,
                                enforceGeofence: task.enforceGeofence,
                              ),
                            ),
                          ),
                        );
                        if (result == true) {
                          _refreshTasks();
                        }
                      },
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: Text(AppLocalizations.of(context)!.startGuidedTask),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _uploadEvidence(task),
                          icon: const Icon(Icons.cloud_upload, size: 18),
                          label: Text(AppLocalizations.of(context)!.quickUpload),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final requiredEvidence = task.requiredEvidenceCount ?? 0;
                            final uploadedEvidence = task.evidenceUrls.length;
                            
                            if (requiredEvidence > 0 && uploadedEvidence < requiredEvidence) {
                              // Show tooltip-like message for disabled button
                              context.showSnackBar(
                                AppLocalizations.of(context)!.uploadMoreEvidenceFormat((requiredEvidence - uploadedEvidence).toString()),
                                isError: true,
                              );
                            } else {
                              _markTaskAsCompleted(task);
                            }
                          },
                          icon: Icon(
                            Icons.check_circle, 
                            size: 18,
                            color: () {
                              final requiredEvidence = task.requiredEvidenceCount ?? 0;
                              final uploadedEvidence = task.evidenceUrls.length;
                              if (requiredEvidence > 0 && uploadedEvidence < requiredEvidence) {
                                return Colors.grey;
                              }
                              return null;
                            }(),
                          ),
                          label: Text(
                            AppLocalizations.of(context)!.markDone,
                            style: TextStyle(
                              color: () {
                                final requiredEvidence = task.requiredEvidenceCount ?? 0;
                                final uploadedEvidence = task.evidenceUrls.length;
                                if (requiredEvidence > 0 && uploadedEvidence < requiredEvidence) {
                                  return Colors.grey;
                                }
                                return null;
                              }(),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: () {
                                final requiredEvidence = task.requiredEvidenceCount ?? 0;
                                final uploadedEvidence = task.evidenceUrls.length;
                                if (requiredEvidence > 0 && uploadedEvidence < requiredEvidence) {
                                  return Colors.grey;
                                }
                                return Theme.of(context).primaryColor;
                              }(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.taskCompleted,
                          style: TextStyle(
                            color: Colors.green[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  double _calculateTaskProgress(AgentTask task) {
    if (task.status == 'completed') return 1.0;
    if (task.evidenceUrls.isNotEmpty) return 0.7;
    return 0.1; // Task assigned but no evidence yet
  }
  
  String _getLocalizedStatus(String status, BuildContext context) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppLocalizations.of(context)!.completed;
      case 'in_progress':
      case 'started':
        return AppLocalizations.of(context)!.inProgress;
      case 'assigned':
        return AppLocalizations.of(context)!.assigned;
      case 'pending':
        return AppLocalizations.of(context)!.pending;
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
      case 'started':
        return Colors.blue;
      case 'assigned':
        return Colors.purple;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCampaignHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.campaign,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.currentCampaign,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.campaign.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.campaign.description != null && widget.campaign.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  widget.campaign.description!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${AppLocalizations.of(context)!.ends} ${DateFormat.yMMMd().format(widget.campaign.endDate)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.assignment,
                size: 60,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.noTasksAvailable,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.noTasksAssignedDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
