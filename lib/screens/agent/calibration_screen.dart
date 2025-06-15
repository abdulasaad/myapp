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
    
    // String statusText; // Unused variable removed
    // String instructionText; // Unused variable removed

    if (accuracy <= 15) {
      // statusText = "Excellent Accuracy"; // Unused assignment removed
      // instructionText = "GPS lock is strong. Ready to go!"; // Unused assignment removed
    } else if (accuracy <= 40) {
      // statusText = "Good Accuracy"; // Unused assignment removed
      // instructionText = "GPS lock is acceptable. Remain in an open area for best results."; // Unused assignment removed
    } else {
      // statusText = "Poor Accuracy"; // Unused assignment removed
      // instructionText = "Signal is weak. Please go outside with a clear view of the sky."; // Unused assignment removed
    }

    // Helper to determine text for accuracy (e.g., "Poor", "Good")
    String getAccuracyText(double acc) {
      if (acc <= 10) return "Excellent";
      if (acc <= 20) return "Good";
      if (acc <= 35) return "Moderate";
      if (acc <= 50) return "Poor";
      return "Very Poor";
    }

    // Helper to determine signal strength text and value (e.g., "Poor", "1/5")
    Map<String, String> getSignalStrength(double acc) {
      if (acc <= 10) return {"text": "Excellent", "value": "5/5"};
      if (acc <= 20) return {"text": "Good", "value": "4/5"};
      if (acc <= 35) return {"text": "Moderate", "value": "3/5"};
      if (acc <= 50) return {"text": "Poor", "value": "2/5"};
      return {"text": "Very Poor", "value": "1/5"};
    }
    
    final accuracyText = getAccuracyText(accuracy);
    final signalStrengthInfo = getSignalStrength(accuracy);

    return Scaffold(
      appBar: AppBar(title: const Text('GPS Accuracy')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map View
            SizedBox(
              height: 200, // Adjust height as needed
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: _latestPosition != null
                      ? CameraPosition(target: LatLng(_latestPosition!.latitude, _latestPosition!.longitude), zoom: 16)
                      : const CameraPosition(target: LatLng(33.3152, 44.3661), zoom: 10), // Default if no position yet
                  markers: _markers,
                  myLocationButtonEnabled: false, // Design doesn't show it
                  myLocationEnabled: false, // Markers are used instead
                  zoomControlsEnabled: false,
                  onMapCreated: (GoogleMapController controller) {
                    if (!_controller.isCompleted) {
                       _controller.complete(controller);
                    }
                    // If we have a position, update map once created
                    if (_latestPosition != null) {
                      _updateMapWithNewData(_latestPosition!);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // GPS Accuracy Section Title
            Text(
              'GPS Accuracy',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Accuracy Display
            _buildAccuracyRow(
              context,
              label: 'Accuracy',
              valueText: accuracyText,
              numericValue: '${accuracy.toStringAsFixed(0)}m',
            ),
            const SizedBox(height: 8),

            // Signal Strength Display
            _buildAccuracyRow(
              context,
              label: 'Signal Strength',
              valueText: signalStrengthInfo['text']!,
              numericValue: signalStrengthInfo['value']!,
            ),
            const SizedBox(height: 24),

            // Improve GPS Accuracy Section Title
            Text(
              'Improve GPS Accuracy',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTipRow(context, 'Move to an open area'),
            _buildTipRow(context, 'Avoid tall buildings'),
            _buildTipRow(context, 'Ensure clear sky view'),
            
            const Spacer(), // Pushes button to the bottom

            // Refresh Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // As per image
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, color: Colors.white),
                ),
                onPressed: () {
                  // Action for refresh, e.g., re-fetch location or simply update UI
                  // For a stream, just calling setState might be enough if new data is expected
                  // Or call a method on locationService if it supports manual refresh
                  setState(() {}); 
                },
                child: const Text('Refresh', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccuracyRow(BuildContext context, {required String label, required String valueText, required String numericValue}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            Text(valueText, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
          ],
        ),
        Text(numericValue, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }

  Widget _buildTipRow(BuildContext context, String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(tip, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
