// Example: How to use TimezoneService in your app
// This file shows the pattern for converting timestamps using the new timezone service

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'lib/services/timezone_service.dart';

class TimezoneUsageExample {
  
  // BEFORE: Using DateTime.now() directly (local device time)
  static String oldWayTimestamp() {
    return DateTime.now().toIso8601String(); // Uses device timezone
  }
  
  // AFTER: Using TimezoneService for manager's timezone
  static String newWayTimestamp() {
    return TimezoneService.instance.toUtcIsoString(
      TimezoneService.instance.now() // Uses manager's timezone, converts to UTC for storage
    );
  }
  
  // BEFORE: Displaying timestamp (shows in device timezone)
  static String oldWayDisplay(String isoString) {
    final dateTime = DateTime.parse(isoString);
    return DateFormat('MMM d, y - h:mm a').format(dateTime);
  }
  
  // AFTER: Displaying timestamp in manager's timezone
  static String newWayDisplay(String isoString) {
    final dateTime = DateTime.parse(isoString);
    return TimezoneService.instance.formatForDisplay(dateTime);
  }
  
  // Example: Evidence submission with timezone
  static Map<String, dynamic> submitEvidenceWithTimezone() {
    return {
      'captured_at': TimezoneService.instance.toUtcIsoString(
        TimezoneService.instance.now()
      ),
      'user_id': 'user-id',
      'location': 'POINT(lat lng)',
    };
  }
  
  // Example: Calendar event with timezone awareness
  static Widget buildEventTile(Map<String, dynamic> event) {
    final eventDate = TimezoneService.instance.parseToUserTime(event['event_date']);
    final displayTime = TimezoneService.instance.formatWithTimezone(eventDate);
    
    return ListTile(
      title: Text(event['title']),
      subtitle: Text(displayTime), // Shows in manager's timezone with TZ suffix
    );
  }
  
  // Example: Location tracking with timezone
  static Future<void> saveLocationWithTimezone(double lat, double lng) async {
    // Save to database in UTC
    TimezoneService.instance.toUtcIsoString(
      TimezoneService.instance.now()
    );
    
    // Database stores in UTC, displays in manager's timezone
  }
}

// How to update existing code patterns:

/*
OLD PATTERN:
DateTime.now().toIso8601String()

NEW PATTERN:
TimezoneService.instance.toUtcIsoString(TimezoneService.instance.now())

---

OLD PATTERN:
DateFormat('MMM d, y - h:mm a').format(DateTime.parse(isoString))

NEW PATTERN:
TimezoneService.instance.formatForDisplay(DateTime.parse(isoString))

---

OLD PATTERN:
DateTime.now()

NEW PATTERN:
TimezoneService.instance.now()
*/