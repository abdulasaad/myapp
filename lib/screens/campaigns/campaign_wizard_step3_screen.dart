// lib/screens/campaigns/campaign_wizard_step3_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/campaign.dart';
import '../../utils/constants.dart';
import '../../widgets/modern_notification.dart';
import 'campaign_detail_screen.dart';

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
          
          // Navigate back to campaign detail
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => CampaignDetailScreen(
                campaign: widget.existingCampaign!,
              ),
            ),
          );
        }
      } else {
        final userId = supabase.auth.currentUser!.id;
        campaignData['created_by'] = userId;
        
        final response = await supabase
            .from('campaigns')
            .insert(campaignData)
            .select()
            .single();
        
        if (mounted) {
          ModernNotification.success(
            context,
            message: AppLocalizations.of(context)!.campaignCreatedSuccessfully,
            subtitle: campaignData['name'],
          );
          
          // Create campaign object from response
          final campaign = Campaign.fromJson(response);
          
          // Navigate to campaign detail screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => CampaignDetailScreen(
                campaign: campaign,
              ),
            ),
          );
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
                                '• Create work zones (geofences)\n'
                                '• Add tasks and touring tasks\n'
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
}