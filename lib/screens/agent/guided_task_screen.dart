// lib/screens/agent/guided_task_screen.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';
import '../../services/location_service.dart';
import 'task_location_viewer_screen.dart';
import 'evidence_submission_screen.dart';
import '../../l10n/app_localizations.dart';

enum TaskStep {
  overview,
  location,
  evidence,
  completion,
}

class GuidedTaskScreen extends StatefulWidget {
  final Task task;
  
  const GuidedTaskScreen({super.key, required this.task});

  @override
  State<GuidedTaskScreen> createState() => _GuidedTaskScreenState();
}

class _GuidedTaskScreenState extends State<GuidedTaskScreen> with TickerProviderStateMixin {
  TaskStep _currentStep = TaskStep.overview;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  bool _locationVerified = false;
  bool _evidenceUploaded = false;
  bool _taskCompleted = false;
  
  Position? _currentPosition;
  bool _isCheckingLocation = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
    _checkInitialTaskStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialTaskStatus() async {
    // Check if task already has evidence or is completed
    try {
      final response = await supabase.rpc('get_agent_tasks_for_campaign', 
        params: {'p_campaign_id': widget.task.campaignId});
      
      final taskData = (response as List).firstWhere(
        (task) => task['task_id'] == widget.task.id,
        orElse: () => null,
      );
      
      if (taskData != null) {
        final evidenceUrls = List<String>.from(taskData['evidence_urls'] ?? []);
        final status = taskData['assignment_status'] as String;
        
        // Check if assignment is pending
        if (status == 'pending') {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showPendingAssignmentDialog();
            });
          }
          return;
        }
        
        setState(() {
          _evidenceUploaded = evidenceUrls.isNotEmpty;
          _taskCompleted = status == 'completed';
          
          if (_taskCompleted) {
            _currentStep = TaskStep.completion;
          } else if (_evidenceUploaded) {
            _currentStep = TaskStep.evidence;
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking task status: $e');
    }
  }

  void _showPendingAssignmentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange[700]),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.assignmentPendingTitle),
          ],
        ),
        content: Text(
          AppLocalizations.of(context)!.assignmentPendingDesc,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: Text(AppLocalizations.of(context)!.goBack),
          ),
        ],
      ),
    );
  }

  Future<void> _checkLocation() async {
    if (_isCheckingLocation) return;
    
    setState(() => _isCheckingLocation = true);
    
    try {
      final locationService = LocationService();
      _currentPosition = await locationService.getCurrentLocation();
      
      if (_currentPosition != null) {
        // Check if task requires geofence validation
        if (widget.task.enforceGeofence ?? false) {
          final isInGeofence = await locationService.isAgentInTaskGeofence(widget.task.id);
          setState(() {
            _locationVerified = isInGeofence;
          });
          
          if (!isInGeofence) {
            if (mounted) {
              context.showSnackBar(
                AppLocalizations.of(context)!.notWithinTaskLocation,
                isError: true
              );
            }
          }
        } else {
          setState(() => _locationVerified = true);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.errorCheckingLocation(e.toString()), isError: true);
      }
    } finally {
      setState(() => _isCheckingLocation = false);
    }
  }

  void _nextStep() {
    switch (_currentStep) {
      case TaskStep.overview:
        if (widget.task.enforceGeofence ?? false) {
          setState(() => _currentStep = TaskStep.location);
        } else {
          setState(() => _currentStep = TaskStep.evidence);
        }
        break;
      case TaskStep.location:
        if (_locationVerified) {
          setState(() => _currentStep = TaskStep.evidence);
        } else {
          _checkLocation();
        }
        break;
      case TaskStep.evidence:
        setState(() => _currentStep = TaskStep.completion);
        break;
      case TaskStep.completion:
        Navigator.of(context).pop(true);
        break;
    }
    _animationController.reset();
    _animationController.forward();
  }

  void _previousStep() {
    switch (_currentStep) {
      case TaskStep.location:
        setState(() => _currentStep = TaskStep.overview);
        break;
      case TaskStep.evidence:
        if (widget.task.enforceGeofence ?? false) {
          setState(() => _currentStep = TaskStep.location);
        } else {
          setState(() => _currentStep = TaskStep.overview);
        }
        break;
      case TaskStep.completion:
        setState(() => _currentStep = TaskStep.evidence);
        break;
      case TaskStep.overview:
        Navigator.of(context).pop();
        break;
    }
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.task.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _previousStep,
        ),
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildCurrentStepContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = [
      AppLocalizations.of(context)!.overview,
      if (widget.task.enforceGeofence ?? false) AppLocalizations.of(context)!.locationVerification,
      AppLocalizations.of(context)!.evidenceUpload,
      AppLocalizations.of(context)!.complete,
    ];
    
    final currentIndex = _getCurrentStepIndex();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isActive = index == currentIndex;
              final isCompleted = index < currentIndex;
              
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isCompleted 
                                  ? Colors.green 
                                  : isActive 
                                      ? Theme.of(context).primaryColor 
                                      : Colors.grey[300],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: isCompleted
                                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: isActive ? Colors.white : Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            step,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive ? Theme.of(context).primaryColor : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (index < steps.length - 1)
                      Container(
                        height: 2,
                        width: 20,
                        color: isCompleted ? Colors.green : Colors.grey[300],
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  int _getCurrentStepIndex() {
    switch (_currentStep) {
      case TaskStep.overview:
        return 0;
      case TaskStep.location:
        return widget.task.enforceGeofence ?? false ? 1 : 0;
      case TaskStep.evidence:
        return widget.task.enforceGeofence ?? false ? 2 : 1;
      case TaskStep.completion:
        return widget.task.enforceGeofence ?? false ? 3 : 2;
    }
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case TaskStep.overview:
        return _buildOverviewStep();
      case TaskStep.location:
        return _buildLocationStep();
      case TaskStep.evidence:
        return _buildEvidenceStep();
      case TaskStep.completion:
        return _buildCompletionStep();
    }
  }

  Widget _buildOverviewStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.assignment,
            size: 64,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.taskOverview,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.stars, color: Colors.orange[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.task.points} ${AppLocalizations.of(context)!.points}',
                        style: TextStyle(
                          color: Colors.orange[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if (widget.task.description?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 16),
                    Text(
                      '${AppLocalizations.of(context)!.description}:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.task.description!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (widget.task.enforceGeofence ?? false)
                    _buildRequirement(
                      Icons.location_on,
                      AppLocalizations.of(context)!.locationCheckRequired,
                      AppLocalizations.of(context)!.mustBeWithinArea,
                      Colors.orange,
                    ),
                  _buildRequirement(
                    Icons.photo_camera,
                    AppLocalizations.of(context)!.evidenceRequired,
                    AppLocalizations.of(context)!.uploadPhotosOrFiles,
                    Colors.blue,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.startTask,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _locationVerified ? Icons.location_on : Icons.location_searching,
            size: 64,
            color: _locationVerified ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.locationVerification,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_locationVerified) ...[
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.locationVerified,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)!.withinRequiredArea,
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.locationCheckRequired,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)!.moveToDesignatedArea,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TaskLocationViewerScreen(task: widget.task),
                              ),
                            );
                          },
                          icon: const Icon(Icons.map, size: 18),
                          label: Text(AppLocalizations.of(context)!.viewMap),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isCheckingLocation ? null : _checkLocation,
                          icon: _isCheckingLocation 
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.location_searching, size: 18),
                          label: Text(_isCheckingLocation ? AppLocalizations.of(context)!.checking : AppLocalizations.of(context)!.checkLocation),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _locationVerified ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _locationVerified ? Colors.green : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _locationVerified ? AppLocalizations.of(context)!.continueToEvidence : AppLocalizations.of(context)!.verifyLocationFirst,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _evidenceUploaded ? Icons.cloud_done : Icons.cloud_upload,
            size: 64,
            color: _evidenceUploaded ? Colors.green : Colors.blue,
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.evidenceUpload,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_evidenceUploaded) ...[
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.evidenceUploaded,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)!.successfullyUploadedEvidence,
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(Icons.cloud_upload, color: Colors.blue, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.uploadEvidence,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)!.uploadEvidenceDesc,
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EvidenceSubmissionScreen(task: widget.task),
                          ),
                        );
                        if (result == true) {
                          setState(() => _evidenceUploaded = true);
                          _checkInitialTaskStatus();
                        }
                      },
                      icon: const Icon(Icons.add_a_photo, size: 18),
                      label: Text(_evidenceUploaded ? AppLocalizations.of(context)!.addMoreEvidence : AppLocalizations.of(context)!.uploadEvidence),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _evidenceUploaded ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _evidenceUploaded ? Colors.green : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _evidenceUploaded ? AppLocalizations.of(context)!.complete : AppLocalizations.of(context)!.uploadEvidenceFirst,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            AppLocalizations.of(context)!.taskCompleted,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.congratulationsCompleted(widget.task.title),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.stars, color: Colors.orange[600], size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.pointsEarned,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${widget.task.points} ${AppLocalizations.of(context)!.points}',
                          style: TextStyle(
                            color: Colors.orange[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.returnToTasks,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(IconData icon, String title, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
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