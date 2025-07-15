// lib/screens/tasks/create_touring_task_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/campaign.dart';
import '../../models/campaign_geofence.dart';
import '../../models/touring_task.dart';
import '../../services/campaign_geofence_service.dart';
import '../../services/touring_task_service.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/modern_notification.dart';

class CreateTouringTaskScreen extends StatefulWidget {
  final Campaign campaign;
  final TouringTask? touringTask;

  const CreateTouringTaskScreen({super.key, required this.campaign, this.touringTask});

  @override
  State<CreateTouringTaskScreen> createState() => _CreateTouringTaskScreenState();
}

class _CreateTouringTaskScreenState extends State<CreateTouringTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _requiredTimeController = TextEditingController(text: '30');
  final _movementTimeoutController = TextEditingController(text: '60');
  final _movementThresholdController = TextEditingController(text: '5.0');
  final _pointsController = TextEditingController(text: '10');

  final CampaignGeofenceService _geofenceService = CampaignGeofenceService();
  final TouringTaskService _touringTaskService = TouringTaskService();

  List<CampaignGeofence> _geofences = [];
  CampaignGeofence? _selectedGeofence;
  bool _isLoading = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadGeofences();
    
    // If editing an existing touring task, populate the form fields
    if (widget.touringTask != null) {
      _titleController.text = widget.touringTask!.title;
      _descriptionController.text = widget.touringTask!.description ?? '';
      _requiredTimeController.text = widget.touringTask!.requiredTimeMinutes.toString();
      _movementTimeoutController.text = widget.touringTask!.movementTimeoutSeconds.toString();
      _movementThresholdController.text = widget.touringTask!.minMovementThreshold.toString();
      _pointsController.text = widget.touringTask!.points.toString();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _requiredTimeController.dispose();
    _movementTimeoutController.dispose();
    _movementThresholdController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _loadGeofences() async {
    setState(() => _isLoading = true);
    try {
      final geofences = await _geofenceService.getAvailableGeofencesForCampaign(widget.campaign.id);
      setState(() {
        _geofences = geofences;
        _isLoading = false;
        
        // If editing, select the current geofence
        if (widget.touringTask != null) {
          _selectedGeofence = geofences.firstWhere(
            (g) => g.id == widget.touringTask!.geofenceId,
            orElse: () => geofences.first,
          );
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ModernNotification.error(
          context,
          message: 'Failed to load geofences',
          subtitle: e.toString(),
        );
      }
    }
  }

  Future<void> _saveTouringTask() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGeofence == null) {
      ModernNotification.error(context, message: 'Please select a work zone');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final TouringTask task;
      final bool isEditing = widget.touringTask != null;
      
      if (isEditing) {
        // Update existing task
        task = await _touringTaskService.updateTouringTask(
          taskId: widget.touringTask!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          requiredTimeMinutes: int.parse(_requiredTimeController.text),
          movementTimeoutSeconds: int.parse(_movementTimeoutController.text),
          minMovementThreshold: double.parse(_movementThresholdController.text),
          points: int.parse(_pointsController.text),
        );
      } else {
        // Create new task
        task = await _touringTaskService.createTouringTask(
          campaignId: widget.campaign.id,
          geofenceId: _selectedGeofence!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          requiredTimeMinutes: int.parse(_requiredTimeController.text),
          movementTimeoutSeconds: int.parse(_movementTimeoutController.text),
          minMovementThreshold: double.parse(_movementThresholdController.text),
          points: int.parse(_pointsController.text),
        );
      }

      if (mounted) {
        ModernNotification.success(
          context,
          message: isEditing 
              ? AppLocalizations.of(context)!.touringTaskUpdatedSuccessfully 
              : AppLocalizations.of(context)!.touringTaskCreatedSuccessfully,
          subtitle: task.title,
        );
        Navigator.of(context).pop(task);
      }
    } catch (e) {
      if (mounted) {
        ModernNotification.error(
          context,
          message: widget.touringTask != null 
              ? AppLocalizations.of(context)!.failedToUpdateTouringTask 
              : AppLocalizations.of(context)!.failedToCreateTouringTask,
          subtitle: e.toString(),
        );
      }
    } finally {
      setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.touringTask != null 
            ? AppLocalizations.of(context)!.editTouringTask 
            : AppLocalizations.of(context)!.createTouringTask),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 24),
                    _buildBasicInfoSection(),
                    const SizedBox(height: 24),
                    _buildGeofenceSection(),
                    const SizedBox(height: 24),
                    _buildTimingSection(),
                    const SizedBox(height: 24),
                    _buildMovementSection(),
                    const SizedBox(height: 24),
                    _buildPointsSection(),
                    const SizedBox(height: 32),
                    _buildCreateButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
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
              Icon(Icons.tour, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Text(
                'Touring Task',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Touring tasks require agents to spend time inside a work zone while moving. The timer pauses when agents stop moving for too long.',
            style: TextStyle(color: Colors.blue[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSection(
      title: 'Basic Information',
      icon: Icons.info_outline,
      children: [
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Task Title',
            hintText: 'e.g., "Zone A Patrol", "Building Inspection"',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.title),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a task title';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description (Optional)',
            hintText: 'Additional details about this task',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.description),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildGeofenceSection() {
    return _buildSection(
      title: 'Work Zone Selection',
      icon: Icons.location_on,
      children: [
        if (_geofences.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.warning, color: Colors.orange[700]),
                const SizedBox(height: 8),
                Text(
                  'No work zones available',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create work zones first before adding touring tasks',
                  style: TextStyle(color: Colors.orange[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select a work zone for this touring task:',
                style: TextStyle(fontSize: 14, color: textSecondaryColor),
              ),
              const SizedBox(height: 12),
              ...(_geofences.map((geofence) => _buildGeofenceOption(geofence))),
            ],
          ),
      ],
    );
  }

  Widget _buildGeofenceOption(CampaignGeofence geofence) {
    final isSelected = _selectedGeofence?.id == geofence.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedGeofence = geofence),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? primaryColor : Colors.grey.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: isSelected ? primaryColor.withValues(alpha: 0.1) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 40,
                  decoration: BoxDecoration(
                    color: geofence.color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        geofence.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? primaryColor : textPrimaryColor,
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
                if (isSelected)
                  Icon(Icons.check_circle, color: primaryColor, size: 24)
                else
                  Icon(Icons.radio_button_unchecked, color: Colors.grey[400], size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimingSection() {
    return _buildSection(
      title: 'Time Requirements',
      icon: Icons.schedule,
      children: [
        TextFormField(
          controller: _requiredTimeController,
          decoration: const InputDecoration(
            labelText: 'Required Time (Minutes)',
            hintText: 'e.g., 30, 60, 120',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.timer),
            suffixText: 'minutes',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter required time';
            }
            final time = int.tryParse(value);
            if (time == null || time <= 0) {
              return 'Please enter a valid time in minutes';
            }
            if (time > 480) {
              return 'Maximum time is 8 hours (480 minutes)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildMovementSection() {
    return _buildSection(
      title: 'Movement Detection',
      icon: Icons.directions_walk,
      children: [
        TextFormField(
          controller: _movementTimeoutController,
          decoration: const InputDecoration(
            labelText: 'Movement Timeout (Seconds)',
            hintText: 'Timer pauses after this many seconds without movement',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.pause_circle),
            suffixText: 'seconds',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter movement timeout';
            }
            final timeout = int.tryParse(value);
            if (timeout == null || timeout <= 0) {
              return 'Please enter a valid timeout in seconds';
            }
            if (timeout > 300) {
              return 'Maximum timeout is 5 minutes (300 seconds)';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _movementThresholdController,
          decoration: const InputDecoration(
            labelText: 'Movement Threshold (Meters)',
            hintText: 'Minimum distance to detect movement',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.straighten),
            suffixText: 'meters',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter movement threshold';
            }
            final threshold = double.tryParse(value);
            if (threshold == null || threshold <= 0) {
              return 'Please enter a valid threshold in meters';
            }
            if (threshold > 50) {
              return 'Maximum threshold is 50 meters';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Movement Detection Info',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• Timer counts only when agent is moving\n'
                '• If agent stops for longer than timeout, timer pauses\n'
                '• Movement threshold determines minimum distance for detection',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPointsSection() {
    return _buildSection(
      title: 'Rewards',
      icon: Icons.stars,
      children: [
        TextFormField(
          controller: _pointsController,
          decoration: const InputDecoration(
            labelText: 'Points Reward',
            hintText: 'Points earned for completing this task',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.emoji_events),
            suffixText: 'points',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter points reward';
            }
            final points = int.tryParse(value);
            if (points == null || points <= 0) {
              return 'Please enter a valid points value';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isCreating ? null : _saveTouringTask,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isCreating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                widget.touringTask != null 
                    ? AppLocalizations.of(context)!.updateTouringTask 
                    : AppLocalizations.of(context)!.createTouringTask,
                style: const TextStyle(fontSize: 16),
              ),
      ),
    );
  }
}