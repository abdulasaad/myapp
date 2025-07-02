// lib/screens/agent/agent_route_detail_screen.dart

import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../models/route_assignment.dart';
import '../../models/place_visit.dart';
import '../../models/route_place.dart';
import '../../widgets/route_evidence_upload_dialog.dart';
import '../../widgets/modern_notification.dart';

class AgentRouteDetailScreen extends StatefulWidget {
  final RouteAssignment routeAssignment;

  const AgentRouteDetailScreen({
    super.key,
    required this.routeAssignment,
  });

  @override
  State<AgentRouteDetailScreen> createState() => _AgentRouteDetailScreenState();
}

class _AgentRouteDetailScreenState extends State<AgentRouteDetailScreen> {
  bool _isLoading = true;
  List<RoutePlace> _routePlaces = [];
  Map<String, PlaceVisit?> _placeVisits = {};
  PlaceVisit? _currentActiveVisit;
  Map<String, int> _evidenceCounts = {}; // placeVisitId -> evidence count

  @override
  void initState() {
    super.initState();
    _loadRouteDetails();
  }

  Future<void> _loadRouteDetails() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Load route places with place details
      final routePlacesResponse = await supabase
          .from('route_places')
          .select('*')
          .eq('route_id', widget.routeAssignment.routeId)
          .order('visit_order');

      List<RoutePlace> routePlaces = [];
      
      for (var json in routePlacesResponse) {
        try {
          // Get place details separately
          if (json['place_id'] != null) {
            final placeResponse = await supabase
                .from('places')
                .select('*')
                .eq('id', json['place_id'])
                .maybeSingle();
            
            if (placeResponse != null) {
              json['places'] = placeResponse;
            }
          }
          
          final routePlace = RoutePlace.fromJson(json);
          routePlaces.add(routePlace);
        } catch (e) {
          print('Error parsing route place: $e');
        }
      }

      // Load existing place visits for this route assignment
      final placeVisitsResponse = await supabase
          .from('place_visits')
          .select('*')
          .eq('route_assignment_id', widget.routeAssignment.id)
          .eq('agent_id', currentUser.id);

      Map<String, PlaceVisit?> placeVisits = {};
      PlaceVisit? currentActiveVisit;

      for (var visitJson in placeVisitsResponse) {
        try {
          // Get place details separately for visits
          if (visitJson['place_id'] != null) {
            final placeResponse = await supabase
                .from('places')
                .select('*')
                .eq('id', visitJson['place_id'])
                .maybeSingle();
            
            if (placeResponse != null) {
              visitJson['places'] = placeResponse;
            }
          }
          
          final visit = PlaceVisit.fromJson(visitJson);
          placeVisits[visit.placeId] = visit;
          
          if (visit.status == 'checked_in') {
            currentActiveVisit = visit;
          }
        } catch (e) {
          print('Error parsing place visit: $e');
        }
      }

      // Load evidence counts for each place visit
      await _loadEvidenceCounts();

      setState(() {
        _routePlaces = routePlaces;
        _placeVisits = placeVisits;
        _currentActiveVisit = currentActiveVisit;
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ModernNotification.error(
          context,
          message: 'Error loading route details',
          subtitle: e.toString(),
        );
      }
    }
  }

  Future<void> _loadEvidenceCounts() async {
    try {
      final evidenceCounts = <String, int>{};
      
      // Get evidence counts for all place visits
      for (final visit in _placeVisits.values) {
        if (visit != null) {
          final count = await supabase
              .from('evidence')
              .select('id')
              .eq('place_visit_id', visit.id);
              // Count all evidence, not just approved
          
          evidenceCounts[visit.id] = count.length;
        }
      }
      
      setState(() {
        _evidenceCounts = evidenceCounts;
      });
    } catch (e) {
      print('Error loading evidence counts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.routeAssignment.route?.name ?? 'Route Details'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildRouteContent(),
    );
  }

  Widget _buildRouteContent() {
    if (_routePlaces.isEmpty) {
      return const Center(
        child: Text('No places found in this route'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRouteDetails,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentActiveVisit != null)
              _buildCurrentVisitCard(),
            
            const SizedBox(height: 16),
            
            _buildRouteProgress(),
            
            const SizedBox(height: 24),
            
            const Text(
              'Places to Visit',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            
            const SizedBox(height: 16),
            
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _routePlaces.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final routePlace = _routePlaces[index];
                final visit = _placeVisits[routePlace.placeId];
                final isNext = _getNextPlaceIndex() == index;
                
                return _buildPlaceCard(routePlace, visit, index, isNext);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentVisitCard() {
    final visit = _currentActiveVisit!;
    final place = visit.place;
    final routePlace = _routePlaces.firstWhere(
      (rp) => rp.placeId == visit.placeId,
      orElse: () => RoutePlace(
        routeId: widget.routeAssignment.routeId,
        placeId: visit.placeId,
        visitOrder: 1,
        estimatedDurationMinutes: 30,
        requiredEvidenceCount: 1,
        createdAt: DateTime.now(),
      ),
    );
    final currentEvidenceCount = _evidenceCounts[visit.id] ?? 0;
    final requiredEvidenceCount = routePlace.requiredEvidenceCount;
    final hasEnoughEvidence = currentEvidenceCount >= requiredEvidenceCount;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.access_time,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACTIVE VISIT',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place?.name ?? 'Loading...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Time and Evidence Progress
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timer, color: Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Time Spent',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getVisitDuration(visit),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.camera_alt, color: Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Evidence',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$currentEvidenceCount / $requiredEvidenceCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addEvidence(visit),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.camera_alt, size: 20),
                  label: Text(
                    'Evidence ($currentEvidenceCount/$requiredEvidenceCount)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _checkOut(visit),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.exit_to_app, size: 20),
                  label: const Text(
                    'Check Out',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteProgress() {
    final completedCount = _placeVisits.values
        .where((visit) => visit?.status == 'completed')
        .length;
    final totalCount = _routePlaces.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Route Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
              Text(
                '$completedCount / $totalCount',
                style: TextStyle(
                  fontSize: 14,
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}% Complete',
            style: const TextStyle(
              fontSize: 12,
              color: textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(RoutePlace routePlace, PlaceVisit? visit, int index, bool isNext) {
    final place = routePlace.place;
    final isCompleted = visit?.status == 'completed';
    final isCheckedIn = visit?.status == 'checked_in';
    final canCheckIn = !isCheckedIn && _currentActiveVisit == null && isNext;
    
    Color cardColor;
    Color textColor;
    IconData statusIcon;
    
    if (isCompleted) {
      cardColor = Colors.green[50]!;
      textColor = Colors.green[700]!;
      statusIcon = Icons.check_circle;
    } else if (isCheckedIn) {
      cardColor = Colors.white;
      textColor = Colors.blue[700]!;
      statusIcon = Icons.access_time;
    } else if (canCheckIn) {
      cardColor = Colors.orange[50]!;
      textColor = Colors.orange[700]!;
      statusIcon = Icons.play_circle;
    } else {
      cardColor = Colors.grey[50]!;
      textColor = Colors.grey[600]!;
      statusIcon = Icons.radio_button_unchecked;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCheckedIn ? Colors.blue : textColor.withValues(alpha: 0.3),
          width: isCheckedIn ? 3 : 2,
        ),
        boxShadow: [
          if (isCheckedIn)
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: shadowColor,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: textColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place?.name ?? 'Loading...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (place?.address?.isNotEmpty == true)
                        Text(
                          place!.address!,
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(statusIcon, color: textColor, size: 28),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: textColor),
                const SizedBox(width: 4),
                Text(
                  '${routePlace.estimatedDurationMinutes} min',
                  style: TextStyle(fontSize: 12, color: textColor),
                ),
                const SizedBox(width: 16),
                Icon(Icons.camera_alt, size: 16, color: textColor),
                const SizedBox(width: 4),
                Text(
                  _buildEvidenceText(routePlace, visit),
                  style: TextStyle(fontSize: 12, color: textColor),
                ),
              ],
            ),
            
            if (routePlace.instructions?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        routePlace.instructions!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (visit != null && visit.visitNotes?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Notes: ${visit.visitNotes}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            if (canCheckIn)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _checkIn(routePlace),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.play_circle),
                  label: const Text('Check In'),
                ),
              )
            else if (isCheckedIn && visit != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Currently Active - See top card for actions',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else if (isCompleted && visit != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Completed${visit.formattedDuration.isNotEmpty ? " (${visit.formattedDuration})" : ""}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isNext ? 'Complete previous places first' : 'Waiting...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _getNextPlaceIndex() {
    for (int i = 0; i < _routePlaces.length; i++) {
      final placeId = _routePlaces[i].placeId;
      final visit = _placeVisits[placeId];
      if (visit == null || visit.status == 'pending') {
        return i;
      }
    }
    return -1; // All completed
  }

  String _buildEvidenceText(RoutePlace routePlace, PlaceVisit? visit) {
    if (visit == null) {
      return '${routePlace.requiredEvidenceCount} evidence required';
    }
    
    final currentCount = _evidenceCounts[visit.id] ?? 0;
    final requiredCount = routePlace.requiredEvidenceCount;
    
    if (currentCount >= requiredCount) {
      return '$currentCount/$requiredCount evidence ✓';
    } else {
      return '$currentCount/$requiredCount evidence';
    }
  }

  String _getVisitDuration(PlaceVisit visit) {
    if (visit.checkedInAt != null) {
      final duration = DateTime.now().difference(visit.checkedInAt!);
      final minutes = duration.inMinutes;
      final hours = duration.inHours;
      
      if (hours > 0) {
        return '${hours}h ${minutes % 60}m';
      } else {
        return '${minutes}m';
      }
    }
    return '';
  }

  Future<void> _checkIn(RoutePlace routePlace) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Check if there's already an active visit
      if (_currentActiveVisit != null) {
        ModernNotification.warning(
          context,
          message: 'Already checked in',
          subtitle: 'Please check out from current place first',
        );
        return;
      }

      // Create a new place visit
      await supabase.from('place_visits').insert({
        'route_assignment_id': widget.routeAssignment.id,
        'place_id': routePlace.placeId,
        'agent_id': currentUser.id,
        'checked_in_at': DateTime.now().toIso8601String(),
        'status': 'checked_in',
        'check_in_latitude': 0.0,
        'check_in_longitude': 0.0,
      });

      // If this is the first check-in, update route assignment status
      if (widget.routeAssignment.status == 'assigned') {
        await supabase.from('route_assignments').update({
          'status': 'in_progress',
          'started_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.routeAssignment.id);
      }

      ModernNotification.success(
        context,
        message: 'Checked in successfully!',
        subtitle: 'Visit started',
      );
      _loadRouteDetails(); // Refresh data

    } catch (e) {
      ModernNotification.error(
        context,
        message: 'Error checking in',
        subtitle: e.toString(),
      );
    }
  }

  Future<void> _checkOut(PlaceVisit visit) async {
    try {
      // Update the place visit to completed
      await supabase.from('place_visits').update({
        'checked_out_at': DateTime.now().toIso8601String(),
        'status': 'completed',
        'check_out_latitude': 0.0,
        'check_out_longitude': 0.0,
      }).eq('id', visit.id);

      // Check if this was the last place to complete the route
      await _checkAndUpdateRouteCompletion();

      ModernNotification.success(
        context,
        message: 'Checked out successfully!',
        subtitle: 'Place visit completed',
      );
      
      _loadRouteDetails(); // Refresh data

    } catch (e) {
      ModernNotification.error(
        context,
        message: 'Error checking out',
        subtitle: e.toString(),
      );
    }
  }

  Future<void> _checkAndUpdateRouteCompletion() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Get all place visits for this route assignment
      final allVisitsResponse = await supabase
          .from('place_visits')
          .select('id, status')
          .eq('route_assignment_id', widget.routeAssignment.id)
          .eq('agent_id', currentUser.id);

      // Check if all places have been visited (should match the number of route places)
      final completedVisits = allVisitsResponse.where((v) => v['status'] == 'completed').length;
      final totalPlaces = _routePlaces.length;

      print('Completed visits: $completedVisits, Total places: $totalPlaces');

      // If all places are completed, update route assignment status
      if (completedVisits >= totalPlaces) {
        await supabase.from('route_assignments').update({
          'status': 'completed',
          'completed_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.routeAssignment.id);

        print('Route assignment marked as completed');
        
        ModernNotification.success(
          context,
          message: 'Route completed!',
          subtitle: 'All places visited successfully',
        );
      }
    } catch (e) {
      print('Error checking route completion: $e');
    }
  }

  void _addEvidence(PlaceVisit visit) async {
    // Find the route place for this visit
    final routePlace = _routePlaces.firstWhere(
      (rp) => rp.placeId == visit.placeId,
      orElse: () => RoutePlace(
        routeId: widget.routeAssignment.routeId,
        placeId: visit.placeId,
        visitOrder: 1,
        estimatedDurationMinutes: 30,
        requiredEvidenceCount: 1,
        createdAt: DateTime.now(),
      ),
    );

    // Get current evidence count
    final currentCount = _evidenceCounts[visit.id] ?? 0;

    // Show evidence upload dialog
    final uploaded = await showDialog<bool>(
      context: context,
      builder: (context) => RouteEvidenceUploadDialog(
        placeVisit: visit,
        routePlace: routePlace,
        requiredEvidenceCount: routePlace.requiredEvidenceCount,
        currentEvidenceCount: currentCount,
      ),
    );

    // Refresh data if evidence was uploaded
    if (uploaded == true) {
      await _loadEvidenceCounts();
      setState(() {}); // Trigger rebuild to show updated evidence counts
    }
  }
}