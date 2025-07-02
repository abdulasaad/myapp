// lib/screens/manager/route_management_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import '../../models/route.dart' as route_model;
import 'create_route_screen.dart';
import 'route_detail_screen.dart';
import 'place_management_screen.dart';

class RouteManagementScreen extends StatefulWidget {
  const RouteManagementScreen({super.key});

  @override
  State<RouteManagementScreen> createState() => _RouteManagementScreenState();
}

class _RouteManagementScreenState extends State<RouteManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<route_model.Route> _activeRoutes = [];
  List<route_model.Route> _completedRoutes = [];
  
  // Store place counts for each route
  Map<String, int> _routePlaceCounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRoutes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Get routes created by current manager or assigned to them with creator profile
      final routesResponse = await supabase
          .from('routes')
          .select('''
            *,
            created_by_profile:profiles!created_by(*)
          ''')
          .or('created_by.eq.${currentUser.id},assigned_manager_id.eq.${currentUser.id}')
          .order('created_at', ascending: false);

      print('Routes response: $routesResponse');

      // Parse routes and get place counts separately
      List<route_model.Route> routes = [];
      for (var json in routesResponse) {
        try {
          final route = route_model.Route.fromJson(json);
          
          // Get place count for this route separately
          final placeCountResponse = await supabase
              .from('route_places')
              .select('id')
              .eq('route_id', route.id);
          
          final placeCount = placeCountResponse.length;
          print('Route ${route.name} has $placeCount places');
          
          // Store place count for UI display
          _routePlaceCounts[route.id] = placeCount;
          
          routes.add(route);
        } catch (e) {
          print('Error parsing route: $e');
          print('JSON data: $json');
        }
      }

      setState(() {
        _activeRoutes = routes.where((r) => r.status == 'active').toList();
        _completedRoutes = routes.where((r) => r.status == 'completed' || r.status == 'archived').toList();
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showSnackBar('Error loading routes: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Route Management'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PlaceManagementScreen(),
                ),
              );
            },
            icon: const Icon(Icons.location_on),
            tooltip: 'Manage Places',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.route, size: 16),
                  const SizedBox(width: 4),
                  Text('Active (${_activeRoutes.length})', 
                    style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.archive, size: 16),
                  const SizedBox(width: 4),
                  Text('Completed (${_completedRoutes.length})', 
                    style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRoutesList(_activeRoutes),
                _buildRoutesList(_completedRoutes),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewRoute,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Route'),
      ),
    );
  }

  Widget _buildRoutesList(List<route_model.Route> routes, {bool isDraft = false}) {
    if (routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDraft ? Icons.edit : Icons.route,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isDraft ? 'No draft routes' : 'No routes found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first route to get started',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRoutes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: routes.length,
        itemBuilder: (context, index) {
          final route = routes[index];
          return _buildRouteCard(route);
        },
      ),
    );
  }

  Widget _buildRouteCard(route_model.Route route) {
    final placesCount = _routePlaceCounts[route.id] ?? 0;
    final estimatedHours = route.estimatedDurationHours ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openRouteDetail(route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(route.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon(route.status),
                      color: _getStatusColor(route.status),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimaryColor,
                          ),
                        ),
                        if (route.description?.isNotEmpty == true)
                          Text(
                            route.description!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: textSecondaryColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(route.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      route.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(route.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Route Stats
              Row(
                children: [
                  _buildStatChip(
                    icon: Icons.location_on,
                    label: '$placesCount Places',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  if (estimatedHours > 0)
                    _buildStatChip(
                      icon: Icons.access_time,
                      label: '${estimatedHours}h',
                      color: Colors.orange,
                    ),
                  if (route.startDate != null) ...[
                    const SizedBox(width: 8),
                    _buildStatChip(
                      icon: Icons.calendar_today,
                      label: DateFormat.MMMd().format(route.startDate!),
                      color: Colors.green,
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Places Preview
              if (placesCount > 0) ...[
                const Text(
                  'Route Order:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getPlacesPreview(route),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Created by: ${route.createdByUser?.fullName ?? 'Unknown'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat.MMMd().add_jm().format(route.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getPlacesPreview(route_model.Route route) {
    if (route.routePlaces == null || route.routePlaces!.isEmpty) {
      return 'No places added';
    }
    
    final sortedPlaces = route.routePlaces!..sort((a, b) => a.visitOrder.compareTo(b.visitOrder));
    final placeNames = sortedPlaces.take(3).map((rp) => rp.place?.name ?? 'Unknown').toList();
    
    if (sortedPlaces.length > 3) {
      placeNames.add('... (+${sortedPlaces.length - 3} more)');
    }
    
    return placeNames.join(' → ');
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.orange;
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
      case 'draft':
        return Icons.edit;
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

  void _createNewRoute() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateRouteScreen(),
      ),
    ).then((_) {
      // Refresh routes when returning from create screen
      _loadRoutes();
    });
  }

  void _openRouteDetail(route_model.Route route) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RouteDetailScreen(route: route),
      ),
    ).then((_) {
      // Refresh routes when returning from detail screen
      _loadRoutes();
    });
  }
}