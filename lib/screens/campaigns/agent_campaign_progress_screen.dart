// lib/screens/campaigns/agent_campaign_progress_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../models/campaign.dart';
import '../../models/agent_campaign_progress.dart';
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
                Text('Task Progress',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                _buildTasksList(details.tasks),
                formSpacer,
                Text('Uploaded Files',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                _buildFilesList(details.files),
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
                _buildMetric('Total Points', details.totalPoints.toString()),
                _buildMetric('Points Paid', details.pointsPaid.toString()),
                _buildMetric(
                    'Outstanding', details.outstandingBalance.toString()),
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
            title: Text(file.title.isNotEmpty ? file.title : 'Untitled Evidence',
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
                  menuItems.add(const PopupMenuItem<String>(
                      value: 'view',
                      child: ListTile(
                          leading: Icon(Icons.visibility_outlined),
                          title: Text('View'))));
                }
                menuItems.add(const PopupMenuItem<String>(
                    value: 'download',
                    child: ListTile(
                        leading: Icon(Icons.download_outlined),
                        title: Text('Download'))));
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
}
