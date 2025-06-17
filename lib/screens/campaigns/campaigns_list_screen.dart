// lib/screens/campaigns/campaigns_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/screens/agent/task_location_viewer_screen.dart';
import '../../models/campaign.dart';
import '../../models/task.dart';
import '../../services/location_service.dart';
import '../../services/profile_service.dart';
import '../../utils/constants.dart';
import './create_campaign_screen.dart'; // Added for navigation to edit
import 'campaign_detail_screen.dart';
import '../agent/agent_task_list_screen.dart';
import '../agent/evidence_submission_screen.dart';

// Helper model for standalone tasks
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
  // Use specific futures for clarity
  late Future<List<dynamic>> _agentDataFuture;
  late Future<List<Campaign>> _managerCampaignsFuture;

  // Geofence status tracking
  StreamSubscription<GeofenceStatus>? _geofenceStatusSubscription;
  final Map<String, bool> _geofenceStatuses = {};

  @override
  void initState() {
    super.initState();
    // Initialize data fetching based on user role
    if (ProfileService.instance.canManageCampaigns) {
      _managerCampaignsFuture = _fetchManagerCampaigns();
    } else {
      // For agents, fetch both campaigns and tasks concurrently
      _agentDataFuture = Future.wait([
        _fetchAgentCampaigns(),
        _fetchAgentStandaloneTasks(),
      ]);
      // Subscribe to geofence status updates
      _geofenceStatusSubscription =
          widget.locationService.geofenceStatusStream.listen((status) {
        if (mounted) {
          setState(() => _geofenceStatuses[status.campaignId] = status.isInside);
        }
      });
    }
  }

  @override
  void dispose() {
    _geofenceStatusSubscription?.cancel();
    super.dispose();
  }

  // Refreshes all data for the current user type
  void refreshAll() {
    setState(() {
      if (ProfileService.instance.canManageCampaigns) {
        _managerCampaignsFuture = _fetchManagerCampaigns();
      } else {
        _agentDataFuture = Future.wait([
          _fetchAgentCampaigns(),
          _fetchAgentStandaloneTasks(),
        ]);
      }
    });
  }

  // --- DATA FETCHING METHODS ---

  Future<List<Campaign>> _fetchManagerCampaigns() async {
    final response = await supabase
        .from('campaigns')
        .select()
        .order('created_at', ascending: false);
    return response.map((json) => Campaign.fromJson(json)).toList();
  }

  Future<List<Campaign>> _fetchAgentCampaigns() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final agentCampaignsResponse = await supabase
        .from('campaign_agents')
        .select('campaign_id')
        .eq('agent_id', userId);

    final campaignIds =
        agentCampaignsResponse.map((e) => e['campaign_id'] as String).toList();

    if (campaignIds.isEmpty) return [];
    
    final idsFilter = '(${campaignIds.map((id) => '"$id"').join(',')})';

    final response = await supabase
        .from('campaigns')
        .select()
        .filter('id', 'in', idsFilter)
        .order('created_at', ascending: false);

    return response.map((json) => Campaign.fromJson(json)).toList();
  }

  Future<List<AgentStandaloneTask>> _fetchAgentStandaloneTasks() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await supabase
        .from('task_assignments')
        .select('status, tasks(*)')
        .eq('agent_id', userId)
        .filter('tasks.campaign_id', 'is', null); // Standalone tasks only

    return response
        .where((json) => json['tasks'] != null) // Ensure task data is not null
        .map((json) => AgentStandaloneTask(
              task: Task.fromJson(json['tasks']),
              assignmentStatus: json['status'],
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Build the UI based on the user's role
    return ProfileService.instance.canManageCampaigns
        ? _buildManagerView()
        : _buildAgentView();
  }

  // --- WIDGET BUILDERS ---

  /// Builds the view for a manager (a simple list of campaigns).
  Widget _buildManagerView() {
    return FutureBuilder<List<Campaign>>(
      future: _managerCampaignsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return preloader;
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final campaigns = snapshot.data ?? [];
        if (campaigns.isEmpty) {
          return const Center(child: Text('No campaigns found.'));
        }
        return RefreshIndicator(
          onRefresh: () async => refreshAll(),
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: campaigns.length,
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              return CampaignCard(
                campaign: campaign,
                showAdminActions: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        CampaignDetailScreen(campaign: campaign))),
                onEdit: () async {
                  // Navigate to CreateCampaignScreen for editing
                  final result = await Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => CreateCampaignScreen(campaignToEdit: campaign),
                  ));
                  if (result == true && mounted) {
                    refreshAll(); // Refresh list if campaign was saved
                  }
                },
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Confirm Delete'),
                        content: Text('Are you sure you want to delete "${campaign.name}"? This action cannot be undone.'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Delete'),
                            onPressed: () => Navigator.of(context).pop(true),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirm == true && mounted) {
                    try {
                      // Placeholder for actual delete logic
                      // await supabase.from('campaigns').delete().match({'id': campaign.id});
                      // For now, just show a snackbar and refresh
                      // In a real app, handle related data (tasks, assignments) deletion as well.
                      // This might involve a Supabase Edge Function for cascading deletes or complex logic.
                      
                      // Delete related records in order of dependency
                      await supabase.from('payments').delete().eq('campaign_id', campaign.id); // Added this line
                      await supabase.from('tasks').delete().eq('campaign_id', campaign.id);
                      await supabase.from('campaign_agents').delete().eq('campaign_id', campaign.id);
                      // Finally, delete the campaign itself
                      await supabase.from('campaigns').delete().eq('id', campaign.id);

                      // If the CampaignsListScreenState is no longer mounted, we shouldn't proceed.
                      if (!mounted) return; // 'mounted' refers to CampaignsListScreenState.mounted

                      // If the BuildContext of the CampaignCard is still mounted, show the success SnackBar.
                      // This 'context.mounted' check is required by the linter for using 'context' after an async gap.
                      if (context.mounted) { // 'context' is CampaignCard's context
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Campaign "${campaign.name}" deleted successfully.')),
                        );
                      }
                      // refreshAll is a method of CampaignsListScreenState, guarded by the 'if (!mounted) return;' above.
                      refreshAll();
                    } catch (e) {
                      // If the CampaignsListScreenState is no longer mounted, we shouldn't proceed.
                      if (!mounted) return;

                      // If the BuildContext of the CampaignCard is still mounted, show the error SnackBar.
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error deleting campaign: ${e.toString()}')),
                        );
                      }
                      // Optionally, log to console if context is not mounted but state is.
                      // else {
                      //   print('Error deleting campaign: $e. UI context for SnackBar not available.');
                      // }
                    }
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  /// Builds the conditional tabbed view for an agent.
  Widget _buildAgentView() {
    return FutureBuilder<List<dynamic>>(
      future: _agentDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return preloader;
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching data: ${snapshot.error}'));
        }
        
        final List<Campaign> campaigns = snapshot.data?[0] ?? [];
        final List<AgentStandaloneTask> tasks = snapshot.data?[1] ?? [];
        
        final List<Widget> tabs = [];
        final List<Widget> tabViews = [];

        // Conditionally add tabs and views
        if (campaigns.isNotEmpty) {
          tabs.add(const Tab(text: 'Campaigns'));
          tabViews.add(_buildCampaignsList(campaigns));
        }
        if (tasks.isNotEmpty) {
          tabs.add(const Tab(text: 'Tasks'));
          tabViews.add(_buildTasksList(tasks));
        }

        // Handle the case where there is no work
        if (tabs.isEmpty) {
          return const Center(child: Text('No work assigned at the moment.'));
        }
        
        // Build the tabbed UI
        return DefaultTabController(
          length: tabs.length,
          child: Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white24, width: 0.5))),
                child: TabBar(
                  tabs: tabs,
                  indicatorColor: primaryColor,
                  labelColor: primaryColor,
                  unselectedLabelColor: Colors.grey[400],
                ),
              ),
              Expanded(
                child: TabBarView(children: tabViews),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the list view for campaigns.
  Widget _buildCampaignsList(List<Campaign> campaigns) {
    return RefreshIndicator(
      onRefresh: () async => refreshAll(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: campaigns.length,
        itemBuilder: (context, index) {
          final campaign = campaigns[index];
          return CampaignCard(
            campaign: campaign,
            isInsideGeofence: _geofenceStatuses[campaign.id],
            onTap: () {
              widget.locationService.setActiveCampaign(campaign.id);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) =>
                      AgentTaskListScreen(campaign: campaign)));
            },
          );
        },
      ),
    );
  }

  /// Builds the list view for standalone tasks.
  Widget _buildTasksList(List<AgentStandaloneTask> tasks) {
    return RefreshIndicator(
      onRefresh: () async => refreshAll(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final agentTask = tasks[index];
          final isCompleted = agentTask.assignmentStatus == 'completed';
          return TaskCard(
            task: agentTask.task,
            isCompleted: isCompleted,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) =>
                        EvidenceSubmissionScreen(task: agentTask.task)),
              );
            },
          );
        },
      ),
    );
  }
}

// --- REUSABLE CARD WIDGETS ---

class CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final bool? isInsideGeofence;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showAdminActions;

  const CampaignCard({
    super.key,
    required this.campaign,
    this.isInsideGeofence,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.showAdminActions = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget? statusWidget;
    if (isInsideGeofence != null) {
      final String message =
          isInsideGeofence! ? '✅ Inside Geofence' : '❌ Outside Geofence';
      
      final Color bgColor = isInsideGeofence!
          ? Colors.green.withAlpha(51)
          : Colors.red.withAlpha(51);

      statusWidget = Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: bgColor,
          child: Center(
              child: Text(message,
                  style: TextStyle(
                      color: isInsideGeofence!
                          ? Colors.green[200]
                          : Colors.red[200],
                      fontSize: 12,
                      fontWeight: FontWeight.bold))));
    }

    return Card(
      clipBehavior: Clip.antiAlias, // Ensures footer corners are rounded
      color: cardBackgroundColor,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(children: [
                CircleAvatar(
                    backgroundColor: primaryColor,
                    child: const Icon(Icons.campaign,
                        color: Colors.white, size: 20)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(campaign.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Ends: ${DateFormat.yMMMd().format(campaign.endDate)}',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                ),
                if (showAdminActions) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: Colors.blue[300],
                    tooltip: 'Edit Campaign',
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8), // Spacing between buttons
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red[300],
                    tooltip: 'Delete Campaign',
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ] else ...[
                  const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                ]
              ]),
            ),
            if (statusWidget != null) statusWidget,
          ],
        ),
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Task task;
  final bool isCompleted;
  final VoidCallback onTap;

  const TaskCard(
      {super.key,
      required this.task,
      required this.isCompleted,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardBackgroundColor,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(children: [
            Icon(isCompleted ? Icons.check_circle : Icons.assignment,
                color: isCompleted ? Colors.green : Colors.grey[400], size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('${task.points} Points',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            ),
            // ================================================================
            // THE CHANGE IS HERE: Add a conditional location button
            // ================================================================
            if (task.enforceGeofence == true)
              IconButton(
                icon: const Icon(Icons.location_on_outlined),
                color: Colors.blue[300],
                tooltip: 'View Task Location',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TaskLocationViewerScreen(task: task),
                    ),
                  );
                },
              ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ]),
        ),
      ),
    );
  }
}
