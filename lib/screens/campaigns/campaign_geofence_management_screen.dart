// lib/screens/campaigns/campaign_geofence_management_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/campaign.dart';
import '../../models/campaign_geofence.dart';
import '../../services/campaign_geofence_service.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/modern_notification.dart';
import 'dart:async';

class CampaignGeofenceManagementScreen extends StatefulWidget {
  final Campaign campaign;

  const CampaignGeofenceManagementScreen({super.key, required this.campaign});

  @override
  State<CampaignGeofenceManagementScreen> createState() => _CampaignGeofenceManagementScreenState();
}

class _CampaignGeofenceManagementScreenState extends State<CampaignGeofenceManagementScreen> {
  final CampaignGeofenceService _geofenceService = CampaignGeofenceService();
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  
  late Future<List<CampaignGeofence>> _geofencesFuture;
  
  Set<Polygon> _polygons = {};
  Set<Marker> _markers = {};
  List<LatLng> _currentPolygonPoints = [];
  bool _isDrawingMode = false;
  bool _isSaving = false;
  CampaignGeofence? _selectedGeofence;

  // Form controllers for creating/editing geofences
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxAgentsController = TextEditingController(text: '5');
  Color _selectedColor = primaryColor;

  @override
  void initState() {
    super.initState();
    _loadGeofences();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxAgentsController.dispose();
    super.dispose();
  }

  void _loadGeofences() {
    setState(() {
      _geofencesFuture = _geofenceService.getAvailableGeofencesForCampaign(widget.campaign.id);
    });
    _updateMapPolygons();
  }

  Future<void> _updateMapPolygons() async {
    try {
      final geofences = await _geofenceService.getAvailableGeofencesForCampaign(widget.campaign.id);
      setState(() {
        _polygons = geofences.map((geofence) {
          final points = _parseWKTToLatLng(geofence.areaText);
          return Polygon(
            polygonId: PolygonId(geofence.id),
            points: points,
            strokeColor: geofence.color,
            strokeWidth: 2,
            fillColor: geofence.color.withValues(alpha: 0.3),
          );
        }).toSet();

        _markers = geofences.map((geofence) {
          final points = _parseWKTToLatLng(geofence.areaText);
          if (points.isNotEmpty) {
            final center = _calculateCenter(points);
            return Marker(
              markerId: MarkerId(geofence.id),
              position: center,
              infoWindow: InfoWindow(
                title: geofence.name,
                snippet: geofence.capacityText,
              ),
              onTap: () => _selectGeofence(geofence),
            );
          }
          return null;
        }).where((marker) => marker != null).cast<Marker>().toSet();
      });
    } catch (e) {
      debugPrint('Error updating map polygons: $e');
    }
  }

  List<LatLng> _parseWKTToLatLng(String wkt) {
    try {
      // Parse WKT POLYGON format: "POLYGON((lat lng, lat lng, ...))"
      final coordsStr = wkt.replaceAll(RegExp(r'POLYGON\(\(|\)\)'), '');
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

  String _latLngListToWKT(List<LatLng> points) {
    if (points.length < 3) return '';
    
    // Ensure polygon is closed
    final closedPoints = List<LatLng>.from(points);
    if (points.first.latitude != points.last.latitude || 
        points.first.longitude != points.last.longitude) {
      closedPoints.add(points.first);
    }
    
    final coords = closedPoints.map((point) => '${point.latitude} ${point.longitude}').join(', ');
    return 'POLYGON(($coords))';
  }

  LatLng _calculateCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    
    double lat = 0;
    double lng = 0;
    
    for (final point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }
    
    return LatLng(lat / points.length, lng / points.length);
  }

  void _selectGeofence(CampaignGeofence geofence) {
    setState(() {
      _selectedGeofence = geofence;
      _nameController.text = geofence.name;
      _descriptionController.text = geofence.description ?? '';
      _maxAgentsController.text = geofence.maxAgents.toString();
      _selectedColor = geofence.color;
    });
    _showGeofenceDetailsBottomSheet();
  }

  void _startDrawing() {
    setState(() {
      _isDrawingMode = true;
      _currentPolygonPoints.clear();
      _selectedGeofence = null;
      _nameController.clear();
      _descriptionController.clear();
      _maxAgentsController.text = '5';
      _selectedColor = primaryColor;
    });
    
    ModernNotification.info(
      context,
      message: 'Draw your work zone on the map',
      subtitle: 'Tap to add points, then use ✓ to finish drawing',
    );
  }

  void _cancelDrawing() {
    setState(() {
      _isDrawingMode = false;
      _currentPolygonPoints.clear();
    });
  }

  void _finishDrawing() {
    if (_currentPolygonPoints.length < 3) {
      ModernNotification.error(
        context,
        message: 'Need at least 3 points',
        subtitle: 'Add more points to create a valid geofence',
      );
      return;
    }

    setState(() {
      _isDrawingMode = false;
    });
    _showCreateGeofenceDialog();
  }

  void _onMapTapped(LatLng point) {
    if (!_isDrawingMode) return;

    setState(() {
      _currentPolygonPoints.add(point);
      
      // Update temporary polygon
      _polygons.removeWhere((polygon) => polygon.polygonId.value == 'temp');
      
      if (_currentPolygonPoints.length >= 3) {
        _polygons.add(Polygon(
          polygonId: const PolygonId('temp'),
          points: _currentPolygonPoints,
          strokeColor: _selectedColor,
          strokeWidth: 2,
          fillColor: _selectedColor.withValues(alpha: 0.3),
        ));
      }
      
      // Add markers for points
      _markers.removeWhere((marker) => marker.markerId.value.startsWith('temp_'));
      for (int i = 0; i < _currentPolygonPoints.length; i++) {
        _markers.add(Marker(
          markerId: MarkerId('temp_$i'),
          position: _currentPolygonPoints[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ));
      }
    });
  }

  Future<void> _createGeofence() async {
    if (_nameController.text.trim().isEmpty) {
      ModernNotification.error(context, message: 'Please enter a geofence name');
      return;
    }

    if (_currentPolygonPoints.length < 3) {
      ModernNotification.error(context, message: 'Please create a valid geofence polygon');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final wkt = _latLngListToWKT(_currentPolygonPoints);
      final maxAgents = int.tryParse(_maxAgentsController.text) ?? 5;

      await _geofenceService.createCampaignGeofence(
        campaignId: widget.campaign.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        areaText: wkt,
        maxAgents: maxAgents,
        color: '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      );

      ModernNotification.success(
        context,
        message: 'Geofence created successfully',
        subtitle: _nameController.text.trim(),
      );

      _loadGeofences();
      _clearForm();
      Navigator.of(context).pop();
    } catch (e) {
      ModernNotification.error(
        context,
        message: 'Failed to create geofence',
        subtitle: e.toString(),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _updateGeofence() async {
    if (_selectedGeofence == null) return;

    setState(() => _isSaving = true);

    try {
      final maxAgents = int.tryParse(_maxAgentsController.text) ?? 5;

      await _geofenceService.updateCampaignGeofence(
        geofenceId: _selectedGeofence!.id,
        name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        maxAgents: maxAgents,
        color: '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      );

      ModernNotification.success(
        context,
        message: 'Geofence updated successfully',
      );

      _loadGeofences();
      Navigator.of(context).pop();
    } catch (e) {
      ModernNotification.error(
        context,
        message: 'Failed to update geofence',
        subtitle: e.toString(),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteGeofence() async {
    if (_selectedGeofence == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Geofence'),
        content: Text('Are you sure you want to delete "${_selectedGeofence!.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: errorColor),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      await _geofenceService.deleteCampaignGeofence(_selectedGeofence!.id);

      ModernNotification.success(
        context,
        message: 'Geofence deleted successfully',
      );

      _loadGeofences();
      Navigator.of(context).pop();
    } catch (e) {
      ModernNotification.error(
        context,
        message: 'Failed to delete geofence',
        subtitle: e.toString(),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    setState(() {
      _currentPolygonPoints.clear();
      _selectedGeofence = null;
      _nameController.clear();
      _descriptionController.clear();
      _maxAgentsController.text = '5';
      _selectedColor = primaryColor;
      
      // Remove temporary polygons and markers
      _polygons.removeWhere((polygon) => polygon.polygonId.value == 'temp');
      _markers.removeWhere((marker) => marker.markerId.value.startsWith('temp_'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Work Zones - ${widget.campaign.name}'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isDrawingMode) ...[
            IconButton(
              onPressed: _cancelDrawing,
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
            ),
            IconButton(
              onPressed: _finishDrawing,
              icon: const Icon(Icons.check),
              tooltip: 'Finish Drawing',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (_isDrawingMode)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                border: Border(bottom: BorderSide(color: Colors.blue.withValues(alpha: 0.2))),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.touch_app, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap on the map to draw your work zone',
                          style: TextStyle(
                            color: Colors.blue[700], 
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Points: ${_currentPolygonPoints.length} (need at least 3 to create zone)',
                          style: TextStyle(color: Colors.blue[600], fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController.complete(controller);
              },
              onTap: _onMapTapped,
              polygons: _polygons,
              markers: _markers,
              initialCameraPosition: const CameraPosition(
                target: LatLng(24.7136, 46.6753), // Riyadh, Saudi Arabia
                zoom: 10,
              ),
              mapType: MapType.normal,
            ),
          ),
          _buildGeofencesList(),
        ],
      ),
    );
  }

  Widget _buildGeofencesList() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Work Zones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
              if (!_isDrawingMode)
                ElevatedButton.icon(
                  onPressed: _startDrawing,
                  icon: const Icon(Icons.add_location, size: 18),
                  label: const Text('Add Zone'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                )
              else
                Text(
                  '${_polygons.length} zones',
                  style: const TextStyle(
                    fontSize: 14,
                    color: textSecondaryColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<CampaignGeofence>>(
              future: _geofencesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final geofences = snapshot.data ?? [];
                if (geofences.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off, size: 32, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'No work zones created yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create work zones to define areas where agents will work',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _startDrawing,
                          icon: const Icon(Icons.add_location, size: 20),
                          label: const Text('Create First Zone'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: geofences.length,
                  itemBuilder: (context, index) {
                    final geofence = geofences[index];
                    return _buildGeofenceListItem(geofence);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeofenceListItem(CampaignGeofence geofence) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 40,
          decoration: BoxDecoration(
            color: geofence.color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        title: Text(
          geofence.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(geofence.capacityText),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: geofence.statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                geofence.statusText,
                style: TextStyle(
                  color: geofence.statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
        onTap: () => _selectGeofence(geofence),
      ),
    );
  }

  void _showCreateGeofenceDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGeofenceForm(isEditing: false),
    );
  }

  void _showGeofenceDetailsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGeofenceForm(isEditing: true),
    );
  }

  Widget _buildGeofenceForm({required bool isEditing}) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Work Zone' : 'Create Work Zone',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                  if (isEditing)
                    IconButton(
                      onPressed: _deleteGeofence,
                      icon: const Icon(Icons.delete),
                      color: errorColor,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Zone Name',
                  hintText: 'e.g., Zone A, Downtown Area, Building 1',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Brief description of this work area',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maxAgentsController,
                decoration: const InputDecoration(
                  labelText: 'Maximum Agents',
                  hintText: 'How many agents can work in this zone?',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people_outline),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Color: ', style: TextStyle(fontSize: 16)),
                  GestureDetector(
                    onTap: _showColorPicker,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : (isEditing ? _updateGeofence : _createGeofence),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEditing ? 'Update Work Zone' : 'Create Work Zone'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (Color color) {
              setState(() {
                _selectedColor = color;
              });
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}