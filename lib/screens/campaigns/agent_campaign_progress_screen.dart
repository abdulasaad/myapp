// lib/screens/campaigns/agent_campaign_progress_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../l10n/app_localizations.dart';
import '../../models/app_user.dart';
import '../../models/campaign.dart';
import '../../models/agent_campaign_progress.dart';
import '../../models/touring_task.dart';
import '../../models/touring_task_session.dart';
import '../../services/touring_task_service.dart';
import '../../utils/constants.dart';
import '../full_screen_image_viewer.dart';

class AgentCampaignProgressScreen extends StatefulWidget {
  final Campaign campaign;
  final AppUser agent;

  const AgentCampaignProgressScreen({
    super.key,
    required this.campaign,
    required this.agent,
  });

  @override
  State<AgentCampaignProgressScreen> createState() =>
      _AgentCampaignProgressScreenState();
}

class _AgentCampaignProgressScreenState
    extends State<AgentCampaignProgressScreen> {
  late Future<AgentCampaignDetails> _detailsFuture;
  final TouringTaskService _touringTaskService = TouringTaskService();
  Timer? _refreshTimer;
  List<Map<String, dynamic>> _touringTaskProgress = [];
  Map<String, TouringTaskSession?> _activeSessions = {};
  bool _hasRegularTasks = false;

  bool _isImageUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.gif');
  }

  @override
  void initState() {
    super.initState();
    _detailsFuture = _fetchDetails();
    _loadTouringTaskProgress();
    // Set up timer to refresh touring task progress every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadTouringTaskProgress();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<AgentCampaignDetails> _fetchDetails() async {
    // Fetch basic earnings data using the RPC
    final rpcData = await supabase.rpc('get_agent_campaign_details_fixed', params: {
      'p_campaign_id': widget.campaign.id,
      'p_agent_id': widget.agent.id,
    });
    
    // Fetch evidence directly from evidence table with custom titles
    final evidenceResponse = await supabase
        .from('evidence')
        .select('''
          id,
          title,
          file_url,
          created_at,
          task_assignments!inner(
            id,
            task:tasks!inner(title)
          )
        ''')
        .eq('task_assignments.agent_id', widget.agent.id)
        .eq('task_assignments.task.campaign_id', widget.campaign.id);
    
    // Convert evidence response to EvidenceFile objects
    final evidenceFiles = evidenceResponse.map((evidence) {
      final taskTitle = evidence['task_assignments']['task']['title'] as String;
      return EvidenceFile(
        id: evidence['id'] as String,
        title: evidence['title'] as String,
        fileUrl: evidence['file_url'] as String,
        createdAt: DateTime.parse(evidence['created_at'] as String),
        taskTitle: taskTitle,
      );
    }).toList();
    
    // Create AgentCampaignDetails with real evidence data
    final earnings = rpcData['earnings'] as Map<String, dynamic>;
    final total = earnings['total_points'] as int? ?? 0;
    final paid = earnings['paid_points'] as int? ?? 0;
    
    return AgentCampaignDetails(
      totalPoints: total,
      pointsPaid: paid,
      outstandingBalance: total - paid,
      tasks: (rpcData['tasks'] as List)
          .map((t) => ProgressTaskItem.fromJson(t as Map<String, dynamic>))
          .toList(),
      files: evidenceFiles, // Use real evidence files instead of generated ones
    );
  }

  Future<void> _loadTouringTaskProgress() async {
    try {
      // Fetch touring task assignments for this agent in this campaign
      final assignments = await supabase
          .from('touring_task_assignments')
          .select('''
            *,
            touring_tasks (
              *,
              campaign_geofences (
                id,
                name,
                area_text,
                color
              )
            )
          ''')
          .eq('agent_id', widget.agent.id)
          .eq('touring_tasks.campaign_id', widget.campaign.id);

      List<Map<String, dynamic>> progressList = [];
      Map<String, TouringTaskSession?> sessions = {};

      for (var assignment in assignments) {
        final taskData = assignment['touring_tasks'];
        if (taskData != null) {
          final task = TouringTask.fromJson(taskData);
          
          // Get active session if any
          final session = await _touringTaskService.getActiveSession(
            task.id,
            widget.agent.id,
          );
          
          sessions[task.id] = session;
          
          progressList.add({
            'assignment': assignment,
            'task': task,
            'geofence': taskData['campaign_geofences'],
            'session': session,
          });
        }
      }

      if (mounted) {
        setState(() {
          _touringTaskProgress = progressList;
          _activeSessions = sessions;
        });
      }
    } catch (e) {
      debugPrint('Error loading touring task progress: $e');
    }
  }

  Future<void> _downloadFile(EvidenceFile file) async {
    // ... (This function is unchanged from the previous correct version)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.agent.fullName}'s Progress")),
      body: FutureBuilder<AgentCampaignDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return preloader;
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading details: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No data available.'));
          }

          final details = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(details),
                formSpacer,
                // Regular Tasks Section
                if (details.tasks.isNotEmpty) ...[
                  Text(AppLocalizations.of(context)!.taskProgress,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  _buildTasksList(details.tasks),
                  formSpacer,
                ],
                // Touring Tasks Section
                if (_touringTaskProgress.isNotEmpty) ...[
                  Text('Touring Tasks Progress',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  _buildTouringTasksList(),
                  formSpacer,
                ],
                // Only show uploaded files if there are regular tasks that require evidence
                if (details.tasks.isNotEmpty && details.files.isNotEmpty) ...[
                  Text(AppLocalizations.of(context)!.uploadedFiles,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  _buildFilesList(details.files),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(AgentCampaignDetails details) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
                radius: 30,
                child: Text(widget.agent.fullName.isNotEmpty
                    ? widget.agent.fullName[0]
                    : 'A')),
            const SizedBox(height: 8),
            Text(widget.agent.fullName,
                style: Theme.of(context).textTheme.titleLarge),
            Text('Campaign: ${widget.campaign.name}',
                style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(AppLocalizations.of(context)!.totalPoints, details.totalPoints.toString()),
                _buildMetric(AppLocalizations.of(context)!.pointsPaid, details.pointsPaid.toString()),
                _buildMetric(
                    AppLocalizations.of(context)!.outstanding, details.outstandingBalance.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildTasksList(List<ProgressTaskItem> tasks) {
    if (tasks.isEmpty) {
      return const Text('No tasks assigned in this campaign.');
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _getStatusIcon(task.status),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(task.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))),
                    Text('${task.points} pts',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                if (task.description != null && task.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 32),
                    child: Text(task.description!,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: _getStatusColor(task.status),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(task.status.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    Text(
                        'Evidence: ${task.evidenceUploaded} / ${task.evidenceRequired}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilesList(List<EvidenceFile> files) {
    if (files.isEmpty) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No files uploaded yet.')));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final isImage = _isImageUrl(file.fileUrl);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(isImage
                ? Icons.image_outlined
                : Icons.insert_drive_file_outlined),
            title: Text(file.title.isNotEmpty ? file.title : AppLocalizations.of(context)!.untitledEvidence,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                'For: ${file.taskTitle}\nOn: ${DateFormat.yMMMd().add_jm().format(file.createdAt)}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'view' && isImage) {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => FullScreenImageViewer(
                          imageUrl: file.fileUrl, heroTag: file.id)));
                } else if (value == 'download') {
                  _downloadFile(file);
                }
              },
              itemBuilder: (BuildContext context) {
                final menuItems = <PopupMenuEntry<String>>[];
                if (isImage) {
                  menuItems.add(PopupMenuItem<String>(
                      value: 'view',
                      child: ListTile(
                          leading: Icon(Icons.visibility_outlined),
                          title: Text(AppLocalizations.of(context)!.view))));
                }
                menuItems.add(PopupMenuItem<String>(
                    value: 'download',
                    child: ListTile(
                        leading: Icon(Icons.download_outlined),
                        title: Text(AppLocalizations.of(context)!.download))));
                return menuItems;
              },
            ),
          ),
        );
      },
    );
  }

  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icon(Icons.check_circle, color: Colors.green[400]);
      case 'pending':
        return Icon(Icons.radio_button_unchecked, color: Colors.grey[600]);
      default:
        return Icon(Icons.hourglass_top_outlined, color: Colors.orange[400]);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green[600]!;
      case 'pending':
        return Colors.grey[700]!;
      default:
        return Colors.orange[800]!;
    }
  }

  Widget _buildTouringTasksList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _touringTaskProgress.length,
      itemBuilder: (context, index) {
        final item = _touringTaskProgress[index];
        final task = item['task'] as TouringTask;
        final geofence = item['geofence'] as Map<String, dynamic>;
        final session = item['session'] as TouringTaskSession?;
        final assignment = item['assignment'] as Map<String, dynamic>;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task Header
                Row(
                  children: [
                    Icon(Icons.tour, color: primaryColor, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Work Zone: ${geofence['name']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _getStatusIcon(assignment['status']),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Progress Information
                if (session != null && session.isActive) ...[
                  // Live Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress: ${_formatDuration(session.elapsedSeconds)} / ${task.formattedDuration}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${_calculateProgressPercentage(session.elapsedSeconds, task.requiredTimeMinutes).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _calculateProgressPercentage(session.elapsedSeconds, task.requiredTimeMinutes) / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          session.isPaused ? Colors.orange : primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Status Indicators
                  Row(
                    children: [
                      _buildStatusChip(
                        icon: Icons.location_on,
                        label: session.lastLatitude != null 
                            ? 'Location Active' 
                            : 'Location Unknown',
                        color: session.lastLatitude != null 
                            ? Colors.green 
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(
                        icon: Icons.directions_walk,
                        label: session.isPaused ? 'Not Moving' : 'Moving',
                        color: session.isPaused ? Colors.orange : Colors.green,
                      ),
                    ],
                  ),
                  
                  // Pause Reason if applicable
                  if (session.isPaused && session.pauseReason != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Timer Paused: ${session.pauseReason}',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else if (assignment['status'] == 'completed') ...[
                  // Completed Task
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Task Completed',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Not Started
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Not Started',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Task Details
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailItem('Required Time', task.formattedDuration),
                    _buildDetailItem('Points', '${task.points}'),
                    _buildDetailItem('Movement Timeout', task.movementTimeoutText),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    }
  }

  double _calculateProgressPercentage(int elapsedSeconds, int requiredMinutes) {
    final requiredSeconds = requiredMinutes * 60;
    final percentage = (elapsedSeconds / requiredSeconds) * 100;
    return percentage.clamp(0, 100);
  }
}
