// lib/screens/campaigns/campaign_wizard_step3_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/campaign.dart';
import '../../utils/constants.dart';
import '../../widgets/modern_notification.dart';
import '../../services/campaign_geofence_service.dart';
import '../../services/touring_task_service.dart';
import 'campaign_wizard_step2_screen.dart';
import '../modern_home_screen.dart';

class CampaignWizardStep3Screen extends StatefulWidget {
  final Map<String, dynamic> campaignData;
  final bool isEditing;
  final Campaign? existingCampaign;

  const CampaignWizardStep3Screen({
    super.key,
    required this.campaignData,
    required this.isEditing,
    this.existingCampaign,
  });

  @override
  State<CampaignWizardStep3Screen> createState() => _CampaignWizardStep3ScreenState();
}

class _CampaignWizardStep3ScreenState extends State<CampaignWizardStep3Screen> {
  bool _isCreating = false;
  final CampaignGeofenceService _geofenceService = CampaignGeofenceService();
  final TouringTaskService _touringTaskService = TouringTaskService();

  void _goBack() {
    Navigator.of(context).pop();
  }

  Future<void> _createCampaign() async {
    setState(() => _isCreating = true);
    
    try {
      final campaignData = Map<String, dynamic>.from(widget.campaignData);
      
      // Remove the selected_days from campaignData as it's not needed for database
      campaignData.remove('selected_days');
      
      if (widget.isEditing) {
        await supabase
            .from('campaigns')
            .update(campaignData)
            .eq('id', widget.existingCampaign!.id);
        
        if (mounted) {
          ModernNotification.success(
            context,
            message: AppLocalizations.of(context)!.campaignUpdatedSuccessfully,
            subtitle: campaignData['name'],
          );
          
          // Navigate back to main screen with campaigns tab selected
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const ModernHomeScreen(
                initialTabIndex: 1, // Select campaigns tab
              ),
            ),
            (route) => false, // Remove all previous routes
          );
        }
      } else {
        final userId = supabase.auth.currentUser!.id;
        campaignData['created_by'] = userId;
        
        // Remove temp data before inserting campaign
        final tempGeofences = campaignData.remove('temp_geofences') as List<TempGeofenceData>?;
        final tempTouringTasks = campaignData.remove('temp_touring_tasks') as List<TempTouringTaskData>?;
        final tempAssignedAgentIds = campaignData.remove('temp_assigned_agent_ids') as List<String>?;
        
        final response = await supabase
            .from('campaigns')
            .insert(campaignData)
            .select()
            .single();
        
        final campaign = Campaign.fromJson(response);
        
        // Create geofences if any were added during wizard
        // Store mapping of temp geofence IDs to real geofence IDs
        final Map<String, String> geofenceIdMapping = {};
        
        if (tempGeofences != null && tempGeofences.isNotEmpty) {
          for (final tempGeofence in tempGeofences) {
            try {
              final createdGeofence = await _geofenceService.createCampaignGeofence(
                campaignId: campaign.id,
                name: tempGeofence.name,
                description: tempGeofence.description,
                areaText: tempGeofence.areaText,
                maxAgents: tempGeofence.maxAgents,
                color: '#${tempGeofence.color}',
              );
              // Map the temporary ID to the real ID
              geofenceIdMapping[tempGeofence.id] = createdGeofence.id;
              debugPrint('✅ Mapped temp geofence ID ${tempGeofence.id} to real ID ${createdGeofence.id}');
            } catch (e) {
              debugPrint('Error creating geofence "${tempGeofence.name}": $e');
              // Continue with other geofences even if one fails
            }
          }
        }
        
        // Create touring tasks if any were added during wizard
        if (tempTouringTasks != null && tempTouringTasks.isNotEmpty) {
          for (final tempTouringTask in tempTouringTasks) {
            try {
              // Use the real geofence ID from the mapping
              final realGeofenceId = geofenceIdMapping[tempTouringTask.geofenceId];
              
              if (realGeofenceId != null) {
                debugPrint('✅ Creating touring task "${tempTouringTask.title}" with real geofence ID $realGeofenceId (was ${tempTouringTask.geofenceId})');
                await _touringTaskService.createTouringTask(
                  campaignId: campaign.id,
                  geofenceId: realGeofenceId,
                  title: tempTouringTask.title,
                  description: tempTouringTask.description,
                  requiredTimeMinutes: tempTouringTask.requiredTimeMinutes,
                  movementTimeoutSeconds: tempTouringTask.movementTimeoutSeconds,
                  minMovementThreshold: tempTouringTask.minMovementThreshold,
                  points: tempTouringTask.points,
                  useSchedule: tempTouringTask.useSchedule,
                  dailyStartTime: tempTouringTask.dailyStartTime,
                  dailyEndTime: tempTouringTask.dailyEndTime,
                );
                debugPrint('✅ Successfully created touring task "${tempTouringTask.title}"');
              } else {
                debugPrint('❌ Error creating touring task "${tempTouringTask.title}": geofence ID mapping not found for ${tempTouringTask.geofenceId}');
              }
            } catch (e) {
              debugPrint('Error creating touring task "${tempTouringTask.title}": $e');
              // Continue with other touring tasks even if one fails
            }
          }
        }
        
        // Assign agents if any were assigned during wizard
        if (tempAssignedAgentIds != null && tempAssignedAgentIds.isNotEmpty) {
          final currentUserId = supabase.auth.currentUser!.id;
          for (final agentId in tempAssignedAgentIds) {
            try {
              await supabase.from('campaign_agents').insert({
                'campaign_id': campaign.id,
                'agent_id': agentId,
                'assigned_by': currentUserId,
              });
              
              // Send notification to the agent
              try {
                await supabase.from('notifications').insert({
                  'recipient_id': agentId,
                  'title': 'Campaign Assignment',
                  'message': 'You have been assigned to campaign "${campaign.name}"',
                  'type': 'campaign_assignment',
                  'data': {
                    'campaign_id': campaign.id,
                    'campaign_name': campaign.name,
                  },
                });
              } catch (e) {
                debugPrint('Error sending notification to agent $agentId: $e');
              }
            } catch (e) {
              debugPrint('Error assigning agent $agentId: $e');
              // Continue with other agents even if one fails
            }
          }
        }
        
        if (mounted) {
          ModernNotification.success(
            context,
            message: AppLocalizations.of(context)!.campaignCreatedSuccessfully,
            subtitle: campaignData['name'],
          );
          
          // Add a small delay to ensure all database operations are completed
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Navigate back to main screen with campaigns tab selected
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const ModernHomeScreen(
                  initialTabIndex: 1, // Select campaigns tab
                ),
              ),
              (route) => false, // Remove all previous routes
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ModernNotification.error(
          context,
          message: AppLocalizations.of(context)!.failedToCreateCampaign,
          subtitle: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDays = widget.campaignData['selected_days'] as Set<DateTime>;
    final sortedDays = selectedDays.toList()..sort();
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.isEditing ? AppLocalizations.of(context)!.editCampaign : 'Create Campaign - Review'),
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
                _buildStepIndicator(2, false, 'Setup'),
                Expanded(child: Container(height: 2, color: Colors.grey[300])),
                _buildStepIndicator(3, true, 'Review'),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
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
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.preview,
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
                                    'Review Campaign',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimaryColor,
                                    ),
                                  ),
                                  Text(
                                    'Review your campaign details before creating',
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
                        const SizedBox(height: 24),
                        
                        // Campaign details
                        _buildDetailItem(
                          'Campaign Name',
                          widget.campaignData['name'],
                          Icons.campaign,
                        ),
                        
                        if (widget.campaignData['description'] != null && widget.campaignData['description'].toString().isNotEmpty)
                          _buildDetailItem(
                            'Description',
                            widget.campaignData['description'],
                            Icons.description,
                          ),
                        
                        _buildDetailItem(
                          'Start Date',
                          DateFormat.yMMMd().format(sortedDays.first),
                          Icons.calendar_today,
                        ),
                        
                        _buildDetailItem(
                          'End Date',
                          DateFormat.yMMMd().format(sortedDays.last),
                          Icons.calendar_today,
                        ),
                        
                        _buildDetailItem(
                          'Duration',
                          '${selectedDays.length} days',
                          Icons.timeline,
                        ),
                        
                        if (widget.campaignData['assigned_manager_id'] != null)
                          _buildDetailItem(
                            'Assigned Manager',
                            'Manager assigned',
                            Icons.person,
                          ),
                        
                        const SizedBox(height: 24),
                        
                        // Selected days preview
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_month, size: 16, color: primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Selected Days',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                selectedDays.length <= 10
                                    ? selectedDays
                                        .map((d) => DateFormat.MMMd().format(d))
                                        .join(', ')
                                    : '${DateFormat.MMMd().format(sortedDays.first)} - ${DateFormat.MMMd().format(sortedDays.last)} (${selectedDays.length} days)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Geofences preview
                        _buildGeofencesPreview(),
                        
                        const SizedBox(height: 24),
                        
                        // Touring tasks preview
                        _buildTouringTasksPreview(),
                        
                        const SizedBox(height: 24),
                        
                        // Assigned agents preview
                        _buildAssignedAgentsPreview(),
                        
                        const SizedBox(height: 24),
                        
                        // Next steps info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.green[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Next Steps',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'After creating the campaign, you can:\n'
                                '• Add more work zones (geofences)\n'
                                '• Create tasks and touring tasks\n'
                                '• Assign agents to the campaign\n'
                                '• Monitor campaign progress',
                                style: TextStyle(fontSize: 12, color: Colors.green[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                    onPressed: _isCreating ? null : _goBack,
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
                    onPressed: _isCreating ? null : _createCampaign,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.isEditing ? Icons.update : Icons.check,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.isEditing ? 'Update Campaign' : 'Create Campaign',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: textSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGeofencesPreview() {
    final tempGeofences = widget.campaignData['temp_geofences'] as List<TempGeofenceData>?;
    
    if (tempGeofences == null || tempGeofences.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_off, size: 16, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  'No Work Zones',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'No work zones (geofences) have been created yet. You can add them after creating the campaign.',
              style: TextStyle(fontSize: 12, color: Colors.orange[600]),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                'Work Zones (${tempGeofences.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tempGeofences.map((geofence) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Color(int.parse('0xFF${geofence.color}') & 0xFFFFFFFF).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Color(int.parse('0xFF${geofence.color}') & 0xFFFFFFFF),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                      if (geofence.description != null && geofence.description!.isNotEmpty)
                        Text(
                          geofence.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: textSecondaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  'Max: ${geofence.maxAgents}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: textSecondaryColor,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildTouringTasksPreview() {
    final tempTouringTasks = widget.campaignData['temp_touring_tasks'] as List<TempTouringTaskData>?;
    
    if (tempTouringTasks == null || tempTouringTasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tour_outlined, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'No Touring Tasks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'No touring tasks have been created yet. You can add them after creating the campaign.',
              style: TextStyle(fontSize: 12, color: Colors.blue[600]),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tour, size: 16, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                'Touring Tasks (${tempTouringTasks.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tempTouringTasks.map((task) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.tour,
                    color: primaryColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                      if (task.description != null && task.description!.isNotEmpty)
                        Text(
                          task.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: textSecondaryColor,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${task.requiredTimeMinutes}min',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${task.points} pts',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildAssignedAgentsPreview() {
    final tempAssignedAgentIds = widget.campaignData['temp_assigned_agent_ids'] as List<String>?;
    
    if (tempAssignedAgentIds == null || tempAssignedAgentIds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_outline, size: 16, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Text(
                  'No Agents Assigned',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'No agents have been assigned yet. You can assign agents after creating the campaign.',
              style: TextStyle(fontSize: 12, color: Colors.purple[600]),
            ),
          ],
        ),
      );
    }
    
    return FutureBuilder<List<dynamic>>(
      future: supabase
          .from('profiles')
          .select('id, full_name')
          .filter('id', 'in', '(${tempAssignedAgentIds.join(',')})')
          .then((data) => data as List<dynamic>),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final agents = snapshot.data ?? [];
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Assigned Agents (${agents.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...agents.map((agent) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: primaryColor.withValues(alpha: 0.2),
                      child: Text(
                        (agent['full_name'] as String).substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        agent['full_name'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }
}