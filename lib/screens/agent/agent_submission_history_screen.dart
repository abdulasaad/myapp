// lib/screens/agent/agent_submission_history_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';

class SubmissionHistoryItem {
  final String id;
  final String taskId;
  final String taskTitle;
  final String? campaignName;
  final Map<String, dynamic> customFields;
  final DateTime submittedAt;
  final String status;
  final String type; // 'form' or 'evidence'
  final String? evidenceUrl;
  final String? evidenceTitle;

  SubmissionHistoryItem({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    this.campaignName,
    required this.customFields,
    required this.submittedAt,
    required this.status,
    required this.type,
    this.evidenceUrl,
    this.evidenceTitle,
  });

  factory SubmissionHistoryItem.fromTaskJson(Map<String, dynamic> json) {
    return SubmissionHistoryItem(
      id: json['id'],
      taskId: json['id'],
      taskTitle: json['title'],
      campaignName: json['campaign_name'],
      customFields: json['custom_fields'] ?? {},
      submittedAt: DateTime.parse(json['updated_at'] ?? json['created_at']),
      status: 'submitted',
      type: 'form',
    );
  }

  factory SubmissionHistoryItem.fromEvidenceJson(Map<String, dynamic> json) {
    final taskAssignment = json['task_assignments'] as Map<String, dynamic>?;
    final task = taskAssignment?['tasks'] as Map<String, dynamic>?;
    
    return SubmissionHistoryItem(
      id: json['id'],
      taskId: taskAssignment?['task_id'] ?? '',
      taskTitle: task?['title'] ?? 'Unknown Task',
      campaignName: null, // Will be fetched separately if needed
      customFields: {},
      submittedAt: DateTime.parse(json['created_at']),
      status: json['approval_status'] ?? 'pending',
      type: 'evidence',
      evidenceUrl: json['file_url'],
      evidenceTitle: json['title'],
    );
  }
}

class AgentSubmissionHistoryScreen extends StatefulWidget {
  const AgentSubmissionHistoryScreen({super.key});

  @override
  State<AgentSubmissionHistoryScreen> createState() => _AgentSubmissionHistoryScreenState();
}

class _AgentSubmissionHistoryScreenState extends State<AgentSubmissionHistoryScreen> {
  late Future<List<SubmissionHistoryItem>> _submissionsFuture;
  String _selectedFilter = 'all'; // 'all', 'forms', 'evidence'
  String _selectedStatus = 'all'; // 'all', 'pending', 'approved', 'rejected'

  @override
  void initState() {
    super.initState();
    _submissionsFuture = _loadSubmissionHistory();
  }

  void _refreshSubmissions() {
    setState(() {
      _submissionsFuture = _loadSubmissionHistory();
    });
  }

  Future<List<SubmissionHistoryItem>> _loadSubmissionHistory() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('No authenticated user');

      List<SubmissionHistoryItem> allSubmissions = [];

      // Load form submissions (tasks with custom fields)
      if (_selectedFilter == 'all' || _selectedFilter == 'forms') {
        final formSubmissions = await supabase
            .from('task_assignments')
            .select('''
              tasks!inner(
                id,
                title,
                custom_fields,
                created_at,
                campaigns(name)
              )
            ''')
            .eq('agent_id', userId)
            .not('tasks.custom_fields', 'is', null)
            .order('created_at', ascending: false);

        for (final item in formSubmissions) {
          final task = item['tasks'] as Map<String, dynamic>;
          final campaigns = task['campaigns'] as List?;
          final campaignName = campaigns?.isNotEmpty == true 
              ? campaigns!.first['name'] as String?
              : null;

          allSubmissions.add(SubmissionHistoryItem(
            id: task['id'],
            taskId: task['id'],
            taskTitle: task['title'],
            campaignName: campaignName,
            customFields: task['custom_fields'] ?? {},
            submittedAt: DateTime.parse(task['created_at']),
            status: 'submitted',
            type: 'form',
          ));
        }
      }

      // Load evidence submissions
      if (_selectedFilter == 'all' || _selectedFilter == 'evidence') {
        final evidenceSubmissions = await supabase
            .from('evidence')
            .select('''
              id,
              title,
              file_url,
              created_at,
              approval_status,
              task_assignments!inner(
                task_id,
                tasks!inner(title)
              )
            ''')
            .eq('uploader_id', userId)
            .order('created_at', ascending: false);

        for (final item in evidenceSubmissions) {
          if (_selectedStatus == 'all' || 
              (_selectedStatus == 'pending' && (item['approval_status'] == null || item['approval_status'] == 'pending')) ||
              (_selectedStatus == 'approved' && item['approval_status'] == 'approved') ||
              (_selectedStatus == 'rejected' && item['approval_status'] == 'rejected')) {
            
            allSubmissions.add(SubmissionHistoryItem.fromEvidenceJson(item));
          }
        }
      }

      // Sort all submissions by date (newest first)
      allSubmissions.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

      return allSubmissions;
    } catch (e) {
      debugPrint('Error loading submission history: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.mySubmissions,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey[200],
          ),
        ),
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Type Filter
                Row(
                  children: [
                    Text('${AppLocalizations.of(context)!.type}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment(value: 'all', label: Text(AppLocalizations.of(context)!.all)),
                          ButtonSegment(value: 'forms', label: Text(AppLocalizations.of(context)!.forms)),
                          ButtonSegment(value: 'evidence', label: Text(AppLocalizations.of(context)!.evidence)),
                        ],
                        selected: {_selectedFilter},
                        onSelectionChanged: (Set<String> selection) {
                          setState(() {
                            _selectedFilter = selection.first;
                            _submissionsFuture = _loadSubmissionHistory();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Status Filter
                Row(
                  children: [
                    Text('${AppLocalizations.of(context)!.status}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment(value: 'all', label: Text(AppLocalizations.of(context)!.all)),
                          ButtonSegment(value: 'pending', label: Text(AppLocalizations.of(context)!.pending)),
                          ButtonSegment(value: 'approved', label: Text(AppLocalizations.of(context)!.approved)),
                          ButtonSegment(value: 'rejected', label: Text(AppLocalizations.of(context)!.rejected)),
                        ],
                        selected: {_selectedStatus},
                        onSelectionChanged: (Set<String> selection) {
                          setState(() {
                            _selectedStatus = selection.first;
                            _submissionsFuture = _loadSubmissionHistory();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Submissions List
          Expanded(
            child: FutureBuilder<List<SubmissionHistoryItem>>(
              future: _submissionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(AppLocalizations.of(context)!.loadingSubmissions),
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
                          onPressed: _refreshSubmissions,
                          child: Text(AppLocalizations.of(context)!.tryAgain),
                        ),
                      ],
                    ),
                  );
                }

                final submissions = snapshot.data ?? [];
                
                if (submissions.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async => _refreshSubmissions(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: submissions.length,
                    itemBuilder: (context, index) {
                      final submission = submissions[index];
                      return _buildSubmissionCard(submission);
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

  Widget _buildSubmissionCard(SubmissionHistoryItem submission) {
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
              // Header
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
                          submission.taskTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (submission.campaignName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            submission.campaignName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      submission.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Content Preview
              if (isForm && submission.customFields.isNotEmpty) ...[
                Text(
                  '${AppLocalizations.of(context)!.formData}:',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: submission.customFields.entries.take(3).map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '${entry.key}: ${entry.value}',
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (submission.customFields.length > 3) ...[
                  const SizedBox(height: 4),
                  Text(
                    '+${submission.customFields.length - 3} ${AppLocalizations.of(context)!.moreFields}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ] else if (!isForm) ...[
                if (submission.evidenceTitle != null) ...[
                  Text(
                    '${AppLocalizations.of(context)!.evidence}: ${submission.evidenceTitle}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (submission.evidenceUrl != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.image, color: Colors.grey[600], size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.fileUploaded,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              
              const SizedBox(height: 12),
              
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(submission.submittedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    isForm ? AppLocalizations.of(context)!.form.toUpperCase() : AppLocalizations.of(context)!.evidence.toUpperCase(),
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
                Icons.history,
                size: 60,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.noSubmissionsYet,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.submissionsWillAppearHere,
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'submitted':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}