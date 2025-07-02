// lib/models/calendar_event.dart

class CalendarEvent {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String type; // 'campaign', 'task', or 'route_visit'

  CalendarEvent({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.type,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      type: json['type'] as String,
    );
  }

  // Helper to check if the event occurs on a specific day
  bool isSameDay(DateTime day) {
    // Normalize all dates to midnight to ignore time differences
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    final normalizedStart = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final normalizedEnd = DateTime.utc(endDate.year, endDate.month, endDate.day);

    return normalizedDay.isAtSameMomentAs(normalizedStart) ||
           normalizedDay.isAtSameMomentAs(normalizedEnd) ||
           (normalizedDay.isAfter(normalizedStart) && normalizedDay.isBefore(normalizedEnd));
  }
}