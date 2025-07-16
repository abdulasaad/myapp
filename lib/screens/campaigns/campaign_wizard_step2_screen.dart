// lib/screens/campaigns/campaign_wizard_step2_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_user.dart';
import '../../models/campaign.dart';
import '../../models/campaign_geofence.dart';
import '../../models/agent_geofence_assignment.dart';
import '../../models/touring_task.dart';
import '../../services/touring_task_service.dart';
import '../../services/profile_service.dart';
import '../../services/simple_notification_service.dart';
import '../../services/campaign_geofence_service.dart';
import '../../utils/constants.dart';
import '../../widgets/modern_notification.dart';
import 'campaign_wizard_step3_screen.dart';
import 'campaign_geofence_management_screen.dart';
import '../agent/geofence_selection_screen.dart';
import '../tasks/create_touring_task_screen.dart';

// Helper class to store temporary geofence data during wizard
class TempGeofenceData {
  final String id;
  final String name;
  final String? description;
  final String areaText;
  final int maxAgents;
  final String color;
  
  TempGeofenceData({
    required this.id,
    required this.name,
    this.description,
    required this.areaText,
    required this.maxAgents,
    required this.color,
  });
}

// Helper class to store temporary touring task data during wizard
class TempTouringTaskData {
  final String id;
  final String title;
  final String? description;
  final int requiredTimeMinutes;
  final int movementTimeoutSeconds;
  final double minMovementThreshold;
  final int points;
  final bool useSchedule;
  final String? dailyStartTime;
  final String? dailyEndTime;
  final String geofenceId;
  
  TempTouringTaskData({
    required this.id,
    required this.title,
    this.description,
    required this.requiredTimeMinutes,
    required this.movementTimeoutSeconds,
    required this.minMovementThreshold,
    required this.points,
    required this.useSchedule,
    this.dailyStartTime,
    this.dailyEndTime,
    required this.geofenceId,
  });
}

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
  // late Future<List<Task>> _tasksFuture;
  late Future<List<TouringTask>> _touringTasksFuture;
  late Future<List<CampaignGeofence>> _geofencesFuture;
  late Future<AgentGeofenceAssignment?> _currentAssignmentFuture;
  final SimpleNotificationService _notificationService = SimpleNotificationService();
  final CampaignGeofenceService _geofenceService = CampaignGeofenceService();
  final TouringTaskService _touringTaskService = TouringTaskService();
  
  // Create a temporary campaign for the wizard
  late Campaign _tempCampaign;
  
  // Store temporary geofences during wizard process
  final List<TempGeofenceData> _tempGeofences = [];
  
  // Store temporary touring tasks during wizard process
  final List<TempTouringTaskData> _tempTouringTasks = [];
  
  // Store temporary agent assignments during wizard process
  final List<String> _tempAssignedAgentIds = [];

  @override
  void initState() {
    super.initState();
    _createTempCampaign();
    _assignedAgentsFuture = _fetchAssignedAgents();
    // _tasksFuture = _fetchTasks();
    _touringTasksFuture = _fetchTouringTasks();
    _geofencesFuture = _fetchGeofences();
    _currentAssignmentFuture = _fetchCurrentAssignment();
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

  void _refreshAll() {
    setState(() {
      _assignedAgentsFuture = _fetchAssignedAgents();
      // _tasksFuture = _fetchTasks();
      _touringTasksFuture = _fetchTouringTasks();
      _geofencesFuture = _fetchGeofences();
      _currentAssignmentFuture = _fetchCurrentAssignment();
    });
  }

  // --- DATA FETCHING ---
  Future<List<AppUser>> _fetchAssignedAgents() async {
    if (!widget.isEditing) {
      // For new campaigns, fetch agent details for temporary assignments
      if (_tempAssignedAgentIds.isEmpty) return [];
      
      final agentsResponse = await supabase
          .from('profiles')
          .select('id, full_name')
          .filter('id', 'in', '(${_tempAssignedAgentIds.join(',')})');

      return agentsResponse.map((json) => AppUser.fromJson(json)).toList();
    }
    
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

  // Removed _fetchTasks - not needed for this implementation

  Future<List<TouringTask>> _fetchTouringTasks() async {
    if (!widget.isEditing) {
      // For new campaigns, convert temp touring tasks to TouringTask objects for display
      return _tempTouringTasks.map((tempTask) {
        return TouringTask(
          id: tempTask.id,
          campaignId: _tempCampaign.id,
          geofenceId: tempTask.geofenceId,
          title: tempTask.title,
          description: tempTask.description,
          requiredTimeMinutes: tempTask.requiredTimeMinutes,
          movementTimeoutSeconds: tempTask.movementTimeoutSeconds,
          minMovementThreshold: tempTask.minMovementThreshold,
          points: tempTask.points,
          status: 'active',
          useSchedule: tempTask.useSchedule,
          dailyStartTime: tempTask.dailyStartTime,
          dailyEndTime: tempTask.dailyEndTime,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();
    }
    
    try {
      return await _touringTaskService.getTouringTasksForCampaign(widget.existingCampaign!.id);
    } catch (e) {
      debugPrint('Error fetching touring tasks: $e');
      return [];
    }
  }

  Future<List<CampaignGeofence>> _fetchGeofences() async {
    if (!widget.isEditing) {
      // For new campaigns, convert temp geofences to CampaignGeofence objects for display
      return _tempGeofences.map((tempGeofence) {
        return CampaignGeofence(
          id: tempGeofence.id,
          campaignId: _tempCampaign.id,
          name: tempGeofence.name,
          description: tempGeofence.description,
          areaText: tempGeofence.areaText,
          maxAgents: tempGeofence.maxAgents,
          color: Color(int.parse('0xFF${tempGeofence.color}') & 0xFFFFFFFF),
          isActive: true,
          currentAgents: 0,
          createdAt: DateTime.now(),
        );
      }).toList();
    }
    
    try {
      return await _geofenceService.getAvailableGeofencesForCampaign(widget.existingCampaign!.id);
    } catch (e) {
      debugPrint('Error fetching geofences: $e');
      return [];
    }
  }

  Future<AgentGeofenceAssignment?> _fetchCurrentAssignment() async {
    if (!widget.isEditing) return null;
    
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return null;
      
      return await _geofenceService.getAgentCurrentAssignment(
        campaignId: widget.existingCampaign!.id,
        agentId: currentUser.id,
      );
    } catch (e) {
      debugPrint('Error fetching current assignment: $e');
      return null;
    }
  }

  // --- EXACT FUNCTIONS FROM CAMPAIGN DETAIL SCREEN ---

  // Removed _addTask - not needed for this implementation

  Future<void> _showAddTouringTaskDialog() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateTouringTaskScreen(
          campaign: widget.existingCampaign ?? _tempCampaign,
          tempGeofences: widget.isEditing ? null : _tempGeofences,
          onTempTouringTaskAdded: widget.isEditing ? null : _onTempTouringTaskAdded,
        ),
      ),
    );
    
    if (result != null) {
      _refreshAll();
    }
  }

  // Removed _showAddTaskDialog - not needed for this implementation

  Future<void> _assignAgent(String agentId) async {
    if (!widget.isEditing) {
      // For new campaigns, add to temporary assignments
      if (_tempAssignedAgentIds.contains(agentId)) {
        ModernNotification.warning(
          context,
          message: 'Agent already assigned',
          subtitle: 'This agent is already assigned to the campaign',
        );
        return;
      }
      
      setState(() {
        _tempAssignedAgentIds.add(agentId);
      });
      
      if (mounted) {
        ModernNotification.success(
          context,
          message: 'Agent assigned to campaign',
          subtitle: 'The agent will be notified when the campaign is created',
        );
        _refreshAll();
      }
      return;
    }

    try {
      final currentUserId = supabase.auth.currentUser!.id;
      await supabase.from('campaign_agents').upsert({
        'campaign_id': widget.existingCampaign!.id,
        'agent_id': agentId,
        'assigned_by': currentUserId
      }); 

      // Auto-assign all campaign tasks to the agent
      final tasks = await supabase
          .from('tasks')
          .select('id')
          .eq('campaign_id', widget.existingCampaign!.id);
      
      for (final task in tasks) {
        try {
          // Check if assignment already exists
          final existingAssignment = await supabase
              .from('task_assignments')
              .select('id, status')
              .eq('task_id', task['id'])
              .eq('agent_id', agentId)
              .maybeSingle();
          
          if (existingAssignment == null) {
            // Create new assignment with 'assigned' status
            await supabase.from('task_assignments').insert({
              'task_id': task['id'],
              'agent_id': agentId,
              'status': 'assigned',
              'created_at': DateTime.now().toIso8601String(),
            });
          } else if (existingAssignment['status'] == 'pending') {
            // Update pending assignments to assigned
            await supabase
                .from('task_assignments')
                .update({'status': 'assigned'})
                .eq('id', existingAssignment['id']);
          }
        } catch (e) {
          Logger().e('Failed to assign task ${task['id']} to agent: $e');
        }
      }

      // Send notification to the agent
      try {
        Logger().i('Sending notification to agent: $agentId for campaign: ${widget.existingCampaign!.name}');
        await _notificationService.createNotification(
          recipientId: agentId,
          title: AppLocalizations.of(context)!.campaignAssignment,
          message: 'You have been assigned to campaign "${widget.existingCampaign!.name}"',
          type: 'campaign_assignment',
          data: {
            'campaign_id': widget.existingCampaign!.id,
            'campaign_name': widget.existingCampaign!.name,
          },
        );
        Logger().i('Notification sent successfully to agent: $agentId');
      } catch (e) {
        Logger().e('Failed to send notification to agent: $e');
        Logger().e('Stack trace: ${StackTrace.current}');
      }

      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.agentAssignedSuccess);
        _refreshAll();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.agentAssignFailed(e.toString()), isError: true);
      }
    }
  }

  Future<void> _showAssignAgentDialog() async {

    final allAgentsResponse = await supabase.from('profiles').select('id, full_name').eq('role', 'agent');
    final allAgents = allAgentsResponse.map((json) => AppUser.fromJson(json)).toList();
    if (!mounted) return;

    final selectedAgent = await showDialog<AppUser>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.assignAnAgent),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allAgents.length,
            itemBuilder: (context, index) {
              final agent = allAgents[index];
              return ListTile(
                  title: Text(agent.fullName),
                  onTap: () => Navigator.of(context).pop(agent));
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.cancel))
        ],
      ),
    );

    if (selectedAgent != null) {
      _assignAgent(selectedAgent.id);
    }
  }

  // --- TEMP GEOFENCE MANAGEMENT ---
  void _onTempGeofenceAdded(TempGeofenceData geofence) {
    setState(() {
      _tempGeofences.add(geofence);
    });
  }
  
  // --- TEMP TOURING TASK MANAGEMENT ---
  void _onTempTouringTaskAdded(TempTouringTaskData touringTask) {
    setState(() {
      _tempTouringTasks.add(touringTask);
    });
  }
  
  // --- NAVIGATION ---
  void _goToNextStep() {
    // Pass temporary data to step 3
    final updatedCampaignData = Map<String, dynamic>.from(widget.campaignData);
    updatedCampaignData['temp_geofences'] = _tempGeofences;
    updatedCampaignData['temp_touring_tasks'] = _tempTouringTasks;
    updatedCampaignData['temp_assigned_agent_ids'] = _tempAssignedAgentIds;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CampaignWizardStep3Screen(
          campaignData: updatedCampaignData,
          isEditing: widget.isEditing,
          existingCampaign: widget.existingCampaign,
        ),
      ),
    );
  }

  void _goBack() {
    Navigator.of(context).pop();
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
          
          // Main content - EXACT SAME AS CAMPAIGN DETAIL SCREEN
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
          
          // Bottom navigation for wizard
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

  // --- EXACT SAME BUILD METHODS FROM CAMPAIGN DETAIL SCREEN ---

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_tempCampaign.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (_tempCampaign.description != null && _tempCampaign.description!.isNotEmpty)
            Text(_tempCampaign.description!, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          Text('Start Date: ${DateFormat.yMMMd().format(_tempCampaign.startDate)}'),
          Text('End Date: ${DateFormat.yMMMd().format(_tempCampaign.endDate)}'),
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
        ]),
      ),
    );
  }

  Widget _buildGeofenceSection() {
    return FutureBuilder<List<CampaignGeofence>>(
      future: _geofencesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  Text('Loading geofences...'),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }
        final geofences = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Work Zones (Geofences)',
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
                if (ProfileService.instance.canManageCampaigns)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CampaignGeofenceManagementScreen(
                            campaign: widget.existingCampaign ?? _tempCampaign,
                            tempGeofences: widget.isEditing ? null : _tempGeofences,
                            onTempGeofenceAdded: widget.isEditing ? null : _onTempGeofenceAdded,
                          ),
                        ),
                      ).then((_) => _refreshAll());
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Manage'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (geofences.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.location_on, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.noGeofencesCreated,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create work zones to define areas for your campaign',
                        style: const TextStyle(
                          fontSize: 14,
                          color: textSecondaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...geofences.map((geofence) => _buildGeofenceCard(geofence)),
            const SizedBox(height: 16),
            _buildAgentGeofenceButton(),
          ],
        );
      },
    );
  }

  Widget _buildGeofenceCard(CampaignGeofence geofence) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: geofence.color, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: geofence.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  geofence.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (geofence.description != null && geofence.description!.isNotEmpty)
                  Text(
                    geofence.description!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: textSecondaryColor,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  geofence.capacityText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentGeofenceButton() {
    return FutureBuilder<AgentGeofenceAssignment?>(
      future: _currentAssignmentFuture,
      builder: (context, assignmentSnapshot) {
        final hasAssignment = assignmentSnapshot.data != null;
        
        if (!ProfileService.instance.canManageCampaigns) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasAssignment)
                    Column(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.assignedToGeofence,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          assignmentSnapshot.data!.geofenceName ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 14,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Icon(Icons.location_searching, color: Colors.grey[400], size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'No geofence assignment',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (!widget.isEditing) {
                              ModernNotification.info(
                                context,
                                message: 'Create the campaign first',
                                subtitle: 'You can select geofences after creating the campaign',
                              );
                              return;
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => GeofenceSelectionScreen(
                                  campaign: widget.existingCampaign!,
                                ),
                              ),
                            ).then((_) => _refreshAll());
                          },
                          icon: const Icon(Icons.add_location),
                          label: Text(AppLocalizations.of(context)!.selectGeofence),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSectionHeader(String title, {required VoidCallback onPressed, required String buttonLabel}) {
    // Create a shorter button label for better fit
    String shortButtonLabel = buttonLabel;
    if (buttonLabel == 'Add Touring Task') {
      shortButtonLabel = 'Add Task';
    } else if (buttonLabel.toLowerCase().contains('assign')) {
      shortButtonLabel = 'Assign';
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        ElevatedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add, size: 16),
          label: Text(shortButtonLabel),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTouringTasksList() {
    return FutureBuilder<List<TouringTask>>(
      future: _touringTasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return preloader;
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        final tasks = snapshot.data!;
        if (tasks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.tour, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No touring tasks created yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create touring tasks that use your work zones',
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return _buildTouringTaskCard(task);
          },
        );
      },
    );
  }

  Widget _buildTouringTaskCard(TouringTask task) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.tour, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimaryColor,
                          ),
                        ),
                        if (task.description != null && task.description!.isNotEmpty)
                          Text(
                            task.description!,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTaskInfoChip(
                    Icons.schedule,
                    task.formattedDuration,
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildTaskInfoChip(
                    Icons.directions_walk,
                    task.movementTimeoutText,
                    Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildTaskInfoChip(
                    Icons.stars,
                    '${task.points} pts',
                    Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedAgentsList() {
    return FutureBuilder<List<AppUser>>(
      future: _assignedAgentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return preloader;
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final agents = snapshot.data!;
        if (agents.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.people, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noAgentsAssigned,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Assign agents to participate in this campaign',
                    style: const TextStyle(
                      fontSize: 14,
                      color: textSecondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: agents.length,
          itemBuilder: (context, index) {
            final agent = agents[index];
            return AgentCard(
              agent: agent,
              campaign: widget.existingCampaign ?? _tempCampaign,
              isTemporary: !widget.isEditing,
              onRemove: () {
                if (!widget.isEditing) {
                  setState(() {
                    _tempAssignedAgentIds.remove(agent.id);
                  });
                }
                _refreshAll();
              },
            );
          },
        );
      },
    );
  }
}

// Agent Card Widget - exactly like in campaign detail screen
class AgentCard extends StatefulWidget {
  final AppUser agent;
  final Campaign campaign;
  final VoidCallback onRemove;
  final bool isTemporary;

  const AgentCard({
    super.key,
    required this.agent,
    required this.campaign,
    required this.onRemove,
    this.isTemporary = false,
  });

  @override
  State<AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<AgentCard> {
  Map<String, dynamic>? _earningsData;
  // bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    // Skip loading earnings for temporary assignments
    if (widget.isTemporary) {
      setState(() {
        _earningsData = {'outstanding_balance': 0};
      });
      return;
    }
    
    try {
      final response = await supabase
          .rpc('get_agent_earnings_for_campaign', params: {
        'p_agent_id': widget.agent.id,
        'p_campaign_id': widget.campaign.id,
      });

      if (mounted) {
        setState(() {
          _earningsData = response.isNotEmpty ? response.first : {'outstanding_balance': 0};
          // _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _earningsData = {'outstanding_balance': 0};
          // _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeAgent() async {
    if (widget.isTemporary) {
      // For temporary assignments, just call onRemove
      widget.onRemove();
      return;
    }
    
    try {
      await supabase
          .from('campaign_agents')
          .delete()
          .eq('campaign_id', widget.campaign.id)
          .eq('agent_id', widget.agent.id);
      
      if (mounted) {
        widget.onRemove();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove agent: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _earningsData?['outstanding_balance'] ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
            child: Text(widget.agent.fullName.substring(0, 1).toUpperCase())),
        title: Text(widget.agent.fullName),
        subtitle: _earningsData == null
            ? Text(AppLocalizations.of(context)!.loadingEarnings)
            : Text('${AppLocalizations.of(context)!.outstandingBalance}: ${balance.toString()} ${AppLocalizations.of(context)!.points}'),
        trailing: IconButton(
          icon: const Icon(Icons.person_remove_outlined),
          color: Colors.red[300],
          tooltip: AppLocalizations.of(context)!.removeAgent,
          onPressed: _removeAgent,
        ),
      ),
    );
  }
}