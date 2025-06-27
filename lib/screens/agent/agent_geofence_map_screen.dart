// lib/screens/agent/agent_geofence_map_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/constants.dart';

class AgentGeofenceMapScreen extends StatefulWidget {
  const AgentGeofenceMapScreen({super.key});

  @override
  State<AgentGeofenceMapScreen> createState() => _AgentGeofenceMapScreenState();
}

class _AgentGeofenceMapScreenState extends State<AgentGeofenceMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  final PageController _pageController = PageController();
  
  bool _isLoading = true;
  List<GeofenceZone> _geofenceZones = [];
  int _currentZoneIndex = 0;
  final Set<Polygon> _polygons = {};

  @override
  void initState() {
    super.initState();
    _loadAgentGeofences();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAgentGeofences() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get campaigns assigned to this agent
      final userGroupsResponse = await supabase
          .from('user_groups')
          .select('group_id')
          .eq('user_id', userId);
      
      if (userGroupsResponse.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final groupIds = userGroupsResponse
          .map((item) => item['group_id'] as String)
          .toList();

      // Get campaigns for these groups
      final campaignsResponse = await supabase
          .from('campaigns')
          .select('''
            id, title, description, geofence_area_wkt,
            campaign_groups!inner(group_id)
          ''')
          .inFilter('campaign_groups.group_id', groupIds)
          .eq('status', 'active');

      final zones = <GeofenceZone>[];
      for (final campaign in campaignsResponse) {
        final wkt = campaign['geofence_area_wkt'] as String?;
        if (wkt != null && wkt.isNotEmpty) {
          final points = _parseWktPolygon(wkt);
          if (points.isNotEmpty) {
            zones.add(GeofenceZone(
              id: campaign['id'],
              title: campaign['title'] ?? 'Unnamed Campaign',
              description: campaign['description'] ?? '',
              points: points,
            ));
          }
        }
      }

      setState(() {
        _geofenceZones = zones;
        _isLoading = false;
        _updatePolygons();
      });

      if (zones.isNotEmpty) {
        _focusOnZone(0);
      }
    } catch (e) {
      debugPrint('Error loading agent geofences: $e');
      setState(() => _isLoading = false);
    }
  }

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

  void _updatePolygons() {
    _polygons.clear();
    for (int i = 0; i < _geofenceZones.length; i++) {
      final zone = _geofenceZones[i];
      final isSelected = i == _currentZoneIndex;
      
      _polygons.add(Polygon(
        polygonId: PolygonId(zone.id),
        points: zone.points,
        strokeColor: isSelected ? primaryColor : primaryColor.withValues(alpha: 0.6),
        strokeWidth: isSelected ? 3 : 2,
        fillColor: isSelected 
            ? primaryColor.withValues(alpha: 0.2)
            : primaryColor.withValues(alpha: 0.1),
      ));
    }
  }

  Future<void> _focusOnZone(int index) async {
    if (index >= 0 && index < _geofenceZones.length) {
      final zone = _geofenceZones[index];
      if (zone.points.isNotEmpty) {
        // Calculate bounds for the polygon
        double minLat = zone.points.first.latitude;
        double maxLat = zone.points.first.latitude;
        double minLng = zone.points.first.longitude;
        double maxLng = zone.points.first.longitude;

        for (final point in zone.points) {
          minLat = minLat < point.latitude ? minLat : point.latitude;
          maxLat = maxLat > point.latitude ? maxLat : point.latitude;
          minLng = minLng < point.longitude ? minLng : point.longitude;
          maxLng = maxLng > point.longitude ? maxLng : point.longitude;
        }

        final bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );

        final controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
      }
    }
  }

  void _onZoneChanged(int index) {
    setState(() {
      _currentZoneIndex = index;
      _updatePolygons();
    });
    _focusOnZone(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Campaign Zones',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        backgroundColor: surfaceColor,
      ),
      body: _isLoading
          ? preloader
          : _geofenceZones.isEmpty
              ? _buildEmptyState()
              : Stack(
                  children: [
                    // Map
                    GoogleMap(
                      mapType: MapType.normal,
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(33.3152, 44.3661),
                        zoom: 11,
                      ),
                      polygons: _polygons,
                      onMapCreated: (GoogleMapController controller) {
                        _mapController.complete(controller);
                        if (_geofenceZones.isNotEmpty) {
                          _focusOnZone(0);
                        }
                      },
                      // Performance optimizations
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      zoomControlsEnabled: false,
                      indoorViewEnabled: false,
                      trafficEnabled: false,
                      buildingsEnabled: false,
                      myLocationButtonEnabled: false,
                      myLocationEnabled: false,
                    ),
                    // Zone carousel at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildZoneCarousel(),
                    ),
                    // Zone counter at top
                    if (_geofenceZones.length > 1)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: _buildZoneCounter(),
                      ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.map_outlined,
              size: 60,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Campaign Zones',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'You are not assigned to any campaigns with geofenced zones yet.',
              style: TextStyle(
                fontSize: 16,
                color: textSecondaryColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${_currentZoneIndex + 1} / ${_geofenceZones.length}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildZoneCarousel() {
    return Container(
      height: 160,
      margin: const EdgeInsets.all(16),
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: _onZoneChanged,
        itemCount: _geofenceZones.length,
        itemBuilder: (context, index) {
          final zone = _geofenceZones[index];
          final isActive = index == _currentZoneIndex;
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.symmetric(
              horizontal: isActive ? 0 : 8,
              vertical: isActive ? 0 : 8,
            ),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isActive
                      ? primaryColor.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.1),
                  blurRadius: isActive ? 15 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isActive
                    ? primaryColor.withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor.withValues(alpha: 0.15),
                              primaryColor.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          zone.title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textPrimaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive)
                        Icon(
                          Icons.center_focus_strong,
                          color: primaryColor,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (zone.description.isNotEmpty)
                    Expanded(
                      child: Text(
                        zone.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondaryColor,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.layers,
                        size: 16,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Zone Area',
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class GeofenceZone {
  final String id;
  final String title;
  final String description;
  final List<LatLng> points;

  GeofenceZone({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
  });
}