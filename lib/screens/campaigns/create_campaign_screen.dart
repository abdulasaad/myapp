// lib/screens/campaigns/create_campaign_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/campaign.dart'; // Import Campaign model
import '../../models/app_user.dart';
import '../../services/user_management_service.dart';
import '../../utils/constants.dart';

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
  DateTime? _startDate;
  DateTime? _endDate;
  
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
      _startDate = campaign.startDate;
      _endDate = campaign.endDate;
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

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = DateTime.now();
    final newDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (newDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = newDate;
        } else {
          _endDate = newDate;
        }
      });
    }
  }

  Future<void> _saveCampaign() async {
    if (_formKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null) {
        context.showSnackBar(
          'Please select both start and end dates.',
          isError: true,
        );
        return;
      }
      if (_endDate!.isBefore(_startDate!)) {
        context.showSnackBar(
          'End date cannot be before the start date.',
          isError: true,
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        final campaignData = {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'start_date': _startDate!.toIso8601String(),
          'end_date': _endDate!.toIso8601String(),
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
            context.showSnackBar('Campaign updated successfully!');
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        } else {
          final userId = supabase.auth.currentUser!.id;
          campaignData['created_by'] = userId; // Add created_by only for new campaigns
          await supabase.from('campaigns').insert(campaignData);
          if (mounted) {
            context.showSnackBar('Campaign created successfully!');
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        }
      } catch (e) {
        if (mounted) {
          context.showSnackBar(
            'Failed to create campaign. Please try again.',
            isError: true,
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
        title: Text(_isEditing ? 'Edit Campaign' : 'Create Campaign'),
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
                              _isEditing ? 'Edit Campaign' : 'New Campaign',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textPrimaryColor,
                              ),
                            ),
                            Text(
                              _isEditing 
                                  ? 'Update campaign details'
                                  : 'Create a new campaign for your team',
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
                            labelText: 'Campaign Name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: backgroundColor,
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Campaign name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Description',
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
                              labelText: 'Assign to Manager',
                              hintText: 'Select a manager to oversee this campaign',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: backgroundColor,
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('No specific manager'),
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
                                      'This campaign will be assigned to the selected manager. Only they and their agents will be able to see and work on this campaign.',
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
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context, true),
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
                                      const Text(
                                        'Start Date',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: primaryColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _startDate == null
                                                ? 'Select date'
                                                : DateFormat.yMMMd().format(_startDate!),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _startDate == null 
                                                  ? textSecondaryColor 
                                                  : textPrimaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context, false),
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
                                      const Text(
                                        'End Date',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: primaryColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _endDate == null
                                                ? 'Select date'
                                                : DateFormat.yMMMd().format(_endDate!),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _endDate == null 
                                                  ? textSecondaryColor 
                                                  : textPrimaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                                  _isEditing ? 'Update Campaign' : 'Create Campaign',
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
