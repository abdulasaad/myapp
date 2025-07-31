// lib/screens/agent/geofence_tracking_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import '../../models/campaign.dart';
import '../../models/agent_geofence_assignment.dart';
import '../../models/campaign_geofence.dart';
import '../../services/geofence_location_tracker.dart';
import '../../services/campaign_geofence_service.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/modern_notification.dart';

class GeofenceTrackingScreen extends StatefulWidget {
  final Campaign campaign;

  const GeofenceTrackingScreen({super.key, required this.campaign});

  @override
  State<GeofenceTrackingScreen> createState() => _GeofenceTrackingScreenState();
}

class _GeofenceTrackingScreenState extends State<GeofenceTrackingScreen> {
  final GeofenceLocationTracker _tracker = GeofenceLocationTracker();
  final CampaignGeofenceService _geofenceService = CampaignGeofenceService();
  final Completer<maps.GoogleMapController> _mapController = Completer<maps.GoogleMapController>();

  AgentGeofenceAssignment? _currentAssignment;
  CampaignGeofence? _currentGeofence;
  Position? _currentPosition;
  bool _isTracking = false;
  bool _isInsideGeofence = false;
  String _statusMessage = 'Initializing...';
  Duration _timeInGeofence = Duration.zero;
  Timer? _timeTimer;

  Set<maps.Polygon> _polygons = {};
  final Set<maps.Marker> _markers = {};
  Set<maps.Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _tracker.stopTracking();
    _timeTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    try {
      setState(() {
        _statusMessage = 'Loading assignment...';
      });

      // Get current assignment
      _currentAssignment = await _geofenceService.getAgentCurrentAssignment(
        campaignId: widget.campaign.id,
        agentId: supabase.auth.currentUser!.id,
      );

      if (_currentAssignment == null) {
        setState(() {
          _statusMessage = AppLocalizations.of(context)!.noActiveAssignment;
        });
        return;
      }

      // Get geofence details
      final geofences = await _geofenceService.getAvailableGeofencesForCampaign(widget.campaign.id);
      _currentGeofence = geofences.firstWhere(
        (g) => g.id == _currentAssignment!.geofenceId,
        orElse: () => throw Exception('Geofence not found'),
      );

      // Start tracking
      final success = await _tracker.startTracking(
        campaignId: widget.campaign.id,
        agentId: supabase.auth.currentUser!.id,
        onGeofenceStatusChanged: _onGeofenceStatusChanged,
        onLocationUpdate: _onLocationUpdate,
        onError: _onError,
      );

      if (success) {
        setState(() {
          _isTracking = true;
          _statusMessage = AppLocalizations.of(context)!.trackingActive;
        });
        _updateMapDisplay();
        _startTimeTracking();
      } else {
        setState(() {
          _statusMessage = 'Failed to start tracking';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
      ModernNotification.error(context, message: 'Failed to initialize tracking', subtitle: e.toString());
    }
  }

  void _onGeofenceStatusChanged(bool isInside) {
    setState(() {
      _isInsideGeofence = isInside;
      _statusMessage = isInside ? AppLocalizations.of(context)!.insideGeofence : AppLocalizations.of(context)!.outsideGeofence;
    });

    // Show notification for status change
    if (isInside) {
      ModernNotification.success(
        context,
        message: AppLocalizations.of(context)!.enteredGeofence,
        subtitle: _currentGeofence?.name ?? 'Work area',
      );
    } else {
      ModernNotification.warning(
        context,
        message: AppLocalizations.of(context)!.leftGeofence,
        subtitle: AppLocalizations.of(context)!.returnToAssignedArea,
      );
    }

    _updateMapDisplay();
  }

  void _onLocationUpdate(Position position) {
    setState(() {
      _currentPosition = position;
    });
    _updateMapDisplay();
  }

  void _onError(String error) {
    ModernNotification.error(context, message: 'Tracking error', subtitle: error);
  }

  void _startTimeTracking() {
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentAssignment?.isCurrentlyInside == true) {
        setState(() {
          _timeInGeofence = _timeInGeofence + const Duration(seconds: 1);
        });
      }
    });
  }

  void _updateMapDisplay() async {
    if (_currentGeofence == null) return;

    try {
      // Parse geofence polygon
      final points = _parseWKTToLatLng(_currentGeofence!.areaText);
      
      setState(() {
        // Add geofence polygon
        _polygons = {
          maps.Polygon(
            polygonId: maps.PolygonId(_currentGeofence!.id),
            points: points,
            strokeColor: _currentGeofence!.color,
            strokeWidth: 3,
            fillColor: _currentGeofence!.color.withValues(alpha: 0.2),
          ),
        };

        // Add current location marker
        _markers.clear();
        if (_currentPosition != null) {
          _markers.add(
            maps.Marker(
              markerId: const maps.MarkerId('current_location'),
              position: maps.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              icon: maps.BitmapDescriptor.defaultMarkerWithHue(
                _isInsideGeofence ? maps.BitmapDescriptor.hueGreen : maps.BitmapDescriptor.hueRed,
              ),
              infoWindow: maps.InfoWindow(
                title: 'Your Location',
                snippet: _isInsideGeofence ? AppLocalizations.of(context)!.insideGeofence : AppLocalizations.of(context)!.outsideGeofence,
              ),
            ),
          );

          // Add accuracy circle
          _circles = {
            maps.Circle(
              circleId: const maps.CircleId('accuracy'),
              center: maps.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              radius: _currentPosition!.accuracy,
              fillColor: Colors.blue.withValues(alpha: 0.1),
              strokeColor: Colors.blue.withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          };
        }
      });

      // Move camera to show both geofence and current location
      if (_currentPosition != null && points.isNotEmpty) {
        final controller = await _mapController.future;
        final bounds = _calculateBounds([
          ...points,
          maps.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ]);
        controller.animateCamera(maps.CameraUpdate.newLatLngBounds(bounds, 100));
      }
    } catch (e) {
      debugPrint('Error updating map display: $e');
    }
  }

  List<maps.LatLng> _parseWKTToLatLng(String wkt) {
    try {
      final coordsStr = wkt.replaceAll(RegExp(r'POLYGON\(\(|\)\)'), '');
      return coordsStr.split(',').map((coord) {
        final parts = coord.trim().split(' ');
        if (parts.length >= 2) {
          final lat = double.tryParse(parts[0]);
          final lng = double.tryParse(parts[1]);
          if (lat != null && lng != null) {
            return maps.LatLng(lat, lng);
          }
        }
        return null;
      }).where((point) => point != null).cast<maps.LatLng>().toList();
    } catch (e) {
      return [];
    }
  }

  maps.LatLngBounds _calculateBounds(List<maps.LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return maps.LatLngBounds(
      southwest: maps.LatLng(minLat, minLng),
      northeast: maps.LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.geofenceTracking),
        backgroundColor: _isInsideGeofence ? successColor : primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _updateMapDisplay,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusCard(),
          Expanded(
            child: _currentGeofence != null
                ? maps.GoogleMap(
                    onMapCreated: (maps.GoogleMapController controller) {
                      _mapController.complete(controller);
                    },
                    polygons: _polygons,
                    markers: _markers,
                    circles: _circles,
                    initialCameraPosition: const maps.CameraPosition(
                      target: maps.LatLng(24.7136, 46.6753), // Riyadh, Saudi Arabia
                      zoom: 15,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    mapType: maps.MapType.normal,
                  )
                : _buildNoAssignmentView(),
          ),
          if (_currentAssignment != null) _buildControlsPanel(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isInsideGeofence ? successColor.withValues(alpha: 0.1) : warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isInsideGeofence ? successColor.withValues(alpha: 0.3) : warningColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isInsideGeofence ? successColor : warningColor,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  _isInsideGeofence ? Icons.check_circle : Icons.warning,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentGeofence?.name ?? AppLocalizations.of(context)!.noActiveAssignment,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimaryColor,
                      ),
                    ),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: _isInsideGeofence ? successColor : warningColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isTracking)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: successColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: successColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'TRACKING',
                        style: TextStyle(
                          color: successColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_currentPosition != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    AppLocalizations.of(context)!.accuracy,
                    '${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                    Icons.gps_fixed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoChip(
                    AppLocalizations.of(context)!.timeInside,
                    _formatDuration(_timeInGeofence),
                    Icons.schedule,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: primaryColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPrimaryColor,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAssignmentView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noActiveAssignment,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.selectGeofenceToStartTracking,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: Text(AppLocalizations.of(context)!.goBack),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isTracking ? _stopTracking : _startTracking,
                icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                label: Text(_isTracking ? AppLocalizations.of(context)!.stopTracking : AppLocalizations.of(context)!.startTracking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTracking ? errorColor : successColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _completeAssignment,
              icon: const Icon(Icons.task_alt),
              label: Text(AppLocalizations.of(context)!.complete),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startTracking() async {
    final success = await _tracker.startTracking(
      campaignId: widget.campaign.id,
      agentId: supabase.auth.currentUser!.id,
      onGeofenceStatusChanged: _onGeofenceStatusChanged,
      onLocationUpdate: _onLocationUpdate,
      onError: _onError,
    );

    setState(() {
      _isTracking = success;
      _statusMessage = success ? AppLocalizations.of(context)!.trackingActive : 'Failed to start tracking';
    });
  }

  void _stopTracking() {
    _tracker.stopTracking();
    setState(() {
      _isTracking = false;
      _statusMessage = AppLocalizations.of(context)!.trackingStopped;
    });
  }

  void _completeAssignment() async {
    if (_currentAssignment == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.completeAssignment),
        content: const Text('Are you sure you want to complete your geofence assignment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: successColor),
            child: Text(AppLocalizations.of(context)!.complete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _geofenceService.completeAgentAssignment(_currentAssignment!.id);
        ModernNotification.success(context, message: AppLocalizations.of(context)!.assignmentCompletedSuccessfully);
        Navigator.of(context).pop();
      } catch (e) {
        ModernNotification.error(context, message: AppLocalizations.of(context)!.failedToCompleteAssignment, subtitle: e.toString());
      }
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}