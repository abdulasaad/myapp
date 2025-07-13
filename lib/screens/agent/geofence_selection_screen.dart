// lib/screens/agent/geofence_selection_screen.dart

import 'package:flutter/material.dart';
import '../../models/campaign.dart';
import '../../models/campaign_geofence.dart';
import '../../models/agent_geofence_assignment.dart';
import '../../services/campaign_geofence_service.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/modern_notification.dart';

class GeofenceSelectionScreen extends StatefulWidget {
  final Campaign campaign;

  const GeofenceSelectionScreen({super.key, required this.campaign});

  @override
  State<GeofenceSelectionScreen> createState() => _GeofenceSelectionScreenState();
}

class _GeofenceSelectionScreenState extends State<GeofenceSelectionScreen> {
  final CampaignGeofenceService _geofenceService = CampaignGeofenceService();
  
  late Future<List<CampaignGeofence>> _geofencesFuture;
  late Future<AgentGeofenceAssignment?> _currentAssignmentFuture;
  
  bool _isAssigning = false;
  String? _selectedGeofenceId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _geofencesFuture = _geofenceService.getAvailableGeofencesForCampaign(widget.campaign.id);
      _currentAssignmentFuture = _geofenceService.getAgentCurrentAssignment(
        campaignId: widget.campaign.id,
        agentId: supabase.auth.currentUser!.id,
      );
    });
  }

  Future<void> _assignToGeofence(CampaignGeofence geofence) async {
    if (_isAssigning) return;

    // Check if geofence is full
    if (geofence.isFull == true) {
      ModernNotification.error(
        context,
        message: AppLocalizations.of(context)!.geofenceIsFull,
        subtitle: 'Please choose another geofence',
      );
      return;
    }

    setState(() {
      _isAssigning = true;
      _selectedGeofenceId = geofence.id;
    });

    try {
      final result = await _geofenceService.assignAgentToGeofence(
        campaignId: widget.campaign.id,
        geofenceId: geofence.id,
        agentId: supabase.auth.currentUser!.id,
      );

      if (result['success'] == true) {
        ModernNotification.success(
          context,
          message: AppLocalizations.of(context)!.assignedToGeofence,
          subtitle: geofence.name,
        );
        
        // Refresh data
        _loadData();
        
        // Navigate back after successful assignment
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate assignment was made
        }
      } else {
        ModernNotification.error(
          context,
          message: result['error'] ?? 'Assignment failed',
        );
      }
    } catch (e) {
      ModernNotification.error(
        context,
        message: AppLocalizations.of(context)!.assignmentFailed,
        subtitle: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAssigning = false;
          _selectedGeofenceId = null;
        });
      }
    }
  }

  Future<void> _cancelCurrentAssignment(AgentGeofenceAssignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.cancelAssignment),
        content: Text(AppLocalizations.of(context)!.cancelAssignmentConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: errorColor),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.cancelAssignment),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _geofenceService.cancelAgentAssignment(assignmentId: assignment.id);
        ModernNotification.success(
          context,
          message: AppLocalizations.of(context)!.assignmentCancelled,
        );
        _loadData();
      } catch (e) {
        ModernNotification.error(
          context,
          message: AppLocalizations.of(context)!.cancellationFailed,
          subtitle: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.selectGeofence),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCampaignHeader(),
              const SizedBox(height: 24),
              _buildCurrentAssignmentSection(),
              const SizedBox(height: 24),
              _buildAvailableGeofencesSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.campaign,
                    color: primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.campaign.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textPrimaryColor,
                        ),
                      ),
                      if (widget.campaign.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.campaign.description!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.selectGeofenceInstructions,
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentAssignmentSection() {
    return FutureBuilder<AgentGeofenceAssignment?>(
      future: _currentAssignmentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final assignment = snapshot.data;
        if (assignment == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.assignment_turned_in, color: Colors.grey[400], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.noCurrentAssignment,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)!.selectGeofenceToStart,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          color: successColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: successColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.location_on, color: successColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.currentAssignment,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            assignment.geofenceName ?? 'Unknown Geofence',
                            style: TextStyle(
                              fontSize: 14,
                              color: successColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _cancelCurrentAssignment(assignment),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: Text(AppLocalizations.of(context)!.cancel),
                      style: TextButton.styleFrom(
                        foregroundColor: errorColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
                if (assignment.isCurrentlyInside) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: successColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          AppLocalizations.of(context)!.currentlyInside,
                          style: TextStyle(
                            color: successColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
      },
    );
  }

  Widget _buildAvailableGeofencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.availableGeofences,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<CampaignGeofence>>(
          future: _geofencesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.error, size: 48, color: errorColor),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)!.errorLoadingGeofences,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: Text(AppLocalizations.of(context)!.retry),
                      ),
                    ],
                  ),
                ),
              );
            }

            final geofences = snapshot.data ?? [];
            if (geofences.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)!.noGeofencesAvailable,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.contactManagerForGeofences,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
              itemCount: geofences.length,
              itemBuilder: (context, index) {
                final geofence = geofences[index];
                return _buildGeofenceCard(geofence);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildGeofenceCard(CampaignGeofence geofence) {
    final isAssigningThis = _isAssigning && _selectedGeofenceId == geofence.id;
    final isFull = geofence.isFull == true;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: isFull || isAssigningThis ? null : () => _assignToGeofence(geofence),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isFull 
                          ? Colors.grey.withValues(alpha: 0.3)
                          : geofence.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      geofence.statusIcon,
                      color: isFull ? Colors.grey[600] : geofence.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          geofence.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isFull ? Colors.grey[600] : textPrimaryColor,
                          ),
                        ),
                        if (geofence.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            geofence.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: isFull ? Colors.grey[500] : textSecondaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isAssigningThis)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: geofence.statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      geofence.capacityText,
                      style: TextStyle(
                        color: geofence.statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: geofence.statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      geofence.statusText,
                      style: TextStyle(
                        color: geofence.statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!isFull && !isAssigningThis)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}