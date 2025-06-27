// lib/screens/tasks/task_geofence_editor_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';
import '../../services/location_service.dart';

// GeofenceZone model for multiple geofences
class GeofenceZone {
  String id;
  String name;
  List<LatLng> points;
  Color color;
  final bool isNew;

  GeofenceZone({
    required this.id,
    required this.name,
    required this.points,
    required this.color,
    this.isNew = false,
  });

  factory GeofenceZone.create(String name, Color color) {
    return GeofenceZone(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      points: [],
      color: color,
      isNew: true,
    );
  }
}

class TaskGeofenceEditorScreen extends StatefulWidget {
  final Task task;
  const TaskGeofenceEditorScreen({super.key, required this.task});

  @override
  State<TaskGeofenceEditorScreen> createState() => _TaskGeofenceEditorScreenState();
}

class _TaskGeofenceEditorScreenState extends State<TaskGeofenceEditorScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  
  final List<GeofenceZone> _zones = [];
  String? _selectedZoneId;
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Default camera position - will be updated with admin location
  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(24.7136, 46.6753), // Fallback to Riyadh coordinates
    zoom: 15,
  );
  
  // Available colors for zones
  final List<Color> _availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    _initializeMapLocation();
    _loadExistingGeofences();
  }
  
  // Initialize map with admin's current location
  Future<void> _initializeMapLocation() async {
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();
      
      if (position != null && mounted) {
        setState(() {
          _initialCameraPosition = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          );
        });
        
        // If map is already created, animate to the new location
        if (_mapController.isCompleted) {
          final controller = await _mapController.future;
          await controller.animateCamera(
            CameraUpdate.newCameraPosition(_initialCameraPosition),
          );
        }
      }
    } catch (e) {
      debugPrint('[GeofenceEditor] Failed to get admin location: $e');
      // Keep the default Riyadh coordinates as fallback
    }
  }

  // --- Data Loading & Saving ---

  Future<void> _loadExistingGeofences() async {
    try {
      debugPrint("[GeofenceLoad] Loading geofences for task_id: ${widget.task.id}");
      
      final response = await supabase
          .from('geofences')
          .select('*')
          .eq('task_id', widget.task.id);
      
      debugPrint("[GeofenceLoad] Found ${response.length} geofences");

      if (response.isNotEmpty) {
        for (int i = 0; i < response.length; i++) {
          try {
            final data = response[i];
            if (data.isEmpty) continue;
            
            final wktString = data['area_text'] as String? ?? data['area'] as String?;
            if (wktString != null && wktString.isNotEmpty) {
              final points = _parseWktPolygon(wktString);
              if (points.isNotEmpty) {
                final colorIndex = _zones.length % _availableColors.length;
                final fallbackColor = _availableColors[colorIndex];
                
                final zone = GeofenceZone(
                  id: data['id']?.toString() ?? 'zone_$i',
                  name: data['name']?.toString() ?? 'Geofence ${_zones.length + 1}',
                  points: points,
                  color: _colorFromHex(data['color']?.toString()) ?? fallbackColor,
                );
                _zones.add(zone);
                
                // Select the first zone by default
                _selectedZoneId ??= zone.id;
                
                debugPrint("[GeofenceLoad] Successfully loaded zone: ${zone.name}");
              }
            }
          } catch (parseError) {
            debugPrint("[GeofenceLoad] Error parsing geofence at index $i: $parseError");
            // Continue with other geofences
            continue;
          }
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
      
      debugPrint("[GeofenceLoad] Finished loading. Total zones: ${_zones.length}");
    } catch (e) {
      debugPrint("[GeofenceLoad] Critical error loading geofences: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        // Don't show error to user, just log it
      }
    }
  }

  Future<void> _saveAllGeofences() async {
    if (_isSaving) return;
    
    setState(() => _isSaving = true);
    
    try {
      debugPrint("[GeofenceSave] Saving ${_zones.length} zones for task ${widget.task.id}");
      
      // Delete existing geofences for this task
      await supabase
          .from('geofences')
          .delete()
          .eq('task_id', widget.task.id);
      
      // Save all valid zones
      final validZones = _zones.where((zone) => zone.points.length >= 3).toList();
      
      for (final zone in validZones) {
        final wktPoints = zone.points.map((p) => '${p.longitude} ${p.latitude}').toList();
        wktPoints.add('${zone.points.first.longitude} ${zone.points.first.latitude}');
        final wktString = 'POLYGON((${wktPoints.join(', ')}))';
        
        // Use the new RPC function to handle PostGIS conversion
        await supabase.rpc('insert_task_geofence', params: {
          'task_id_param': widget.task.id,
          'geofence_name': zone.name,
          'wkt_polygon': wktString,
        });
        
        // Also store the color
        await supabase
            .from('geofences')
            .update({'color': _colorToHex(zone.color)})
            .eq('task_id', widget.task.id)
            .eq('name', zone.name);
      }
      
      if (mounted) {
        context.showSnackBar('${validZones.length} geofence(s) saved successfully!');
        Navigator.of(context).pop();
      }
      
    } catch (e) {
      debugPrint("[GeofenceSave] Error saving geofences: $e");
      if (mounted) {
        context.showSnackBar('Error saving geofences: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // --- Zone Management ---

  void _addNewZone() {
    final newZone = GeofenceZone.create(
      'Zone ${_zones.length + 1}',
      _availableColors[_zones.length % _availableColors.length],
    );
    
    setState(() {
      _zones.add(newZone);
      _selectedZoneId = newZone.id;
    });
  }

  void _deleteSelectedZone() {
    if (_selectedZoneId == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Zone'),
        content: const Text('Are you sure you want to delete this geofence zone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _zones.removeWhere((zone) => zone.id == _selectedZoneId);
                _selectedZoneId = _zones.isNotEmpty ? _zones.first.id : null;
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _renameSelectedZone() {
    if (_selectedZoneId == null) return;
    
    final zone = _zones.firstWhere((z) => z.id == _selectedZoneId);
    final controller = TextEditingController(text: zone.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Zone'),
        content: TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Zone Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  zone.name = controller.text.trim();
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _changeSelectedZoneColor() {
    if (_selectedZoneId == null) return;
    
    final zone = _zones.firstWhere((z) => z.id == _selectedZoneId);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Zone Color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableColors.map((color) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  zone.color = color;
                });
                Navigator.pop(context);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: zone.color == color ? Colors.black : Colors.grey,
                    width: zone.color == color ? 3 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _clearSelectedZone() {
    if (_selectedZoneId == null) return;
    
    final zone = _zones.firstWhere((z) => z.id == _selectedZoneId);
    setState(() {
      zone.points.clear();
    });
  }

  // --- Map Interaction ---

  void _onMapTapped(LatLng point) {
    if (_selectedZoneId == null) return;
    
    final zone = _zones.firstWhere((z) => z.id == _selectedZoneId);
    setState(() {
      zone.points.add(point);
    });
  }

  // --- Helper Methods ---

  List<LatLng> _parseWktPolygon(String wkt) {
    try {
      if (wkt.isEmpty || wkt.length > 10000) {
        debugPrint("WKT string is empty or too large: ${wkt.length} chars");
        return [];
      }
      
      // Parse POLYGON((lng lat, lng lat, ...))
      final coordsMatch = RegExp(r'POLYGON\s*\(\s*\(([^)]+)\)\s*\)').firstMatch(wkt);
      if (coordsMatch == null) {
        debugPrint("No valid POLYGON format found in: ${wkt.substring(0, wkt.length > 100 ? 100 : wkt.length)}...");
        return [];
      }
      
      final coordsString = coordsMatch.group(1)!;
      final coordPairs = coordsString.split(',');
      
      // Limit number of points to prevent memory issues
      if (coordPairs.length > 1000) {
        debugPrint("Too many coordinate pairs: ${coordPairs.length}, limiting to 1000");
        coordPairs.removeRange(1000, coordPairs.length);
      }
      
      final points = <LatLng>[];
      for (int i = 0; i < coordPairs.length; i++) {
        try {
          final coords = coordPairs[i].trim().split(RegExp(r'\s+'));
          if (coords.length >= 2) {
            final lng = double.tryParse(coords[0]);
            final lat = double.tryParse(coords[1]);
            if (lng != null && lat != null && 
                lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
              points.add(LatLng(lat, lng));
            }
          }
        } catch (coordError) {
          debugPrint("Error parsing coordinate pair $i: $coordError");
          continue;
        }
      }
      
      // Remove the last point if it's the same as the first (closing polygon)
      if (points.length > 3 && 
          (points.first.latitude - points.last.latitude).abs() < 0.000001 && 
          (points.first.longitude - points.last.longitude).abs() < 0.000001) {
        points.removeLast();
      }
      
      debugPrint("Successfully parsed ${points.length} points from WKT");
      return points;
    } catch (e) {
      debugPrint("Critical error parsing WKT: $e");
      return [];
    }
  }

  Color? _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    
    try {
      final hexString = hex.replaceAll('#', '');
      if (hexString.length == 6) {
        final colorValue = int.parse('FF$hexString', radix: 16);
        return Color(colorValue);
      } else if (hexString.length == 8) {
        final colorValue = int.parse(hexString, radix: 16);
        return Color(colorValue);
      }
      return null;
    } catch (e) {
      debugPrint("[ColorParse] Error parsing color '$hex': $e");
      return null;
    }
  }

  String _colorToHex(Color color) {
    final red = color.r.round().toRadixString(16).padLeft(2, '0');
    final green = color.g.round().toRadixString(16).padLeft(2, '0');
    final blue = color.b.round().toRadixString(16).padLeft(2, '0');
    return '#$red$green$blue'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Geofences - ${widget.task.title}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _zones.isNotEmpty ? _saveAllGeofences : null,
            icon: _isSaving 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save),
            tooltip: 'Save All Geofences',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Google Map
                GoogleMap(
                  onMapCreated: (controller) async {
                    _mapController.complete(controller);
                    // If admin location was loaded after map creation, animate to it
                    if (_initialCameraPosition.target.latitude != 24.7136 || 
                        _initialCameraPosition.target.longitude != 46.6753) {
                      await controller.animateCamera(
                        CameraUpdate.newCameraPosition(_initialCameraPosition),
                      );
                    }
                  },
                  onTap: _onMapTapped,
                  initialCameraPosition: _initialCameraPosition,
                  polygons: _zones.map((zone) {
                    final isSelected = zone.id == _selectedZoneId;
                    return Polygon(
                      polygonId: PolygonId(zone.id),
                      points: zone.points,
                      strokeWidth: isSelected ? 3 : 2,
                      strokeColor: zone.color,
                      fillColor: zone.color.withValues(alpha: isSelected ? 0.3 : 0.2),
                      onTap: () => setState(() => _selectedZoneId = zone.id),
                    );
                  }).toSet(),
                  markers: _selectedZoneId != null 
                      ? _zones.firstWhere((z) => z.id == _selectedZoneId).points.asMap().entries.map((entry) {
                          return Marker(
                            markerId: MarkerId('point_${entry.key}'),
                            position: entry.value,
                            infoWindow: InfoWindow(title: 'Point ${entry.key + 1}'),
                          );
                        }).toSet()
                      : {},
                ),

                // Zone List Sidebar
                if (_zones.isNotEmpty)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      width: 220,
                      constraints: const BoxConstraints(maxHeight: 300),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Geofence Zones',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_zones.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _zones.length,
                              itemBuilder: (context, index) {
                                final zone = _zones[index];
                                final isSelected = zone.id == _selectedZoneId;
                                
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? zone.color.withValues(alpha: 0.1) : null,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected ? Border.all(color: zone.color, width: 2) : null,
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: zone.color,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    title: Text(
                                      zone.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${zone.points.length} points',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    onTap: () => setState(() => _selectedZoneId = zone.id),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Instructions Panel
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _selectedZoneId != null 
                              ? 'Tap on map to add points to selected zone'
                              : 'Create a zone first',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Controls Panel
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Zone management buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _addNewZone,
                                icon: const Icon(Icons.add_location, size: 18),
                                label: const Text('Add Zone'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
                              ),
                            ),
                            if (_selectedZoneId != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _renameSelectedZone,
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Rename'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[100],
                                    foregroundColor: Colors.grey[700],
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        
                        if (_selectedZoneId != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _changeSelectedZoneColor,
                                  icon: const Icon(Icons.color_lens, size: 18),
                                  label: const Text('Color'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _clearSelectedZone,
                                  icon: const Icon(Icons.clear, size: 18),
                                  label: const Text('Clear'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _deleteSelectedZone,
                                  icon: const Icon(Icons.delete, size: 18),
                                  label: const Text('Delete'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Status info
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _zones.any((z) => z.points.length >= 3) 
                                    ? Icons.check_circle 
                                    : Icons.warning,
                                size: 16,
                                color: _zones.any((z) => z.points.length >= 3) 
                                    ? Colors.green 
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _zones.isEmpty
                                      ? 'No zones created yet'
                                      : _zones.any((z) => z.points.length >= 3)
                                          ? '${_zones.where((z) => z.points.length >= 3).length} valid zone(s) ready to save'
                                          : 'Add at least 3 points to each zone',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}