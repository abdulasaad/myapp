// lib/screens/manager/place_management_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/constants.dart';
import '../../models/place.dart';
import 'map_location_picker_screen.dart';

class PlaceManagementScreen extends StatefulWidget {
  const PlaceManagementScreen({super.key});

  @override
  State<PlaceManagementScreen> createState() => _PlaceManagementScreenState();
}

class _PlaceManagementScreenState extends State<PlaceManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Place> _pendingPlaces = [];
  List<Place> _approvedPlaces = [];
  List<Place> _rejectedPlaces = [];
  List<Place> _inactivePlaces = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPlaces();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Get manager's groups
      final managerGroups = await supabase
          .from('user_groups')
          .select('group_id')
          .eq('user_id', currentUser.id);

      if (managerGroups.isEmpty) {
        setState(() {
          _pendingPlaces = [];
          _approvedPlaces = [];
          _rejectedPlaces = [];
          _isLoading = false;
        });
        return;
      }

      final groupIds = managerGroups.map((g) => g['group_id']).toList();

      // Get agents in manager's groups
      final agentsInGroups = await supabase
          .from('user_groups')
          .select('user_id')
          .inFilter('group_id', groupIds);

      if (agentsInGroups.isEmpty) {
        setState(() {
          _pendingPlaces = [];
          _approvedPlaces = [];
          _rejectedPlaces = [];
          _isLoading = false;
        });
        return;
      }

      final agentIds = agentsInGroups.map((a) => a['user_id'] as String).toList();

      // Add current manager to the list to include their own places
      agentIds.add(currentUser.id);

      // Get places created by agents in manager's groups or by the manager
      final placesResponse = await supabase
          .from('places')
          .select('''
            *,
            created_by_profile:profiles!created_by(id, full_name),
            approved_by_profile:profiles!approved_by(id, full_name)
          ''')
          .inFilter('created_by', agentIds)
          .order('created_at', ascending: false);

      final places = placesResponse.map((json) => Place.fromJson(json)).toList();

      setState(() {
        _pendingPlaces = places.where((p) => p.approvalStatus == 'pending').toList();
        _approvedPlaces = places.where((p) => p.approvalStatus == 'approved' && p.status == 'active').toList();
        _rejectedPlaces = places.where((p) => p.approvalStatus == 'rejected').toList();
        _inactivePlaces = places.where((p) => p.status == 'inactive').toList();
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showSnackBar('Error loading places: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Place Management'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
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
                  const Icon(Icons.pending_actions, size: 16),
                  const SizedBox(width: 4),
                  Text('Pending (${_pendingPlaces.length})', 
                    style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 16),
                  const SizedBox(width: 4),
                  Text('Approved (${_approvedPlaces.length})', 
                    style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cancel, size: 16),
                  const SizedBox(width: 4),
                  Text('Rejected (${_rejectedPlaces.length})', 
                    style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility_off, size: 16),
                  const SizedBox(width: 4),
                  Text('Inactive (${_inactivePlaces.length})', 
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
                _buildPlacesList(_pendingPlaces, isPending: true),
                _buildPlacesList(_approvedPlaces),
                _buildPlacesList(_rejectedPlaces),
                _buildPlacesList(_inactivePlaces, isInactive: true),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewPlace,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location),
        label: const Text('Add Place'),
      ),
    );
  }

  Widget _buildPlacesList(List<Place> places, {bool isPending = false, bool isInactive = false}) {
    if (places.isEmpty) {
      IconData emptyIcon;
      String emptyTitle;
      String emptySubtitle;
      
      if (isPending) {
        emptyIcon = Icons.pending_actions;
        emptyTitle = 'No pending suggestions';
        emptySubtitle = 'Agent suggestions will appear here';
      } else if (isInactive) {
        emptyIcon = Icons.visibility_off;
        emptyTitle = 'No inactive places';
        emptySubtitle = 'Deactivated places will appear here';
      } else {
        emptyIcon = Icons.location_on;
        emptyTitle = 'No places found';
        emptySubtitle = 'Places will appear here once added';
      }
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
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
      onRefresh: _loadPlaces,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: places.length,
        itemBuilder: (context, index) {
          final place = places[index];
          return _buildPlaceCard(place, isPending: isPending, isInactive: isInactive);
        },
      ),
    );
  }

  Widget _buildPlaceCard(Place place, {bool isPending = false, bool isInactive = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    color: _getStatusColor(place.approvalStatus).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(place.approvalStatus),
                    color: _getStatusColor(place.approvalStatus),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimaryColor,
                        ),
                      ),
                      if (place.description?.isNotEmpty == true)
                        Text(
                          place.description!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: textSecondaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(place.approvalStatus).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    place.approvalStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(place.approvalStatus),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (place.address?.isNotEmpty == true) ...[
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      place.address!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Icon(Icons.gps_fixed, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${place.latitude.toStringAsFixed(6)}, ${place.longitude.toStringAsFixed(6)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _viewPlaceOnMap(place),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map, size: 12, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          'View',
                          style: TextStyle(
                            fontSize: 10,
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Suggested by: ${place.createdByUser?.fullName ?? 'Unknown'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                Text(
                  DateFormat.MMMd().add_jm().format(place.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectPlace(place),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approvePlace(place),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
            if (place.approvalStatus == 'rejected' && place.rejectionReason?.isNotEmpty == true) ...[
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
                    Icon(Icons.info_outline, color: Colors.red[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rejection reason: ${place.rejectionReason}',
                        style: TextStyle(fontSize: 12, color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Action buttons based on status
            if (isInactive) ...[
              // Reactivate button for inactive places
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility_off, color: Colors.orange[700], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'This place is inactive and hidden from new routes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _reactivatePlace(place),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Reactivate Place'),
                  ),
                ],
              ),
            ] else if (place.approvalStatus == 'approved') ...[
              // Delete button for approved places (managers only)
              const SizedBox(height: 16),
              Row(
                children: [
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _deletePlace(place),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove Place'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending_actions;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.location_on;
    }
  }

  Future<void> _approvePlace(Place place) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      await supabase.from('places').update({
        'approval_status': 'approved',
        'status': 'active',
        'approved_by': currentUser.id,
        'approved_at': DateTime.now().toIso8601String(),
        'rejection_reason': null,
      }).eq('id', place.id);

      if (mounted) {
        context.showSnackBar('Place approved successfully!');
        _loadPlaces(); // Refresh the list
      }

    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error approving place: $e', isError: true);
      }
    }
  }

  Future<void> _rejectPlace(Place place) async {
    final reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Place Suggestion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to reject "${place.name}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (Optional)',
                hintText: 'Explain why this place was rejected',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final currentUser = supabase.auth.currentUser;
        if (currentUser == null) return;

        await supabase.from('places').update({
          'approval_status': 'rejected',
          'status': 'inactive',
          'approved_by': currentUser.id,
          'approved_at': DateTime.now().toIso8601String(),
          'rejection_reason': reasonController.text.trim().isNotEmpty 
              ? reasonController.text.trim() 
              : null,
        }).eq('id', place.id);

        if (mounted) {
          context.showSnackBar('Place rejected.');
          _loadPlaces(); // Refresh the list
        }

      } catch (e) {
        if (mounted) {
          context.showSnackBar('Error rejecting place: $e', isError: true);
        }
      }
    }
  }

  void _addNewPlace() {
    showDialog(
      context: context,
      builder: (context) => _buildAddPlaceDialog(),
    );
  }

  Widget _buildAddPlaceDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    LatLng? selectedLocation;
    double? geofenceRadius;
    
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Add New Place'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Place Name *',
                        hintText: 'Enter place name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Place name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Brief description of the place',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        hintText: 'Physical address (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    
                    // Location Selection
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.location_on, color: primaryColor, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Location & Geofence *',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (selectedLocation != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green[200]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Location Selected',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Lat: ${selectedLocation!.latitude.toStringAsFixed(6)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            color: Colors.green[700],
                                          ),
                                        ),
                                        Text(
                                          'Lng: ${selectedLocation!.longitude.toStringAsFixed(6)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            color: Colors.green[700],
                                          ),
                                        ),
                                        if (geofenceRadius != null)
                                          Text(
                                            'Geofence: ${geofenceRadius!.round()}m radius',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final result = await Navigator.push<Map<String, dynamic>>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MapLocationPickerScreen(
                                            initialLocation: selectedLocation,
                                            initialRadius: geofenceRadius,
                                          ),
                                        ),
                                      );
                                      
                                      if (result != null) {
                                        setDialogState(() {
                                          selectedLocation = result['location'] as LatLng;
                                          geofenceRadius = result['radius'] as double;
                                        });
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: selectedLocation == null ? primaryColor : Colors.grey[600],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    icon: Icon(selectedLocation == null ? Icons.map : Icons.edit_location),
                                    label: Text(selectedLocation == null ? 'Select Location on Map' : 'Change Location'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                          Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Manager-created places are automatically approved and ready for use.',
                              style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedLocation == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a location on the map'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _createPlace(
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    address: addressController.text.trim(),
                    latitude: selectedLocation!.latitude,
                    longitude: selectedLocation!.longitude,
                    geofenceRadius: geofenceRadius ?? 50.0,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Place'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createPlace({
    required String name,
    required String description,
    required String address,
    required double latitude,
    required double longitude,
    required double geofenceRadius,
  }) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        context.showSnackBar('Authentication required', isError: true);
        return;
      }

      // Create the place with immediate approval since it's created by a manager
      await supabase.from('places').insert({
        'name': name,
        'description': description.isNotEmpty ? description : null,
        'address': address.isNotEmpty ? address : null,
        'latitude': latitude,
        'longitude': longitude,
        'created_by': currentUser.id,
        'approval_status': 'approved', // Auto-approve manager-created places
        'status': 'active',
        'approved_by': currentUser.id, // Manager approves their own place
        'approved_at': DateTime.now().toIso8601String(),
        'metadata': {
          'created_by_role': 'manager',
          'auto_approved': true,
          'geofence_radius': geofenceRadius,
        },
      });

      if (mounted) {
        context.showSnackBar('Place added successfully!');
        _loadPlaces(); // Refresh the list
      }

    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error creating place: $e', isError: true);
      }
    }
  }

  Future<void> _deletePlace(Place place) async {
    // Check comprehensive place usage
    final usageDetails = await _checkPlaceUsageDetails(place.id);
    final hasUsage = usageDetails['inRoutes'] as bool || usageDetails['inVisits'] as bool;
    
    if (hasUsage) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot Remove Place'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The place "${place.name}" cannot be deleted because it has historical data or is currently in use:',
                  ),
                  const SizedBox(height: 16),
                  
                  // Routes usage
                  if (usageDetails['inRoutes'] as bool) ...[
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
                              Icon(Icons.route, color: Colors.orange[700], size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Used in ${usageDetails['routeCount']} route(s):',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...(usageDetails['routeNames'] as List<String>).map((name) => 
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
                  if (usageDetails['inVisits'] as bool) ...[
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
                              'Has ${usageDetails['visitCount']} historical visit record(s). This data cannot be deleted to maintain audit trail.',
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
                        if (usageDetails['inRoutes'] as bool)
                          Text(
                            '• Remove this place from all routes first',
                            style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                          ),
                        if (usageDetails['inVisits'] as bool)
                          Text(
                            '• Mark the place as inactive to hide it from new routes while preserving history',
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
              if (usageDetails['inRoutes'] as bool)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context); // Go back to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Go to Routes'),
                ),
              if (usageDetails['inVisits'] as bool && !(usageDetails['inRoutes'] as bool))
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _deactivatePlace(place);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Deactivate Place'),
                ),
            ],
          ),
        );
      }
      return;
    }

    // For places with no usage, show simple confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Place'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to permanently remove "${place.name}"?'),
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
                      'This place is not used in any routes or visits and can be safely deleted.',
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
                      'This action cannot be undone. The place will be permanently deleted from the system.',
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
      try {
        // Delete the place from the database
        await supabase.from('places').delete().eq('id', place.id);

        if (mounted) {
          context.showSnackBar('Place removed successfully.');
          _loadPlaces(); // Refresh the list
        }

      } catch (e) {
        if (mounted) {
          context.showSnackBar('Error removing place: $e', isError: true);
        }
      }
    }
  }

  Future<Map<String, dynamic>> _checkPlaceUsageDetails(String placeId) async {
    try {
      // Check all possible usages of the place
      final results = {
        'inRoutes': false,
        'inVisits': false,
        'routeCount': 0,
        'visitCount': 0,
        'routeNames': <String>[],
      };

      // Check route_places
      final routePlacesResponse = await supabase
          .from('route_places')
          .select('route_id, routes!inner(name, status)')
          .eq('place_id', placeId);

      if (routePlacesResponse.isNotEmpty) {
        results['inRoutes'] = true;
        results['routeCount'] = routePlacesResponse.length;
        results['routeNames'] = routePlacesResponse
            .map((rp) => rp['routes']['name'] as String)
            .toList();
      }

      // Check place_visits
      final placeVisitsResponse = await supabase
          .from('place_visits')
          .select('id')
          .eq('place_id', placeId);

      if (placeVisitsResponse.isNotEmpty) {
        results['inVisits'] = true;
        results['visitCount'] = placeVisitsResponse.length;
      }

      return results;
    } catch (e) {
      print('Error checking place usage: $e');
      return {
        'inRoutes': true,
        'inVisits': true,
        'routeCount': 0,
        'visitCount': 0,
        'routeNames': <String>[],
      };
    }
  }

  Future<void> _deactivatePlace(Place place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Place'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to deactivate "${place.name}"?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The place will be hidden from new routes but all historical data will be preserved. You can reactivate it later.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[700]),
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
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await supabase.from('places').update({
          'status': 'inactive',
        }).eq('id', place.id);

        if (mounted) {
          context.showSnackBar('Place deactivated successfully.');
          _loadPlaces(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          context.showSnackBar('Error deactivating place: $e', isError: true);
        }
      }
    }
  }

  Future<void> _reactivatePlace(Place place) async {
    try {
      await supabase.from('places').update({
        'status': 'active',
      }).eq('id', place.id);

      if (mounted) {
        context.showSnackBar('Place reactivated successfully.');
        _loadPlaces(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error reactivating place: $e', isError: true);
      }
    }
  }

  void _viewPlaceOnMap(Place place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceMapViewScreen(place: place),
      ),
    );
  }
}

class PlaceMapViewScreen extends StatefulWidget {
  final Place place;

  const PlaceMapViewScreen({super.key, required this.place});

  @override
  State<PlaceMapViewScreen> createState() => _PlaceMapViewScreenState();
}

class _PlaceMapViewScreenState extends State<PlaceMapViewScreen> {
  GoogleMapController? _mapController;
  bool _isEditing = false;
  LatLng? _newLocation;
  bool _isLoading = false;
  double _geofenceRadius = 50.0;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  late LatLng _currentLocation; // Current location that gets updated on save

  @override
  void initState() {
    super.initState();
    // Initialize with place's current location
    _currentLocation = LatLng(widget.place.latitude, widget.place.longitude);
    
    // Get initial geofence radius from place metadata
    if (widget.place.metadata != null && widget.place.metadata!['geofence_radius'] != null) {
      _geofenceRadius = (widget.place.metadata!['geofence_radius'] as num).toDouble();
    }
    _updateMapElements();
  }

  void _updateMapElements() {
    final displayLocation = _newLocation ?? _currentLocation;

    _markers = {
      Marker(
        markerId: const MarkerId('place'),
        position: displayLocation,
        infoWindow: InfoWindow(
          title: widget.place.name,
          snippet: _isEditing ? 'Tap to move location' : widget.place.address,
        ),
        draggable: _isEditing,
        onDragEnd: _isEditing
            ? (LatLng newPosition) {
                setState(() {
                  _newLocation = newPosition;
                  _updateMapElements();
                });
              }
            : null,
      ),
    };

    _circles = {
      Circle(
        circleId: const CircleId('geofence'),
        center: displayLocation,
        radius: _geofenceRadius,
        fillColor: primaryColor.withValues(alpha: 0.2),
        strokeColor: primaryColor,
        strokeWidth: 2,
      ),
    };
  }

  void _onRadiusChanged(double value) {
    setState(() {
      _geofenceRadius = value;
      _updateMapElements();
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayLocation = _newLocation ?? _currentLocation;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.place.name),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _newLocation = _currentLocation;
                  _updateMapElements();
                });
              },
              icon: const Icon(Icons.edit_location),
              tooltip: 'Edit Location',
            )
          else ...[
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _newLocation = null;
                  _updateMapElements();
                });
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: _isLoading ? null : _saveLocation,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            initialCameraPosition: CameraPosition(
              target: displayLocation,
              zoom: 16.0,
            ),
            markers: _markers,
            circles: _circles,
            onTap: _isEditing
                ? (LatLng tappedLocation) {
                    setState(() {
                      _newLocation = tappedLocation;
                      _updateMapElements();
                    });
                  }
                : null,
          ),
          if (_isEditing)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: primaryColor, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Edit Mode Active',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap on the map or drag the marker to change the location',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    if (_newLocation != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.gps_fixed, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_newLocation!.latitude.toStringAsFixed(6)}, ${_newLocation!.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    
                    // Geofence radius selector
                    Row(
                      children: [
                        const Text(
                          'Geofence Radius:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_geofenceRadius.round()}m',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.radio_button_unchecked, size: 16, color: primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: _geofenceRadius,
                            min: 10.0,
                            max: 500.0,
                            divisions: 49,
                            activeColor: primaryColor,
                            label: '${_geofenceRadius.round()}m',
                            onChanged: _onRadiusChanged,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveLocation() async {
    if (_newLocation == null && _geofenceRadius == (widget.place.metadata?['geofence_radius'] ?? 50.0)) {
      return; // No changes to save
    }

    setState(() => _isLoading = true);

    try {
      // Prepare the update data
      Map<String, dynamic> updateData = {};
      
      // Update location if it changed
      if (_newLocation != null) {
        updateData['latitude'] = _newLocation!.latitude;
        updateData['longitude'] = _newLocation!.longitude;
      }
      
      // Update metadata with geofence radius
      Map<String, dynamic> metadata = Map<String, dynamic>.from(widget.place.metadata ?? {});
      metadata['geofence_radius'] = _geofenceRadius;
      updateData['metadata'] = metadata;
      
      await supabase.from('places').update(updateData).eq('id', widget.place.id);

      if (mounted) {
        context.showSnackBar('Location and geofence updated successfully!');
        setState(() {
          // Update the current location to the new location if it changed
          if (_newLocation != null) {
            _currentLocation = _newLocation!;
          }
          _isEditing = false;
          _newLocation = null;
          _updateMapElements();
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error updating location: $e', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}