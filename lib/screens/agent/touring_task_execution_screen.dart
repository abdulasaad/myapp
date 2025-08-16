// lib/screens/agent/touring_task_execution_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/touring_task.dart';
import '../../models/campaign_geofence.dart';
import '../../models/touring_survey.dart';
import '../../models/survey_field.dart';
import '../../services/touring_task_movement_service.dart';
import '../../services/survey_service.dart';
import '../../utils/constants.dart';
import '../../widgets/modern_notification.dart';
import 'touring_survey_screen.dart';

class TouringTaskExecutionScreen extends StatefulWidget {
  final TouringTask task;
  final CampaignGeofence geofence;
  final String agentId;

  const TouringTaskExecutionScreen({
    super.key,
    required this.task,
    required this.geofence,
    required this.agentId,
  });

  @override
  State<TouringTaskExecutionScreen> createState() => _TouringTaskExecutionScreenState();
}

class _TouringTaskExecutionScreenState extends State<TouringTaskExecutionScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  TouringTaskMovementService? _movementService;
  final _surveyService = SurveyService();
  bool _isInitializing = false;
  bool _hasStarted = false;
  TouringSurvey? _availableSurvey;

  @override
  void initState() {
    super.initState();
    _movementService = Provider.of<TouringTaskMovementService>(context, listen: false);
    _setupCompletionListener();
    _checkExistingSession();
    _loadAvailableSurvey();
  }
  
  Future<void> _loadAvailableSurvey() async {
    try {
      debugPrint('🔍 Loading survey for task: ${widget.task.id}');
      
      // First, let's check if there are any surveys at all for this task
      try {
        final response = await supabase
            .from('touring_task_surveys')
            .select('*')
            .eq('touring_task_id', widget.task.id);
        debugPrint('🗄️ Direct DB query result: $response');
      } catch (e) {
        debugPrint('🗄️ Direct DB query failed: $e');
      }
      
      // Check all surveys in the system for debugging
      try {
        final allSurveys = await supabase
            .from('touring_task_surveys')
            .select('*');
        debugPrint('🗄️ All surveys in database: ${allSurveys.length}');
        for (var survey in allSurveys) {
          debugPrint('🗄️ Survey: ${survey['id']} for task: ${survey['touring_task_id']}');
        }
      } catch (e) {
        debugPrint('🗄️ Failed to get all surveys: $e');
      }
      
      // Check if agent is assigned to the campaign
      try {
        final currentUser = supabase.auth.currentUser;
        if (currentUser != null) {
          final campaignAssignment = await supabase
              .from('campaign_agents')
              .select('*')
              .eq('agent_id', currentUser.id);
          debugPrint('🗄️ Agent campaign assignments: $campaignAssignment');
          
          // Also check the campaign ID for this task
          final taskInfo = await supabase
              .from('touring_tasks')
              .select('campaign_id')
              .eq('id', widget.task.id)
              .single();
          debugPrint('🗄️ Task campaign ID: ${taskInfo['campaign_id']}');
        }
      } catch (e) {
        debugPrint('🗄️ Failed to check campaign assignment: $e');
      }
      
      final survey = await _surveyService.getSurveyWithFieldsByTouringTask(widget.task.id);
      debugPrint('📋 Survey found: ${survey?.title ?? 'null'}');
      debugPrint('📝 Survey has fields: ${survey?.hasFields ?? false}');
      debugPrint('🔢 Field count: ${survey?.fieldCount ?? 0}');
      
      if (mounted) {
        setState(() {
          _availableSurvey = survey;
        });
        debugPrint('✅ Survey state updated. Available: ${_availableSurvey != null}');
      }
    } catch (e) {
      debugPrint('❌ Error loading survey: $e');
    }
  }

  // Check if there's already an active session for this task
  Future<void> _checkExistingSession() async {
    if (_movementService?.currentTask?.id == widget.task.id && _movementService?.isSessionActive == true) {
      setState(() {
        _hasStarted = true;
      });
      debugPrint('🔄 Found existing active session for task: ${widget.task.title}');
    }
  }

  void _setupCompletionListener() {
    _movementService?.addListener(_onMovementServiceChange);
  }

  void _onMovementServiceChange() {
    if (_movementService?.isCompleted == true && mounted) {
      _showCompletionDialog();
    }
  }

  @override
  void dispose() {
    _movementService?.removeListener(_onMovementServiceChange);
    super.dispose();
  }

  Future<void> _startTask() async {
    setState(() => _isInitializing = true);

    try {
      final success = await _movementService!.startTouringTaskSession(widget.task, widget.agentId);
      
      if (success) {
        setState(() => _hasStarted = true);
        ModernNotification.success(
          context,
          message: 'Touring task started',
          subtitle: 'Move around the work zone to accumulate time',
        );
      } else {
        throw Exception('Failed to start task session');
      }
    } catch (e) {
      ModernNotification.error(
        context,
        message: 'Failed to start task',
        subtitle: e.toString(),
      );
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _stopTask() async {
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Task'),
        content: const Text('Are you sure you want to stop this touring task? Your progress will be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Stop'),
          ),
        ],
      ),
    );

    if (shouldStop == true) {
      await _movementService!.stopTouringTaskSession();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 28),
            const SizedBox(width: 12),
            const Text('Task Completed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Congratulations! You have successfully completed the touring task.'),
            const SizedBox(height: 16),
            _buildCompletionStats(),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to task list
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTestSurvey() async {
    try {
      debugPrint('🧪 Creating test survey for task: ${widget.task.id}');
      
      final survey = await _surveyService.createSurvey(
        touringTaskId: widget.task.id,
        title: 'Test Survey',
        description: 'Test survey for debugging',
        isRequired: false,
      );
      
      if (survey != null) {
        // Create a test field
        await _surveyService.createSurveyField(
          surveyId: survey.id,
          fieldName: 'test_feedback',
          fieldType: SurveyFieldType.text,
          fieldLabel: 'How was your experience?',
          fieldPlaceholder: 'Enter your feedback...',
          isRequired: false,
          fieldOrder: 0,
        );
        
        debugPrint('✅ Test survey created successfully: ${survey.id}');
        
        // Reload the survey
        await _loadAvailableSurvey();
      } else {
        debugPrint('❌ Failed to create test survey');
      }
    } catch (e) {
      debugPrint('❌ Error creating test survey: $e');
    }
  }

  Future<void> _openSurvey(TouringSurvey survey) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if agent has already submitted this survey
      final existingSubmission = await _surveyService.getAgentSurveySubmission(
        surveyId: survey.id,
        agentId: currentUser.id,
      );

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TouringSurveyScreen(
            survey: survey,
            touringTaskId: widget.task.id,
            sessionId: null, // Will be handled by the survey service
            existingSubmission: existingSubmission,
          ),
        ),
      );

      if (mounted && result != null) {
        // Survey was completed
        ModernNotification.success(
          context,
          message: 'Survey Completed',
          subtitle: 'Thank you for your feedback!',
        );
      }
    } catch (e) {
      if (mounted) {
        ModernNotification.error(
          context,
          message: 'Error opening survey',
          subtitle: e.toString(),
        );
      }
    }
  }

  Widget _buildCompletionStats() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task: ${widget.task.title}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text('Required Time: ${widget.task.formattedDuration}'),
          Text('Points Earned: ${widget.task.points}'),
          Text('Work Zone: ${widget.geofence.name}'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.task.title),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_hasStarted)
            IconButton(
              onPressed: _stopTask,
              icon: const Icon(Icons.stop),
              tooltip: 'Stop Task',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildTaskHeader(),
          Expanded(
            child: Stack(
              children: [
                _buildMap(),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _buildStatusCards(),
                ),
              ],
            ),
          ),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildTaskHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: cardBackgroundColor,
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tour, color: primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.task.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          if (widget.task.description != null && widget.task.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.task.description!,
              style: const TextStyle(color: textSecondaryColor),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(
                Icons.schedule,
                'Required: ${widget.task.formattedDuration}',
                Colors.blue,
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                Icons.location_on,
                widget.geofence.name,
                widget.geofence.color,
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                Icons.stars,
                '${widget.task.points} pts',
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final geofencePolygon = _parseWKTToLatLng(widget.geofence.areaText);
    final center = _calculateCenter(geofencePolygon);

    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController.complete(controller);
      },
      initialCameraPosition: CameraPosition(
        target: center,
        zoom: 16,
      ),
      polygons: {
        Polygon(
          polygonId: PolygonId(widget.geofence.id),
          points: geofencePolygon,
          strokeColor: widget.geofence.color,
          strokeWidth: 2,
          fillColor: widget.geofence.color.withValues(alpha: 0.3),
        ),
      },
      markers: {
        Marker(
          markerId: MarkerId(widget.geofence.id),
          position: center,
          infoWindow: InfoWindow(
            title: widget.geofence.name,
            snippet: 'Work Zone',
          ),
        ),
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapType: MapType.normal,
    );
  }

  Widget _buildStatusCards() {
    return Consumer<TouringTaskMovementService>(
      builder: (context, service, child) {
        return Column(
          children: [
            _buildTimerCard(service),
            const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildStatusCard(service)),
                    const SizedBox(width: 8),
                Expanded(child: _buildMovementCard(service)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimerCard(TouringTaskMovementService service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimaryColor,
                ),
              ),
              Text(
                '${(service.progressPercentage * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  color: service.statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: service.progressPercentage,
            backgroundColor: Colors.grey.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(service.statusColor),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                service.formattedElapsedTime,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
              Text(
                '/ ${widget.task.formattedDuration}',
                style: const TextStyle(
                  fontSize: 16,
                  color: textSecondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(TouringTaskMovementService service) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
              Icon(
                service.isInGeofence ? Icons.location_on : Icons.location_off,
                size: 16,
                color: service.isInGeofence ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              const Text(
                'Location',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            service.isInGeofence ? 'In Work Zone' : 'Outside Zone',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: service.isInGeofence ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementCard(TouringTaskMovementService service) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
              Icon(
                service.isMoving ? Icons.directions_walk : Icons.pause_circle,
                size: 16,
                color: service.isMoving ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              const Text(
                'Movement',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            service.isMoving ? 'Moving' : 'Stationary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: service.isMoving ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurveyCard() {
    return GestureDetector(
      onTap: () => _openSurvey(_availableSurvey!),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
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
                Icon(
                  Icons.quiz,
                  size: 16,
                  color: Colors.purple[700],
                ),
                const SizedBox(width: 4),
                const Text(
                  'Survey',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSecondaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Available',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.purple[700],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_availableSurvey!.fieldCount} questions',
              style: const TextStyle(
                fontSize: 10,
                color: textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: cardBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Consumer<TouringTaskMovementService>(
        builder: (context, service, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: service.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: service.statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      service.isTimerRunning ? Icons.timer : Icons.timer_off,
                      color: service.statusColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        service.statusText,
                        style: TextStyle(
                          color: service.statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!_hasStarted)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isInitializing ? null : _startTask,
                    icon: _isInitializing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_isInitializing ? 'Starting...' : 'Start Task'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (_hasStarted && !service.isCompleted)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _stopTask,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop Task'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  List<LatLng> _parseWKTToLatLng(String wkt) {
    try {
      final coordsStr = wkt.replaceAll(RegExp(r'POLYGON\\(\\(|\\)\\)'), '');
      final coords = coordsStr.split(',').map((coord) {
        final parts = coord.trim().split(' ');
        if (parts.length >= 2) {
          final lat = double.tryParse(parts[0]);
          final lng = double.tryParse(parts[1]);
          if (lat != null && lng != null) {
            return LatLng(lat, lng);
          }
        }
        return null;
      }).where((point) => point != null).cast<LatLng>().toList();
      
      return coords;
    } catch (e) {
      debugPrint('Error parsing WKT: $e');
      return [];
    }
  }

  LatLng _calculateCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(24.7136, 46.6753); // Riyadh default
    
    double lat = 0;
    double lng = 0;
    
    for (final point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }
    
    return LatLng(lat / points.length, lng / points.length);
  }
}
