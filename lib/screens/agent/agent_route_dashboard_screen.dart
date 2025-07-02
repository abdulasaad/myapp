// lib/screens/agent/agent_route_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import '../../models/route_assignment.dart';
import '../../models/place_visit.dart';
import 'agent_route_detail_screen.dart';

class AgentRouteDashboardScreen extends StatefulWidget {
  const AgentRouteDashboardScreen({super.key});

  @override
  State<AgentRouteDashboardScreen> createState() => _AgentRouteDashboardScreenState();
}

class _AgentRouteDashboardScreenState extends State<AgentRouteDashboardScreen> {
  bool _isLoading = true;
  List<RouteAssignment> _activeRoutes = [];
  PlaceVisit? _currentActiveVisit;

  @override
  void initState() {
    super.initState();
    _loadRouteData();
  }

  Future<void> _loadRouteData() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load route assignments for current agent
      final routeAssignmentsResponse = await supabase
          .from('route_assignments')
          .select('*')
          .eq('agent_id', currentUser.id)
          .inFilter('status', ['assigned', 'in_progress'])
          .order('assigned_at', ascending: false);

      List<RouteAssignment> routeAssignments = [];
      
      for (var json in routeAssignmentsResponse) {
        try {
          // Get route details separately
          if (json['route_id'] != null) {
            final routeResponse = await supabase
                .from('routes')
                .select('*')
                .eq('id', json['route_id'])
                .maybeSingle();
            
            if (routeResponse != null) {
              json['routes'] = routeResponse;
            }
          }
          
          final assignment = RouteAssignment.fromJson(json);
          routeAssignments.add(assignment);
        } catch (e) {
          print('Error parsing route assignment: $e');
        }
      }

      setState(() {
        _activeRoutes = routeAssignments;
        _currentActiveVisit = null; // Simplify for now
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showSnackBar('Error loading route data: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildRouteContent(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _suggestNewPlace,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location),
        label: const Text('Suggest Place'),
      ),
    );
  }

  Widget _buildRouteContent() {
    return RefreshIndicator(
      onRefresh: _loadRouteData,
      child: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'My Routes',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      primaryColor.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Current Active Visit Section
          if (_currentActiveVisit != null) ...[ 
            SliverToBoxAdapter(
              child: _buildActiveVisitCard(),
            ),
          ],
          
          // Routes List
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Routes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _activeRoutes.isEmpty
                      ? _buildEmptyState()
                      : Column(
                          children: _activeRoutes.map(_buildRouteCard).toList(),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveVisitCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[400]!, Colors.green[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Currently Visiting',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _currentActiveVisit?.place?.name ?? 'Loading...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _checkOut,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green[600],
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Check Out'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addEvidence,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Add Evidence'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(RouteAssignment assignment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.route,
            color: primaryColor,
            size: 24,
          ),
        ),
        title: Text(
          assignment.route?.name ?? 'Route ${assignment.routeId}',
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
              'Status: ${assignment.status.toUpperCase()}',
              style: TextStyle(
                color: _getStatusColor(assignment.status),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Assigned: ${DateFormat.MMMd().format(assignment.assignedAt)}',
              style: const TextStyle(color: textSecondaryColor),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: textSecondaryColor,
          size: 16,
        ),
        onTap: () => _openRoute(assignment),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.route_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Routes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your manager will assign routes for you to visit.',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return textSecondaryColor;
    }
  }

  void _openRoute(RouteAssignment assignment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AgentRouteDetailScreen(routeAssignment: assignment),
      ),
    ).then((_) {
      // Refresh when returning from detail screen
      _loadRouteData();
    });
  }

  void _checkOut() {
    // TODO: Implement check-out functionality
    context.showSnackBar('Check-out functionality - Coming soon!');
  }

  void _addEvidence() {
    // TODO: Show evidence upload dialog for current place visit
    context.showSnackBar('Evidence upload - Coming soon!');
  }

  void _suggestNewPlace() {
    showDialog(
      context: context,
      builder: (context) => _buildPlaceSuggestionDialog(),
    );
  }

  Widget _buildPlaceSuggestionDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final addressController = TextEditingController();
    final latitudeController = TextEditingController();
    final longitudeController = TextEditingController();
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_location, color: primaryColor),
          const SizedBox(width: 8),
          const Text('Suggest New Place'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Place Name *',
                  hintText: 'Enter place name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Brief description of the place',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'Street address or landmark',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude *',
                        hintText: '0.0',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: longitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude *',
                        hintText: '0.0',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
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
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Tip: Use GPS coordinates from your current location or a maps app',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _getCurrentLocation(latitudeController, longitudeController),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.my_location),
                label: const Text('Use Current Location'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _submitPlaceSuggestion(
            nameController.text,
            descriptionController.text,
            addressController.text,
            latitudeController.text,
            longitudeController.text,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Submit Suggestion'),
        ),
      ],
    );
  }

  void _getCurrentLocation(TextEditingController latController, TextEditingController lngController) {
    // TODO: Implement GPS location capture
    // For now, show placeholder coordinates
    latController.text = '24.7136';
    lngController.text = '46.6753';
    context.showSnackBar('Using current location (demo coordinates)');
  }

  void _submitPlaceSuggestion(String name, String description, String address, String latitude, String longitude) {
    if (name.trim().isEmpty || latitude.trim().isEmpty || longitude.trim().isEmpty) {
      context.showSnackBar('Please fill required fields (Name, Latitude, Longitude)', isError: true);
      return;
    }

    try {
      final lat = double.parse(latitude);
      final lng = double.parse(longitude);
      
      // Validate coordinates
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        context.showSnackBar('Invalid coordinates. Latitude: -90 to 90, Longitude: -180 to 180', isError: true);
        return;
      }

      Navigator.pop(context);
      
      // TODO: Submit to Supabase with approval_status = 'pending'
      _savePlaceSuggestion({
        'name': name.trim(),
        'description': description.trim(),
        'address': address.trim(),
        'latitude': lat,
        'longitude': lng,
      });
      
    } catch (e) {
      context.showSnackBar('Invalid coordinate format. Please enter valid numbers.', isError: true);
    }
  }

  Future<void> _savePlaceSuggestion(Map<String, dynamic> placeData) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        context.showSnackBar('Authentication required', isError: true);
        return;
      }

      // Insert place with pending approval status
      await supabase.from('places').insert({
        'name': placeData['name'],
        'description': placeData['description'],
        'address': placeData['address'],
        'latitude': placeData['latitude'],
        'longitude': placeData['longitude'],
        'created_by': currentUser.id,
        'approval_status': 'pending', // Requires manager approval
        'status': 'pending_approval',
      });

      if (mounted) {
        context.showSnackBar('Place suggestion submitted! Waiting for manager approval.');
      }
      
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error submitting suggestion: $e', isError: true);
      }
    }
  }
}