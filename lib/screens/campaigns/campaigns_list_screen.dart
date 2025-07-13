// lib/screens/campaigns/campaigns_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:myapp/screens/agent/task_location_viewer_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../models/campaign.dart';
import '../../models/task.dart';
import '../../services/location_service.dart';
import '../../services/background_location_service.dart';
import '../../services/profile_service.dart';
import '../../services/session_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/constants.dart';
import '../../widgets/offline_widget.dart';
import '../../widgets/modern_notification.dart';
import './create_campaign_screen.dart'; // Added for navigation to edit
import 'campaign_detail_screen.dart';
import '../agent/agent_task_list_screen.dart';

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
    
    // Validate session immediately when loading campaigns
    SessionService().validateSessionImmediately();
    
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
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return [];

    try {
      // Get current user's role
      final userRoleResponse = await supabase
          .from('profiles')
          .select('role')
          .eq('id', currentUser.id)
          .single();
      
      final userRole = userRoleResponse['role'] as String;

      if (userRole == 'admin') {
        // Admins can see all campaigns
        final response = await supabase
            .from('campaigns')
            .select('*, created_at')
            .order('created_at', ascending: false);
        return response.map((json) => Campaign.fromJson(json)).toList();
      } else if (userRole == 'manager') {
        // Managers can see:
        // 1. Campaigns assigned to them directly (assigned_manager_id)
        // 2. Campaigns created by users in their shared groups
        
        // First, get campaigns assigned directly to this manager
        final assignedCampaignsResponse = await supabase
            .from('campaigns')
            .select('*, created_at')
            .eq('assigned_manager_id', currentUser.id)
            .order('created_at', ascending: false);
        
        final assignedCampaigns = assignedCampaignsResponse.map((json) => Campaign.fromJson(json)).toList();
        
        // Then get current manager's groups for group-based campaigns
        final userGroupsResponse = await supabase
            .from('user_groups')
            .select('group_id')
            .eq('user_id', currentUser.id);
        
        final userGroupIds = userGroupsResponse
            .map((item) => item['group_id'] as String)
            .toSet();
        
        List<Campaign> groupCampaigns = [];
        
        if (userGroupIds.isNotEmpty) {
          // Get all users in the same groups (including the manager)
          final usersInGroupsResponse = await supabase
              .from('user_groups')
              .select('user_id')
              .inFilter('group_id', userGroupIds.toList());
          
          final allowedUserIds = usersInGroupsResponse
              .map((item) => item['user_id'] as String)
              .toSet();
          
          // Always include the current manager
          allowedUserIds.add(currentUser.id);

          if (allowedUserIds.isNotEmpty) {
            // Get campaigns created by users in the same groups
            final groupCampaignsResponse = await supabase
                .from('campaigns')
                .select('*, created_at')
                .inFilter('created_by', allowedUserIds.toList())
                .order('created_at', ascending: false);
            
            groupCampaigns = groupCampaignsResponse.map((json) => Campaign.fromJson(json)).toList();
          }
        }
        
        // Combine assigned campaigns and group campaigns, removing duplicates
        final allCampaigns = <String, Campaign>{};
        
        // Add assigned campaigns first (higher priority)
        for (final campaign in assignedCampaigns) {
          allCampaigns[campaign.id] = campaign;
        }
        
        // Add group campaigns (won't overwrite assigned campaigns due to map)
        for (final campaign in groupCampaigns) {
          allCampaigns[campaign.id] = campaign;
        }
        
        // Convert back to list and sort by creation date
        final resultCampaigns = allCampaigns.values.toList();
        resultCampaigns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        return resultCampaigns;
      } else {
        // Other roles (agents) typically don't manage campaigns
        return [];
      }
    } catch (e) {
      debugPrint('Error filtering manager campaigns: $e');
      // Return empty list on error rather than throwing
      return [];
    }
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppLocalizations.of(context)!.campaigns,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<Campaign>>(
              future: _managerCampaignsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  // Check if this is a network error
                  if (ConnectivityService.isNetworkError(snapshot.error)) {
                    return OfflineWidget(
                      title: AppLocalizations.of(context)!.noInternetConnection,
                      subtitle: AppLocalizations.of(context)!.unableToLoadCampaigns,
                      onRetry: () => refreshAll(),
                    );
                  }
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red[400]),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.errorLoadingCampaigns,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: refreshAll,
                          child: Text(AppLocalizations.of(context)!.retry),
                        ),
                      ],
                    ),
                  );
                }
                final campaigns = snapshot.data ?? [];
                if (campaigns.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: Icon(
                      Icons.campaign,
                      size: 60,
                      color: primaryColor.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context)!.noCampaignsYet,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.createFirstCampaign,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: textSecondaryColor,
                      height: 1.5,
                    ),
                  ),
                  // Removed center creation button - using only FAB for consistency
                  // const SizedBox(height: 32),
                  // ElevatedButton.icon(
                  //   onPressed: () async {
                  //     final result = await Navigator.of(context).push(
                  //       MaterialPageRoute(
                  //         builder: (context) => const CreateCampaignScreen(),
                  //       ),
                  //     );
                  //     if (result == true && mounted) {
                  //       refreshAll();
                  //     }
                  //   },
                  //   icon: const Icon(Icons.add),
                  //   label: const Text('Create Campaign'),
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: primaryColor,
                  //     foregroundColor: Colors.white,
                  //     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  //     shape: RoundedRectangleBorder(
                  //       borderRadius: BorderRadius.circular(12),
                  //     ),
                  //     elevation: 2,
                  //   ),
                  // ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => refreshAll(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: campaigns.length,
                    itemBuilder: (context, index) {
                      final campaign = campaigns[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CampaignCard(
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Text(AppLocalizations.of(context)!.confirmDelete),
                            content: Text(AppLocalizations.of(context)!.confirmDeleteCampaign(campaign.name)),
                            actions: <Widget>[
                              TextButton(
                                child: Text(AppLocalizations.of(context)!.cancel),
                                onPressed: () => Navigator.of(context).pop(false),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: errorColor),
                                child: Text(AppLocalizations.of(context)!.deleteCampaign),
                                onPressed: () => Navigator.of(context).pop(true),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirm == true && mounted) {
                        try {
                          // Delete related records in order of dependency
                          await supabase.from('payments').delete().eq('campaign_id', campaign.id);
                          await supabase.from('tasks').delete().eq('campaign_id', campaign.id);
                          await supabase.from('campaign_agents').delete().eq('campaign_id', campaign.id);
                          // Finally, delete the campaign itself
                          await supabase.from('campaigns').delete().eq('id', campaign.id);

                          // If the CampaignsListScreenState is no longer mounted, we shouldn't proceed.
                          if (!mounted) return;

                          // If the BuildContext of the CampaignCard is still mounted, show the success SnackBar.
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context)!.campaignDeleted(campaign.name)),
                                backgroundColor: successColor,
                              ),
                            );
                          }
                          refreshAll();
                        } catch (e) {
                          // If the CampaignsListScreenState is no longer mounted, we shouldn't proceed.
                          if (!mounted) return;

                          // If the BuildContext of the CampaignCard is still mounted, show the error SnackBar.
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context)!.errorDeletingCampaign(e.toString())),
                                backgroundColor: errorColor,
                              ),
                            );
                          }
                        }
                      }
                    },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CreateCampaignScreen(),
              ),
            );
            if (result == true && mounted) {
              refreshAll();
            }
          },
          icon: const Icon(Icons.add),
          label: Text(AppLocalizations.of(context)!.campaign),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        ),
      ),
    );
  }

  /// Builds the campaigns view for an agent.
  Widget _buildAgentView() {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppLocalizations.of(context)!.myCampaigns,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _agentDataFuture,
              builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // Check if this is a network error
            if (ConnectivityService.isNetworkError(snapshot.error)) {
              return OfflineWidget(
                title: AppLocalizations.of(context)!.noInternetConnection,
                subtitle: AppLocalizations.of(context)!.unableToLoadCampaigns,
                onRetry: () => refreshAll(),
              );
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.errorLoadingCampaigns,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: refreshAll,
                    child: Text(AppLocalizations.of(context)!.retry),
                  ),
                ],
              ),
            );
          }
          
          final List<Campaign> campaigns = snapshot.data?[0] ?? [];
          
          // Handle the case where there are no campaigns
          if (campaigns.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: Icon(
                      Icons.campaign,
                      size: 60,
                      color: primaryColor.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context)!.noCampaignsAssigned,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.viewAssignedCampaigns,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: textSecondaryColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Show campaigns directly without tabs
          return _buildCampaignsList(campaigns);
        },
            ),
          ),
        ],
        ),
      ),
    );
  }

  /// Builds the list view for campaigns.
  Widget _buildCampaignsList(List<Campaign> campaigns) {
    return RefreshIndicator(
      onRefresh: () async => refreshAll(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0),
        itemCount: campaigns.length,
        itemBuilder: (context, index) {
          final campaign = campaigns[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CampaignCard(
              campaign: campaign,
              isInsideGeofence: _geofenceStatuses[campaign.id],
              onTap: () {
                widget.locationService.setActiveCampaign(campaign.id);
                // Also set active campaign in background service
                BackgroundLocationService.setActiveCampaign(campaign.id);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        AgentTaskListScreen(campaign: campaign)));
              },
            ),
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
      final String message = isInsideGeofence!
          ? '✅ ${AppLocalizations.of(context)!.insideGeofence}'
          : '❌ ${AppLocalizations.of(context)!.outsideGeofence}';
      
      final Color bgColor = isInsideGeofence!
          ? successColor.withValues(alpha: 0.1)
          : errorColor.withValues(alpha: 0.1);

      statusWidget = Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Center(
              child: Text(message,
                  style: TextStyle(
                      color: isInsideGeofence!
                          ? successColor
                          : errorColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold))));
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 90),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: lightShadowColor,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryColor.withValues(alpha: 0.15),
                          primaryLightColor.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.campaign,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: textPrimaryColor,
                            letterSpacing: 0.2,
                          ),
                          softWrap: true,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppLocalizations.of(context)!.ends} ${DateFormat.yMMMd().format(campaign.endDate)}',
                          style: const TextStyle(
                            color: textSecondaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showAdminActions) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: primaryColor,
                        tooltip: AppLocalizations.of(context)!.editCampaign,
                        onPressed: onEdit,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: errorColor,
                        tooltip: AppLocalizations.of(context)!.deleteCampaign,
                        onPressed: onDelete,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.arrow_forward_ios,
                      color: textSecondaryColor,
                      size: 16,
                    ),
                  ]
                ]),
              ),
              if (statusWidget != null) statusWidget,
            ],
          ),
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
    final color = isCompleted ? successColor : warningColor;
    
    return Container(
      constraints: const BoxConstraints(minHeight: 90),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: lightShadowColor,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.15),
                      color.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle : Icons.assignment,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: textPrimaryColor,
                        letterSpacing: 0.2,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)!.pointsFormat(task.points.toString()),
                      style: const TextStyle(
                        color: textSecondaryColor,
                        fontSize: 13,
                    ),
                  ),
                  ],
                ),
              ),
              if (task.enforceGeofence == true)
                Container(
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.location_on_outlined, size: 18),
                    color: primaryColor,
                    tooltip: AppLocalizations.of(context)!.viewTaskLocation,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => TaskLocationViewerScreen(task: task),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                color: textSecondaryColor,
                size: 16,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
