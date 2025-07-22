// lib/screens/campaigns/campaign_geofence_management_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:geocoding/geocoding.dart';
import '../../models/campaign.dart';
import '../../models/campaign_geofence.dart';
import '../../services/campaign_geofence_service.dart';
import '../../services/location_service.dart';
import '../../utils/constants.dart';
import '../../widgets/modern_notification.dart';
import 'campaign_wizard_step2_screen.dart';
import 'dart:async';

class CampaignGeofenceManagementScreen extends StatefulWidget {
  final Campaign campaign;
  final List<TempGeofenceData>? tempGeofences;
  final Function(TempGeofenceData)? onTempGeofenceAdded;

  const CampaignGeofenceManagementScreen({
    super.key, 
    required this.campaign,
    this.tempGeofences,
    this.onTempGeofenceAdded,
  });

  @override
  State<CampaignGeofenceManagementScreen> createState() => _CampaignGeofenceManagementScreenState();
}

class _CampaignGeofenceManagementScreenState extends State<CampaignGeofenceManagementScreen> {
  final CampaignGeofenceService _geofenceService = CampaignGeofenceService();
  final LocationService _locationService = LocationService();
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  
  late Future<List<CampaignGeofence>> _geofencesFuture;
  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(33.2232, 43.6793), // Center of Iraq
    zoom: 6.5, // Show entire Iraq
  );
  
  Set<Polygon> _polygons = {};
  Set<Marker> _markers = {};
  List<LatLng> _currentPolygonPoints = [];
  bool _isDrawingMode = false;
  bool _isSaving = false;
  bool _isLocationLoading = false;
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
    _getCurrentLocationAndUpdateCamera();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxAgentsController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocationAndUpdateCamera() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        
        // Get city information from coordinates
        final cityInfo = await _getCityInfoFromLocation(position.latitude, position.longitude);
        
        // Create camera position for the city (not exact coordinates)
        final cityCameraPosition = CameraPosition(
          target: cityInfo['coordinates'] as LatLng,
          zoom: cityInfo['zoom'] as double,
        );
        
        // If map is already loaded, animate to the city
        if (_mapController.isCompleted) {
          final controller = await _mapController.future;
          controller.animateCamera(
            CameraUpdate.newCameraPosition(cityCameraPosition),
          );
          
          // Show notification with city name
          if (mounted) {
            ModernNotification.info(
              context,
              message: 'Map centered on ${cityInfo['city']}',
              subtitle: 'Create geofences around your city',
            );
          }
        } else {
          // Update initial position if map not loaded yet
          setState(() {
            _initialCameraPosition = cityCameraPosition;
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
      // Keep the default Iraq location if unable to get manager location
    }
  }

  // Get city information and optimal map view for the location
  Future<Map<String, dynamic>> _getCityInfoFromLocation(double latitude, double longitude) async {
    try {
      // Reverse geocoding to get address information
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final cityName = placemark.locality ?? 
                        placemark.subAdministrativeArea ?? 
                        placemark.administrativeArea ?? 
                        'Unknown City';
        
        debugPrint('🏙️ Detected city: $cityName');
        
        // Get optimized city view based on known Iraqi cities
        return _getOptimizedCityView(cityName, latitude, longitude);
      }
    } catch (e) {
      debugPrint('Error in reverse geocoding: $e');
    }
    
    // Fallback to exact coordinates with moderate zoom
    return {
      'city': 'Your Location',
      'coordinates': LatLng(latitude, longitude),
      'zoom': 14.0,
    };
  }

  // Get optimized map view for major Iraqi cities
  Map<String, dynamic> _getOptimizedCityView(String cityName, double lat, double lng) {
    // Iraqi cities with their optimal center coordinates and zoom levels
    final cityMap = <String, Map<String, dynamic>>{
      // Major cities
      'Baghdad': {'lat': 33.3152, 'lng': 44.3661, 'zoom': 11.0},
      'Basra': {'lat': 30.5088, 'lng': 47.7804, 'zoom': 12.0},
      'Mosul': {'lat': 36.3489, 'lng': 43.1189, 'zoom': 12.0},
      'Erbil': {'lat': 36.1900, 'lng': 44.0092, 'zoom': 12.0},
      'Sulaymaniyah': {'lat': 35.5528, 'lng': 45.4334, 'zoom': 12.0},
      'Kirkuk': {'lat': 35.4681, 'lng': 44.3922, 'zoom': 13.0},
      'Najaf': {'lat': 32.0000, 'lng': 44.3333, 'zoom': 13.0},
      'Karbala': {'lat': 32.6160, 'lng': 44.0242, 'zoom': 13.0},
      'Nasiriyah': {'lat': 31.0439, 'lng': 46.2593, 'zoom': 13.0},
      'Amarah': {'lat': 31.8365, 'lng': 47.1448, 'zoom': 13.0},
      'Diwaniyah': {'lat': 31.9929, 'lng': 44.9249, 'zoom': 13.0},
      'Kut': {'lat': 32.5126, 'lng': 45.8183, 'zoom': 13.0},
      'Hillah': {'lat': 32.4637, 'lng': 44.4199, 'zoom': 13.0},
      'Ramadi': {'lat': 33.4206, 'lng': 43.3058, 'zoom': 13.0},
      'Fallujah': {'lat': 33.3506, 'lng': 43.7881, 'zoom': 13.0},
      'Tikrit': {'lat': 34.5975, 'lng': 43.6817, 'zoom': 13.0},
      'Samarra': {'lat': 34.1989, 'lng': 43.8742, 'zoom': 13.0},
      'Dohuk': {'lat': 36.8617, 'lng': 42.9783, 'zoom': 13.0},
      'Zakho': {'lat': 37.1433, 'lng': 42.6838, 'zoom': 14.0},
    };
    
    // Check for exact city match (case insensitive)
    for (final entry in cityMap.entries) {
      if (cityName.toLowerCase().contains(entry.key.toLowerCase()) || 
          entry.key.toLowerCase().contains(cityName.toLowerCase())) {
        return {
          'city': entry.key,
          'coordinates': LatLng(entry.value['lat']!, entry.value['lng']!),
          'zoom': entry.value['zoom']!,
        };
      }
    }
    
    // If no specific city found, use a moderate zoom level on user coordinates
    return {
      'city': cityName,
      'coordinates': LatLng(lat, lng),
      'zoom': 13.0, // Good zoom level for most Iraqi cities
    };
  }

  void _loadGeofences() {
    setState(() {
      if (widget.tempGeofences != null) {
        // Working with temporary geofences during wizard
        _geofencesFuture = Future.value(widget.tempGeofences!.map((tempGeofence) {
          return CampaignGeofence(
            id: tempGeofence.id,
            campaignId: widget.campaign.id,
            name: tempGeofence.name,
            description: tempGeofence.description,
            areaText: tempGeofence.areaText,
            maxAgents: tempGeofence.maxAgents,
            color: Color(int.parse('0xFF${tempGeofence.color}') & 0xFFFFFFFF),
            isActive: true,
            currentAgents: 0,
            createdAt: DateTime.now(),
          );
        }).toList());
      } else {
        // Working with real geofences for existing campaign
        _geofencesFuture = _geofenceService.getAvailableGeofencesForCampaign(widget.campaign.id);
      }
    });
    _updateMapPolygons();
  }

  Future<void> _updateMapPolygons() async {
    try {
      final geofences = await _geofencesFuture;
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
      final colorHex = _selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2);

      if (widget.tempGeofences != null && widget.onTempGeofenceAdded != null) {
        // Working with temporary geofences during wizard
        final tempGeofence = TempGeofenceData(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          areaText: wkt,
          maxAgents: maxAgents,
          color: colorHex,
        );
        
        widget.onTempGeofenceAdded!(tempGeofence);
        
        ModernNotification.success(
          context,
          message: 'Geofence added to campaign',
          subtitle: _nameController.text.trim(),
        );
      } else {
        // Working with real geofences for existing campaign
        await _geofenceService.createCampaignGeofence(
          campaignId: widget.campaign.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          areaText: wkt,
          maxAgents: maxAgents,
          color: '#$colorHex',
        );

        ModernNotification.success(
          context,
          message: 'Geofence created successfully',
          subtitle: _nameController.text.trim(),
        );
      }

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

      if (widget.tempGeofences != null) {
        // Working with temporary geofences during wizard
        final tempIndex = widget.tempGeofences!.indexWhere((g) => g.id == _selectedGeofence!.id);
        if (tempIndex >= 0) {
          final updatedTempGeofence = TempGeofenceData(
            id: _selectedGeofence!.id,
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            areaText: _selectedGeofence!.areaText,
            maxAgents: maxAgents,
            color: _selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2),
          );
          widget.tempGeofences![tempIndex] = updatedTempGeofence;
        }
        
        ModernNotification.success(
          context,
          message: 'Geofence updated',
        );
      } else {
        // Working with real geofences for existing campaign
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
      }

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
      if (widget.tempGeofences != null) {
        // Working with temporary geofences during wizard
        widget.tempGeofences!.removeWhere((g) => g.id == _selectedGeofence!.id);
        
        ModernNotification.success(
          context,
          message: 'Geofence removed from campaign',
        );
      } else {
        // Working with real geofences for existing campaign
        await _geofenceService.deleteCampaignGeofence(_selectedGeofence!.id);

        ModernNotification.success(
          context,
          message: 'Geofence deleted successfully',
        );
      }

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

  Widget _buildFloatingActionButton() {
    // Calculate responsive bottom position based on panel height
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.3;
    final minHeight = 160.0;
    final bottomHeight = maxHeight.clamp(minHeight, 200.0);
    
    return Positioned(
      bottom: bottomHeight + 16, // Position above the bottom panel with padding
      right: 16,
      child: FloatingActionButton(
        onPressed: _centerOnManagerLocation,
        backgroundColor: Colors.blueAccent,
        child: _isLocationLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.my_location, color: Colors.white),
        tooltip: 'Center on my location',
      ),
    );
  }

  Future<void> _centerOnManagerLocation() async {
    setState(() => _isLocationLoading = true);
    
    try {
      final position = await _locationService.getCurrentLocation();
      
      if (position != null && mounted) {
        // Get city information from coordinates
        final cityInfo = await _getCityInfoFromLocation(position.latitude, position.longitude);
        
        final controller = await _mapController.future;
        
        // Create camera position for the city view
        final cityPosition = CameraPosition(
          target: cityInfo['coordinates'] as LatLng,
          zoom: cityInfo['zoom'] as double,
        );
        
        await controller.animateCamera(CameraUpdate.newCameraPosition(cityPosition));
        
        if (mounted) {
          ModernNotification.success(
            context,
            message: 'Centered on ${cityInfo['city']}',
            subtitle: 'Perfect view for creating city geofences',
          );
        }
      } else {
        if (mounted) {
          ModernNotification.error(
            context,
            message: 'Could not get your location',
            subtitle: 'Please check location permissions',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ModernNotification.error(
          context,
          message: 'Failed to get location',
          subtitle: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocationLoading = false);
      }
    }
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
      body: SafeArea(
        child: Stack(
          children: [
            Column(
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
                    initialCameraPosition: _initialCameraPosition,
                    mapType: MapType.normal,
                  ),
                ),
                _buildGeofencesList(),
              ],
            ),
            _buildFloatingActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildGeofencesList() {
    // Calculate responsive height - max 30% of screen height
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.3;
    final minHeight = 160.0; // Minimum height for usability
    final bottomHeight = maxHeight.clamp(minHeight, 200.0);
    
    return Container(
      height: bottomHeight,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), // Reduced bottom padding
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