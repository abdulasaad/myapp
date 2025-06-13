// lib/screens/campaigns/campaigns_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/campaign.dart';
import '../../models/task.dart'; // <-- NEW: Import Task model for standalone tasks
import '../../services/location_service.dart';
import '../../services/profile_service.dart';
import '../../utils/constants.dart';
import 'campaign_detail_screen.dart';
import '../agent/agent_task_list_screen.dart';
// --- NEW: Import the new screen for evidence submission ---
import '../agent/evidence_submission_screen.dart';

// --- NEW: A helper model for standalone tasks to avoid confusion ---
class AgentStandaloneTask {
  final Task task;
  final String assignmentStatus;

  AgentStandaloneTask({required this.task, required this.assignmentStatus});
}

class CampaignsListScreen extends StatefulWidget {
  final LocationService locationService;
  const CampaignsListScreen({super.key, required this.locationService});

  @override
  CampaignsListScreenState createState() => CampaignsListScreenState();
}

class CampaignsListScreenState extends State<CampaignsListScreen> {
  late Future<List<Campaign>> _campaignsFuture;
  // --- NEW: A future specifically for the agent's standalone tasks ---
  late Future<List<AgentStandaloneTask>> _standaloneTasksFuture;

  // These variables remain from previous geofencing features
  StreamSubscription<GeofenceStatus>? _geofenceStatusSubscription;
  final Map<String, bool> _geofenceStatuses = {};

  @override
  void initState() {
    super.initState();
    // Fetch data based on user role
    if (ProfileService.instance.canManageCampaigns) {
      _campaignsFuture = _fetchManagerCampaigns();
    } else {
      _campaignsFuture = _fetchAgentCampaigns();
      _standaloneTasksFuture = _fetchAgentStandaloneTasks(); // Fetch tasks for agents
      _geofenceStatusSubscription = widget.locationService.geofenceStatusStream.listen((status) {
        if (mounted) setState(() => _geofenceStatuses[status.campaignId] = status.isInside);
      });
    }
  }

  @override
  void dispose() {
    _geofenceStatusSubscription?.cancel();
    super.dispose();
  }

  void refreshAll() {
    setState(() {
      if (ProfileService.instance.canManageCampaigns) {
        _campaignsFuture = _fetchManagerCampaigns();
      } else {
        _campaignsFuture = _fetchAgentCampaigns();
        _standaloneTasksFuture = _fetchAgentStandaloneTasks();
      }
    });
  }

  // --- DATA FETCHING LOGIC ---

  Future<List<Campaign>> _fetchManagerCampaigns() async {
    final response = await supabase.from('campaigns').select().order('created_at', ascending: false);
    return response.map((json) => Campaign.fromJson(json)).toList();
  }

  Future<List<Campaign>> _fetchAgentCampaigns() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];
    
    final agentCampaignsResponse = await supabase.from('campaign_agents').select('campaign_id').eq('agent_id', userId);
    final campaignIds = agentCampaignsResponse.map((e) => e['campaign_id'] as String).toList();
    if (campaignIds.isEmpty) return [];

    final idsFilter = '(${campaignIds.map((id) => "'$id'").join(',')})';
    final response = await supabase.from('campaigns').select().filter('id', 'in', idsFilter).order('created_at', ascending: false);
    
    return response.map((json) => Campaign.fromJson(json)).toList();
  }

  // --- NEW: Fetches standalone tasks assigned to the current agent ---
  Future<List<AgentStandaloneTask>> _fetchAgentStandaloneTasks() async {
    final userId = supabase.auth.currentUser!.id;
    // We get the assignment, but also join the full task details
    final response = await supabase
        .from('task_assignments')
        .select('status, tasks(*)')
        .eq('agent_id', userId)
        .filter('tasks.campaign_id', 'is', null); // IMPORTANT: only get tasks where campaign_id is null

    return response.map((json) {
      return AgentStandaloneTask(
        task: Task.fromJson(json['tasks']),
        assignmentStatus: json['status'],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Determine which view to show based on the user's role
    return ProfileService.instance.canManageCampaigns
        ? _buildManagerView()
        : _buildAgentView();
  }

  // --- WIDGET BUILDERS ---

  /// The view for a manager, which is a simple list of campaigns.
  Widget _buildManagerView() {
    return FutureBuilder<List<Campaign>>(
      future: _campaignsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return preloader;
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final campaigns = snapshot.data ?? [];
        if (campaigns.isEmpty) return const Center(child: Text('No campaigns found.'));

        return RefreshIndicator(
          onRefresh: () async => refreshAll(),
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: campaigns.length,
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              return CampaignCard(
                campaign: campaign,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => CampaignDetailScreen(campaign: campaign))),
              );
            },
          ),
        );
      },
    );
  }

  /// The view for an agent, which shows campaigns AND standalone tasks.
  Widget _buildAgentView() {
    return RefreshIndicator(
      onRefresh: () async => refreshAll(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Text('Campaigns', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            // FutureBuilder for Campaigns
            FutureBuilder<List<Campaign>>(
              future: _campaignsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return preloader;
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                final campaigns = snapshot.data ?? [];
                if (campaigns.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No campaigns assigned.')));

                return ListView.builder(
                  itemCount: campaigns.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final campaign = campaigns[index];
                    return CampaignCard(
                      campaign: campaign,
                      isInsideGeofence: _geofenceStatuses[campaign.id],
                      onTap: () {
                        widget.locationService.setActiveCampaign(campaign.id);
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => AgentTaskListScreen(campaign: campaign)));
                      },
                    );
                  },
                );
              },
            ),
            const Divider(height: 40),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Text('Other Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            // --- NEW: FutureBuilder for Standalone Tasks ---
            FutureBuilder<List<AgentStandaloneTask>>(
              future: _standaloneTasksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return preloader;
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                final tasks = snapshot.data ?? [];
                if (tasks.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No other tasks assigned.')));

                return ListView.builder(
                  itemCount: tasks.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final agentTask = tasks[index];
                    final isCompleted = agentTask.assignmentStatus == 'completed';
                    return Card(
                      child: ListTile(
                        leading: Icon(isCompleted ? Icons.check_circle : Icons.assignment, color: isCompleted ? Colors.green : Colors.grey),
                        title: Text(agentTask.task.title),
                        subtitle: Text('${agentTask.task.points} points'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          // --- NAVIGATE TO THE NEW SCREEN ---
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => EvidenceSubmissionScreen(task: agentTask.task)),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// This widget remains mostly the same, but onTap and isInsideGeofence are now optional
class CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final bool? isInsideGeofence;
  final VoidCallback onTap;

  const CampaignCard({
    super.key,
    required this.campaign,
    this.isInsideGeofence,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget? statusWidget;
    if (isInsideGeofence != null) {
      final String message = isInsideGeofence! ? '✅ Inside Geofence' : '❌ Outside Geofence';
      final Color bgColor = isInsideGeofence! ? Colors.green.withAlpha(51) : Colors.red.withAlpha(51);
      statusWidget = Container(
        padding: const EdgeInsets.all(8),
        color: bgColor,
        child: Center(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
      );
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(backgroundColor: primaryColor, child: Text(campaign.status.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              title: Text(campaign.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('${DateFormat.yMMMd().format(campaign.startDate)} - ${DateFormat.yMMMd().format(campaign.endDate)}')),
              trailing: const Icon(Icons.arrow_forward_ios),
            ),
            if (statusWidget != null) statusWidget,
          ],
        ),
      ),
    );
  }
}
