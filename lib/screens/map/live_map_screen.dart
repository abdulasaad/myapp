// lib/screens/map/live_map_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/constants.dart';

// --- DATA MODEL: Defined here to be self-contained and fully null-safe ---
// This class safely represents an agent, handling cases where location is missing.
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

  // This factory is the key to preventing crashes. It safely handles all nulls.
  factory AgentMapInfo.fromJson(Map<String, dynamic> data) {
    LatLng? parsedLocation;
    // Safely check if 'last_location' is a non-null String before parsing.
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
    // Safely check if 'last_seen' is a non-null String before parsing.
    if (data['last_seen'] is String) {
      // Use tryParse, which returns null on failure instead of crashing.
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

// --- MAIN WIDGET ---
class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  Timer? _periodicTimer;

  bool _isLoading = true;
  // --- FIX: We use a Map of our safe data model ---
  final Map<String, AgentMapInfo> _agents = {};
  
  String? _selectedAgentId;
  final Set<Marker> _markers = {};

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

  // --- DATA FETCHING & LOGIC ---

  Future<void> _initializeAndStartTimer() async {
    await _fetchLatestAgentData();
    _periodicTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) _fetchLatestAgentData();
    });
  }

  Future<void> _fetchLatestAgentData() async {
    try {
      final response = await supabase.rpc('get_agents_with_last_location') as List;
      if (!mounted) return;
      
      final newAgentData = <String, AgentMapInfo>{};
      for (final data in response) {
        // --- FIX: Use the safe fromJson factory which prevents all crashes ---
        final agent = AgentMapInfo.fromJson(data.cast<String, dynamic>());
        newAgentData[agent.id] = agent;
      }

      setState(() {
        _agents.clear();
        _agents.addAll(newAgentData);
        _updateMarkers();
      });

    } catch (e) {
      if (mounted) context.showSnackBar('Could not refresh agent data: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI ACTIONS & HELPERS ---

  void _updateMarkers() {
    _markers.clear();
    for (final agent in _agents.values) {
      // --- This check is now robust because the data type is nullable ---
      if (agent.lastLocation != null) {
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
  }

  Future<void> _onAgentTapped(AgentMapInfo agent) async {
    setState(() {
      _selectedAgentId = agent.id;
      _updateMarkers();
    });

    // --- This check is now robust ---
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
  
  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agent Status & Map')),
      body: _isLoading
          ? preloader
          : Stack(
              children: [
                GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: const CameraPosition(target: LatLng(33.3152, 44.3661), zoom: 11),
                  markers: _markers,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController.complete(controller);
                  },
                ),
                DraggableScrollableSheet(
                  initialChildSize: 0.3, minChildSize: 0.1, maxChildSize: 0.6,
                  builder: (context, scrollController) {
                    final agentList = _agents.values.toList();
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withAlpha(51))],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40, height: 5,
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(12)),
                          ),
                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
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

                                return ListTile(
                                  leading: CircleAvatar(backgroundColor: statusColor, radius: 8),
                                  title: Text(agent.fullName),
                                  subtitle: Text(status),
                                  onTap: () => _onAgentTapped(agent),
                                  selected: _selectedAgentId == agent.id,
                                  selectedTileColor: primaryColor.withAlpha(51),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              ],
            ),
    );
  }
}