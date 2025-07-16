// lib/screens/campaigns/campaign_wizard_step2_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/campaign.dart';
import '../../models/app_user.dart';
import '../../models/campaign_geofence.dart';
import '../../models/task.dart';
import '../../models/touring_task.dart';
import '../../services/touring_task_service.dart';
import '../../services/profile_service.dart';
import '../../services/campaign_geofence_service.dart';
import '../../utils/constants.dart';
import '../../widgets/modern_notification.dart';
import 'campaign_wizard_step3_screen.dart';
import 'campaign_geofence_management_screen.dart';
import '../tasks/create_touring_task_screen.dart';

class CampaignWizardStep2Screen extends StatefulWidget {
  final Map<String, dynamic> campaignData;
  final bool isEditing;
  final Campaign? existingCampaign;

  const CampaignWizardStep2Screen({
    super.key,
    required this.campaignData,
    required this.isEditing,
    this.existingCampaign,
  });

  @override
  State<CampaignWizardStep2Screen> createState() => _CampaignWizardStep2ScreenState();
}

class _CampaignWizardStep2ScreenState extends State<CampaignWizardStep2Screen> {
  late Future<List<AppUser>> _assignedAgentsFuture;
  late Future<List<Task>> _tasksFuture;
  late Future<List<TouringTask>> _touringTasksFuture;
  late Future<List<CampaignGeofence>> _geofencesFuture;
  
  final CampaignGeofenceService _geofenceService = CampaignGeofenceService();
  final TouringTaskService _touringTaskService = TouringTaskService();
  
  // Create a temporary campaign for the wizard
  late Campaign _tempCampaign;

  @override
  void initState() {
    super.initState();
    _createTempCampaign();
    _loadData();
  }

  void _createTempCampaign() {
    // Create a temporary campaign object for the wizard
    final selectedDays = widget.campaignData['selected_days'] as Set<DateTime>;
    final sortedDays = selectedDays.toList()..sort();
    
    _tempCampaign = Campaign(
      id: widget.existingCampaign?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
      name: widget.campaignData['name'],
      description: widget.campaignData['description'],
      startDate: sortedDays.first,
      endDate: sortedDays.last,
      status: 'draft',
      createdAt: DateTime.now(),
      packageType: 'standard',
    );
  }

  void _loadData() {
    if (widget.isEditing && widget.existingCampaign != null) {
      // Load existing campaign data
      _assignedAgentsFuture = _fetchAssignedAgents();
      _tasksFuture = _fetchTasks();
      _touringTasksFuture = _fetchTouringTasks();
      _geofencesFuture = _fetchGeofences();
    } else {
      // Empty data for new campaign
      _assignedAgentsFuture = Future.value([]);
      _tasksFuture = Future.value([]);
      _touringTasksFuture = Future.value([]);
      _geofencesFuture = Future.value([]);
    }
  }

  void _refreshAll() {
    setState(() {
      _loadData();
    });
  }

  Future<List<AppUser>> _fetchAssignedAgents() async {
    if (!widget.isEditing) return [];
    
    final agentIdsResponse = await supabase
        .from('campaign_agents')
        .select('agent_id')
        .eq('campaign_id', widget.existingCampaign!.id);

    final agentIds = agentIdsResponse.map((map) => map['agent_id'] as String).toList();

    if (agentIds.isEmpty) return [];
    
    final agentsResponse = await supabase
        .from('profiles')
        .select('id, full_name')
        .filter('id', 'in', '(${agentIds.join(',')})');

    return agentsResponse.map((json) => AppUser.fromJson(json)).toList();
  }

  Future<List<Task>> _fetchTasks() async {
    if (!widget.isEditing) return [];
    
    final response = await supabase
        .from('tasks')
        .select()
        .eq('campaign_id', widget.existingCampaign!.id)
        .order('created_at', ascending: true);
    return response.map((json) => Task.fromJson(json)).toList();
  }

  Future<List<TouringTask>> _fetchTouringTasks() async {
    if (!widget.isEditing) return [];
    
    try {
      return await _touringTaskService.getTouringTasksForCampaign(widget.existingCampaign!.id);
    } catch (e) {
      debugPrint('Error fetching touring tasks: $e');
      return [];
    }
  }

  Future<List<CampaignGeofence>> _fetchGeofences() async {
    if (!widget.isEditing) return [];
    
    try {
      return await _geofenceService.getAvailableGeofencesForCampaign(widget.existingCampaign!.id);
    } catch (e) {
      debugPrint('Error fetching geofences: $e');
      return [];
    }
  }

  void _goToNextStep() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CampaignWizardStep3Screen(
          campaignData: widget.campaignData,
          isEditing: widget.isEditing,
          existingCampaign: widget.existingCampaign,
        ),
      ),
    );
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  void _showAddTouringTaskDialog() {
    if (!widget.isEditing) {
      ModernNotification.info(
        context,
        message: 'Create the campaign first',
        subtitle: 'You can add touring tasks after creating the campaign',
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateTouringTaskScreen(campaign: widget.existingCampaign!),
      ),
    ).then((result) {
      if (result != null) {
        _refreshAll();
      }
    });
  }

  void _showAssignAgentDialog() {
    if (!widget.isEditing) {
      ModernNotification.info(
        context,
        message: 'Create the campaign first',
        subtitle: 'You can assign agents after creating the campaign',
      );
      return;
    }

    ModernNotification.info(
      context,
      message: 'Agent assignment will be available here',
    );
  }

  void _navigateToGeofenceManagement() {
    if (!widget.isEditing) {
      ModernNotification.info(
        context,
        message: 'Create the campaign first',
        subtitle: 'You can add geofences after creating the campaign',
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CampaignGeofenceManagementScreen(
          campaign: widget.existingCampaign!,
        ),
      ),
    ).then((_) {
      _refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.isEditing ? AppLocalizations.of(context)!.editCampaign : 'Create Campaign - Step 2'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStepIndicator(1, false, 'Basic Info'),
                Expanded(child: Container(height: 2, color: Colors.grey[300])),
                _buildStepIndicator(2, true, 'Setup'),
                Expanded(child: Container(height: 2, color: Colors.grey[300])),
                _buildStepIndicator(3, false, 'Review'),
              ],
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refreshAll(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 24),
                    _buildGeofenceSection(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Touring Tasks',
                        onPressed: _showAddTouringTaskDialog, buttonLabel: 'Add Touring Task'),
                    _buildTouringTasksList(),
                    const SizedBox(height: 24),
                    _buildSectionHeader(AppLocalizations.of(context)!.assignedAgents,
                        onPressed: _showAssignAgentDialog, buttonLabel: AppLocalizations.of(context)!.assignAgent),
                    _buildAssignedAgentsList(),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom navigation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _goBack,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_back, size: 18),
                        const SizedBox(width: 8),
                        Text('Back'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _goToNextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Next',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int stepNumber, bool isActive, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? primaryColor : Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: isActive ? Colors.white : Colors.grey[400],
            child: Text(
              stepNumber.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isActive ? primaryColor : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign, color: primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tempCampaign.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimaryColor,
                      ),
                    ),
                    if (_tempCampaign.description != null && _tempCampaign.description!.isNotEmpty)
                      Text(
                        _tempCampaign.description!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: textSecondaryColor,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                '${DateFormat.yMMMd().format(_tempCampaign.startDate)} - ${DateFormat.yMMMd().format(_tempCampaign.endDate)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: textSecondaryColor,
                ),
              ),
            ],
          ),
          if (!widget.isEditing)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Campaign setup will be available after creation',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGeofenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Work Zones (Geofences)',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TextButton.icon(
              onPressed: _navigateToGeofenceManagement,
              icon: const Icon(Icons.add),
              label: const Text('Manage Geofences'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<CampaignGeofence>>(
          future: _geofencesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            final geofences = snapshot.data!;
            if (geofences.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.location_on, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'No work zones created yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textSecondaryColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Create work zones to define areas for your campaign',
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: geofences.length,
              itemBuilder: (context, index) {
                final geofence = geofences[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: geofence.color,
                      radius: 12,
                    ),
                    title: Text(geofence.name),
                    subtitle: Text(geofence.capacityText),
                    trailing: Icon(Icons.location_on, color: geofence.color),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {required VoidCallback onPressed, required String buttonLabel}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add),
          label: Text(buttonLabel),
        ),
      ],
    );
  }

  Widget _buildTouringTasksList() {
    return FutureBuilder<List<TouringTask>>(
      future: _touringTasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        final tasks = snapshot.data!;
        if (tasks.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              children: [
                Icon(Icons.tour, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'No touring tasks created yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textSecondaryColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Create touring tasks that use your work zones',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.tour, color: primaryColor),
                title: Text(task.title),
                subtitle: Text(task.description ?? 'No description'),
                trailing: Text('${task.points} pts'),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAssignedAgentsList() {
    return FutureBuilder<List<AppUser>>(
      future: _assignedAgentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        final agents = snapshot.data!;
        if (agents.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              children: [
                Icon(Icons.people, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'No agents assigned yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textSecondaryColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Assign agents to work on this campaign',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: agents.length,
          itemBuilder: (context, index) {
            final agent = agents[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(agent.fullName.isNotEmpty ? agent.fullName[0] : 'A'),
                ),
                title: Text(agent.fullName),
                trailing: Icon(Icons.person, color: primaryColor),
              ),
            );
          },
        );
      },
    );
  }
}