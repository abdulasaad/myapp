// lib/screens/tasks/task_geofence_editor_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';

class TaskGeofenceEditorScreen extends StatefulWidget {
  final Task task;
  const TaskGeofenceEditorScreen({super.key, required this.task});

  @override
  State<TaskGeofenceEditorScreen> createState() => _TaskGeofenceEditorScreenState();
}

class _TaskGeofenceEditorScreenState extends State<TaskGeofenceEditorScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  
  final List<LatLng> _points = [];
  final Set<Polygon> _polygons = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingGeofence();
  }

  // --- Data Logic ---

  Future<void> _loadExistingGeofence() async {
    try {
      debugPrint("[GeofenceLoad] Loading geofence for task_id: ${widget.task.id}");
      
      // Simple approach: just get the row without PostGIS functions
      final response = await supabase.from('geofences').select('*').eq('task_id', widget.task.id).maybeSingle();
      debugPrint("[GeofenceLoad] Supabase response: $response");
      
      if (response != null) {
        final wktString = response['area_text'] as String? ?? response['area'] as String?;
        debugPrint("[GeofenceLoad] WKT String from DB: $wktString");
        
        if (mounted && wktString != null && wktString.isNotEmpty) {
          try {
            final parsedPoints = _parseWktPolygon(wktString);
            debugPrint("[GeofenceLoad] Parsed points: $parsedPoints");
            
            if (parsedPoints.isNotEmpty) {
              setState(() {
                _points.clear(); // Clear existing points
                _points.addAll(parsedPoints); // Add parsed points
                _updatePolygon();
              });
              debugPrint("[GeofenceLoad] Successfully loaded ${parsedPoints.length} points");
            }
          } catch (parseError) {
            debugPrint("[GeofenceLoad] Error parsing WKT: $parseError");
            if (mounted) context.showSnackBar('Could not parse existing geofence data', isError: true);
          }
        } else {
          debugPrint("[GeofenceLoad] No area data found");
        }
      } else {
        debugPrint("[GeofenceLoad] No geofence found for this task");
      }
    } catch (e) {
      debugPrint("[GeofenceLoad] Error loading geofence: $e");
      if (mounted) context.showSnackBar('Could not load existing geofence: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveGeofence() async {
    if (_points.length < 3) {
      context.showSnackBar('A geofence must have at least 3 points.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final wktPoints = _points.map((p) => '${p.longitude} ${p.latitude}').toList();
      wktPoints.add('${_points.first.longitude} ${_points.first.latitude}');
      final wktString = 'POLYGON((${wktPoints.join(', ')}))';

      debugPrint("[GeofenceSave] Saving geofence for task_id: ${widget.task.id}");
      debugPrint("[GeofenceSave] WKT String to save: $wktString");
      
      // Check if geofence already exists
      final existing = await supabase
          .from('geofences')
          .select('id')
          .eq('task_id', widget.task.id)
          .maybeSingle();
      
      if (existing != null) {
        // Update existing geofence - store as text in a text column
        await supabase.from('geofences').update({
          'name': '${widget.task.title} Geofence',
          'area_text': wktString, // Use a text column instead of geometry column
        }).eq('task_id', widget.task.id);
        debugPrint("[GeofenceSave] Updated existing geofence");
      } else {
        // Insert new geofence - store as text in a text column
        await supabase.from('geofences').insert({
          'task_id': widget.task.id,
          'name': '${widget.task.title} Geofence',
          'area_text': wktString, // Use a text column instead of geometry column
        });
        debugPrint("[GeofenceSave] Inserted new geofence");
      }

      if (mounted) {
        context.showSnackBar('Geofence saved successfully!');
        Navigator.of(context).pop();
      }

    } catch (e) {
      debugPrint("[GeofenceSave] Error: $e");
      if (mounted) context.showSnackBar('Failed to save geofence: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // --- UI Logic ---

  void _onMapTapped(LatLng point) {
    setState(() {
      _points.add(point);
      _updatePolygon();
    });
  }

  void _updatePolygon() {
    _polygons.clear();
    if (_points.isNotEmpty) {
      _polygons.add(
        Polygon(
          polygonId: const PolygonId('geofence'),
          points: _points,
          strokeWidth: 2,
          strokeColor: Colors.blue,
          fillColor: Colors.blue.withAlpha(80),
        ),
      );
    }
  }

  void _undo() {
    if (_points.isNotEmpty) setState(() { _points.removeLast(); _updatePolygon(); });
  }

  void _clear() {
    setState(() { _points.clear(); _updatePolygon(); });
  }

  List<LatLng> _parseWktPolygon(String wkt) {
    debugPrint("[WKT Parser] Input WKT: '$wkt'");
    
    if (!wkt.contains('POLYGON')) {
      debugPrint("[WKT Parser] Not a valid POLYGON WKT");
      return [];
    }
    
    try {
      final pointsList = <LatLng>[];
      final content = wkt.substring(wkt.indexOf('((') + 2, wkt.lastIndexOf('))'));
      debugPrint("[WKT Parser] Extracted content: '$content'");
      
      final pairs = content.split(',');
      debugPrint("[WKT Parser] Coordinate pairs: ${pairs.length}");
      
      for (var i = 0; i < pairs.length; i++) {
        final coords = pairs[i].trim().split(' ');
        debugPrint("[WKT Parser] Pair $i: '${pairs[i].trim()}' -> coords: $coords");
        
        if (coords.length >= 2) {
          try {
            final lng = double.parse(coords[0]);
            final lat = double.parse(coords[1]);
            pointsList.add(LatLng(lat, lng));
            debugPrint("[WKT Parser] Added point: ($lat, $lng)");
          } catch (e) {
            debugPrint("[WKT Parser] Failed to parse coordinates: $e");
          }
        } else {
          debugPrint("[WKT Parser] Invalid coordinate pair: ${coords.length} elements");
        }
      }
      
      debugPrint("[WKT Parser] Final points count: ${pointsList.length}");
      return pointsList;
    } catch (e) {
      debugPrint("[WKT Parser] Failed to parse WKT Polygon: $e");
      return [];
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Geofence Editor'),
        actions: [
          IconButton(icon: const Icon(Icons.undo), tooltip: 'Undo', onPressed: _undo),
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Clear', onPressed: _clear),
        ],
      ),
      body: _isLoading
          ? preloader
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(target: LatLng(33.3152, 44.3661), zoom: 12),
                  onMapCreated: (controller) {
                    if (!_mapController.isCompleted) {
                      _mapController.complete(controller);
                    }
                  },
                  onTap: _onMapTapped,
                  polygons: _polygons,
                  markers: _points.map((point) => Marker(
                    markerId: MarkerId(point.toString()),
                    position: point,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  )).toSet(),
                  // Performance optimizations for mobile devices
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  rotateGesturesEnabled: true, // Keep enabled for editing
                  tiltGesturesEnabled: false,
                  zoomControlsEnabled: false,
                  indoorViewEnabled: false,
                  trafficEnabled: false,
                  buildingsEnabled: false,
                  myLocationButtonEnabled: true,
                  myLocationEnabled: true,
                  // Reduce memory usage for non-essential features
                  polylines: const <Polyline>{},
                  circles: const <Circle>{},
                ),
                Positioned(
                  top: 10, left: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black.withAlpha(180), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Tap on the map to draw the geofence boundary.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_isLoading || _points.length < 3) ? null : _saveGeofence,
        label: const Text('Save Geofence'),
        icon: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save),
        backgroundColor: (_points.length < 3) ? Colors.grey : primaryColor,
      ),
    );
  }
}
