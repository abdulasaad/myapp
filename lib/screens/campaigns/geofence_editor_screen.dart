// lib/screens/campaigns/geofence_editor_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/campaign.dart';
import '../../utils/constants.dart';

class GeofenceEditorScreen extends StatefulWidget {
  final Campaign campaign;
  const GeofenceEditorScreen({super.key, required this.campaign});

  @override
  State<GeofenceEditorScreen> createState() => _GeofenceEditorScreenState();
}

class _GeofenceEditorScreenState extends State<GeofenceEditorScreen> {
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
      // --- THE FIX: Call our new, reliable database function ---
      final wktString = await supabase.rpc('get_geofence_for_campaign', params: {
        'p_campaign_id': widget.campaign.id,
      });

      // If the function returns a valid text string, parse it.
      if (mounted && wktString != null) {
        setState(() {
          _points.addAll(_parseWktPolygon(wktString.toString()));
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

      await supabase.from('geofences').upsert({
        'campaign_id': widget.campaign.id,
        'name': '${widget.campaign.name} Geofence',
        'area': wktString,
      }, onConflict: 'campaign_id');

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
          fillColor: Color.fromRGBO((Colors.blue.r * 255.0).round() & 0xff, (Colors.blue.g * 255.0).round() & 0xff, (Colors.blue.b * 255.0).round() & 0xff, 0.3),
        ),
      );
    }
  }

  void _undo() {
    if (_points.isNotEmpty) {
      setState(() {
        _points.removeLast();
        _updatePolygon();
      });
    }
  }

  void _clear() {
    setState(() {
      _points.clear();
      _updatePolygon();
    });
  }

  List<LatLng> _parseWktPolygon(String wkt) {
    try {
      final pointsList = <LatLng>[];
      final content = wkt.substring(wkt.indexOf('((') + 2, wkt.lastIndexOf('))'));
      final pairs = content.split(',');
      for (var i = 0; i < pairs.length - 1; i++) {
        final coords = pairs[i].trim().split(' ');
        final lng = double.parse(coords[0]);
        final lat = double.parse(coords[1]);
        pointsList.add(LatLng(lat, lng));
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
        title: const Text('Geofence Editor'),
        actions: [
          if (_points.isNotEmpty)
            IconButton(icon: const Icon(Icons.undo), tooltip: 'Undo Last Point', onPressed: _undo),
          if (_points.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Clear All Points', onPressed: _clear),
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
                    draggable: false,
                  )).toSet(),
                ),
                if (_isLoading)
                  Container(color: Colors.black.withAlpha(128), child: preloader),
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(179),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Tap on the map to draw the geofence boundary. You need at least 3 points.',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
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
