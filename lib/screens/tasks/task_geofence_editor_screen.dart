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
      // Request the area column as WKT using the computed column get_area_wkt
      final response = await supabase.from('geofences').select('*, area:get_area_wkt').eq('task_id', widget.task.id).maybeSingle();
      debugPrint("[GeofenceLoad] Supabase response: $response");
      final wktString = response?['area'];
      debugPrint("[GeofenceLoad] WKT String from DB: $wktString");
      
      if (mounted && wktString != null) {
        final parsedPoints = _parseWktPolygon(wktString);
        debugPrint("[GeofenceLoad] Parsed points: $parsedPoints");
        setState(() {
          _points.addAll(parsedPoints);
          _updatePolygon();
        });
      }
    } catch (e) {
      if(mounted) context.showSnackBar('Could not load existing geofence: $e', isError: true);
    } finally {
      if(mounted) setState(() => _isLoading = false);
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

      // Use upsert to either create a new geofence or update the existing one for this task.
      debugPrint("[GeofenceSave] Saving geofence for task_id: ${widget.task.id}");
      debugPrint("[GeofenceSave] WKT String to save: $wktString");
      final upsertResponse = await supabase.from('geofences').upsert({
        'task_id': widget.task.id,
        'name': '${widget.task.title} Geofence',
        'area': wktString,
      }, onConflict: 'task_id');
      debugPrint("[GeofenceSave] Supabase upsert response: $upsertResponse");

      if (mounted) {
        context.showSnackBar('Geofence saved successfully!');
        Navigator.of(context).pop();
      }

    } catch (e) {
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
    try {
      final pointsList = <LatLng>[];
      final content = wkt.substring(wkt.indexOf('((') + 2, wkt.lastIndexOf('))'));
      final pairs = content.split(',');
      for (var i = 0; i < pairs.length; i++) {
        final coords = pairs[i].trim().split(' ');
        pointsList.add(LatLng(double.parse(coords[1]), double.parse(coords[0])));
      }
      return pointsList;
    } catch (e) {
      debugPrint("Failed to parse WKT Polygon: $e");
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
                  onMapCreated: (controller) => _mapController.complete(controller),
                  onTap: _onMapTapped,
                  polygons: _polygons,
                  markers: _points.map((point) => Marker(
                    markerId: MarkerId(point.toString()),
                    position: point,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  )).toSet(),
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
