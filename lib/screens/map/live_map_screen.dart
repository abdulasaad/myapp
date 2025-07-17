// lib/screens/map/live_map_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/constants.dart';
import '../reporting/location_history_screen.dart';

// --- DATA MODELS ---

class AgentMapInfo {
  final String id;
  final String fullName;
  final LatLng? lastLocation;
  final DateTime? lastSeen;
  final String? status;
  final String? connectionStatus;
  final DateTime? lastHeartbeat;

  AgentMapInfo({
    required this.id,
    required this.fullName,
    this.lastLocation,
    this.lastSeen,
    this.status,
    this.connectionStatus,
    this.lastHeartbeat,
  });

  factory AgentMapInfo.fromJson(Map<String, dynamic> data) {
    LatLng? parsedLocation;
    if (data['last_location'] is String) {
      final pointString = data['last_location'] as String;
      
      // Try POINT(lng lat) format first
      final pointRegex = RegExp(r'POINT\(([-\d.]+) ([-\d.]+)\)');
      final pointMatch = pointRegex.firstMatch(pointString);
      if (pointMatch != null) {
        final lng = double.tryParse(pointMatch.group(1)!);
        final lat = double.tryParse(pointMatch.group(2)!);
        if (lat != null && lng != null) {
          parsedLocation = LatLng(lat, lng);
        }
      } else {
        // Try PostgreSQL default format (lng,lat)
        final postgresRegex = RegExp(r'\(([-\d.]+),([-\d.]+)\)');
        final postgresMatch = postgresRegex.firstMatch(pointString);
        if (postgresMatch != null) {
          final lng = double.tryParse(postgresMatch.group(1)!);
          final lat = double.tryParse(postgresMatch.group(2)!);
          if (lat != null && lng != null) {
            parsedLocation = LatLng(lat, lng);
          }
        }
      }
    }

    DateTime? parsedTime;
    if (data['last_seen'] is String) {
      parsedTime = DateTime.tryParse(data['last_seen']);
    }

    DateTime? parsedHeartbeat;
    if (data['last_heartbeat'] is String) {
      parsedHeartbeat = DateTime.tryParse(data['last_heartbeat']);
    }

    return AgentMapInfo(
      id: data['id'] ?? 'unknown_id_${DateTime.now()}',
      fullName: data['full_name'] ?? 'Unknown Agent',
      lastLocation: parsedLocation,
      lastSeen: parsedTime,
      status: data['status'] as String?,
      connectionStatus: data['connection_status'] as String?,
      lastHeartbeat: parsedHeartbeat,
    );
  }
}

class GeofenceInfo {
  final String id;
  final String name;
  final List<LatLng> points;
  final String type; // 'campaign' or 'touring_task'
  final Color color;
  final String? campaignId;
  final String? campaignName;
  final String? touringTaskId;
  final String? touringTaskTitle;
  final String? touringTasksInfo;
  final bool isActive;

  GeofenceInfo({
    required this.id,
    required this.name,
    required this.points,
    required this.type,
    required this.color,
    this.campaignId,
    this.campaignName,
    this.touringTaskId,
    this.touringTaskTitle,
    this.touringTasksInfo,
    this.isActive = true,
  });

  factory GeofenceInfo.fromJson(Map<String, dynamic> data) {
    final wkt = data['geofence_area_wkt'] as String?;
    if (wkt == null) {
      throw ArgumentError('geofence_area_wkt is required');
    }

    // Parse color from hex string
    final colorString = data['geofence_color'] as String? ?? 'FFA500';
    final colorValue = int.tryParse(colorString, radix: 16) ?? 0xFFA500;
    final color = Color(0xFF000000 | colorValue);

    return GeofenceInfo(
      id: data['geofence_id'] ?? 'unknown_id',
      name: data['geofence_name'] ?? 'Unnamed Zone',
      points: _parseWktPolygon(wkt),
      type: data['geofence_type'] ?? 'campaign',
      color: color,
      campaignId: data['campaign_id'],
      campaignName: data['campaign_name'],
      touringTaskId: data['touring_task_id'],
      touringTaskTitle: data['touring_task_title'],
      touringTasksInfo: data['touring_tasks_info'],
      isActive: data['is_active'] ?? true,
    );
  }

  static List<LatLng> _parseWktPolygon(String wkt) {
    try {
      final pointsList = <LatLng>[];
      final content = wkt.substring(wkt.indexOf('((') + 2, wkt.lastIndexOf('))'));
      final pairs = content.split(',');
      debugPrint('🔍 DEBUG: Parsing WKT with ${pairs.length} coordinate pairs');
      
      for (var pair in pairs) {
        final coords = pair.trim().split(' ');
        if (coords.length == 2) {
          // Your WKT data has coordinates in "latitude longitude" format
          // So coords[0] is latitude, coords[1] is longitude
          final lat = double.parse(coords[0]);
          final lng = double.parse(coords[1]);
          pointsList.add(LatLng(lat, lng));
          debugPrint('🔍 DEBUG: Added point: lat=$lat, lng=$lng');
        }
      }
      debugPrint('🔍 DEBUG: Successfully parsed ${pointsList.length} points');
      return pointsList;
    } catch (e) {
      debugPrint("❌ DEBUG: Failed to parse WKT Polygon: $e");
      debugPrint("❌ DEBUG: WKT content: $wkt");
      return [];
    }
  }
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
  BitmapDescriptor? _agentIconYellow;

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
      _agentIconYellow = await _createAgentMarker(Colors.orange);
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
    _periodicTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
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
        
        // Use the new RPC function that bypasses RLS policies
        try {
          final response = await supabase.rpc('get_all_agents_with_location_for_admin', params: {
            'requesting_user_id': currentUser.id,
          });
          
          if (response != null && response.isNotEmpty) {
            return response;
          }
        } catch (e) {
          debugPrint('RPC call failed: $e');
        }
        
        // Fallback: Try the previous approach if RPC fails
        try {
          final allAgentsResponse = await supabase
              .from('profiles')
              .select('id, full_name, role, status, last_heartbeat')
              .eq('role', 'agent')
              .order('full_name');
          
          if (allAgentsResponse.isNotEmpty) {
            final List<Map<String, dynamic>> agentsWithLocation = [];
            
            for (final profile in allAgentsResponse) {
              final Map<String, dynamic> result = Map.from(profile);
              
              // Calculate connection status based on last_heartbeat
              if (result['last_heartbeat'] != null) {
                try {
                  final lastHeartbeat = DateTime.parse(result['last_heartbeat']);
                  final now = DateTime.now();
                  final diff = now.difference(lastHeartbeat);
                  
                  if (diff.inSeconds < 45) {
                    result['connection_status'] = 'active';
                  } else if (diff.inMinutes < 10) {
                    result['connection_status'] = 'away';
                  } else {
                    result['connection_status'] = 'offline';
                  }
                } catch (e) {
                  result['connection_status'] = 'offline';
                }
              } else {
                result['connection_status'] = 'offline';
              }
              
              agentsWithLocation.add(result);
            }
            
            return agentsWithLocation;
          }
        } catch (e) {
          debugPrint('Fallback approach failed: $e');
        }
        
        return [];
      } else if (userRole == 'manager') {
        // Managers can see agents in their groups (including those without heartbeats)
        return await supabase.rpc('get_agents_in_manager_groups', params: {
          'manager_user_id': currentUser.id,
        });
      } else {
        // Other roles (agents) typically don't access live map
        return [];
      }
    } catch (e) {
      debugPrint('❌ ADMIN DEBUG: Error filtering agent locations: $e');
      debugPrint('❌ ADMIN DEBUG: Error stack trace: ${StackTrace.current}');
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
      final geofenceMap = <String, GeofenceInfo>{};
      
      debugPrint('🔍 DEBUG: Received ${geofenceResponse.length} geofences from database');
      debugPrint('🔍 DEBUG: Raw geofence response: $geofenceResponse');
      
      for (final data in geofenceResponse) {
        try {
          debugPrint('🔍 DEBUG: Processing geofence data: ${data['geofence_name']} - WKT: ${data['geofence_area_wkt']?.toString().substring(0, 50)}...');
          debugPrint('🔍 DEBUG: Full geofence data: $data');
          
          final geofence = GeofenceInfo.fromJson(data.cast<String, dynamic>());
          debugPrint('🔍 DEBUG: Parsed geofence ${geofence.name} with ${geofence.points.length} points');
          debugPrint('🔍 DEBUG: Geofence active: ${geofence.isActive}, Points: ${geofence.points}');
          
          if (geofence.isActive && geofence.points.isNotEmpty) {
            // Only add unique geofences (avoid duplicates from touring tasks)
            if (!geofenceMap.containsKey(geofence.id)) {
              geofenceMap[geofence.id] = geofence;
              debugPrint('✅ DEBUG: Added geofence ${geofence.name} to map');
            } else {
              debugPrint('⚠️ DEBUG: Geofence ${geofence.name} already exists, skipping duplicate');
            }
          } else {
            debugPrint('❌ DEBUG: Skipped geofence ${geofence.name} - Active: ${geofence.isActive}, Points: ${geofence.points.length}');
          }
        } catch (e) {
          debugPrint('❌ DEBUG: Error parsing geofence data: $e');
          debugPrint('❌ DEBUG: Raw data: $data');
        }
      }
      
      newGeofenceData.addAll(geofenceMap.values);
      debugPrint('🔍 DEBUG: Final geofence count: ${newGeofenceData.length}');

      setState(() {
        _agents.clear();
        _agents.addAll(newAgentData);
        _geofences.clear();
        _geofences.addAll(newGeofenceData);

        if (_selectAllAgents) _visibleAgentIds = _agents.keys.toSet();
        // Always refresh visible geofence IDs to match current geofences
        final allGeofenceIds = _geofences.map((g) => g.id).toSet();
        
        if (_visibleGeofenceIds.isEmpty) {
          // If no geofences are visible, show all geofences (initial state)
          _visibleGeofenceIds = allGeofenceIds;
          _selectAllGeofences = true;
          debugPrint('🔍 DEBUG: Initial state - set all geofences visible: $_visibleGeofenceIds');
        } else {
          // Keep only existing visible geofences that are still valid
          _visibleGeofenceIds = _visibleGeofenceIds.where((id) => allGeofenceIds.contains(id)).toSet();
          
          // If after filtering we have no geofences visible, show all
          if (_visibleGeofenceIds.isEmpty) {
            _visibleGeofenceIds = allGeofenceIds;
            _selectAllGeofences = true;
            debugPrint('🔍 DEBUG: No valid geofences after filtering - set all visible: $_visibleGeofenceIds');
          } else {
            // Update select all state based on actual visibility
            _selectAllGeofences = _visibleGeofenceIds.length == allGeofenceIds.length;
            debugPrint('🔍 DEBUG: Filtered visible geofence IDs: $_visibleGeofenceIds');
          }
        }
        
        // Debug: Show all geofence IDs for comparison
        debugPrint('🔍 DEBUG: All geofence IDs: ${_geofences.map((g) => g.id).toList()}');
        debugPrint('🔍 DEBUG: All geofence names: ${_geofences.map((g) => g.name).toList()}');
        debugPrint('🔍 DEBUG: Select all geofences: $_selectAllGeofences');
        
        // Debug: Log agent data updates
        for (final agent in _agents.values) {
          if (agent.lastLocation != null) {
            debugPrint('📍 Agent ${agent.fullName}: ${agent.lastLocation} at ${agent.lastSeen}');
          }
        }
        
        _updateMarkers();
        _updatePolygons();
        
        // Auto-center map on geofences if available
        if (_geofences.isNotEmpty && _visibleGeofenceIds.isNotEmpty) {
          _centerMapOnGeofences();
        }
        
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
    // Use new connection status if available
    if (agent.connectionStatus != null) {
      return agent.connectionStatus == 'active';
    }
    
    // Fallback to checking last seen timestamp
    if (agent.lastSeen == null) return false;
    
    final now = DateTime.now();
    final timeSinceLastSeen = now.difference(agent.lastSeen!);
    
    // Consider online if seen within last 15 minutes
    return timeSinceLastSeen.inMinutes < 15;
  }

  String _getAgentStatus(AgentMapInfo agent) {
    // Use new connection status if available
    if (agent.connectionStatus != null) {
      switch (agent.connectionStatus) {
        case 'active':
          return 'Active';
        case 'away':
          return 'Away';
        case 'offline':
          return 'Offline';
        default:
          return 'Unknown';
      }
    }
    
    // Fallback to calculated status based on location timestamp
    return _getCalculatedStatus(agent.lastSeen);
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
          // Not selected - check connection status
          final connectionStatus = agent.connectionStatus;
          debugPrint('Agent ${agent.fullName}: connectionStatus=$connectionStatus, lastSeen=${agent.lastSeen}');
          
          if (connectionStatus == 'active') {
            // Active agents get green icon
            markerIcon = _agentIconGreen ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
          } else if (connectionStatus == 'away') {
            // Away agents get yellow/orange icon
            markerIcon = _agentIconYellow ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
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
              snippet: 'Status: ${_getAgentStatus(agent)} • ${agent.lastSeen?.toString().substring(11, 16) ?? 'Unknown'}',
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
    debugPrint('🔍 DEBUG: Updating polygons for ${_geofences.length} geofences');
    debugPrint('🔍 DEBUG: Visible geofence IDs: $_visibleGeofenceIds');
    
    for (final geofence in _geofences) {
      debugPrint('🔍 DEBUG: Checking geofence ${geofence.name} (ID: ${geofence.id})');
      debugPrint('🔍 DEBUG: Is visible: ${_visibleGeofenceIds.contains(geofence.id)}');
      
      if (_visibleGeofenceIds.contains(geofence.id)) {
        debugPrint('🔍 DEBUG: Creating polygon for ${geofence.name} with ${geofence.points.length} points');
        debugPrint('🔍 DEBUG: First point: ${geofence.points.isNotEmpty ? geofence.points.first : 'No points'}');
        
        final polygon = Polygon(
          polygonId: PolygonId(geofence.id),
          points: geofence.points,
          strokeColor: geofence.color,
          strokeWidth: 2,
          fillColor: geofence.color.withAlpha(38), // 0.15 opacity
        );
        _polygons.add(polygon);
        
        // Debug: Log polygon details
        debugPrint('🔍 DEBUG: Polygon created with color: ${geofence.color}');
        debugPrint('🔍 DEBUG: Polygon bounds: ${geofence.points.map((p) => '(${p.latitude}, ${p.longitude})').join(', ')}');
        
        debugPrint('✅ DEBUG: Added polygon ${geofence.id} to map');
      } else {
        debugPrint('❌ DEBUG: Geofence ${geofence.name} (ID: ${geofence.id}) not visible (not in visible set)');
      }
    }
    
    debugPrint('🔍 DEBUG: Total polygons created: ${_polygons.length}');
    setState(() {});
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

  Future<void> _centerMapOnGeofences() async {
    final controller = await _mapController.future;
    
    // Get all visible geofence points
    final allPoints = <LatLng>[];
    for (final geofence in _geofences) {
      if (_visibleGeofenceIds.contains(geofence.id)) {
        allPoints.addAll(geofence.points);
      }
    }
    
    if (allPoints.isEmpty) return;
    
    // Calculate bounds
    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;
    
    for (final point in allPoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    
    // Animate camera to show all geofences
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100, // padding
      ),
    );
    
    debugPrint('🔍 DEBUG: Centered map on geofences - bounds: ($minLat, $minLng) to ($maxLat, $maxLng)');
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
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
                // Top Navigation Bar with Back and History buttons
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.8),
                                Colors.black.withValues(alpha: 0.9),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 20,
                          ),
                        ),
                      ),
                      // Tech-Style Location Title - Constrained width to prevent overlap
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.8),
                                    Colors.black.withValues(alpha: 0.9),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // GPS Signal Icon
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.gps_fixed,
                                        color: Colors.green[300],
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Title with tech styling
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'LIVE TRACKING',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green[300],
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          'Real-time',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withValues(alpha: 0.9),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    // Status indicator
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _hasConnectivityIssue 
                                            ? Colors.orange 
                                            : Colors.green,
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (_hasConnectivityIssue 
                                                ? Colors.orange 
                                                : Colors.green).withValues(alpha: 0.5),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Location History Button
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const LocationHistoryScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.8),
                                Colors.black.withValues(alpha: 0.9),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.history,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                    top: MediaQuery.of(context).padding.top + 80,
                    left: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: FloatingActionButton(
                        mini: true,
                        heroTag: 'agent-fab',
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        onPressed: () => setState(() {
                          _isGeofencePanelVisible = false;
                          _isAgentPanelVisible = true;
                        }),
                        tooltip: 'Show Agent List',
                        child: Icon(
                          Icons.people_alt_outlined,
                          color: Colors.blue[300],
                        ),
                      ),
                    ),
                  ),
                
                // Right Toggle Button
                if (!_isGeofencePanelVisible)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 80,
                    right: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: FloatingActionButton(
                        mini: true,
                        heroTag: 'geofence-fab',
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        onPressed: () => setState(() {
                          _isAgentPanelVisible = false;
                          _isGeofencePanelVisible = true;
                        }),
                        tooltip: 'Show Geofences',
                        child: Icon(
                          Icons.layers_outlined,
                          color: Colors.orange[300],
                        ),
                      ),
                    ),
                  ),
                
                // Stop Tracking Button
                if (_trackedAgentId != null && !_isAgentPanelVisible && !_isGeofencePanelVisible)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.black.withValues(alpha: 0.9),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.purple.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: FloatingActionButton(
                        mini: true,
                        heroTag: 'stop-tracking-fab',
                        backgroundColor: Colors.transparent,
                        elevation: 0,
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
                        child: Icon(
                          Icons.location_off,
                          color: Colors.purple[300],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
                        debugPrint('🔍 DEBUG: Select All checked - showing all geofences: $_visibleGeofenceIds');
                      } else {
                        _visibleGeofenceIds.clear();
                        debugPrint('🔍 DEBUG: Select All unchecked - hiding all geofences');
                      }
                      _updatePolygons();
                    });
                  },
                ),
                
                if (_visibleGeofenceIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: ElevatedButton.icon(
                      onPressed: _centerMapOnGeofences,
                      icon: const Icon(Icons.center_focus_strong),
                      label: const Text('Center on Geofences'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(36),
                      ),
                    ),
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
                            final isVisible = _visibleGeofenceIds.contains(geofence.id);
                            
                            return CheckboxListTile(
                              secondary: Icon(
                                geofence.touringTasksInfo?.isNotEmpty == true ? Icons.tour : Icons.layers_outlined,
                                color: geofence.color,
                              ),
                              title: Text(
                                geofence.name,
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (geofence.campaignName != null)
                                    Text(
                                      'Campaign: ${geofence.campaignName}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  if (geofence.touringTasksInfo?.isNotEmpty == true)
                                    Text(
                                      'Touring Tasks: ${geofence.touringTasksInfo}',
                                      style: TextStyle(fontSize: 12, color: Colors.purple[600]),
                                    ),
                                ],
                              ),
                              value: isVisible,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _visibleGeofenceIds.add(geofence.id);
                                    debugPrint('🔍 DEBUG: Added geofence ${geofence.name} to visible set');
                                  } else {
                                    _visibleGeofenceIds.remove(geofence.id);
                                    debugPrint('🔍 DEBUG: Removed geofence ${geofence.name} from visible set');
                                  }
                                  
                                  // Update select all state
                                  _selectAllGeofences = _visibleGeofenceIds.length == _geofences.length;
                                  debugPrint('🔍 DEBUG: Updated select all state to: $_selectAllGeofences');
                                  debugPrint('🔍 DEBUG: Visible geofences: $_visibleGeofenceIds');
                                  
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
