// lib/screens/admin/evidence_location_viewer.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import '../../utils/constants.dart';
import 'evidence_detail_screen.dart';

class EvidenceLocationViewer extends StatefulWidget {
  final EvidenceDetail evidence;

  const EvidenceLocationViewer({
    super.key,
    required this.evidence,
  });

  @override
  State<EvidenceLocationViewer> createState() => _EvidenceLocationViewerState();
}

class _EvidenceLocationViewerState extends State<EvidenceLocationViewer> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _setupMapData();
  }

  void _setupMapData() {
    final Set<Marker> markers = {};
    final Set<Circle> circles = {};

    // Add evidence location marker
    if (widget.evidence.hasLocationData) {
      markers.add(
        Marker(
          markerId: const MarkerId('evidence_location'),
          position: LatLng(widget.evidence.latitude!, widget.evidence.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'Evidence Location',
            snippet: 'Submitted by ${widget.evidence.agentName}',
          ),
        ),
      );

      // Add accuracy circle if available
      if (widget.evidence.accuracy != null) {
        circles.add(
          Circle(
            circleId: const CircleId('evidence_accuracy'),
            center: LatLng(widget.evidence.latitude!, widget.evidence.longitude!),
            radius: widget.evidence.accuracy!,
            fillColor: Colors.blue.withValues(alpha: 0.2),
            strokeColor: Colors.blue,
            strokeWidth: 2,
          ),
        );
      }
    }

    // Add task geofence if available
    if (widget.evidence.hasTaskGeofence) {
      markers.add(
        Marker(
          markerId: const MarkerId('task_center'),
          position: LatLng(
            widget.evidence.taskGeofenceCenterLat!,
            widget.evidence.taskGeofenceCenterLng!,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Task Center',
            snippet: widget.evidence.taskTitle,
          ),
        ),
      );

      circles.add(
        Circle(
          circleId: const CircleId('task_geofence'),
          center: LatLng(
            widget.evidence.taskGeofenceCenterLat!,
            widget.evidence.taskGeofenceCenterLng!,
          ),
          radius: widget.evidence.taskGeofenceRadius!,
          fillColor: Colors.green.withValues(alpha: 0.1),
          strokeColor: Colors.green,
          strokeWidth: 2,
        ),
      );
    }

    setState(() {
      _markers = markers;
      _circles = circles;
    });
  }

  LatLng get _centerLocation {
    if (widget.evidence.hasLocationData) {
      return LatLng(widget.evidence.latitude!, widget.evidence.longitude!);
    } else if (widget.evidence.hasTaskGeofence) {
      return LatLng(
        widget.evidence.taskGeofenceCenterLat!,
        widget.evidence.taskGeofenceCenterLng!,
      );
    }
    // Default to a central location
    return const LatLng(37.7749, -122.4194); // San Francisco
  }

  double get _zoomLevel {
    if (widget.evidence.hasTaskGeofence) {
      final radius = widget.evidence.taskGeofenceRadius!;
      // Calculate zoom level based on radius
      if (radius > 5000) return 10.0;
      if (radius > 2000) return 12.0;
      if (radius > 1000) return 14.0;
      if (radius > 500) return 15.0;
      return 16.0;
    }
    return 15.0; // Default zoom
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Evidence Location'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.evidence.hasLocationData && widget.evidence.hasTaskGeofence)
            IconButton(
              onPressed: _fitBounds,
              icon: const Icon(Icons.fit_screen),
              tooltip: 'Fit to bounds',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            initialCameraPosition: CameraPosition(
              target: _centerLocation,
              zoom: _zoomLevel,
            ),
            markers: _markers,
            circles: _circles,
            mapType: MapType.normal,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
          ),
          
          // Information overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildInfoCard(),
          ),
          
          // Legend
          Positioned(
            bottom: 16,
            left: 16,
            child: _buildLegendCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.evidence.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  widget.evidence.agentName,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const Spacer(),
                _buildStatusBadge(widget.evidence.status),
              ],
            ),
            if (widget.evidence.hasLocationData && widget.evidence.hasTaskGeofence) ...[
              const SizedBox(height: 8),
              _buildLocationValidation(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationValidation() {
    final distance = widget.evidence.distanceFromTaskCenter;
    final isWithinGeofence = widget.evidence.isWithinTaskGeofence;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isWithinGeofence ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isWithinGeofence ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isWithinGeofence ? Icons.check_circle : Icons.warning,
            color: isWithinGeofence ? Colors.green : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isWithinGeofence 
                  ? 'Location verified (${distance?.toStringAsFixed(0)}m from center)'
                  : 'Outside task area (${distance?.toStringAsFixed(0)}m from center)',
              style: TextStyle(
                color: isWithinGeofence ? Colors.green[700] : Colors.orange[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Legend',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.evidence.hasLocationData) ...[
              _buildLegendItem(
                Colors.blue,
                'Evidence Location',
                Icons.location_on,
              ),
              if (widget.evidence.accuracy != null)
                _buildLegendItem(
                  Colors.blue.withValues(alpha: 0.3),
                  'GPS Accuracy (±${widget.evidence.accuracy!.toStringAsFixed(0)}m)',
                  Icons.radio_button_unchecked,
                ),
            ],
            if (widget.evidence.hasTaskGeofence) ...[
              _buildLegendItem(
                Colors.green,
                'Task Center',
                Icons.location_on,
              ),
              _buildLegendItem(
                Colors.green.withValues(alpha: 0.3),
                'Task Area (${widget.evidence.taskGeofenceRadius!.toStringAsFixed(0)}m radius)',
                Icons.radio_button_unchecked,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case 'pending':
      default:
        color = Colors.orange;
        icon = Icons.schedule;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _fitBounds() {
    if (_mapController == null || !widget.evidence.hasLocationData || !widget.evidence.hasTaskGeofence) {
      return;
    }

    final evidenceLat = widget.evidence.latitude!;
    final evidenceLng = widget.evidence.longitude!;
    final taskLat = widget.evidence.taskGeofenceCenterLat!;
    final taskLng = widget.evidence.taskGeofenceCenterLng!;

    final southwest = LatLng(
      math.min(evidenceLat, taskLat),
      math.min(evidenceLng, taskLng),
    );
    final northeast = LatLng(
      math.max(evidenceLat, taskLat),
      math.max(evidenceLng, taskLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: southwest, northeast: northeast),
        100.0, // padding
      ),
    );
  }
}