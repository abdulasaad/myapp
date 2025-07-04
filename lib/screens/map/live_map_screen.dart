// lib/screens/map/live_map_screen.dart

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/constants.dart';

// --- DATA MODELS ---

class AgentMapInfo {
  final String id;
  final String fullName;
  final LatLng? lastLocation;
  final DateTime? lastSeen;
  final String? status;

  AgentMapInfo({
    required this.id,
    required this.fullName,
    this.lastLocation,
    this.lastSeen,
    this.status,
  });

  factory AgentMapInfo.fromJson(Map<String, dynamic> data) {
    LatLng? parsedLocation;
    if (data['last_location'] is String) {
      final pointString = data['last_location'] as String;
      final pointRegex = RegExp(r'POINT\(([-\d.]+) ([-\d.]+)\)');
      final match = pointRegex.firstMatch(pointString);
      if (match != null) {
        final lng = double.tryParse(match.group(1)!);
        final lat = double.tryParse(match.group(2)!);
        if (lat != null && lng != null) {
          parsedLocation = LatLng(lat, lng);
        }
      }
    }

    DateTime? parsedTime;
    if (data['last_seen'] is String) {
      parsedTime = DateTime.tryParse(data['last_seen']);
    }

    return AgentMapInfo(
      id: data['id'] ?? 'unknown_id_${DateTime.now()}',
      fullName: data['full_name'] ?? 'Unknown Agent',
      lastLocation: parsedLocation,
      lastSeen: parsedTime,
      status: data['status'] as String?,
    );
  }
}

class GeofenceInfo {
  final String id;
  final String name;
  final List<LatLng> points;

  GeofenceInfo({required this.id, required this.name, required this.points});
}


class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  Timer? _periodicTimer;

  bool _isLoading = true;
  bool _hasConnectivityIssue = false;
  
  final Map<String, AgentMapInfo> _agents = {};
  String? _selectedAgentId;
  String? _trackedAgentId; // Agent being actively tracked
  bool _isAgentPanelVisible = false;
  Set<String> _visibleAgentIds = {};
  bool _selectAllAgents = true;
  
  final List<GeofenceInfo> _geofences = [];
  bool _isGeofencePanelVisible = false;
  Set<String> _visibleGeofenceIds = {};
  bool _selectAllGeofences = true;

  final Set<Marker> _markers = {};
  final Set<Polygon> _polygons = {};
  
  // Custom marker icons
  BitmapDescriptor? _agentIconRed;
  BitmapDescriptor? _agentIconPurple;
  BitmapDescriptor? _agentIconBlue;
  BitmapDescriptor? _agentIconGreen;

  @override
  void initState() {
    super.initState();
    _initializeCustomMarkers();
    _initializeAndStartTimer();
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _initializeCustomMarkers() async {
    try {
      _agentIconRed = await _createAgentMarker(Colors.red);
      _agentIconPurple = await _createAgentMarker(Colors.purple);
      _agentIconBlue = await _createAgentMarker(Colors.blue);
      _agentIconGreen = await _createAgentMarker(Colors.green);
    } catch (e) {
      // Fallback to default markers if custom icons fail
      debugPrint('Failed to create custom markers: $e');
    }
  }
  
  Future<BitmapDescriptor> _createAgentMarker(Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 28.0;
    
    // Draw circle background
    final Paint circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, circlePaint);
    
    // Draw white border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 0.75, borderPaint);
    
    // Draw agent icon
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.person.codePoint),
        style: TextStyle(
          fontSize: 14,
          fontFamily: Icons.person.fontFamily,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );
    
    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();
    
    return BitmapDescriptor.bytes(pngBytes);
  }

  Future<void> _initializeAndStartTimer() async {
    await _fetchMapData();
    _periodicTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) _fetchMapData();
    });
  }

  /// Fetch agent locations with group filtering applied for managers
  Future<List> _fetchFilteredAgentLocations() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return [];

    try {
      // Get current user's role
      final userRoleResponse = await supabase
          .from('profiles')
          .select('role')
          .eq('id', currentUser.id)
          .single();
      
      final userRole = userRoleResponse['role'] as String;

      if (userRole == 'admin') {
        // Admins can see all agents
        return await supabase.rpc('get_agents_with_last_location');
      } else if (userRole == 'manager') {
        // Managers can only see agents in their shared groups
        // Get current manager's groups
        final userGroupsResponse = await supabase
            .from('user_groups')
            .select('group_id')
            .eq('user_id', currentUser.id);
        
        final userGroupIds = userGroupsResponse
            .map((item) => item['group_id'] as String)
            .toSet();
        
        if (userGroupIds.isEmpty) {
          // Manager not in any groups, can't see any agents
          return [];
        }

        // Get all agents in the same groups
        final agentGroupsResponse = await supabase
            .from('user_groups')
            .select('user_id')
            .inFilter('group_id', userGroupIds.toList());
        
        final agentIds = agentGroupsResponse
            .map((item) => item['user_id'] as String)
            .toSet();
        
        if (agentIds.isEmpty) {
          return [];
        }

        // Get agent location data for filtered agents
        final agentLocationData = await supabase.rpc('get_agents_with_last_location');
        
        // Filter the results to only include agents in the same groups
        return (agentLocationData as List).where((agentData) {
          final agentId = agentData['id'] as String?;
          return agentId != null && agentIds.contains(agentId);
        }).toList();
      } else {
        // Other roles (agents) typically don't access live map
        return [];
      }
    } catch (e) {
      debugPrint('Error filtering agent locations: $e');
      // Return empty list on error rather than throwing
      return [];
    }
  }

  Future<void> _fetchMapData() async {
    try {
      // Add timeout to prevent hanging
      final responses = await Future.wait([
        _fetchFilteredAgentLocations().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Agent location request timed out', const Duration(seconds: 10)),
        ),
        supabase.rpc('get_all_geofences_wkt').timeout(
          const Duration(seconds: 10), 
          onTimeout: () => throw TimeoutException('Geofences request timed out', const Duration(seconds: 10)),
        ),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Map data request timed out', const Duration(seconds: 15)),
      );

      if (!mounted) return;
      
      final agentResponse = responses[0] as List;
      final newAgentData = <String, AgentMapInfo>{};
      for (final data in agentResponse) {
        final agent = AgentMapInfo.fromJson(data.cast<String, dynamic>());
        newAgentData[agent.id] = agent;
      }

      final geofenceResponse = responses[1] as List;
      final newGeofenceData = <GeofenceInfo>[];
      for (final data in geofenceResponse) {
        final wkt = data['geofence_area_wkt'] as String?;
        if (wkt != null) {
          newGeofenceData.add(GeofenceInfo(
            id: data['geofence_id'],
            name: data['geofence_name'] ?? 'Unnamed Zone',
            points: _parseWktPolygon(wkt),
          ));
        }
      }

      setState(() {
        _agents.clear();
        _agents.addAll(newAgentData);
        _geofences.clear();
        _geofences.addAll(newGeofenceData);

        if (_selectAllAgents) _visibleAgentIds = _agents.keys.toSet();
        if (_selectAllGeofences) _visibleGeofenceIds = _geofences.map((g) => g.id).toSet();
        
        // Debug: Log agent data updates
        for (final agent in _agents.values) {
          if (agent.lastLocation != null) {
            debugPrint('📍 Agent ${agent.fullName}: ${agent.lastLocation} at ${agent.lastSeen}');
          }
        }
        
        _updateMarkers();
        _updatePolygons();
        
        // Auto-track the tracked agent if one is selected
        if (_trackedAgentId != null) {
          _autoTrackAgent();
        }
      });

      // Clear connectivity issue flag on successful data fetch
      if (mounted && _hasConnectivityIssue) {
        setState(() => _hasConnectivityIssue = false);
      }

    } catch (e) {
      debugPrint('Map data fetch error: $e');
      // Silently handle network errors - don't show error messages to user
      // Set connectivity issue flag and app will continue to retry on the next timer cycle
      if (mounted && !_hasConnectivityIssue) {
        setState(() => _hasConnectivityIssue = true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isAgentOnline(AgentMapInfo agent) {
    // First check explicit status from database
    if (agent.status != null) {
      return agent.status == 'active';
    }
    
    // Fallback to checking last seen timestamp
    if (agent.lastSeen == null) return false;
    
    final now = DateTime.now();
    final timeSinceLastSeen = now.difference(agent.lastSeen!);
    
    // Consider online if seen within last 15 minutes
    return timeSinceLastSeen.inMinutes < 15;
  }

  void _updateMarkers() {
    _markers.clear();
    for (final agent in _agents.values) {
      if (_visibleAgentIds.contains(agent.id) && agent.lastLocation != null) {
        BitmapDescriptor markerIcon;
        if (_trackedAgentId == agent.id) {
          // Tracked agent gets purple agent icon
          markerIcon = _agentIconPurple ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
          // Debug: Log tracked agent position
          debugPrint('🟣 Tracked agent ${agent.fullName} at ${agent.lastLocation} (${agent.lastSeen})');
        } else if (_selectedAgentId == agent.id) {
          // Selected agent gets blue agent icon
          markerIcon = _agentIconBlue ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
        } else {
          // Not selected - check online/offline status
          final isOnline = _isAgentOnline(agent);
          debugPrint('Agent ${agent.fullName}: status=${agent.status}, lastSeen=${agent.lastSeen}, isOnline=$isOnline');
          if (isOnline) {
            // Online agents get green icon
            markerIcon = _agentIconGreen ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
          } else {
            // Offline agents get red icon
            markerIcon = _agentIconRed ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
          }
        }
        
        _markers.add(
          Marker(
            markerId: MarkerId(agent.id),
            position: agent.lastLocation!,
            infoWindow: InfoWindow(
              title: agent.fullName,
              snippet: 'Last seen: ${agent.lastSeen?.toString().substring(11, 16) ?? 'Unknown'}',
            ),
            icon: markerIcon,
            onTap: () => _onAgentTapped(agent),
          )
        );
      }
    }
    setState(() {});
  }
  
  void _updatePolygons() {
    _polygons.clear();
    for (final geofence in _geofences) {
      if (_visibleGeofenceIds.contains(geofence.id)) {
        _polygons.add(Polygon(
          polygonId: PolygonId(geofence.id),
          points: geofence.points,
          strokeColor: Colors.amber,
          strokeWidth: 2,
          // ===================================================================
          // THE FIX: Replaced deprecated withOpacity with withAlpha
          // ===================================================================
          fillColor: Colors.amber.withAlpha(38), // 0.15 opacity
        ));
      }
    }
    setState(() {});
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

  Future<void> _onAgentTapped(AgentMapInfo agent) async {
    setState(() {
      _selectedAgentId = agent.id; // Always select the agent when tapped
      _updateMarkers();
    });

    if (agent.lastLocation != null) {
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(agent.lastLocation!, 15.0));
    }
  }

  Future<void> _startTrackingAgent(AgentMapInfo agent) async {
    setState(() {
      _trackedAgentId = agent.id;
      _selectedAgentId = agent.id;
      
      // Automatically make the agent visible if not already selected
      if (!_visibleAgentIds.contains(agent.id)) {
        _visibleAgentIds.add(agent.id);
      }
      
      _isAgentPanelVisible = false; // Close the panel
      _isGeofencePanelVisible = false;
      _updateMarkers();
    });

    if (agent.lastLocation != null) {
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(agent.lastLocation!, 15.0));
      if (mounted) {
        context.showSnackBar('Now tracking ${agent.fullName}');
      }
    } else {
      if (mounted) {
        context.showSnackBar('${agent.fullName} has no location on record.', isError: true);
      }
    }
  }

  Future<void> _autoTrackAgent() async {
    if (_trackedAgentId == null) return;
    
    final trackedAgent = _agents[_trackedAgentId];
    if (trackedAgent?.lastLocation != null) {
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLng(trackedAgent!.lastLocation!));
    }
  }

  String _getCalculatedStatus(DateTime? lastSeen) {
    if (lastSeen == null) return 'Offline';
    final difference = DateTime.now().difference(lastSeen);
    if (difference.inSeconds <= 45) return 'Active';
    if (difference.inMinutes < 15) return 'Away';
    return 'Offline';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Map'),
        actions: [
          if (_hasConnectivityIssue)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                Icons.wifi_off,
                color: Colors.orange[300],
                size: 20,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? preloader
          : Stack(
              children: [
                GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: const CameraPosition(target: LatLng(33.3152, 44.3661), zoom: 11),
                  markers: _markers,
                  polygons: _polygons,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController.complete(controller);
                  },
                  onTap: (_) {
                    if (_isAgentPanelVisible || _isGeofencePanelVisible) {
                      setState(() {
                        _isAgentPanelVisible = false;
                        _isGeofencePanelVisible = false;
                      });
                    } else if (_trackedAgentId != null) {
                      // Stop tracking when map is tapped
                      setState(() {
                        _trackedAgentId = null;
                        _updateMarkers();
                      });
                      if (mounted) {
                        context.showSnackBar('Stopped tracking agent');
                      }
                    } else if (_selectedAgentId != null) {
                      // Deselect agent when tapping empty area of map
                      setState(() {
                        _selectedAgentId = null;
                        _updateMarkers();
                      });
                    }
                  },
                  // Performance optimizations for mobile devices
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  zoomControlsEnabled: false,
                  indoorViewEnabled: false,
                  trafficEnabled: false,
                  buildingsEnabled: false,
                  myLocationButtonEnabled: false, // We have custom controls
                  myLocationEnabled: false, // Focus on agent tracking
                  // Reduce memory usage for non-essential features
                  polylines: const <Polyline>{},
                  circles: const <Circle>{},
                ),
                // Left Panel (Agents)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  left: _isAgentPanelVisible ? 0 : -260,
                  top: 0, 
                  bottom: 0,
                  width: 250,
                  child: _buildAgentListPanel(),
                ),
                // Right Panel (Geofences)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  right: _isGeofencePanelVisible ? 0 : -260,
                  top: 0,
                  bottom: 0,
                  width: 250,
                  child: _buildGeofenceListPanel(),
                ),
                // Left Toggle Button
                if (!_isAgentPanelVisible)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: FloatingActionButton(
                      mini: true,
                      heroTag: 'agent-fab',
                      onPressed: () => setState(() {
                        _isGeofencePanelVisible = false;
                        _isAgentPanelVisible = true;
                      }),
                      tooltip: 'Show Agent List',
                      child: const Icon(Icons.people_alt_outlined),
                    ),
                  ),
                
                // Right Toggle Button
                if (!_isGeofencePanelVisible)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      heroTag: 'geofence-fab',
                      backgroundColor: Colors.amber,
                      onPressed: () => setState(() {
                        _isAgentPanelVisible = false;
                        _isGeofencePanelVisible = true;
                      }),
                      tooltip: 'Show Geofences',
                      child: const Icon(Icons.layers_outlined),
                    ),
                  ),
                
                // Stop Tracking Button
                if (_trackedAgentId != null && !_isAgentPanelVisible && !_isGeofencePanelVisible)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      heroTag: 'stop-tracking-fab',
                      backgroundColor: Colors.purple,
                      onPressed: () {
                        final trackedAgentName = _agents[_trackedAgentId]?.fullName ?? 'Agent';
                        setState(() {
                          _trackedAgentId = null;
                          _updateMarkers();
                        });
                        if (mounted) {
                          context.showSnackBar('Stopped tracking $trackedAgentName');
                        }
                      },
                      tooltip: 'Stop Tracking',
                      child: const Icon(Icons.location_off, color: Colors.white),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildAgentListPanel() {
    final agentList = _agents.values.toList();
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Material(
          elevation: 12,
          borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              // ===================================================================
              // THE FIX: Replaced deprecated withOpacity with withAlpha
              // ===================================================================
              color: Theme.of(context).scaffoldBackgroundColor.withAlpha(242), // 0.95 opacity
              borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text('Agents List', style: Theme.of(context).textTheme.titleLarge),
                ),
                CheckboxListTile(
                  title: const Text('Select All'),
                  value: _selectAllAgents,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (bool? value) {
                    setState(() {
                      _selectAllAgents = value ?? false;
                      if (_selectAllAgents) {
                        _visibleAgentIds = _agents.keys.toSet();
                      } else {
                        _visibleAgentIds.clear();
                      }
                      _updateMarkers();
                    });
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Expanded(
                  child: agentList.isEmpty
                      ? const Center(child: Text('No agents found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8),
                          itemCount: agentList.length,
                          itemBuilder: (context, index) {
                            final agent = agentList[index];
                            final status = _getCalculatedStatus(agent.lastSeen);
                            Color statusColor;
                            switch (status) {
                              case 'Active': statusColor = Colors.green; break;
                              case 'Away': statusColor = Colors.orange; break;
                              default: statusColor = Colors.grey;
                            }

                            return Container(
                              decoration: _trackedAgentId == agent.id 
                                  ? BoxDecoration(
                                      color: Colors.purple.withAlpha(51), // 0.2 opacity
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : null,
                              child: Row(
                                children: [
                                  // Checkbox for selection
                                  Checkbox(
                                    value: _visibleAgentIds.contains(agent.id),
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _visibleAgentIds.add(agent.id);
                                        } else {
                                          _visibleAgentIds.remove(agent.id);
                                        }
                                        if (_visibleAgentIds.length < _agents.length) {
                                          _selectAllAgents = false;
                                        } else {
                                          _selectAllAgents = true;
                                        }
                                        _updateMarkers();
                                      });
                                    },
                                  ),
                                  // Clickable agent info (name tap navigates to agent)
                                  Expanded(
                                    child: ListTile(
                                      dense: true,
                                      leading: CircleAvatar(backgroundColor: statusColor, radius: 5),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              agent.fullName, 
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                          if (_trackedAgentId == agent.id)
                                            const Icon(
                                              Icons.my_location,
                                              color: Colors.purple,
                                              size: 16,
                                            ),
                                        ],
                                      ),
                                      subtitle: Text(status, style: const TextStyle(fontSize: 12)),
                                      onTap: () => _startTrackingAgent(agent),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildGeofenceListPanel() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Material(
          elevation: 12,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              // ===================================================================
              // THE FIX: Replaced deprecated withOpacity with withAlpha
              // ===================================================================
              color: Theme.of(context).scaffoldBackgroundColor.withAlpha(242), // 0.95 opacity
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text('Geofences', style: Theme.of(context).textTheme.titleLarge),
                ),
                CheckboxListTile(
                  title: const Text('Select All'),
                  value: _selectAllGeofences,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (bool? value) {
                    setState(() {
                      _selectAllGeofences = value ?? false;
                      if (_selectAllGeofences) {
                        _visibleGeofenceIds = _geofences.map((g) => g.id).toSet();
                      } else {
                        _visibleGeofenceIds.clear();
                      }
                      _updatePolygons();
                    });
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Expanded(
                  child: _geofences.isEmpty
                      ? const Center(child: Text('No geofences found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8),
                          itemCount: _geofences.length,
                          itemBuilder: (context, index) {
                            final geofence = _geofences[index];
                            return CheckboxListTile(
                              secondary: Icon(Icons.layers_outlined, color: Colors.amber[700]),
                              title: Text(geofence.name, style: const TextStyle(fontSize: 14)),
                              value: _visibleGeofenceIds.contains(geofence.id),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _visibleGeofenceIds.add(geofence.id);
                                  } else {
                                    _visibleGeofenceIds.remove(geofence.id);
                                  }
                                  if (_visibleGeofenceIds.length < _geofences.length) {
                                    _selectAllGeofences = false;
                                  } else {
                                    _selectAllGeofences = true;
                                  }
                                  _updatePolygons();
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
