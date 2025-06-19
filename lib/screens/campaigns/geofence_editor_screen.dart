// lib/screens/campaigns/geofence_editor_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:uuid/uuid.dart';
import '../../models/campaign.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';

// A Dart model to represent a single, editable geofence zone.
class GeofenceZone {
  String id;
  String name;
  List<LatLng> points;
  Color color;
  final bool isNew; // Flag to identify newly created zones

  GeofenceZone({
    required this.id,
    required this.name,
    required this.points,
    required this.color,
    this.isNew = false,
  });
}

class GeofenceEditorScreen extends StatefulWidget {
  final Campaign? campaign;
  final Task? task;

  const GeofenceEditorScreen({super.key, this.campaign, this.task})
      : assert(campaign != null || task != null, 'Either campaign or task must be provided.'),
        assert(campaign == null || task == null, 'Cannot provide both a campaign and a task.');

  @override
  State<GeofenceEditorScreen> createState() => _GeofenceEditorScreenState();
}

class _GeofenceEditorScreenState extends State<GeofenceEditorScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  final Uuid _uuid = const Uuid();

  // --- State Management ---
  bool _isLoading = true;
  bool _isSaving = false;
  List<GeofenceZone> _zones = [];
  final List<String> _deletedZoneIds = [];
  String? _selectedZoneId;

  GeofenceZone? get _selectedZone {
    if (_selectedZoneId == null) return null;
    try {
      return _zones.firstWhere((z) => z.id == _selectedZoneId);
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadGeofences();
  }

  // --- Data Loading ---
  Future<void> _loadGeofences() async {
    setState(() => _isLoading = true);
    try {
      final parentId = widget.campaign?.id ?? widget.task!.id;
      final response = await supabase.rpc('get_geofences_for_parent', params: {'parent_id': parentId});

      final loadedZones = (response as List).map<GeofenceZone>((data) {
        return GeofenceZone(
          id: data['id'],
          name: data['name'] ?? 'Unnamed Zone',
          points: _parseWktPolygon(data['area_wkt'] as String? ?? ''),
          color: _colorFromHex(data['color'] as String? ?? '#808080'),
          isNew: false,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _zones = loadedZones;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Could not load geofences: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }
  
  // --- UI Actions & Dialogs ---
  void _addNewZone() {
    setState(() {
      final newId = _uuid.v4();
      _zones.add(GeofenceZone(id: newId, name: 'New Zone', points: [], color: Colors.blue, isNew: true));
      _selectedZoneId = newId;
    });
  }

  void _deleteSelectedZone() {
    if (_selectedZone == null) return;
    setState(() {
      if (!_selectedZone!.isNew) {
        _deletedZoneIds.add(_selectedZone!.id);
      }
      _zones.removeWhere((z) => z.id == _selectedZoneId);
      _selectedZoneId = null;
    });
  }

  Future<void> _renameSelectedZone() async {
    if (_selectedZone == null) return;
    final nameController = TextEditingController(text: _selectedZone!.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Zone'),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Zone Name')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(nameController.text), child: const Text('Save')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      setState(() => _selectedZone!.name = newName);
    }
  }

  void _changeSelectedZoneColor() {
    if (_selectedZone == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(child: ColorPicker(pickerColor: _selectedZone!.color, onColorChanged: (color) => setState(() => _selectedZone!.color = color))),
        actions: <Widget>[ElevatedButton(child: const Text('Done'), onPressed: () => Navigator.of(context).pop())],
      ),
    );
  }

  // --- Map Interaction Logic ---
  void _onMapTapped(LatLng point) {
    if (_selectedZone != null) {
      setState(() => _selectedZone!.points.add(point));
    } else {
      setState(() => _selectedZoneId = null);
    }
  }

  void _onMarkerTapped(int pointIndex) {
    if (_selectedZone == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pin?'),
        content: const Text('Are you sure you want to remove this pin?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => _selectedZone!.points.removeAt(pointIndex));
              Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  void _onMarkerDragEnd(int pointIndex, LatLng newPosition) {
    if (_selectedZone == null) return;
    setState(() => _selectedZone!.points[pointIndex] = newPosition);
  }

  // --- Data Saving ---
  Future<void> _saveGeofences() async {
    setState(() => _isSaving = true);
    try {
      if (_deletedZoneIds.isNotEmpty) {
        for (final zoneId in _deletedZoneIds) {
          await supabase.from('geofences').delete().eq('id', zoneId);
        }
      }
      final zonesToUpsert = _zones.where((z) => z.points.length >= 3).map((zone) {
        return {
          'id': zone.id,
          'campaign_id': widget.campaign?.id,
          'task_id': widget.task?.id,
          'name': zone.name,
          // ========== FIX 2: Use modern, non-deprecated method for hex conversion ==========
          'color': '#${((zone.color.r * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}${((zone.color.g * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}${((zone.color.b * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}',
          'area': _wktFromPoints(zone.points),
        };
      }).toList();
      if (zonesToUpsert.isNotEmpty) {
        await supabase.from('geofences').upsert(zonesToUpsert);
      }
      if (mounted) {
        context.showSnackBar('Geofences saved successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to save geofences: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.campaign?.name ?? widget.task?.title ?? 'Geofence Editor'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isSaving ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0) : const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveGeofences,
              tooltip: 'Save Geofences',
            ),
        ],
      ),
      body: _isLoading
          ? preloader
          : Stack(
              children: [
                _buildGoogleMap(),
                _buildZoneList(),
                if (_selectedZone != null) _buildEditingControls(),
              ],
            ),
      floatingActionButton: _selectedZoneId == null
          ? FloatingActionButton.extended(
              onPressed: _addNewZone,
              label: const Text('New Zone'),
              icon: const Icon(Icons.add_location_alt_outlined),
            )
          : null,
    );
  }

  // --- Widget Builders ---
  Widget _buildGoogleMap() {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(target: LatLng(33.3152, 44.3661), zoom: 11),
      onMapCreated: (controller) => _mapController.complete(controller),
      onTap: _onMapTapped,
      polygons: _zones.map((zone) {
        return Polygon(
          polygonId: PolygonId(zone.id),
          points: zone.points,
          strokeWidth: _selectedZoneId == zone.id ? 3 : 1,
          strokeColor: zone.color,
          // ========== FIX 3: Use .withAlpha() as the modern replacement ==========
          fillColor: zone.color.withAlpha(80),
          consumeTapEvents: true,
          onTap: () => setState(() => _selectedZoneId = zone.id),
        );
      }).toSet(),
      markers: _getMarkersForSelectedZone(),
    );
  }

  Widget _buildZoneList() {
    return Positioned(
      top: 10,
      left: 10,
      child: Card(
        elevation: 8,
        child: Container(
          padding: const EdgeInsets.all(8.0),
          width: 200,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Zones", style: Theme.of(context).textTheme.titleLarge),
              const Divider(),
              if (_zones.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text("No zones created."))),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _zones.length,
                  itemBuilder: (context, index) {
                    final zone = _zones[index];
                    final isSelected = zone.id == _selectedZoneId;
                    return Material(
                      // ========== FIX 3: Use .withAlpha() as the modern replacement ==========
                      color: isSelected ? primaryColor.withAlpha(75) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      child: ListTile(
                        leading: Icon(Icons.label, color: zone.color, size: 20),
                        title: Text(zone.name, overflow: TextOverflow.ellipsis),
                        selected: isSelected,
                        onTap: () => setState(() => _selectedZoneId = zone.id),
                        dense: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Set<Marker> _getMarkersForSelectedZone() {
    if (_selectedZone == null) return {};
    return Set.from(_selectedZone!.points.asMap().entries.map((entry) {
      final pointIndex = entry.key;
      final point = entry.value;
      return Marker(
        markerId: MarkerId(pointIndex.toString()),
        position: point,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        draggable: true,
        onTap: () => _onMarkerTapped(pointIndex),
        onDragEnd: (newPosition) => _onMarkerDragEnd(pointIndex, newPosition),
      );
    }));
  }
  
  Widget _buildEditingControls() {
    if (_selectedZone == null) return const SizedBox.shrink();
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Editing: ${_selectedZone!.name}", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_selectedZone!.points.length < 3)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text('Add at least ${3 - _selectedZone!.points.length} more points.', style: const TextStyle(color: Colors.orange)),
                ),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(icon: const Icon(Icons.drive_file_rename_outline), label: const Text('Rename'), onPressed: _renameSelectedZone),
                  ElevatedButton.icon(icon: const Icon(Icons.color_lens_outlined), label: const Text('Color'), onPressed: _changeSelectedZoneColor),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever_outlined, color: Colors.white),
                    label: const Text('Delete Zone', style: TextStyle(color: Colors.white)),
                    onPressed: _deleteSelectedZone,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Functions ---
  List<LatLng> _parseWktPolygon(String wkt) {
    if (!wkt.contains('POLYGON')) return [];
    try {
      final content = wkt.substring(wkt.indexOf('((') + 2, wkt.lastIndexOf('))'));
      return content.split(',').map((pair) {
        final coords = pair.trim().split(' ');
        if (coords.length < 2) return null;
        return LatLng(double.parse(coords[1]), double.parse(coords[0]));
      }).whereType<LatLng>().toList();
    } catch (e) {
      debugPrint("Failed to parse WKT Polygon: $e");
      return [];
    }
  }

  String _wktFromPoints(List<LatLng> points) {
    if (points.length < 3) return 'POLYGON(())';
    final pointsString = points.map((p) => '${p.longitude} ${p.latitude}').join(', ');
    final firstPoint = '${points.first.longitude} ${points.first.latitude}';
    return 'POLYGON(($pointsString, $firstPoint))';
  }

  Color _colorFromHex(String hex) {
    hex = hex.toUpperCase().replaceAll("#", "");
    if (hex.length == 6) {
      hex = "FF$hex";
    }
    return Color(int.parse(hex, radix: 16));
  }
}
