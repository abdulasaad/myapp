// lib/widgets/task_submission_preview.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../l10n/app_localizations.dart';
import '../utils/constants.dart';
import '../screens/agent/agent_submission_history_screen.dart';

class TaskSubmissionPreview extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  
  const TaskSubmissionPreview({
    super.key,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<TaskSubmissionPreview> createState() => _TaskSubmissionPreviewState();
}

class _TaskSubmissionPreviewState extends State<TaskSubmissionPreview> {
  List<TaskSubmissionItem> _submissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTaskSubmissions();
  }

  Future<void> _loadTaskSubmissions() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      List<TaskSubmissionItem> submissions = [];

      // Load form submissions for this task by checking evidence table for form data
      final formSubmissions = await supabase
          .from('evidence')
          .select('''
            id,
            title,
            created_at,
            file_url,
            task_assignments!inner(task_id)
          ''')
          .eq('uploader_id', userId)
          .eq('task_assignments.task_id', widget.taskId)
          .like('title', 'Form Data:%')
          .order('created_at', ascending: false)
          .limit(3);

      for (final item in formSubmissions) {
        // Try to extract form data from file_url if it's a data URL
        String preview = AppLocalizations.of(context)!.formSubmitted;
        if (item['file_url'] != null && item['file_url'].toString().startsWith('data:application/json')) {
          try {
            final dataUrl = item['file_url'] as String;
            final base64Data = dataUrl.split(',')[1];
            final jsonString = utf8.decode(base64.decode(base64Data));
            final formData = jsonDecode(jsonString) as Map<String, dynamic>;
            preview = _formatFormPreview(formData);
          } catch (e) {
            preview = AppLocalizations.of(context)!.formDataAvailable;
          }
        }
        
        submissions.add(TaskSubmissionItem(
          id: item['id'],
          type: 'form',
          title: item['title'] ?? AppLocalizations.of(context)!.formSubmission,
          submittedAt: DateTime.parse(item['created_at']),
          preview: preview,
        ));
      }

      // Load evidence submissions for this task (excluding form data)
      final evidenceSubmissions = await supabase
          .from('evidence')
          .select('''
            id,
            title,
            file_url,
            created_at,
            status,
            task_assignments!inner(task_id)
          ''')
          .eq('uploader_id', userId)
          .eq('task_assignments.task_id', widget.taskId)
          .not('title', 'like', 'Form Data:%')
          .order('created_at', ascending: false)
          .limit(3);

      for (final item in evidenceSubmissions) {
        submissions.add(TaskSubmissionItem(
          id: item['id'],
          type: 'evidence',
          title: item['title'] ?? AppLocalizations.of(context)!.evidenceFile,
          submittedAt: DateTime.parse(item['created_at']),
          preview: AppLocalizations.of(context)!.fileUploaded,
          status: item['status'] ?? 'pending',
        ));
      }

      // Sort by date (newest first)
      submissions.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

      if (mounted) {
        setState(() {
          _submissions = submissions.take(3).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading task submissions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatFormPreview(Map<String, dynamic> customFields) {
    if (customFields.isEmpty) return AppLocalizations.of(context)!.noData;
    
    final entries = customFields.entries.take(2);
    return entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_submissions.isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if no submissions
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.history,
                color: Colors.blue[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.previousSubmissionsCount(_submissions.length),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // Individual submission cards
        ...(_submissions.map((submission) => _buildSubmissionCard(submission))),
        
        // View all submissions link
        if (_submissions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AgentSubmissionHistoryScreen(),
                  ),
                );
              },
              icon: Icon(Icons.open_in_new, size: 16, color: Colors.blue[600]),
              label: Text(
                AppLocalizations.of(context)!.viewAllSubmissions,
                style: TextStyle(
                  color: Colors.blue[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubmissionCard(TaskSubmissionItem submission) {
    final isForm = submission.type == 'form';
    final statusColor = _getStatusColor(submission.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isForm ? Colors.blue[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isForm ? Icons.assignment : Icons.attach_file,
                      color: isForm ? Colors.blue : Colors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM dd, yyyy • hh:mm a').format(submission.submittedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (submission.status != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        submission.status!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Content preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                width: double.infinity,
                child: Text(
                  submission.preview,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Type indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    isForm ? AppLocalizations.of(context)!.formSubmissionUppercase : AppLocalizations.of(context)!.evidenceUploadUppercase,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
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

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}

class TaskSubmissionItem {
  final String id;
  final String type; // 'form' or 'evidence'
  final String title;
  final DateTime submittedAt;
  final String preview;
  final String? status;

  TaskSubmissionItem({
    required this.id,
    required this.type,
    required this.title,
    required this.submittedAt,
    required this.preview,
    this.status,
  });
}