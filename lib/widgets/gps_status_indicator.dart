// lib/widgets/gps_status_indicator.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/smart_location_manager.dart';

class GpsStatusIndicator extends StatefulWidget {
  final SmartLocationManager locationManager;
  
  const GpsStatusIndicator({super.key, required this.locationManager});

  @override
  State<GpsStatusIndicator> createState() => _GpsStatusIndicatorState();
}

class _GpsStatusIndicatorState extends State<GpsStatusIndicator> {
  StreamSubscription<Position>? _locationSubscription;
  double? _currentAccuracy;
  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();
    _locationSubscription = widget.locationManager.locationStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentAccuracy = position.accuracy;
          _hasLocation = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Color _getGpsIconColor() {
    if (!_hasLocation || _currentAccuracy == null) {
      return Colors.red; // No GPS signal
    }
    
    int signalBars = _getSignalBars();
    
    if (signalBars == 1) {
      return Colors.red; // 1 bar - red
    } else if (signalBars <= 3) {
      return Colors.orange; // 2-3 bars - orange
    } else {
      return Colors.green; // 4-5 bars - green
    }
  }

  int _getSignalBars() {
    if (!_hasLocation || _currentAccuracy == null) {
      return 1; // No signal = 1 bar
    }
    
    // Signal strength based on accuracy (lower accuracy = better signal)
    if (_currentAccuracy! <= 10) {
      return 5; // Excellent - 5 bars
    } else if (_currentAccuracy! <= 25) {
      return 4; // Good - 4 bars
    } else if (_currentAccuracy! <= 100) {
      return 3; // Fair - 3 bars (100m = 3 bars as requested)
    } else if (_currentAccuracy! <= 200) {
      return 2; // Poor - 2 bars
    } else {
      return 1; // Very poor - 1 bar
    }
  }

  String _getStatusText() {
    if (!_hasLocation || _currentAccuracy == null) {
      return 'No GPS signal (1 bar)';
    }
    
    int bars = _getSignalBars();
    String accuracy = _currentAccuracy!.toStringAsFixed(0);
    
    switch (bars) {
      case 5:
        return 'Excellent GPS (${accuracy}m) - 5 bars';
      case 4:
        return 'Good GPS (${accuracy}m) - 4 bars';
      case 3:
        return 'Fair GPS (${accuracy}m) - 3 bars';
      case 2:
        return 'Poor GPS (${accuracy}m) - 2 bars';
      case 1:
      default:
        return 'Very poor GPS (${accuracy}m) - 1 bar';
    }
  }

  Widget _buildSignalBars() {
    int bars = _getSignalBars();
    Color iconColor = _getGpsIconColor();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        bool isActive = index < bars;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 0.5),
          width: 2,
          height: 4 + (index * 2.0), // Increasing height for each bar
          decoration: BoxDecoration(
            color: isActive ? iconColor : Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Show GPS status details when tapped
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getStatusText()),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.satellite_alt_outlined,
              color: _getGpsIconColor(),
              size: 20,
            ),
            const SizedBox(width: 6),
            _buildSignalBars(),
          ],
        ),
      ),
    );
  }
}