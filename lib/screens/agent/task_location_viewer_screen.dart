// lib/screens/agent/task_location_viewer_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myapp/models/task.dart';
import 'package:myapp/utils/constants.dart';

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
  bool _isLoading = true;
  // Re-introducing this state variable from your working code is key.
  LatLng? _initialCameraPosition;

  @override
  void initState() {
    super.initState();
    _loadGeofence();
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
      final wktString = await supabase.rpc(
        'get_geofence_for_task',
        params: {'p_task_id': widget.task.id},
      );

      if (mounted && wktString != null) {
        final points = _parseWktPolygon(wktString.toString());

        if (points.isNotEmpty) {
          // Add the polygon to the state.
          setState(() {
            _polygons.add(
              Polygon(
                polygonId: PolygonId(widget.task.id),
                points: points,
                strokeWidth: 2,
                strokeColor: primaryColor,
                fillColor: primaryColor.withAlpha(51),
              ),
            );
            // This is from your working version and ensures the UI can build.
            _initialCameraPosition = points.first;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Could not load geofence: $e', isError: true);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.task.title} - Location')),
      body: _isLoading
          ? preloader
          // This logic from your working version is more robust.
          : _initialCameraPosition == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No geofence has been defined for this task.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : GoogleMap(
                  // Use the initial position from the loaded data.
                  initialCameraPosition: CameraPosition(
                    target: _initialCameraPosition!,
                    zoom: 12,
                  ),
                  onMapCreated: _onMapCreated, // Call our new function here.
                  polygons: _polygons,
                  myLocationButtonEnabled: true,
                  myLocationEnabled: true,
                ),
    );
  }
}

