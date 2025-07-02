// lib/screens/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/calendar_event.dart';
import '../models/campaign.dart';
import '../models/task.dart';
import '../models/place_visit.dart';
import '../utils/constants.dart';
import './campaigns/campaign_detail_screen.dart';
import './tasks/standalone_task_detail_screen.dart';
import './place_visit_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // State variables
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<CalendarEvent>> _eventsByDay = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchEventsForMonth(_focusedDay);
  }

  Future<void> _fetchEventsForMonth(DateTime date) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final firstDayOfMonth = DateTime(date.year, date.month, 1);
      final lastDayOfMonth = DateTime(date.year, date.month + 1, 0);

      // ========== THE FIX IS HERE: Call the correct function name ==========
      final response = await supabase.rpc('get_calendar_events', params: {
        'month_start': firstDayOfMonth.toIso8601String(),
        'month_end': lastDayOfMonth.toIso8601String(),
      });
      // =================================================================

      final allEvents = (response as List).map((e) => CalendarEvent.fromJson(e)).toList();
      
      final Map<DateTime, List<CalendarEvent>> events = {};
      for (final event in allEvents) {
        for (DateTime day = event.startDate; day.isBefore(event.endDate.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
          final normalizedDay = DateTime.utc(day.year, day.month, day.day);
          if (events[normalizedDay] == null) {
            events[normalizedDay] = [];
          }
          if (!events[normalizedDay]!.any((e) => e.id == event.id)) {
            events[normalizedDay]!.add(event);
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _eventsByDay = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to load calendar events: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return _eventsByDay[normalizedDay] ?? [];
  }

  Future<void> _navigateToEventDetail(CalendarEvent event) async {
    try {
      if (event.type == 'campaign') {
        final response = await supabase.from('campaigns').select().eq('id', event.id).single();
        if (!mounted) return;
        final campaign = Campaign.fromJson(response);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => CampaignDetailScreen(campaign: campaign),
        ));
      } else if (event.type == 'task') {
        final response = await supabase.from('tasks').select().eq('id', event.id).single();
        if (!mounted) return;
        final task = Task.fromJson(response);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => StandaloneTaskDetailScreen(task: task),
        ));
      } else if (event.type == 'route_visit') {
        final response = await supabase
            .from('place_visits')
            .select('''
              *,
              places!place_visits_place_id_fkey(*),
              route_assignments!place_visits_route_assignment_id_fkey(
                *,
                routes!route_assignments_route_id_fkey(*)
              )
            ''')
            .eq('id', event.id)
            .single();
        if (!mounted) return;
        final placeVisit = PlaceVisit.fromJson(response);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => PlaceVisitDetailScreen(placeVisit: placeVisit),
        ));
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to load event details: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events Calendar')),
      body: Column(
        children: [
          TableCalendar<CalendarEvent>(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            calendarStyle: CalendarStyle(
              markerDecoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: primaryColor.withAlpha(100), shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: primaryColor.withAlpha(200), shape: BoxShape.circle),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _fetchEventsForMonth(focusedDay);
            },
          ),
          const SizedBox(height: 8.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              _selectedDay != null ? "Events for ${DateFormat.yMMMd().format(_selectedDay!)}" : "Select a day",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading 
                ? preloader 
                : _buildEventList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final eventsForSelectedDay = _getEventsForDay(_selectedDay ?? _focusedDay);
    if (eventsForSelectedDay.isEmpty) {
      return const Center(child: Text("No events for this day."));
    }
    return ListView.builder(
      itemCount: eventsForSelectedDay.length,
      itemBuilder: (context, index) {
        final event = eventsForSelectedDay[index];
        final eventType = event.type;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Icon(
              _getEventIcon(eventType),
              color: _getEventColor(eventType),
            ),
            title: Text(event.title),
            subtitle: Text(
              'Type: ${eventType.isEmpty ? '' : eventType[0].toUpperCase() + eventType.substring(1)}'
            ),
            onTap: () => _navigateToEventDetail(event),
          ),
        );
      },
    );
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'campaign':
        return Icons.campaign;
      case 'task':
        return Icons.assignment;
      case 'route_visit':
        return Icons.location_on;
      default:
        return Icons.event;
    }
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'campaign':
        return Colors.blueAccent;
      case 'task':
        return Colors.orangeAccent;
      case 'route_visit':
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }
}