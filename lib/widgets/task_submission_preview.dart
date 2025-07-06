// lib/widgets/task_submission_preview.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  bool _isExpanded = false;

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

      // Load form submissions for this task
      final formSubmissions = await supabase
          .from('tasks')
          .select('id, custom_fields, created_at')
          .eq('id', widget.taskId)
          .not('custom_fields', 'is', null)
          .limit(3);

      for (final item in formSubmissions) {
        if (item['custom_fields'] != null && (item['custom_fields'] as Map).isNotEmpty) {
          submissions.add(TaskSubmissionItem(
            id: item['id'],
            type: 'form',
            title: 'Form Submission',
            submittedAt: DateTime.parse(item['created_at']),
            preview: _formatFormPreview(item['custom_fields']),
          ));
        }
      }

      // Load evidence submissions for this task
      final evidenceSubmissions = await supabase
          .from('evidence')
          .select('''
            id,
            title,
            file_url,
            created_at,
            approval_status,
            task_assignments!inner(task_id)
          ''')
          .eq('uploader_id', userId)
          .eq('task_assignments.task_id', widget.taskId)
          .order('created_at', ascending: false)
          .limit(3);

      for (final item in evidenceSubmissions) {
        submissions.add(TaskSubmissionItem(
          id: item['id'],
          type: 'evidence',
          title: item['title'] ?? 'Evidence File',
          submittedAt: DateTime.parse(item['created_at']),
          preview: 'File uploaded',
          status: item['approval_status'] ?? 'pending',
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
    if (customFields.isEmpty) return 'No data';
    
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            // Header
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: Colors.blue[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Previous Submissions (${_submissions.length})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),
            
            // Expandable content
            if (_isExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Submissions list
                    ...(_submissions.map((submission) => _buildSubmissionItem(submission))),
                    
                    const SizedBox(height: 8),
                    
                    // View all link
                    SizedBox(
                      width: double.infinity,
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
                          'View All Submissions',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionItem(TaskSubmissionItem submission) {
    final isForm = submission.type == 'form';
    final statusColor = _getStatusColor(submission.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isForm ? Colors.blue[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isForm ? Icons.assignment : Icons.attach_file,
              color: isForm ? Colors.blue : Colors.green,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        submission.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (submission.status != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          submission.status!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  submission.preview,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat('MMM dd, hh:mm a').format(submission.submittedAt),
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
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