// lib/screens/place_visit_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/place_visit.dart';
import '../utils/constants.dart';

class PlaceVisitDetailScreen extends StatefulWidget {
  final PlaceVisit placeVisit;

  const PlaceVisitDetailScreen({
    super.key,
    required this.placeVisit,
  });

  @override
  State<PlaceVisitDetailScreen> createState() => _PlaceVisitDetailScreenState();
}

class _PlaceVisitDetailScreenState extends State<PlaceVisitDetailScreen> {
  late PlaceVisit _placeVisit;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _placeVisit = widget.placeVisit;
    _loadFullPlaceVisitDetails();
  }

  Future<void> _loadFullPlaceVisitDetails() async {
    setState(() => _isLoading = true);
    
    try {
      // Load complete place visit details with place and route assignment info
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
          .eq('id', _placeVisit.id)
          .single();

      setState(() {
        _placeVisit = PlaceVisit.fromJson(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showSnackBar('Error loading place visit details: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Place Visit Details'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPlaceInfoCard(),
                  const SizedBox(height: 16),
                  _buildVisitStatusCard(),
                  const SizedBox(height: 16),
                  _buildVisitTimingCard(),
                  const SizedBox(height: 16),
                  _buildRouteInfoCard(),
                  if (_placeVisit.visitNotes?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    _buildNotesCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPlaceInfoCard() {
    final place = _placeVisit.place;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Place Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              place?.name ?? 'Unknown Place',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            if (place?.address?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                place!.address!,
                style: const TextStyle(
                  fontSize: 14,
                  color: textSecondaryColor,
                ),
              ),
            ],
            if (place != null) ...[
              const SizedBox(height: 8),
              Text(
                'Coordinates: ${place.latitude.toStringAsFixed(6)}, ${place.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: textSecondaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVisitStatusCard() {
    final statusColor = _getStatusColor(_placeVisit.status);
    final statusIcon = _getStatusIcon(_placeVisit.status);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Visit Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(51),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _placeVisit.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        _getStatusDescription(_placeVisit.status),
                        style: const TextStyle(
                          fontSize: 14,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitTimingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Visit Timing',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimingRow('Check-in:', _placeVisit.checkedInAt),
            const SizedBox(height: 8),
            _buildTimingRow('Check-out:', _placeVisit.checkedOutAt),
            if (_placeVisit.durationMinutes != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer, size: 16, color: textSecondaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Duration: ${_placeVisit.formattedDuration}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: textPrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimingRow(String label, DateTime? dateTime) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: textSecondaryColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            dateTime != null
                ? DateFormat('MMM d, y - h:mm a').format(dateTime)
                : 'Not yet',
            style: const TextStyle(
              fontSize: 14,
              color: textPrimaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteInfoCard() {
    final routeAssignment = _placeVisit.routeAssignment;
    final route = routeAssignment?.route;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Route Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              route?.name ?? 'Unknown Route',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            if (route?.description?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                route!.description!,
                style: const TextStyle(
                  fontSize: 14,
                  color: textSecondaryColor,
                ),
              ),
            ],
            if (routeAssignment != null) ...[
              const SizedBox(height: 8),
              Text(
                'Assigned: ${DateFormat('MMM d, y').format(routeAssignment.assignedAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: textSecondaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, color: primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Visit Notes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _placeVisit.visitNotes!,
              style: const TextStyle(
                fontSize: 14,
                color: textPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'checked_in':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'skipped':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'checked_in':
        return Icons.login;
      case 'completed':
        return Icons.check_circle;
      case 'skipped':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Visit has not started yet';
      case 'checked_in':
        return 'Currently at the location';
      case 'completed':
        return 'Visit completed successfully';
      case 'skipped':
        return 'Visit was skipped';
      default:
        return 'Unknown status';
    }
  }
}