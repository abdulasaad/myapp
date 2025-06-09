// lib/screens/agent/calibration_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; // <-- Use Geolocator's Position
import '../../services/location_service.dart';

class CalibrationScreen extends StatefulWidget {
  final LocationService locationService;
  
  const CalibrationScreen({super.key, required this.locationService});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  // --- FIX: The stream now provides 'Position' objects ---
  StreamSubscription<Position>? _locationSubscription;
  Position? _latestPosition;

  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    // Subscribe to the updated location stream
    _locationSubscription = widget.locationService.locationStream.listen((position) {
      if (mounted) {
        setState(() {
          _latestPosition = position;
          _updateMapWithNewData(position);
        });
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _updateMapWithNewData(Position data) async {
    final GoogleMapController controller = await _controller.future;
    final LatLng newPosition = LatLng(data.latitude, data.longitude);
    
    controller.animateCamera(CameraUpdate.newLatLngZoom(newPosition, 16.5));

    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: newPosition,
          infoWindow: InfoWindow(title: 'Your Location', snippet: 'Accuracy: ${data.accuracy.toStringAsFixed(1)}m'),
        )
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- FIX: Use the accuracy from the Position object ---
    final double accuracy = _latestPosition?.accuracy ?? 9999.0;
    
    String statusText;
    String instructionText;
    Color statusColor;

    if (accuracy <= 15) {
      statusText = "Excellent Accuracy";
      instructionText = "GPS lock is strong. Ready to go!";
      statusColor = Colors.green;
    } else if (accuracy <= 40) {
      statusText = "Good Accuracy";
      instructionText = "GPS lock is acceptable. Remain in an open area for best results.";
      statusColor = Colors.orange;
    } else {
      statusText = "Poor Accuracy";
      instructionText = "Signal is weak. Please go outside with a clear view of the sky.";
      statusColor = Colors.red;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('GPS Calibration')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: statusColor,
            child: Row(
              children: [
                const Icon(Icons.satellite_alt, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Accuracy: ${accuracy.toStringAsFixed(1)} meters', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: const CameraPosition(target: LatLng(33.3152, 44.3661), zoom: 14),
              myLocationButtonEnabled: true,
              markers: _markers,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(instructionText, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
