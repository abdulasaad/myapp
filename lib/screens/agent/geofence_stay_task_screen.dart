// lib/screens/agent/geofence_stay_task_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../models/task_template.dart';
import '../../services/location_service.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';

class GeofenceStayTaskScreen extends StatefulWidget {
  final Task task;
  final TaskTemplate template;

  const GeofenceStayTaskScreen({
    super.key,
    required this.task,
    required this.template,
  });

  @override
  State<GeofenceStayTaskScreen> createState() => _GeofenceStayTaskScreenState();
}

class _GeofenceStayTaskScreenState extends State<GeofenceStayTaskScreen> {
  Timer? _stayTimer;
  Timer? _locationCheckTimer;
  Duration _elapsedTime = Duration.zero;
  bool _isInGeofence = false;
  bool _taskStarted = false;
  bool _taskCompleted = false;
  bool _isCheckingLocation = false;
  String _currentStatus = 'Not Started'; // Will be localized in UI
  DateTime? _startTime;
  DateTime? _expectedEndTime;

  int get requiredMinutes => widget.template.requiredStayDuration ?? 30;
  bool get allowEarlyCompletion => widget.template.allowsEarlyCompletion;

  @override
  void initState() {
    super.initState();
    _checkInitialLocation();
  }

  @override
  void dispose() {
    _stayTimer?.cancel();
    _locationCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialLocation() async {
    setState(() => _isCheckingLocation = true);
    
    try {
      final locationService = LocationService();
      final isInArea = await locationService.isAgentInTaskGeofence(widget.task.id);
      
      setState(() {
        _isInGeofence = isInArea;
        _currentStatus = isInArea ? 'ready' : 'outside';
        _isCheckingLocation = false;
      });
    } catch (e) {
      setState(() {
        _currentStatus = 'failed';
        _isCheckingLocation = false;
      });
    }
  }

  void _startTask() {
    if (!_isInGeofence || _taskStarted) return;

    setState(() {
      _taskStarted = true;
      _currentStatus = 'active';
      _startTime = DateTime.now();
      _expectedEndTime = _startTime!.add(Duration(minutes: requiredMinutes));
    });

    // Start the stay timer
    _stayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime = Duration(seconds: timer.tick);
        
        if (_elapsedTime.inMinutes >= requiredMinutes) {
          _completeTask();
        }
      });
    });

    // Start location monitoring
    _locationCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkLocationDuringTask();
    });

    context.showSnackBar('Task started! Stay in the area for $requiredMinutes minutes.');
  }

  Future<void> _checkLocationDuringTask() async {
    if (!_taskStarted || _taskCompleted) return;

    try {
      final locationService = LocationService();
      final isInArea = await locationService.isAgentInTaskGeofence(widget.task.id);
      
      if (!isInArea && _isInGeofence) {
        // Agent left the area
        _pauseTask();
        if (mounted) {
          context.showSnackBar(
            'You left the designated area. Task paused.',
            isError: true,
          );
        }
      } else if (isInArea && !_isInGeofence) {
        // Agent returned to the area
        _resumeTask();
        if (mounted) {
          context.showSnackBar('Welcome back! Task resumed.');
        }
      }
      
      setState(() => _isInGeofence = isInArea);
    } catch (e) {
      debugPrint('Location check error: $e');
    }
  }

  void _pauseTask() {
    _stayTimer?.cancel();
    setState(() {
      _currentStatus = 'Paused - Outside Area';
    });
  }

  void _resumeTask() {
    if (_taskCompleted) return;
    
    setState(() {
      _currentStatus = 'active';
    });
    
    // Resume timer from where it left off
    final remainingSeconds = (requiredMinutes * 60) - _elapsedTime.inSeconds;
    if (remainingSeconds > 0) {
      _stayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _elapsedTime = _elapsedTime + const Duration(seconds: 1);
          
          if (_elapsedTime.inMinutes >= requiredMinutes) {
            _completeTask();
          }
        });
      });
    }
  }

  void _completeTask() {
    _stayTimer?.cancel();
    _locationCheckTimer?.cancel();
    
    setState(() {
      _taskCompleted = true;
      _currentStatus = 'completed';
    });

    context.showSnackBar('Task completed successfully!');
    
    // Update task assignment status
    _updateTaskStatus();
  }

  Future<void> _updateTaskStatus() async {
    try {
      await supabase.from('task_assignments')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .match({
            'task_id': widget.task.id,
            'agent_id': supabase.auth.currentUser!.id,
          });
    } catch (e) {
      debugPrint('Failed to update task status: $e');
    }
  }

  void _forceComplete() {
    if (!allowEarlyCompletion) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.earlyCompletion),
        content: const Text('Are you sure you want to complete this task early?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completeTask();
            },
            child: Text(AppLocalizations.of(context)!.complete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTaskHeader(),
            const SizedBox(height: 20),
            _buildLocationStatus(),
            const SizedBox(height: 20),
            _buildTimeDisplay(),
            const SizedBox(height: 20),
            _buildProgress(),
            const SizedBox(height: 30),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.geofenceStayTask,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.task.description ?? 'Stay in the designated area for the required duration.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Required Stay: $requiredMinutes minutes',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
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

  Widget _buildLocationStatus() {
    Color statusColor;
    IconData statusIcon;
    
    if (_isCheckingLocation) {
      statusColor = Colors.orange;
      statusIcon = Icons.location_searching;
    } else if (_isInGeofence) {
      statusColor = Colors.green;
      statusIcon = Icons.location_on;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.location_off;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(statusIcon, color: statusColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.locationStatus,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isCheckingLocation 
                        ? 'Checking location...'
                        : _isInGeofence 
                            ? AppLocalizations.of(context)!.insideDesignatedArea
                            : AppLocalizations.of(context)!.outsideDesignatedArea,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
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

  Widget _buildTimeDisplay() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              AppLocalizations.of(context)!.timeProgress,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _formatDuration(_elapsedTime),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            Text(
              'of $requiredMinutes:00 required',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            if (_startTime != null && _expectedEndTime != null) ...[
              const SizedBox(height: 12),
              Text(
                'Started: ${DateFormat.jm().format(_startTime!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Expected completion: ${DateFormat.jm().format(_expectedEndTime!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final progress = (_elapsedTime.inSeconds / (requiredMinutes * 60)).clamp(0.0, 1.0);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.progress,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _taskCompleted ? Colors.green : Theme.of(context).primaryColor,
              ),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _canStartTask() ? _startTask : null,
            icon: Icon(_taskStarted ? Icons.pause : Icons.play_arrow),
            label: Text(_getButtonText(context)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getButtonColor(),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        if (allowEarlyCompletion && _taskStarted && !_taskCompleted) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _forceComplete,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(AppLocalizations.of(context)!.completeEarly),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _canStartTask() {
    return _isInGeofence && !_taskStarted && !_taskCompleted && !_isCheckingLocation;
  }

  String _getLocalizedStatus(BuildContext context) {
    switch (_currentStatus) {
      case 'ready': return AppLocalizations.of(context)!.inAreaReadyToStart;
      case 'outside': return AppLocalizations.of(context)!.outsideArea;
      case 'failed': return AppLocalizations.of(context)!.locationCheckFailed;
      case 'active': return AppLocalizations.of(context)!.taskActive;
      case 'completed': return AppLocalizations.of(context)!.taskCompleted;
      default: return AppLocalizations.of(context)!.notStarted;
    }
  }

  String _getButtonText(BuildContext context) {
    if (_taskCompleted) return AppLocalizations.of(context)!.taskCompleted;
    if (_taskStarted) return _getLocalizedStatus(context);
    if (_isCheckingLocation) return AppLocalizations.of(context)!.checkingLocation;
    if (!_isInGeofence) return AppLocalizations.of(context)!.moveToDesignatedArea;
    return AppLocalizations.of(context)!.startTask;
  }

  Color _getButtonColor() {
    if (_taskCompleted) return Colors.green;
    if (_taskStarted) return Colors.orange;
    if (!_isInGeofence) return Colors.red;
    return Theme.of(context).primaryColor;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}