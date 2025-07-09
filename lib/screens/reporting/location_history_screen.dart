// lib/screens/reporting/location_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import '../../models/location_history.dart';
import '../../services/location_history_service.dart';
import '../../utils/constants.dart';

class LocationHistoryScreen extends StatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<AgentInfo> _agents = [];
  AgentInfo? _selectedAgent;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  List<LocationHistoryEntry> _locationHistory = [];
  Map<String, dynamic>? _statistics;
  bool _isLoading = false;
  bool _isLoadingAgents = true;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to show/hide filters based on tab
    });
    _loadAgents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    setState(() => _isLoadingAgents = true);
    try {
      final agents = await LocationHistoryService.instance.getAllAgents();
      setState(() {
        _agents = agents;
        _isLoadingAgents = false;
      });
    } catch (e) {
      setState(() => _isLoadingAgents = false);
      if (mounted) {
        context.showSnackBar('Failed to load agents: $e', isError: true);
      }
    }
  }

  Future<void> _loadLocationHistory() async {
    if (_selectedAgent == null) return;

    setState(() => _isLoading = true);
    try {
      final history = await LocationHistoryService.instance.getAgentLocationHistory(
        agentId: _selectedAgent!.id,
        startDate: _startDate,
        endDate: _endDate,
      );

      final stats = await LocationHistoryService.instance.getLocationStatistics(
        agentId: _selectedAgent!.id,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _locationHistory = history;
        _statistics = stats;
      });
      _updateMapData();
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to load location history: $e',
            isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateMapData() async {
    _markers.clear();
    _polylines.clear();

    if (_locationHistory.isEmpty) return;

    // Create custom dot icons
    final startDotIcon = await _createDotIcon(Colors.green, 8);
    final endDotIcon = await _createDotIcon(Colors.red, 8);
    final locationDotIcon = await _createDotIcon(Colors.blue, 6);

    // Add small dot markers for each location point
    for (int i = 0; i < _locationHistory.length; i++) {
      final entry = _locationHistory[i];
      final isStart = i == _locationHistory.length - 1; // Last in list is oldest (start)
      final isEnd = i == 0; // First in list is newest (end)
      
      BitmapDescriptor icon;
      String title;
      if (isStart) {
        icon = startDotIcon;
        title = 'Start';
      } else if (isEnd) {
        icon = endDotIcon;
        title = 'End';
      } else {
        icon = locationDotIcon;
        title = 'Location ${i + 1}';
      }

      _markers.add(Marker(
        markerId: MarkerId('location_$i'),
        position: entry.location,
        icon: icon,
        infoWindow: InfoWindow(
          title: title,
          snippet: entry.formattedTime,
        ),
        anchor: const Offset(0.5, 0.5),
      ));
    }

    // Add continuous polyline connecting all points in chronological order
    if (_locationHistory.length > 1) {
      final points = _locationHistory.reversed.map((entry) => entry.location).toList();
      _polylines.add(Polyline(
        polylineId: const PolylineId('agent_path'),
        points: points,
        color: Colors.blue,
        width: 2,
        patterns: [], // Solid line
      ));
    }
    
    setState(() {});
  }

  Future<BitmapDescriptor> _createDotIcon(Color color, double size) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = color;
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(size, size), size, paint);
    canvas.drawCircle(Offset(size, size), size, borderPaint);

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage((size * 2).toInt(), (size * 2).toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.bytes(uint8List);
  }


  Future<void> _selectDateRange() async {
    // Show date range picker first
    final DateTimeRange? dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime(_startDate.year, _startDate.month, _startDate.day),
        end: DateTime(_endDate.year, _endDate.month, _endDate.day),
      ),
    );

    if (dateRange == null) return;

    // Show time picker for start time
    if (!mounted) return;
    final TimeOfDay? startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startDate),
      helpText: 'Select start time',
    );

    if (startTime == null) return;

    // Show time picker for end time
    if (!mounted) return;
    final TimeOfDay? endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endDate),
      helpText: 'Select end time',
    );

    if (endTime == null) return;

    // Combine date and time
    final newStartDate = DateTime(
      dateRange.start.year,
      dateRange.start.month,
      dateRange.start.day,
      startTime.hour,
      startTime.minute,
    );

    final newEndDate = DateTime(
      dateRange.end.year,
      dateRange.end.month,
      dateRange.end.day,
      endTime.hour,
      endTime.minute,
    );

    setState(() {
      _startDate = newStartDate;
      _endDate = newEndDate;
    });

    _loadLocationHistory();
  }

  void _setPresetDateRange(int days) {
    setState(() {
      _endDate = DateTime.now();
      _startDate = _endDate.subtract(Duration(days: days));
    });
    _loadLocationHistory();
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
        body: SafeArea(
          child: Column(
            children: [
              // Modern Title Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Container(
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
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.black87),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                        child: const Text(
                          'Location History',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.list), text: 'History'),
                    Tab(icon: Icon(Icons.map), text: 'Map'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _buildFilters(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(), // Disable swipe gestures
                        children: [
                          _buildHistoryTab(),
                          _buildMapTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    // Only show filters in the History tab (index 0)
    if (_tabController.index != 0) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Agent Selector
          Row(
            children: [
              const Icon(Icons.person, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: _isLoadingAgents
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<AgentInfo>(
                        value: _selectedAgent,
                        decoration: const InputDecoration(
                          labelText: 'Select Agent',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _agents.map((agent) {
                          return DropdownMenuItem<AgentInfo>(
                            value: agent,
                            child: Text('${agent.fullName} (${agent.role})'),
                          );
                        }).toList(),
                        onChanged: (AgentInfo? newValue) {
                          setState(() {
                            _selectedAgent = newValue;
                            _locationHistory.clear();
                            _statistics = null;
                          });
                          if (newValue != null) {
                            _loadLocationHistory();
                          }
                        },
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Date Range Selector
          Row(
            children: [
              const Icon(Icons.date_range, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    '${_startDate.day}/${_startDate.month}/${_startDate.year} ${_startDate.hour.toString().padLeft(2, '0')}:${_startDate.minute.toString().padLeft(2, '0')} - ${_endDate.day}/${_endDate.month}/${_endDate.year} ${_endDate.hour.toString().padLeft(2, '0')}:${_endDate.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Preset Date Range Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetButton('Today', 0),
                const SizedBox(width: 8),
                _buildPresetButton('7 Days', 7),
                const SizedBox(width: 8),
                _buildPresetButton('30 Days', 30),
                const SizedBox(width: 8),
                _buildPresetButton('90 Days', 90),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(String label, int days) {
    return ElevatedButton(
      onPressed: () => _setPresetDateRange(days),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildHistoryTab() {
    if (_selectedAgent == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Please select an agent to view their location history'),
          ],
        ),
      );
    }

    if (_isLoading) {
      return preloader;
    }

    return Column(
      children: [
        if (_statistics != null) _buildStatistics(),
        Expanded(
          child: _locationHistory.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No location history found for the selected period'),
                    ],
                  ),
                )
              : _buildLocationSummary(),
        ),
      ],
    );
  }

  Widget _buildLocationSummary() {
    if (_locationHistory.isEmpty) return const SizedBox.shrink();
    
    final startLocation = _locationHistory.last; // Oldest (start)
    final endLocation = _locationHistory.first; // Newest (end)
    final totalLocations = _locationHistory.length;
    
    // Calculate time span
    final timeSpan = endLocation.timestamp.difference(startLocation.timestamp);
    String timeSpanText;
    if (timeSpan.inHours > 0) {
      timeSpanText = '${timeSpan.inHours}h ${timeSpan.inMinutes % 60}m';
    } else {
      timeSpanText = '${timeSpan.inMinutes}m';
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        child: InkWell(
          onTap: () {
            // Switch to map tab to show all locations
            _tabController.animateTo(1);
            _showAllLocationsOnMap();
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      radius: 25,
                      child: Icon(
                        Icons.route,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agent Movement Track',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_selectedAgent?.fullName ?? 'Agent'} • $timeSpanText',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Locations',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '$totalLocations points',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Time Period',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  timeSpanText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  startLocation.formattedTime,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'End Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  endLocation.formattedTime,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.map,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Tap to View Complete Route on Map',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAllLocationsOnMap() async {
    if (_mapController != null && _locationHistory.isNotEmpty) {
      // Ensure map data is updated with dot markers
      _updateMapData();
      
      // Calculate bounds to show all locations
      final points = _locationHistory.map((e) => e.location).toList();
      final bounds = _calculateBounds(points);
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    }
  }

  Widget _buildStatistics() {
    final stats = _statistics!;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location Statistics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Entries: ${stats['totalEntries']}'),
                    Text(
                        'Avg Accuracy: ±${stats['averageAccuracy'].toStringAsFixed(1)}m'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Avg Speed: ${stats['averageSpeed'].toStringAsFixed(1)} km/h'),
                    if (stats['firstEntry'] != null)
                      Text(
                          'Period: ${(stats['firstEntry'] as DateTime).day}/${(stats['firstEntry'] as DateTime).month} - ${(stats['lastEntry'] as DateTime).day}/${(stats['lastEntry'] as DateTime).month}'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapTab() {
    if (_selectedAgent == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Please select an agent to view their location history'),
          ],
        ),
      );
    }

    if (_isLoading) {
      return preloader;
    }

    if (_locationHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No location data to display on map'),
          ],
        ),
      );
    }

    // Calculate center point and zoom level
    final latitudes = _locationHistory.map((e) => e.location.latitude).toList();
    final longitudes =
        _locationHistory.map((e) => e.location.longitude).toList();

    final centerLat = (latitudes.reduce((a, b) => a + b)) / latitudes.length;
    final centerLng = (longitudes.reduce((a, b) => a + b)) / longitudes.length;

    return GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition: CameraPosition(
        target: LatLng(centerLat, centerLng),
        zoom: 14,
      ),
      markers: _markers,
      polylines: _polylines,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        // Update map data with dots and fit bounds to show all markers
        if (_locationHistory.isNotEmpty) {
          _updateMapData();
          final bounds = _calculateBounds(
              _locationHistory.map((e) => e.location).toList());
          controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
        }
      },
    );
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
