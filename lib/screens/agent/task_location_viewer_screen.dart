// lib/screens/agent/task_location_viewer_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myapp/models/task.dart';
import 'package:myapp/utils/constants.dart';

class GeofenceInfo {
  final String id;
  final String name;
  final List<LatLng> points;
  final LatLng centerPoint;
  final Color color;

  GeofenceInfo({
    required this.id,
    required this.name,
    required this.points,
    required this.centerPoint,
    required this.color,
  });
}

class TaskLocationViewerScreen extends StatefulWidget {
  final Task task;
  const TaskLocationViewerScreen({super.key, required this.task});

  @override
  State<TaskLocationViewerScreen> createState() =>
      _TaskLocationViewerScreenState();
}

class _TaskLocationViewerScreenState extends State<TaskLocationViewerScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final Set<Polygon> _polygons = {};
  final Set<Marker> _markers = {};
  final List<GeofenceInfo> _geofenceInfos = [];
  final PageController _pageController = PageController();
  bool _isLoading = true;
  int _currentZoneIndex = 0;
  // Re-introducing this state variable from your working code is key.
  LatLng? _initialCameraPosition;

  @override
  void initState() {
    super.initState();
    _loadGeofence();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Parses a WKT (Well-Known Text) string into a list of LatLng points.
  List<LatLng> _parseWktPolygon(String wkt) {
    try {
      final pointsList = <LatLng>[];
      final content = wkt.substring(wkt.indexOf('((') + 2, wkt.lastIndexOf('))'));
      final pairs = content.split(',');
      for (var pair in pairs) {
        final coords = pair.trim().split(' ');
        if (coords.length == 2) {
          final lng = double.parse(coords[0]);
          final lat = double.parse(coords[1]);
          pointsList.add(LatLng(lat, lng));
        }
      }
      return pointsList;
    } catch (e) {
      debugPrint("Failed to parse WKT Polygon: $e");
      return [];
    }
  }

  // This helper function is correct and remains.
  /// Calculates the bounding box for a list of points.
  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLat = points.first.latitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }


  /// Fetches the geofence data from Supabase for the current task.
  Future<void> _loadGeofence() async {
    try {
      debugPrint('[TaskLocationViewer] Loading geofences for task: ${widget.task.id}');

      // Query geofences table directly instead of using RPC
      final response = await supabase
          .from('geofences')
          .select('id, name, area_text, area, color')
          .eq('task_id', widget.task.id);

      debugPrint('[TaskLocationViewer] Found ${response.length} geofences');

      if (response.isNotEmpty) {
        for (int i = 0; i < response.length; i++) {
          final geofence = response[i];
          final wktString = geofence['area_text'] as String? ?? geofence['area'] as String?;
          
          if (wktString != null && wktString.isNotEmpty) {
            debugPrint('[TaskLocationViewer] Processing geofence $i: ${geofence['name']}');
            final points = _parseWktPolygon(wktString);

            if (points.isNotEmpty) {
              debugPrint('[TaskLocationViewer] Successfully parsed ${points.length} points');
              
              // Calculate center point for marker
              final centerLat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
              final centerLng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
              final centerPoint = LatLng(centerLat, centerLng);
              
              final geofenceName = geofence['name'] as String? ?? 'Zone ${i + 1}';
              final geofenceId = geofence['id']?.toString() ?? '${widget.task.id}_$i';
              
              // Create GeofenceInfo object
              final geofenceInfo = GeofenceInfo(
                id: geofenceId,
                name: geofenceName,
                points: points,
                centerPoint: centerPoint,
                color: primaryColor,
              );
              
              _geofenceInfos.add(geofenceInfo);
              
              // Add the polygon to the state.
              setState(() {
                _polygons.add(
                  Polygon(
                    polygonId: PolygonId(geofenceId),
                    points: points,
                    strokeWidth: 2,
                    strokeColor: primaryColor,
                    fillColor: primaryColor.withValues(alpha: 0.2),
                  ),
                );
                
                // Set initial camera position to center of first geofence
                _initialCameraPosition ??= centerPoint;
              });
              
              // Don't break - load all geofences
            } else {
              debugPrint('[TaskLocationViewer] No points parsed from WKT: $wktString');
            }
          } else {
            debugPrint('[TaskLocationViewer] No WKT data in geofence $i');
          }
        }
      } else {
        debugPrint('[TaskLocationViewer] No geofences found for task');
      }
    } catch (e) {
      debugPrint('[TaskLocationViewer] Error loading geofence: $e');
      // Don't show error to user, just continue without geofence
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ===================================================================
  // THE FIX: The camera animation is now done in `onMapCreated`.
  // This ensures the map is ready before we try to move the camera,
  // preventing the loading screen from getting stuck.
  // ===================================================================
  void _onMapCreated(GoogleMapController controller) {
    _mapController.complete(controller);
    // If we have a polygon, calculate its bounds and animate the camera.
    if (_polygons.isNotEmpty) {
      final bounds = _calculateBounds(_polygons.first.points);
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
    }
  }

  Future<void> _navigateToZone(int zoneIndex) async {
    if (zoneIndex < 0 || zoneIndex >= _geofenceInfos.length) return;
    
    final zone = _geofenceInfos[zoneIndex];
    final controller = await _mapController.future;
    
    // Calculate bounds for the specific zone
    final bounds = _calculateBounds(zone.points);
    
    // Animate to the zone with padding
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80.0),
    );
    
    setState(() {
      _currentZoneIndex = zoneIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Modern Title Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.black87),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${widget.task.title} - Location',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _isLoading
                    ? preloader
                    // This logic from your working version is more robust.
                    : _initialCameraPosition == null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_off,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'No Location Set',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.task.locationName != null && widget.task.locationName!.isNotEmpty
                                        ? 'This task has a location name but no geofence area defined. You can submit evidence from any location.'
                                        : 'The manager has not set a specific location or geofence for this task. You can submit evidence from any location.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : GoogleMap(
                            // Use the initial position from the loaded data.
                            initialCameraPosition: CameraPosition(
                              target: _initialCameraPosition!,
                              zoom: 15,
                            ),
                            onMapCreated: _onMapCreated,
                            polygons: _polygons,
                            markers: _markers,
                            myLocationButtonEnabled: true,
                            myLocationEnabled: true,
                            // Enable map interactions
                            zoomGesturesEnabled: true,
                            scrollGesturesEnabled: true,
                            rotateGesturesEnabled: true,
                            tiltGesturesEnabled: true,
                            // UI controls
                            zoomControlsEnabled: true,
                            mapToolbarEnabled: true,
                            compassEnabled: true,
                            // Disable lite mode for full interactivity
                            liteModeEnabled: false,
                            // Performance settings
                            indoorViewEnabled: false,
                            trafficEnabled: false,
                            buildingsEnabled: true,
                          ),
              ),
            ],
          ),
        ),
        bottomSheet: _geofenceInfos.isNotEmpty ? Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with zone counter
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.location_on, color: primaryColor, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Geofence Areas',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentZoneIndex + 1} of ${_geofenceInfos.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Zone cards carousel
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    _navigateToZone(index);
                  },
                  itemCount: _geofenceInfos.length,
                  itemBuilder: (context, index) {
                    final zone = _geofenceInfos[index];
                    return Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: _buildZoneCard(zone, index),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ) : null,
    ),
    );
  }

  Widget _buildZoneCard(GeofenceInfo zone, int index) {
    final isCurrentZone = index == _currentZoneIndex;
    
    return GestureDetector(
      onTap: () => _navigateToZone(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: isCurrentZone 
              ? LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.12),
                    primaryColor.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isCurrentZone ? null : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrentZone ? primaryColor.withValues(alpha: 0.3) : Colors.grey[200]!,
            width: isCurrentZone ? 1.5 : 1,
          ),
          boxShadow: isCurrentZone ? [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : [],
        ),
        child: Row(
          children: [
            // Zone icon with animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: isCurrentZone 
                    ? LinearGradient(
                        colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isCurrentZone ? null : Colors.grey[400],
                borderRadius: BorderRadius.circular(18),
                boxShadow: isCurrentZone ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ] : [],
              ),
              child: Icon(
                Icons.location_on,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Zone details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    zone.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isCurrentZone ? primaryColor : Colors.black87,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.timeline,
                        color: Colors.grey[500],
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${zone.points.length} points',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Navigation indicator
            AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: isCurrentZone ? 0.25 : 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isCurrentZone 
                      ? primaryColor.withValues(alpha: 0.1) 
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCurrentZone ? Icons.gps_fixed : Icons.arrow_forward_ios,
                  color: isCurrentZone ? primaryColor : Colors.grey[400],
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

