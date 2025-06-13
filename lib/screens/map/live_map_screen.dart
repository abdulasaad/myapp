// lib/screens/map/live_map_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/constants.dart';

// --- DATA MODELS ---

class AgentMapInfo {
  final String id;
  final String fullName;
  final LatLng? lastLocation;
  final DateTime? lastSeen;

  AgentMapInfo({
    required this.id,
    required this.fullName,
    this.lastLocation,
    this.lastSeen,
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
  
  final Map<String, AgentMapInfo> _agents = {};
  String? _selectedAgentId;
  bool _isAgentPanelVisible = false;
  Set<String> _visibleAgentIds = {};
  bool _selectAllAgents = true;
  
  final List<GeofenceInfo> _geofences = [];
  bool _isGeofencePanelVisible = false;
  Set<String> _visibleGeofenceIds = {};
  bool _selectAllGeofences = true;

  final Set<Marker> _markers = {};
  final Set<Polygon> _polygons = {};

  @override
  void initState() {
    super.initState();
    _initializeAndStartTimer();
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeAndStartTimer() async {
    await _fetchMapData();
    _periodicTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) _fetchMapData();
    });
  }

  Future<void> _fetchMapData() async {
    try {
      final responses = await Future.wait([
        supabase.rpc('get_agents_with_last_location'),
        supabase.rpc('get_all_geofences_wkt'),
      ]);

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
        
        _updateMarkers();
        _updatePolygons();
      });

    } catch (e) {
      if (mounted) context.showSnackBar('Could not refresh map data: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateMarkers() {
    _markers.clear();
    for (final agent in _agents.values) {
      if (_visibleAgentIds.contains(agent.id) && agent.lastLocation != null) {
        _markers.add(
          Marker(
            markerId: MarkerId(agent.id),
            position: agent.lastLocation!,
            infoWindow: InfoWindow(title: agent.fullName),
            icon: _selectedAgentId == agent.id
                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
                : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
      _selectedAgentId = agent.id;
      _isAgentPanelVisible = true;
      _isGeofencePanelVisible = false;
      _updateMarkers();
    });

    if (agent.lastLocation != null) {
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(agent.lastLocation!, 15.0));
    } else {
      context.showSnackBar('${agent.fullName} has no location on record.', isError: true);
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
      appBar: AppBar(title: const Text('Live Map')),
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
                    }
                  },
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

                            return CheckboxListTile(
                              secondary: CircleAvatar(backgroundColor: statusColor, radius: 5),
                              title: Text(agent.fullName, style: const TextStyle(fontSize: 14)),
                              subtitle: Text(status, style: const TextStyle(fontSize: 12)),
                              value: _visibleAgentIds.contains(agent.id),
                              controlAffinity: ListTileControlAffinity.leading,
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
