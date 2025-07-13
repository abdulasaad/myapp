// lib/screens/campaigns/create_campaign_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/campaign.dart'; // Import Campaign model
import '../../models/app_user.dart';
import '../../services/user_management_service.dart';
import '../../utils/constants.dart';
import '../../widgets/month_day_picker.dart';
import '../../widgets/modern_notification.dart';

class CreateCampaignScreen extends StatefulWidget {
  final Campaign? campaignToEdit; // Optional campaign for editing

  const CreateCampaignScreen({super.key, this.campaignToEdit});

  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  Set<DateTime> _selectedDays = {};
  
  // Manager assignment (for admin only)
  String? _selectedManagerId;
  List<AppUser> _managers = [];
  bool _isAdmin = false;
  bool _managersLoaded = false;

  bool get _isEditing => widget.campaignToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final campaign = widget.campaignToEdit!;
      _nameController.text = campaign.name;
      _descriptionController.text = campaign.description ?? '';
      // Convert start/end dates to selected days for backward compatibility
      if (campaign.startDate != null && campaign.endDate != null) {
        final start = campaign.startDate!;
        final end = campaign.endDate!;
        final days = <DateTime>{};
        for (DateTime day = start; day.isBefore(end) || day.isAtSameMomentAs(end); day = day.add(const Duration(days: 1))) {
          days.add(DateTime(day.year, day.month, day.day));
        }
        _selectedDays = days;
      }
    }
    
    // Check if current user is admin and load managers
    _checkUserRoleAndLoadManagers();
  }

  Future<void> _checkUserRoleAndLoadManagers() async {
    try {
      final userRole = await UserManagementService().getCurrentUserRole();
      final isAdmin = userRole == 'admin';
      
      setState(() {
        _isAdmin = isAdmin;
      });
      
      if (isAdmin) {
        await _loadManagers();
      } else {
        setState(() {
          _managersLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error checking user role: $e');
      setState(() {
        _managersLoaded = true;
      });
    }
  }

  Future<void> _loadManagers() async {
    try {
      final managers = await UserManagementService().getUsers(
        roleFilter: 'manager',
        statusFilter: 'active',
      );
      
      setState(() {
        _managers = managers;
        _managersLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading managers: $e');
      setState(() {
        _managersLoaded = true;
      });
    }
  }

  Future<void> _selectDays(BuildContext context) async {
    final result = await showDialog<Set<DateTime>>(
      context: context,
      builder: (context) => MonthDayPicker(
        initialSelectedDays: _selectedDays,
        onDaysSelected: (days) {},
        title: AppLocalizations.of(context)!.selectCampaignDays,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedDays = result;
      });
    }
  }

  Future<void> _saveCampaign() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDays.isEmpty) {
        ModernNotification.error(
          context,
          message: AppLocalizations.of(context)!.pleaseSelectCampaignDays,
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        // Get earliest and latest selected days for backward compatibility
        final sortedDays = _selectedDays.toList()..sort();
        final startDate = sortedDays.first;
        final endDate = sortedDays.last;

        final campaignData = {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
        };

        // Add assigned manager if admin selected one
        if (_isAdmin && _selectedManagerId != null) {
          campaignData['assigned_manager_id'] = _selectedManagerId!;
        }

        if (_isEditing) {
          await supabase
              .from('campaigns')
              .update(campaignData)
              .eq('id', widget.campaignToEdit!.id);
          if (mounted) {
            ModernNotification.success(
              context,
              message: AppLocalizations.of(context)!.campaignUpdatedSuccessfully,
              subtitle: _nameController.text.trim(),
            );
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        } else {
          final userId = supabase.auth.currentUser!.id;
          campaignData['created_by'] = userId; // Add created_by only for new campaigns
          await supabase.from('campaigns').insert(campaignData);
          if (mounted) {
            ModernNotification.success(
              context,
              message: AppLocalizations.of(context)!.campaignCreatedSuccessfully,
              subtitle: _nameController.text.trim(),
            );
            Navigator.of(context).pop(true); // Return true to indicate success
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
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? AppLocalizations.of(context)!.editCampaign : AppLocalizations.of(context)!.createCampaign),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
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
                          _isEditing ? Icons.edit : Icons.add_box,
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
                              _isEditing ? AppLocalizations.of(context)!.editCampaign : AppLocalizations.of(context)!.newCampaign,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textPrimaryColor,
                              ),
                            ),
                            Text(
                              _isEditing 
                                  ? AppLocalizations.of(context)!.updateCampaignDetails
                                  : AppLocalizations.of(context)!.createNewCampaignForTeam,
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
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.campaignName,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: backgroundColor,
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? AppLocalizations.of(context)!.campaignNameRequired
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.description,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: backgroundColor,
                          ),
                          maxLines: 3,
                        ),
                        // Manager Assignment Section (Admin only)
                        if (_isAdmin && _managersLoaded) ...[
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedManagerId,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.assignToManager,
                              hintText: AppLocalizations.of(context)!.selectManagerToOversee,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: backgroundColor,
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(AppLocalizations.of(context)!.noSpecificManager),
                              ),
                              ..._managers.map((manager) {
                                return DropdownMenuItem<String>(
                                  value: manager.id,
                                  child: Text(manager.fullName),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedManagerId = value;
                              });
                            },
                          ),
                          if (_selectedManagerId != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.of(context)!.campaignAssignmentInfo,
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () => _selectDays(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.campaignDays,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: textSecondaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_month,
                                      size: 16,
                                      color: primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedDays.isEmpty
                                            ? AppLocalizations.of(context)!.selectDays
                                            : AppLocalizations.of(context)!.daysSelected(_selectedDays.length),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _selectedDays.isEmpty 
                                              ? textSecondaryColor 
                                              : textPrimaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_selectedDays.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _selectedDays.length <= 5
                                        ? _selectedDays
                                            .map((d) => DateFormat.MMMd().format(d))
                                            .join(', ')
                                        : '${DateFormat.MMMd().format(_selectedDays.first)} - ${DateFormat.MMMd().format(_selectedDays.last)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveCampaign,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isEditing ? AppLocalizations.of(context)!.updateCampaign : AppLocalizations.of(context)!.createCampaign,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
    );
  }
}
