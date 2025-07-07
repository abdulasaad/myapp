// lib/screens/manager/route_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import '../../models/route.dart' as route_model;
import '../../models/route_place.dart';
import '../../models/place.dart';
import '../admin/evidence_detail_screen.dart';
import '../full_screen_image_viewer.dart';
import '../../widgets/modern_notification.dart';

class RouteDetailScreen extends StatefulWidget {
  final route_model.Route route;

  const RouteDetailScreen({
    super.key,
    required this.route,
  });

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  late route_model.Route _route;
  bool _isLoading = false;
  List<RoutePlace> _routePlaces = [];
  List<Map<String, dynamic>> _assignedAgents = []; // Agent assignments with progress

  @override
  void initState() {
    super.initState();
    _route = widget.route;
    _loadRouteDetails();
  }

  Future<void> _loadRouteDetails() async {
    setState(() => _isLoading = true);
    
    try {
      // Load route places with place details and assigned agents in parallel
      final results = await Future.wait([
        _loadRoutePlaces(),
        _loadAssignedAgents(),
      ]);
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ModernNotification.error(context, message: 'Error loading route details', subtitle: e.toString());
      }
    }
  }

  Future<void> _loadRoutePlaces() async {
    // Load route places with place details
    print('Loading route places for manager route ID: ${_route.id}');
    
    final routePlacesResponse = await supabase
        .from('route_places')
        .select('*')
        .eq('route_id', _route.id)
        .order('visit_order');

    print('Manager route places response: $routePlacesResponse');
    print('Manager route places count: ${routePlacesResponse.length}');

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
        print('Error parsing manager route place: $e');
        print('JSON data: $json');
      }
    }

    setState(() {
      _routePlaces = routePlaces;
    });
  }

  Future<void> _loadAssignedAgents() async {
    // Load route assignments with agent details and visit progress
    print('Loading assigned agents for route ${_route.id}');
    final assignmentsResponse = await supabase
        .from('route_assignments')
        .select('''
          id, status, assigned_at, started_at, completed_at,
          agent_id
        ''')
        .eq('route_id', _route.id)
        .order('assigned_at', ascending: false);
    
    print('Found ${assignmentsResponse.length} assignments for route ${_route.id}');

    List<Map<String, dynamic>> agentsWithProgress = [];

    for (var assignment in assignmentsResponse) {
      try {
        // Get agent profile data
        final agentProfileResponse = await supabase
            .from('profiles')
            .select('id, full_name, email')
            .eq('id', assignment['agent_id'])
            .maybeSingle();
        
        if (agentProfileResponse == null) {
          print('No profile found for agent_id: ${assignment['agent_id']}');
          continue;
        }

        // Get visit progress for this agent
        final visitProgressResponse = await supabase
            .from('place_visits')
            .select('''
              id, place_id, status, checked_in_at, checked_out_at, duration_minutes, visit_notes
            ''')
            .eq('route_assignment_id', assignment['id'])
            .eq('agent_id', assignment['agent_id'])
            .order('checked_in_at', ascending: true);

        // Load evidence files for each visit
        List<Map<String, dynamic>> visitsWithEvidence = [];
        for (var visit in visitProgressResponse) {
          // Get place name for each visit
          if (visit['place_id'] != null) {
            final placeResponse = await supabase
                .from('places')
                .select('name')
                .eq('id', visit['place_id'])
                .maybeSingle();
            visit['places'] = placeResponse;
          }

          final evidenceResponse = await supabase
              .from('evidence')
              .select('id, title, file_url, mime_type, status, created_at')
              .eq('place_visit_id', visit['id'])
              .order('created_at', ascending: false);
          
          visit['evidence_files'] = evidenceResponse;
          visitsWithEvidence.add(visit);
        }

        // Calculate progress statistics
        final totalPlaces = _routePlaces.length;
        final completedVisits = visitProgressResponse.where((v) => v['status'] == 'completed').length;
        final inProgressVisits = visitProgressResponse.where((v) => v['status'] == 'checked_in').length;
        final totalTimeSpent = visitProgressResponse
            .where((v) => v['duration_minutes'] != null)
            .fold<int>(0, (sum, v) => sum + (v['duration_minutes'] as int? ?? 0));

        agentsWithProgress.add({
          'assignment_id': assignment['id'],
          'agent_id': assignment['agent_id'],
          'agent_name': agentProfileResponse['full_name'] ?? 'Unknown Agent',
          'agent_email': agentProfileResponse['email'] ?? '',
          'assignment_status': assignment['status'],
          'assigned_at': assignment['assigned_at'],
          'started_at': assignment['started_at'],
          'completed_at': assignment['completed_at'],
          'total_places': totalPlaces,
          'completed_visits': completedVisits,
          'in_progress_visits': inProgressVisits,
          'total_time_spent_minutes': totalTimeSpent,
          'visits': visitsWithEvidence,
          'progress_percentage': totalPlaces > 0 ? (completedVisits / totalPlaces * 100).round() : 0,
        });
      } catch (e) {
        print('Error loading progress for agent ${assignment['agent_id']}: $e');
      }
    }

    setState(() {
      _assignedAgents = agentsWithProgress;
      print('Loaded ${_assignedAgents.length} agents with progress');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(_route.name),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRouteHeader(),
                  const SizedBox(height: 16),
                  _buildRouteStats(),
                  const SizedBox(height: 16),
                  _buildAssignedAgentsSection(),
                  const SizedBox(height: 16),
                  _buildPlacesList(),
                ],
              ),
            ),
      floatingActionButton: _route.status != 'archived'
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Add Place FAB
                FloatingActionButton(
                  onPressed: _addPlaceToRoute,
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  heroTag: "add_place",
                  child: const Icon(Icons.add_location),
                ),
                const SizedBox(height: 10),
                // Assign Agents FAB (only for active routes)
                if (_route.status == 'active')
                  FloatingActionButton.extended(
                    onPressed: _assignToAgents,
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    heroTag: "assign_agents",
                    icon: const Icon(Icons.person_add),
                    label: const Text('Assign to Agents'),
                  ),
              ],
            )
          : null,
    );
  }

  Future<void> _addPlaceToRoute() async {
    try {
      // Get current user's available places
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Get manager's groups
      final managerGroups = await supabase
          .from('user_groups')
          .select('group_id')
          .eq('user_id', currentUser.id);

      if (managerGroups.isEmpty) {
        if (mounted) {
          ModernNotification.error(context, message: 'No groups found for this manager');
        }
        return;
      }

      final groupIds = managerGroups.map((g) => g['group_id']).toList();

      // Get agents in manager's groups
      final agentsInGroups = await supabase
          .from('user_groups')
          .select('user_id')
          .inFilter('group_id', groupIds);

      List<String> agentIds = [];
      if (agentsInGroups.isNotEmpty) {
        agentIds = agentsInGroups.map((a) => a['user_id'] as String).toList();
      }

      // Add current manager to the list
      agentIds.add(currentUser.id);

      // Get available places (not already in this route)
      final currentPlaceIds = _routePlaces.map((rp) => rp.placeId).toList();
      
      final availablePlacesResponse = await supabase
          .from('places')
          .select('*')
          .eq('approval_status', 'approved')
          .eq('status', 'active')
          .inFilter('created_by', agentIds)
          .order('name');

      final availablePlaces = availablePlacesResponse
          .map((json) => Place.fromJson(json))
          .where((place) => !currentPlaceIds.contains(place.id))
          .toList();

      if (availablePlaces.isEmpty) {
        if (mounted) {
          ModernNotification.info(context, message: 'No available places to add to this route');
        }
        return;
      }

      // Show place selection dialog
      final selectedPlace = await _showPlaceSelectionDialog(availablePlaces);
      if (selectedPlace != null) {
        await _addSelectedPlaceToRoute(selectedPlace);
      }
    } catch (e) {
      if (mounted) {
        ModernNotification.error(context, message: 'Error loading available places', subtitle: e.toString());
      }
    }
  }

  Future<Place?> _showPlaceSelectionDialog(List<Place> availablePlaces) async {
    return await showDialog<Place>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Place to Route'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: availablePlaces.length,
            itemBuilder: (context, index) {
              final place = availablePlaces[index];
              return ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(place.name),
                subtitle: place.address?.isNotEmpty == true
                    ? Text(place.address!)
                    : Text('${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}'),
                onTap: () => Navigator.pop(context, place),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSelectedPlaceToRoute(Place place) async {
    try {
      // Get the next visit order
      final nextVisitOrder = _routePlaces.isEmpty ? 1 : _routePlaces.map((rp) => rp.visitOrder).reduce((a, b) => a > b ? a : b) + 1;

      // Add the place to the route
      await supabase.from('route_places').insert({
        'route_id': _route.id,
        'place_id': place.id,
        'visit_order': nextVisitOrder,
        'estimated_duration_minutes': 30, // Default 30 minutes
        'required_evidence_count': 1, // Default 1 evidence
        'instructions': null,
      });

      if (mounted) {
        ModernNotification.success(context, message: 'Place added to route successfully!');
        // Reload route details to show the new place
        _loadRouteDetails();
      }
    } catch (e) {
      if (mounted) {
        ModernNotification.error(context, message: 'Error adding place to route', subtitle: e.toString());
      }
    }
  }

  Widget _buildRouteHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_route.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(_route.status),
                    color: _getStatusColor(_route.status),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _route.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_route.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _route.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(_route.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_route.description?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              Text(
                _route.description!,
                style: const TextStyle(
                  fontSize: 14,
                  color: textSecondaryColor,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Created by: ${_route.createdByUser?.fullName ?? 'Unknown'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                Text(
                  'Created: ${DateFormat.MMMd().add_jm().format(_route.createdAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteStats() {
    final placesCount = _routePlaces.length;
    final totalDuration = _routePlaces.fold<int>(
      0, (sum, rp) => sum + (rp.estimatedDurationMinutes ?? 0)
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route Statistics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatItem(
                  icon: Icons.location_on,
                  label: 'Places',
                  value: placesCount.toString(),
                  color: Colors.blue,
                ),
                _buildStatItem(
                  icon: Icons.access_time,
                  label: 'Est. Duration',
                  value: '${(totalDuration / 60).ceil()}h',
                  color: Colors.orange,
                ),
                if (_route.estimatedDurationHours != null)
                  _buildStatItem(
                    icon: Icons.schedule,
                    label: 'Total Hours',
                    value: '${_route.estimatedDurationHours}h',
                    color: Colors.green,
                  ),
              ],
            ),
            if (_route.startDate != null || _route.endDate != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_route.startDate != null)
                    _buildStatItem(
                      icon: Icons.play_arrow,
                      label: 'Start Date',
                      value: DateFormat.MMMd().format(_route.startDate!),
                      color: Colors.green,
                    ),
                  if (_route.endDate != null)
                    _buildStatItem(
                      icon: Icons.stop,
                      label: 'End Date',
                      value: DateFormat.MMMd().format(_route.endDate!),
                      color: Colors.red,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedAgentsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Assigned Agents (${_assignedAgents.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_assignedAgents.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_add,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No agents assigned yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "Assign to Agents" to get started',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _assignedAgents.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final agent = _assignedAgents[index];
                  return _buildAgentProgressCard(agent);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentProgressCard(Map<String, dynamic> agent) {
    final progressPercentage = agent['progress_percentage'] as int;
    final completedVisits = agent['completed_visits'] as int;
    final totalPlaces = agent['total_places'] as int;
    final totalTimeSpent = agent['total_time_spent_minutes'] as int;
    final assignmentStatus = agent['assignment_status'] as String;
    
    Color statusColor;
    IconData statusIcon;
    
    switch (assignmentStatus) {
      case 'assigned':
        statusColor = Colors.blue;
        statusIcon = Icons.assignment;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusIcon = Icons.play_circle;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(statusIcon, color: statusColor, size: 24),
        ),
        title: Text(
          agent['agent_name'] as String,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Status: ${assignmentStatus.toUpperCase()}',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            // Progress bar
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progressPercentage / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$progressPercentage%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '$completedVisits/$totalPlaces places',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${(totalTimeSpent / 60).floor()}h ${totalTimeSpent % 60}m',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _showAgentProgressDetails(agent),
      ),
    );
  }

  void _showAgentProgressDetails(Map<String, dynamic> agent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildAgentProgressBottomSheet(agent),
    );
  }

  Widget _buildAgentProgressBottomSheet(Map<String, dynamic> agent) {
    final visits = agent['visits'] as List<dynamic>;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      child: Icon(Icons.person, color: primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agent['agent_name'] as String,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Progress Details',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Content
              Expanded(
                child: visits.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No visits yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Agent hasn\'t started visiting places',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: visits.length,
                        itemBuilder: (context, index) {
                          final visit = visits[index];
                          return _buildVisitDetailCard(visit);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisitDetailCard(Map<String, dynamic> visit) {
    final status = visit['status'] as String;
    final placeName = visit['places']?['name'] ?? 'Unknown Place';
    final checkedInAt = visit['checked_in_at'] != null 
        ? DateTime.parse(visit['checked_in_at']) 
        : null;
    final checkedOutAt = visit['checked_out_at'] != null 
        ? DateTime.parse(visit['checked_out_at']) 
        : null;
    final durationMinutes = visit['duration_minutes'] as int?;

    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'checked_in':
        statusColor = Colors.blue;
        statusIcon = Icons.access_time;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.radio_button_unchecked;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        placeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (durationMinutes != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(durationMinutes / 60).floor()}h ${durationMinutes % 60}m',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            if (checkedInAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.login, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Check-in: ${DateFormat.MMMd().add_jm().format(checkedInAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            if (checkedOutAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.logout, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Check-out: ${DateFormat.MMMd().add_jm().format(checkedOutAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            // Show evidence files if any
            if (visit['evidence_files'] != null && (visit['evidence_files'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attachment, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Evidence Files (${(visit['evidence_files'] as List).length}):',
                    style: TextStyle(
                      fontSize: 12, 
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: (visit['evidence_files'] as List).map<Widget>((evidence) {
                  final fileName = evidence['title'] ?? 'Unknown File';
                  final fileType = evidence['file_type'] ?? 'unknown';  
                  final evidenceId = evidence['id'];
                  
                  return GestureDetector(
                    onTap: () => _viewEvidenceFile(evidence),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            fileType.contains('image') ? Icons.image : Icons.file_present,
                            size: 12,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              fileName,
                              style: TextStyle(
                                fontSize: 10,
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.open_in_new,
                            size: 10,
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (visit['visit_notes'] != null && (visit['visit_notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Notes: ${visit['visit_notes']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

  Widget _buildPlacesList() {
    final places = _routePlaces;
    
    if (places.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No places in this route',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort places by visit order
    final sortedPlaces = places.toList()..sort((a, b) => a.visitOrder.compareTo(b.visitOrder));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route Places',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedPlaces.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final routePlace = sortedPlaces[index];
                final isLast = index == sortedPlaces.length - 1;
                
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              '${routePlace.visitOrder}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 40,
                            color: Colors.grey[300],
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routePlace.place?.name ?? 'Unknown Place',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textPrimaryColor,
                              ),
                            ),
                            if (routePlace.place?.address?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                routePlace.place!.address!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: textSecondaryColor,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${routePlace.estimatedDurationMinutes}min',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.camera_alt, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${routePlace.requiredEvidenceCount} evidence',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            if (routePlace.instructions?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 14, color: Colors.blue[700]),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        routePlace.instructions!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            
                            // Add remove button for all routes except archived
                            if (_route.status != 'archived') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Spacer(),
                                  OutlinedButton.icon(
                                    onPressed: () => _removeRoutePlaceFromRoute(routePlace),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                    icon: const Icon(Icons.remove, size: 14),
                                    label: const Text('Remove', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.route;
      case 'completed':
        return Icons.check_circle;
      case 'archived':
        return Icons.archive;
      default:
        return Icons.route;
    }
  }

  void _handleMenuAction(String action) {
    // Handle any future menu actions
  }

  Future<void> _activateRoute() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activate Route'),
        content: Text('Are you sure you want to activate "${_route.name}"? Once activated, it will be available for agent assignment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Activate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      
      try {
        await supabase.from('routes').update({
          'status': 'active',
        }).eq('id', _route.id);

        setState(() {
          _route = _route.copyWith(status: 'active');
          _isLoading = false;
        });

        if (mounted) {
          ModernNotification.success(context, message: 'Route activated successfully!');
        }

      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ModernNotification.error(context, message: 'Error activating route', subtitle: e.toString());
        }
      }
    }
  }


  Future<void> _deleteRoute() async {
    // Check if route has assignments or visits
    final usageDetails = await _checkRouteUsageDetails(_route.id);
    final hasUsage = usageDetails['hasAssignments'] as bool || usageDetails['hasVisits'] as bool;
    
    if (hasUsage) {
      if (mounted) {
        _showRouteUsageDialog(usageDetails);
      }
      return;
    }

    // For routes with no usage, show simple confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to permanently delete "${_route.name}"?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This route has no assignments or visit history and can be safely deleted.',
                      style: TextStyle(fontSize: 12, color: Colors.green[700]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. The route and all its places will be permanently deleted.',
                      style: TextStyle(fontSize: 12, color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performRouteDelete();
    }
  }

  void _assignToAgents() {
    _showAgentAssignmentDialog();
  }

  void _showAgentAssignmentDialog() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Get manager's groups and agents
      final managerGroups = await supabase
          .from('user_groups')
          .select('group_id')
          .eq('user_id', currentUser.id);

      if (managerGroups.isEmpty) {
        if (mounted) {
          ModernNotification.error(context, message: 'No groups found');
        }
        return;
      }

      final groupIds = managerGroups.map((g) => g['group_id']).toList();

      // Get agents in manager's groups
      final agentsInGroups = await supabase
          .from('user_groups')
          .select('user_id')
          .inFilter('group_id', groupIds);

      if (agentsInGroups.isEmpty) {
        if (mounted) {
          ModernNotification.info(context, message: 'No agents found in your groups');
        }
        return;
      }

      final agentIds = agentsInGroups.map((a) => a['user_id'] as String).toList();

      // Get agent profiles
      final agentsResponse = await supabase
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'agent')
          .inFilter('id', agentIds);

      if (agentsResponse.isEmpty) {
        if (mounted) {
          ModernNotification.info(context, message: 'No agents available for assignment');
        }
        return;
      }

      // Show agent selection dialog
      final selectedAgents = await showDialog<List<String>>(
        context: context,
        builder: (context) => _buildAgentSelectionDialog(agentsResponse),
      );

      if (selectedAgents != null && selectedAgents.isNotEmpty) {
        await _assignRouteToAgents(selectedAgents);
      }

    } catch (e) {
      if (mounted) {
        ModernNotification.error(context, message: 'Error loading agents', subtitle: e.toString());
      }
    }
  }

  Widget _buildAgentSelectionDialog(List<Map<String, dynamic>> agents) {
    List<String> selectedAgents = [];
    
    // Get currently assigned agent IDs
    final currentlyAssignedIds = _assignedAgents.map((agent) => agent['agent_id'] as String).toSet();

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text('Assign "${_route.name}" to Agents'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show currently assigned agents
                if (_assignedAgents.isNotEmpty) ...[
                  Text(
                    'Currently Assigned (${_assignedAgents.length}):',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(51),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withAlpha(128)),
                    ),
                    child: Column(
                      children: _assignedAgents.map((agent) {
                        final agentName = agent['agent_name'] as String;
                        final status = agent['assignment_status'] as String;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 16, color: Colors.green[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  agentName,
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Add More Agents:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // Available agents list (filter out already assigned)
                Expanded(
                  child: () {
                    // Filter out already assigned agents
                    final availableAgents = agents.where((agent) {
                      final agentId = agent['id'] as String;
                      return !currentlyAssignedIds.contains(agentId);
                    }).toList();

                    if (availableAgents.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'All agents are already assigned',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No additional agents available',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: availableAgents.length,
                      itemBuilder: (context, index) {
                        final agent = availableAgents[index];
                        final agentId = agent['id'] as String;
                        final agentName = agent['full_name'] as String;
                        final isSelected = selectedAgents.contains(agentId);

                        return CheckboxListTile(
                          title: Text(agentName),
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedAgents.add(agentId);
                              } else {
                                selectedAgents.remove(agentId);
                              }
                            });
                          },
                        );
                      },
                    );
                  }(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedAgents.isEmpty
                  ? null
                  : () => Navigator.pop(context, selectedAgents),
              child: Text('Assign to ${selectedAgents.length} agents'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _assignRouteToAgents(List<String> agentIds) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // First, check which agents are already assigned
      final existingAssignments = await supabase
          .from('route_assignments')
          .select('agent_id')
          .eq('route_id', _route.id)
          .inFilter('agent_id', agentIds);

      final alreadyAssignedIds = existingAssignments
          .map((a) => a['agent_id'] as String)
          .toSet();

      // Filter out already assigned agents
      final newAgentIds = agentIds
          .where((id) => !alreadyAssignedIds.contains(id))
          .toList();

      if (newAgentIds.isEmpty) {
        if (mounted) {
          ModernNotification.warning(context, 
            message: 'All selected agents are already assigned to this route'
          );
        }
        return;
      }

      // Create route assignments only for new agents
      final assignments = newAgentIds.map((agentId) => {
        'route_id': _route.id,
        'agent_id': agentId,
        'assigned_by': currentUser.id,
        'status': 'assigned',
      }).toList();

      await supabase.from('route_assignments').insert(assignments);

      // Send notifications to newly assigned agents
      for (final agentId in newAgentIds) {
        try {
          await supabase.from('notifications').insert({
            'recipient_id': agentId,
            'title': 'New Route Assigned',
            'message': 'You have been assigned to route: ${_route.name}',
            'type': 'route_assignment',
            'data': {
              'route_id': _route.id,
              'route_name': _route.name,
            },
            'created_at': DateTime.now().toIso8601String(),
          });
          debugPrint('Route assignment notification sent to agent: $agentId');
        } catch (notificationError) {
          debugPrint('Failed to send route assignment notification: $notificationError');
        }
      }

      if (mounted) {
        if (alreadyAssignedIds.isNotEmpty) {
          ModernNotification.success(context, 
            message: 'Assigned ${newAgentIds.length} new agents', 
            subtitle: '${alreadyAssignedIds.length} were already assigned'
          );
        } else {
          ModernNotification.success(context, 
            message: 'Route assigned to ${newAgentIds.length} agents successfully!'
          );
        }
        
        // Reload the assigned agents list
        _loadAssignedAgents();
      }

    } catch (e) {
      if (mounted) {
        ModernNotification.error(context, message: 'Error assigning route', subtitle: e.toString());
      }
    }
  }

  Future<void> _removeRoutePlaceFromRoute(RoutePlace routePlace) async {
    final isActiveRoute = _route.status == 'active';
    final isCompletedRoute = _route.status == 'completed';
    
    String warningMessage;
    MaterialColor warningColor;
    IconData warningIcon;
    
    if (isActiveRoute) {
      warningMessage = 'Warning: This route is active and may be assigned to agents. Removing a place may affect ongoing work.';
      warningColor = Colors.red;
      warningIcon = Icons.warning;
    } else if (isCompletedRoute) {
      warningMessage = 'Warning: This route is completed. Removing a place will modify the historical record.';
      warningColor = Colors.orange;
      warningIcon = Icons.warning;
    } else {
      warningMessage = 'This will remove the place from the route. The place itself will remain available for other routes.';
      warningColor = Colors.blue;
      warningIcon = Icons.info_outline;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Place from Route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to remove "${routePlace.place?.name ?? 'Unknown Place'}" from this route?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: warningColor[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: warningColor[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    warningIcon,
                    color: warningColor[700],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warningMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: warningColor[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Remove the route place from the database
        if (routePlace.id != null) {
          await supabase
              .from('route_places')
              .delete()
              .eq('id', routePlace.id!);
        }

        // Update visit orders for remaining places
        await _updateVisitOrders();

        if (mounted) {
          ModernNotification.success(context, message: 'Place removed from route successfully.');
          _loadRouteDetails(); // Refresh the route details
        }

      } catch (e) {
        if (mounted) {
          ModernNotification.error(context, message: 'Error removing place from route', subtitle: e.toString());
        }
      }
    }
  }

  Future<void> _updateVisitOrders() async {
    try {
      // Get all remaining route places for this route
      final routePlacesResponse = await supabase
          .from('route_places')
          .select('id')
          .eq('route_id', _route.id)
          .order('visit_order');

      // Update visit orders to be sequential (1, 2, 3, ...)
      for (int i = 0; i < routePlacesResponse.length; i++) {
        final routePlaceId = routePlacesResponse[i]['id'];
        await supabase
            .from('route_places')
            .update({'visit_order': i + 1})
            .eq('id', routePlaceId);
      }
    } catch (e) {
      print('Error updating visit orders: $e');
    }
  }

  Future<Map<String, dynamic>> _checkRouteUsageDetails(String routeId) async {
    try {
      final results = {
        'hasAssignments': false,
        'hasVisits': false,
        'assignmentCount': 0,
        'visitCount': 0,
        'agentNames': <String>[],
      };

      // Check route_assignments
      final assignmentsResponse = await supabase
          .from('route_assignments')
          .select('agent_id, profiles!inner(full_name)')
          .eq('route_id', routeId);

      if (assignmentsResponse.isNotEmpty) {
        results['hasAssignments'] = true;
        results['assignmentCount'] = assignmentsResponse.length;
        results['agentNames'] = assignmentsResponse
            .map((assignment) => assignment['profiles']['full_name'] as String)
            .toSet()
            .toList();
      }

      // Check place_visits through route_places
      final routePlacesResponse = await supabase
          .from('route_places')
          .select('id')
          .eq('route_id', routeId);

      if (routePlacesResponse.isNotEmpty) {
        final routePlaceIds = routePlacesResponse.map((rp) => rp['id']).toList();
        
        // Check if any route places have visits
        final visitsResponse = await supabase
            .from('place_visits')
            .select('id')
            .inFilter('route_place_id', routePlaceIds);

        if (visitsResponse.isNotEmpty) {
          results['hasVisits'] = true;
          results['visitCount'] = visitsResponse.length;
        }
      }

      return results;
    } catch (e) {
      print('Error checking route usage: $e');
      return {
        'hasAssignments': true, // Assume usage if we can't check
        'hasVisits': true,
        'assignmentCount': 0,
        'visitCount': 0,
        'agentNames': <String>[],
      };
    }
  }

  void _showRouteUsageDialog(Map<String, dynamic> usageDetails) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cannot Delete Route'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The route "${_route.name}" cannot be deleted because it has historical data or active assignments:',
              ),
              const SizedBox(height: 16),
              
              // Assignments usage
              if (usageDetails['hasAssignments'] as bool) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.assignment_ind, color: Colors.orange[700], size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Assigned to ${usageDetails['assignmentCount']} agent(s):',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...(usageDetails['agentNames'] as List<String>).map((name) => 
                        Padding(
                          padding: const EdgeInsets.only(left: 24, top: 2),
                          child: Text(
                            '• $name',
                            style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Visits usage
              if (usageDetails['hasVisits'] as bool) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Colors.red[700], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Has ${usageDetails['visitCount']} visit record(s). This historical data cannot be deleted to maintain audit trail.',
                          style: TextStyle(fontSize: 12, color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'What you can do:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (usageDetails['hasAssignments'] as bool)
                      Text(
                        '• Remove agent assignments first',
                        style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                      ),
                    if (usageDetails['hasVisits'] as bool)
                      Text(
                        '• Archive the route instead of deleting to preserve historical data',
                        style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (_route.status != 'archived')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _archiveRoute();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Archive Route'),
            ),
        ],
      ),
    );
  }

  Future<void> _performRouteDelete() async {
    try {
      setState(() => _isLoading = true);

      // Delete route places first (due to foreign key constraints)
      await supabase
          .from('route_places')
          .delete()
          .eq('route_id', _route.id);

      // Delete the route
      await supabase
          .from('routes')
          .delete()
          .eq('id', _route.id);

      if (mounted) {
        ModernNotification.success(context, message: 'Route deleted successfully.');
        Navigator.pop(context, true); // Return to previous screen
      }

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ModernNotification.error(context, message: 'Error deleting route', subtitle: e.toString());
      }
    }
  }

  Future<void> _archiveRoute() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to archive "${_route.name}"?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The route will be moved to archived status. All historical data will be preserved and it will no longer be available for new assignments.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await supabase.from('routes').update({
          'status': 'archived',
        }).eq('id', _route.id);

        setState(() {
          _route = _route.copyWith(status: 'archived');
        });

        if (mounted) {
          ModernNotification.success(context, message: 'Route archived successfully.');
        }
      } catch (e) {
        if (mounted) {
          ModernNotification.error(context, message: 'Error archiving route', subtitle: e.toString());
        }
      }
    }
  }

  void _viewEvidenceFile(Map<String, dynamic> evidence) {
    final fileUrl = evidence['file_url'] as String?;
    final mimeType = evidence['mime_type'] as String?;
    final evidenceId = evidence['id'] as String;
    
    if (fileUrl == null) {
      ModernNotification.error(context, message: 'File URL not available');
      return;
    }

    // Check if it's an image
    if (mimeType?.startsWith('image/') == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenImageViewer(
            imageUrl: fileUrl,
            heroTag: 'evidence-$evidenceId',
          ),
        ),
      );
    } else {
      // For non-image files, open evidence detail screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EvidenceDetailScreen(
            evidenceId: evidenceId,
          ),
        ),
      );
    }
  }
}