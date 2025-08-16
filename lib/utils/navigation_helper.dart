import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class NavigationHelper {
  /// Opens the device's default maps app with navigation to the specified location
  static Future<bool> navigateToLocation({
    required double latitude,
    required double longitude,
    String? placeName,
  }) async {
    try {
      // Create a descriptive label for the destination
      final label = placeName ?? 'Destination';
      
      Uri? uri;
      
      if (Platform.isIOS) {
        // For iOS, use Apple Maps URL scheme
        // This opens Apple Maps with the location and prompts for navigation
        uri = Uri.parse(
          'maps:?daddr=$latitude,$longitude&dirflg=d'
        );
      } else if (Platform.isAndroid) {
        // For Android, use Google Maps URL scheme
        // This opens Google Maps with navigation to the destination
        uri = Uri.parse(
          'google.navigation:q=$latitude,$longitude'
        );
      }
      
      // Try platform-specific URL first
      if (uri != null && await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
      
      // Fallback to universal geo scheme
      final geoUri = Uri.parse(
        'geo:$latitude,$longitude?q=$latitude,$longitude($label)'
      );
      
      if (await canLaunchUrl(geoUri)) {
        return await launchUrl(
          geoUri,
          mode: LaunchMode.externalApplication,
        );
      }
      
      // Final fallback to Google Maps web
      final webUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&destination_place_id=$label'
      );
      
      return await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      
    } catch (e) {
      debugPrint('Error launching navigation: $e');
      return false;
    }
  }
  
  /// Opens maps app showing the location without navigation (just view)
  static Future<bool> viewLocation({
    required double latitude,
    required double longitude,
    String? placeName,
  }) async {
    try {
      final label = placeName ?? 'Location';
      
      Uri? uri;
      
      if (Platform.isIOS) {
        // For iOS, use Apple Maps to just view the location
        uri = Uri.parse(
          'maps:?ll=$latitude,$longitude&q=$label'
        );
      } else if (Platform.isAndroid) {
        // For Android, use Google Maps to view the location
        uri = Uri.parse(
          'geo:$latitude,$longitude?q=$latitude,$longitude($label)'
        );
      }
      
      // Try platform-specific URL first
      if (uri != null && await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
      
      // Fallback to universal geo scheme
      final geoUri = Uri.parse(
        'geo:$latitude,$longitude?q=$latitude,$longitude($label)'
      );
      
      if (await canLaunchUrl(geoUri)) {
        return await launchUrl(
          geoUri,
          mode: LaunchMode.externalApplication,
        );
      }
      
      // Final fallback to Google Maps web
      final webUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
      );
      
      return await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      
    } catch (e) {
      debugPrint('Error launching maps: $e');
      return false;
    }
  }
}