// lib/services/smart_defaults_service.dart

import 'package:flutter/material.dart';
import '../services/location_service.dart';

class SmartDefaultsService {
  static final SmartDefaultsService _instance = SmartDefaultsService._internal();
  factory SmartDefaultsService() => _instance;
  SmartDefaultsService._internal();

  // Cache for frequently used defaults
  final Map<String, dynamic> _cache = {};

  /// Auto-suggest task titles based on location and time
  Future<List<String>> suggestTaskTitles(String? locationName) async {
    final hour = DateTime.now().hour;
    final suggestions = <String>[];
    
    // Time-based suggestions
    if (hour >= 6 && hour < 12) {
      suggestions.addAll([
        'Morning Inspection',
        'Opening Checklist',
        'Equipment Status Check',
        'Daily Setup',
      ]);
    } else if (hour >= 12 && hour < 18) {
      suggestions.addAll([
        'Afternoon Review',
        'Quality Control Check',
        'Customer Service Visit',
        'Progress Documentation',
      ]);
    } else {
      suggestions.addAll([
        'End of Day Report',
        'Closing Checklist',
        'Security Check',
        'Equipment Shutdown',
      ]);
    }
    
    // Location-based suggestions
    if (locationName != null) {
      final location = locationName.toLowerCase();
      if (location.contains('office')) {
        suggestions.addAll([
          'Office Documentation',
          'Administrative Review',
          'Meeting Follow-up',
        ]);
      } else if (location.contains('site') || location.contains('field')) {
        suggestions.addAll([
          'Site Inspection',
          'Field Assessment',
          'Safety Verification',
        ]);
      } else if (location.contains('store') || location.contains('shop')) {
        suggestions.addAll([
          'Store Audit',
          'Inventory Check',
          'Customer Experience Review',
        ]);
      }
    }
    
    return suggestions.take(5).toList();
  }

  /// Auto-generate task descriptions based on title
  String generateTaskDescription(String title) {
    final titleLower = title.toLowerCase();
    
    if (titleLower.contains('inspection')) {
      return 'Perform a thorough inspection of the designated area. Document any issues found and take photographic evidence. Report findings to supervisor.';
    } else if (titleLower.contains('checklist')) {
      return 'Complete the required checklist items. Verify all steps are properly executed and document completion with evidence.';
    } else if (titleLower.contains('audit')) {
      return 'Conduct a comprehensive audit following established protocols. Review all relevant areas and document findings with supporting evidence.';
    } else if (titleLower.contains('safety')) {
      return 'Verify all safety protocols are being followed. Check equipment, procedures, and compliance. Report any safety concerns immediately.';
    } else if (titleLower.contains('documentation')) {
      return 'Complete required documentation tasks. Ensure all forms are properly filled out and supporting evidence is collected.';
    } else {
      return 'Complete the assigned task according to established procedures. Document completion with appropriate evidence.';
    }
  }

  /// Smart point calculation based on task complexity
  int calculateSmartPoints(String title, String? description, bool hasGeofence, int evidenceCount) {
    int points = 10; // Base points
    
    // Complexity based on title
    final titleLower = title.toLowerCase();
    if (titleLower.contains('inspection') || titleLower.contains('audit')) {
      points += 15;
    } else if (titleLower.contains('documentation') || titleLower.contains('report')) {
      points += 10;
    } else if (titleLower.contains('checklist')) {
      points += 5;
    }
    
    // Complexity based on description length
    if (description != null && description.length > 100) {
      points += 5;
    }
    
    // Geofence requirement adds complexity
    if (hasGeofence) {
      points += 10;
    }
    
    // Evidence requirement complexity
    points += evidenceCount * 3;
    
    // Round to nearest 5
    return ((points / 5).round() * 5).clamp(5, 100);
  }

  /// Auto-suggest evidence requirements based on task type
  int suggestEvidenceCount(String title) {
    final titleLower = title.toLowerCase();
    
    if (titleLower.contains('inspection') || titleLower.contains('audit')) {
      return 3; // Multiple angles/areas
    } else if (titleLower.contains('documentation') || titleLower.contains('report')) {
      return 2; // Document + completion proof
    } else if (titleLower.contains('checklist')) {
      return 1; // Completed checklist
    } else {
      return 1; // Standard evidence
    }
  }

  /// Smart geofence radius based on location type
  double suggestGeofenceRadius(String? locationName) {
    if (locationName == null) return 100.0; // Default 100m
    
    final location = locationName.toLowerCase();
    
    if (location.contains('building') || location.contains('office')) {
      return 50.0; // Small radius for buildings
    } else if (location.contains('site') || location.contains('construction')) {
      return 200.0; // Larger radius for construction sites
    } else if (location.contains('warehouse') || location.contains('facility')) {
      return 150.0; // Medium radius for facilities
    } else if (location.contains('store') || location.contains('shop')) {
      return 75.0; // Small-medium radius for retail
    } else {
      return 100.0; // Default radius
    }
  }

  /// Auto-populate location name based on current position
  Future<String?> suggestLocationName() async {
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();
      
      if (position != null) {
        // In a real app, you'd use reverse geocoding here
        // For now, return a generic location based on coordinates
        return 'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
      }
    } catch (e) {
      debugPrint('Error getting location suggestion: $e');
    }
    
    return null;
  }

  /// Smart campaign duration based on task count and complexity
  Duration suggestCampaignDuration(int taskCount, List<String> taskTitles) {
    int baseDays = taskCount * 2; // 2 days per task base
    
    // Add complexity based on task types
    int complexityBonus = 0;
    for (final title in taskTitles) {
      final titleLower = title.toLowerCase();
      if (titleLower.contains('inspection') || titleLower.contains('audit')) {
        complexityBonus += 2;
      } else if (titleLower.contains('documentation')) {
        complexityBonus += 1;
      }
    }
    
    final totalDays = (baseDays + complexityBonus).clamp(7, 90); // 1 week to 3 months
    return Duration(days: totalDays);
  }

  /// Auto-save user preferences for future suggestions
  void saveUserPreference(String key, dynamic value) {
    _cache[key] = value;
    // In a real app, you'd persist this to local storage or database
  }

  /// Get cached user preferences
  T? getUserPreference<T>(String key) {
    return _cache[key] as T?;
  }

  /// Smart template field suggestions based on industry/type
  List<Map<String, dynamic>> suggestTemplateFields(String taskType) {
    final taskTypeLower = taskType.toLowerCase();
    
    if (taskTypeLower.contains('inspection')) {
      return [
        {
          'label': 'Overall Condition',
          'type': 'dropdown',
          'options': ['Excellent', 'Good', 'Fair', 'Poor', 'Critical'],
          'required': true,
        },
        {
          'label': 'Issues Found',
          'type': 'textarea',
          'required': false,
        },
        {
          'label': 'Inspector Name',
          'type': 'text',
          'required': true,
        },
        {
          'label': 'Inspection Date',
          'type': 'date',
          'required': true,
        },
      ];
    } else if (taskTypeLower.contains('audit')) {
      return [
        {
          'label': 'Compliance Status',
          'type': 'dropdown',
          'options': ['Compliant', 'Non-Compliant', 'Needs Review'],
          'required': true,
        },
        {
          'label': 'Findings',
          'type': 'textarea',
          'required': true,
        },
        {
          'label': 'Auditor',
          'type': 'text',
          'required': true,
        },
      ];
    } else if (taskTypeLower.contains('safety')) {
      return [
        {
          'label': 'Safety Level',
          'type': 'dropdown',
          'options': ['Safe', 'Caution', 'Unsafe', 'Critical'],
          'required': true,
        },
        {
          'label': 'Safety Concerns',
          'type': 'textarea',
          'required': false,
        },
        {
          'label': 'PPE Verified',
          'type': 'checkbox',
          'required': true,
        },
      ];
    } else {
      return [
        {
          'label': 'Status',
          'type': 'dropdown',
          'options': ['Completed', 'In Progress', 'Pending'],
          'required': true,
        },
        {
          'label': 'Notes',
          'type': 'textarea',
          'required': false,
        },
        {
          'label': 'Completed By',
          'type': 'text',
          'required': true,
        },
      ];
    }
  }

  /// Auto-schedule optimal task times based on location and type
  DateTime suggestOptimalStartTime(String taskType, String? locationName) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    
    final taskTypeLower = taskType.toLowerCase();
    
    // Morning tasks (8 AM)
    if (taskTypeLower.contains('inspection') || 
        taskTypeLower.contains('opening') ||
        taskTypeLower.contains('setup')) {
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 0);
    }
    
    // Afternoon tasks (2 PM)
    if (taskTypeLower.contains('review') || 
        taskTypeLower.contains('audit')) {
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 14, 0);
    }
    
    // Evening tasks (5 PM)
    if (taskTypeLower.contains('closing') || 
        taskTypeLower.contains('end') ||
        taskTypeLower.contains('shutdown')) {
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 17, 0);
    }
    
    // Default to 9 AM next day
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
  }

  /// Smart reminder intervals based on task urgency
  List<Duration> suggestReminderIntervals(DateTime dueDate, String taskType) {
    final now = DateTime.now();
    final timeUntilDue = dueDate.difference(now);
    final taskTypeLower = taskType.toLowerCase();
    
    final reminders = <Duration>[];
    
    // Critical tasks get more frequent reminders
    final isCritical = taskTypeLower.contains('safety') || 
                      taskTypeLower.contains('critical') ||
                      taskTypeLower.contains('urgent');
    
    if (timeUntilDue.inDays > 7) {
      reminders.add(const Duration(days: 7)); // 1 week before
      reminders.add(const Duration(days: 3)); // 3 days before
    }
    
    if (timeUntilDue.inDays > 1) {
      reminders.add(const Duration(days: 1)); // 1 day before
    }
    
    if (timeUntilDue.inHours > 4) {
      reminders.add(const Duration(hours: 4)); // 4 hours before
    }
    
    if (isCritical && timeUntilDue.inHours > 1) {
      reminders.add(const Duration(hours: 1)); // 1 hour before for critical tasks
    }
    
    return reminders;
  }
}