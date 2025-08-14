// lib/screens/agent/agent_route_map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/constants.dart';
import '../../models/route_assignment.dart';
import '../../models/place_visit.dart';
import '../../models/route_place.dart';
import '../../services/location_service.dart';
import '../../widgets/modern_notification.dart';

class AgentRouteMapScreen extends StatefulWidget {
  final List<RoutePlace> routePlaces;
  final RouteAssignment routeAssignment;
  final Map<String, PlaceVisit?> placeVisits;

  const AgentRouteMapScreen({
    super.key,
    required this.routePlaces,
    required this.routeAssignment,
    required this.placeVisits,
  });

  @override
  State<AgentRouteMapScreen> createState() => _AgentRouteMapScreenState();
}

class _AgentRouteMapScreenState extends State<AgentRouteMapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  int _selectedPlaceIndex = -1;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();
      
      setState(() {
        _currentPosition = position;
      });

      if (position != null) {
        _centerOnLocation(LatLng(position.latitude, position.longitude));
      } else {
        _fitAllPlaces();
      }
    } catch (e) {
      _fitAllPlaces();
    }
  }

  void _centerOnLocation(LatLng location) {
    _mapController.move(location, 15.0);
  }

  void _fitAllPlaces() {
    if (widget.routePlaces.isEmpty) return;

    final places = widget.routePlaces.where((rp) => rp.place != null).toList();
    if (places.isEmpty) return;

    final latitudes = places.map((rp) => rp.place!.latitude).toList();
    final longitudes = places.map((rp) => rp.place!.longitude).toList();

    if (_currentPosition != null) {
      latitudes.add(_currentPosition!.latitude);
      longitudes.add(_currentPosition!.longitude);
    }

    final minLat = latitudes.reduce((a, b) => a < b ? a : b);
    final maxLat = latitudes.reduce((a, b) => a > b ? a : b);
    final minLng = longitudes.reduce((a, b) => a < b ? a : b);
    final maxLng = longitudes.reduce((a, b) => a > b ? a : b);

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('${widget.routeAssignment.route?.name ?? 'Route'} Map'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentPosition != null)
            IconButton(
              onPressed: () => _centerOnLocation(LatLng(_currentPosition!.latitude, _currentPosition!.longitude)),
              icon: const Icon(Icons.my_location),
              tooltip: 'Center on my location',
            ),
          IconButton(
            onPressed: _fitAllPlaces,
            icon: const Icon(Icons.fit_screen),
            tooltip: 'Fit all places',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition != null 
                    ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                    : widget.routePlaces.isNotEmpty && widget.routePlaces.first.place != null
                        ? LatLng(widget.routePlaces.first.place!.latitude, widget.routePlaces.first.place!.longitude)
                        : const LatLng(33.3152, 44.3661), // Baghdad default
                initialZoom: 13.0,
                onTap: (tapPosition, point) {
                  setState(() {
                    _selectedPlaceIndex = -1;
                  });
                },
              ),
              children: [
                // Base map tiles
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.myapp',
                ),
                
                // Route line connecting places
                if (widget.routePlaces.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: widget.routePlaces
                            .where((rp) => rp.place != null)
                            .map((rp) => LatLng(rp.place!.latitude, rp.place!.longitude))
                            .toList(),
                        strokeWidth: 3.0,
                        color: primaryColor.withValues(alpha: 0.7),
                        isDotted: true,
                      ),
                    ],
                  ),

                // Place markers
                MarkerLayer(
                  markers: _buildPlaceMarkers(),
                ),

                // Current location marker
                if (_currentPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Bottom place info panel
          if (_selectedPlaceIndex >= 0 && _selectedPlaceIndex < widget.routePlaces.length)
            _buildPlaceInfoPanel(widget.routePlaces[_selectedPlaceIndex]),
        ],
      ),
    );
  }

  List<Marker> _buildPlaceMarkers() {
    List<Marker> markers = [];
    
    for (int i = 0; i < widget.routePlaces.length; i++) {
      final routePlace = widget.routePlaces[i];
      final place = routePlace.place;
      
      if (place == null) continue;

      final visit = widget.placeVisits[routePlace.placeId];
      final completedVisitsCount = widget.placeVisits.values
          .where((v) => v != null && v.placeId == routePlace.placeId && v.status == 'completed')
          .length;
      
      Color markerColor;
      IconData markerIcon;
      
      if (completedVisitsCount >= routePlace.visitFrequency) {
        markerColor = Colors.green;
        markerIcon = Icons.check_circle;
      } else if (visit?.status == 'checked_in') {
        markerColor = Colors.blue;
        markerIcon = Icons.access_time;
      } else {
        markerColor = Colors.orange;
        markerIcon = Icons.location_on;
      }

      markers.add(
        Marker(
          point: LatLng(place.latitude, place.longitude),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedPlaceIndex = i;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      markerIcon,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: markerColor, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: markerColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildPlaceInfoPanel(RoutePlace routePlace) {
    final place = routePlace.place;
    final visit = widget.placeVisits[routePlace.placeId];
    final completedVisitsCount = widget.placeVisits.values
        .where((v) => v != null && v.placeId == routePlace.placeId && v.status == 'completed')
        .length;
    final isCompleted = completedVisitsCount >= routePlace.visitFrequency;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green : visit?.status == 'checked_in' ? Colors.blue : Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${_selectedPlaceIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place?.name ?? 'Unknown Place',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimaryColor,
                      ),
                    ),
                    if (place?.address?.isNotEmpty == true)
                      Text(
                        place!.address!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: textSecondaryColor,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _navigateToPlace(routePlace),
                icon: const Icon(Icons.directions),
                tooltip: 'Get directions',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(
                Icons.access_time,
                '${routePlace.estimatedDurationMinutes} min',
                Colors.blue,
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                Icons.camera_alt,
                '${routePlace.requiredEvidenceCount} photos',
                Colors.green,
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                Icons.repeat,
                '$completedVisitsCount/${routePlace.visitFrequency} visits',
                isCompleted ? Colors.green : Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPlace(RoutePlace routePlace) {
    if (routePlace.place == null) return;
    
    final place = routePlace.place!;
    
    // Show coordinates for navigation
    ModernNotification.info(
      context,
      message: 'Navigate to ${place.name}',
      subtitle: 'Lat: ${place.latitude.toStringAsFixed(6)}, Lng: ${place.longitude.toStringAsFixed(6)}',
    );
  }
}