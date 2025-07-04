// lib/services/timezone_service.dart

import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:intl/intl.dart';
import '../utils/constants.dart';

class TimezoneService {
  static final TimezoneService _instance = TimezoneService._internal();
  factory TimezoneService() => _instance;
  TimezoneService._internal();

  static TimezoneService get instance => _instance;

  String? _userTimezone;
  late tz.Location _userLocation;
  bool _initialized = false;

  /// Initialize the timezone service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone database
    tz_data.initializeTimeZones();
    
    // Set default timezone
    await setUserTimezone('Asia/Kuwait');
    
    _initialized = true;
  }

  /// Set the user's timezone (fetched from database based on manager)
  Future<void> setUserTimezone(String timezone) async {
    try {
      _userTimezone = timezone;
      _userLocation = tz.getLocation(timezone);
    } catch (e) {
      // Fallback to Kuwait timezone if invalid
      _userTimezone = 'Asia/Kuwait';
      _userLocation = tz.getLocation('Asia/Kuwait');
    }
  }

  /// Get user's current timezone
  String get userTimezone => _userTimezone ?? 'Asia/Kuwait';

  /// Get timezone location
  tz.Location get userLocation => _userLocation;

  /// Convert UTC DateTime to user's timezone
  DateTime utcToUserTime(DateTime utcDateTime) {
    if (!utcDateTime.isUtc) {
      // If not UTC, convert to UTC first
      utcDateTime = utcDateTime.toUtc();
    }
    final tzDateTime = tz.TZDateTime.from(utcDateTime, _userLocation);
    return tzDateTime;
  }

  /// Convert user's local time to UTC
  DateTime userTimeToUtc(DateTime localDateTime) {
    final tzDateTime = tz.TZDateTime.from(localDateTime, _userLocation);
    return tzDateTime.toUtc();
  }

  /// Get current time in user's timezone
  DateTime now() {
    return tz.TZDateTime.now(_userLocation);
  }

  /// Get current UTC time
  DateTime utcNow() {
    return DateTime.now().toUtc();
  }

  /// Format datetime for display in user's timezone
  String formatForDisplay(DateTime dateTime, {String pattern = 'MMM d, y - h:mm a'}) {
    final userTime = dateTime.isUtc ? utcToUserTime(dateTime) : dateTime;
    return DateFormat(pattern).format(userTime);
  }

  /// Format datetime with timezone suffix
  String formatWithTimezone(DateTime dateTime, {String pattern = 'MMM d, y - h:mm a'}) {
    final userTime = dateTime.isUtc ? utcToUserTime(dateTime) : dateTime;
    final formatted = DateFormat(pattern).format(userTime);
    final tzAbbr = _userLocation.currentTimeZone.abbreviation;
    return '$formatted $tzAbbr';
  }

  /// Parse ISO string to user's timezone
  DateTime parseToUserTime(String isoString) {
    final utcDateTime = DateTime.parse(isoString).toUtc();
    return utcToUserTime(utcDateTime);
  }

  /// Convert any DateTime to ISO string in UTC for database storage
  String toUtcIsoString(DateTime dateTime) {
    if (dateTime.isUtc) {
      return dateTime.toIso8601String();
    } else {
      // Assume it's in user's timezone and convert to UTC
      return userTimeToUtc(dateTime).toIso8601String();
    }
  }

  /// Fetch user's timezone from database
  Future<void> fetchUserTimezone() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase.rpc('get_user_timezone', params: {
        'user_id': user.id,
      });

      if (response != null) {
        await setUserTimezone(response as String);
      }
    } catch (e) {
      // Use default timezone on error
      await setUserTimezone('Asia/Kuwait');
    }
  }

  /// Get timezone display name
  String getTimezoneDisplayName() {
    final now = tz.TZDateTime.now(_userLocation);
    final offset = now.timeZoneOffset;
    final hours = (offset.inMinutes / 60).floor();
    final minutes = offset.inMinutes % 60;
    
    String sign = offset.isNegative ? '-' : '+';
    String hoursStr = hours.abs().toString().padLeft(2, '0');
    String minutesStr = minutes.toString().padLeft(2, '0');
    
    return 'UTC$sign$hoursStr:$minutesStr ($_userTimezone)';
  }

  /// Common timezone options for managers to choose from
  static const Map<String, String> commonTimezones = {
    'Asia/Kuwait': 'Kuwait (UTC+3)',
    'Asia/Riyadh': 'Saudi Arabia (UTC+3)',
    'Asia/Qatar': 'Qatar (UTC+3)',
    'Asia/Dubai': 'UAE (UTC+4)',
    'Asia/Bahrain': 'Bahrain (UTC+3)',
    'Asia/Muscat': 'Oman (UTC+4)',
    'Europe/London': 'United Kingdom (UTC+0/+1)',
    'America/New_York': 'US Eastern (UTC-5/-4)',
    'Asia/Dhaka': 'Bangladesh (UTC+6)',
    'Asia/Karachi': 'Pakistan (UTC+5)',
    'Africa/Cairo': 'Egypt (UTC+2/+3)',
    'Asia/Baghdad': 'Iraq (UTC+3)',
  };

  /// Validate timezone string
  static bool isValidTimezone(String timezone) {
    try {
      tz.getLocation(timezone);
      return true;
    } catch (e) {
      return false;
    }
  }
}