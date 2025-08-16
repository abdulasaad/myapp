// lib/screens/manager/place_management_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../l10n/app_localizations.dart';
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

      debugPrint('Loading places for user: ${currentUser.id}');

      // Always include the current manager's places
      List<String> agentIds = [currentUser.id];

      // Get manager's groups
      final managerGroups = await supabase
          .from('user_groups')
          .select('group_id')
          .eq('user_id', currentUser.id);

      debugPrint('Manager groups: ${managerGroups.length}');

      // If manager has groups, also include agents from those groups
      if (managerGroups.isNotEmpty) {
        final groupIds = managerGroups.map((g) => g['group_id']).toList();

        // Get agents in manager's groups
        final agentsInGroups = await supabase
            .from('user_groups')
            .select('user_id')
            .inFilter('group_id', groupIds);

        if (agentsInGroups.isNotEmpty) {
          final additionalAgentIds = agentsInGroups.map((a) => a['user_id'] as String).toList();
          // Add unique agent IDs (avoid duplicates)
          for (final agentId in additionalAgentIds) {
            if (!agentIds.contains(agentId)) {
              agentIds.add(agentId);
            }
          }
        }
      }

      debugPrint('Loading places for ${agentIds.length} users: $agentIds');

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

      debugPrint('Loaded ${placesResponse.length} places from database');
      final places = placesResponse.map((json) => Place.fromJson(json)).toList();

      final pendingPlaces = places.where((p) => p.approvalStatus == 'pending').toList();
      final approvedPlaces = places.where((p) => p.approvalStatus == 'approved' && p.status == 'active').toList();
      final rejectedPlaces = places.where((p) => p.approvalStatus == 'rejected').toList();
      final inactivePlaces = places.where((p) => p.status == 'inactive').toList();
      
      debugPrint('Places breakdown: Pending=${pendingPlaces.length}, Approved=${approvedPlaces.length}, Rejected=${rejectedPlaces.length}, Inactive=${inactivePlaces.length}');

      setState(() {
        _pendingPlaces = pendingPlaces;
        _approvedPlaces = approvedPlaces;
        _rejectedPlaces = rejectedPlaces;
        _inactivePlaces = inactivePlaces;
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading places: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading places: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('${AppLocalizations.of(context)!.places} Management'),
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
                  Text('${AppLocalizations.of(context)!.pending} (${_pendingPlaces.length})', 
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
                  Text('${AppLocalizations.of(context)!.approved} (${_approvedPlaces.length})', 
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
                  Text('${AppLocalizations.of(context)!.rejected} (${_rejectedPlaces.length})', 
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
                  Text('${AppLocalizations.of(context)!.inactive} (${_inactivePlaces.length})', 
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
        label: Text('${AppLocalizations.of(context)!.add} ${AppLocalizations.of(context)!.place}'),
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
        emptyTitle = AppLocalizations.of(context)!.noPendingSuggestions;
        emptySubtitle = AppLocalizations.of(context)!.agentSuggestionsWillAppearHere;
      } else if (isInactive) {
        emptyIcon = Icons.visibility_off;
        emptyTitle = AppLocalizations.of(context)!.noInactivePlaces;
        emptySubtitle = AppLocalizations.of(context)!.deactivatedPlacesWillAppearHere;
      } else {
        emptyIcon = Icons.location_on;
        emptyTitle = AppLocalizations.of(context)!.noPlacesFound;
        emptySubtitle = AppLocalizations.of(context)!.placesWillAppearHereOnceAdded;
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
                          AppLocalizations.of(context)!.view,
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
                  '${AppLocalizations.of(context)!.suggestedBy}: ${place.createdByUser?.fullName ?? AppLocalizations.of(context)!.unknown}',
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
                      label: Text(AppLocalizations.of(context)!.reject),
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
                      label: Text(AppLocalizations.of(context)!.approve),
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
                        '${AppLocalizations.of(context)!.rejectionReason}: ${place.rejectionReason}',
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
                      AppLocalizations.of(context)!.thisPlaceIsInactiveAndHiddenFromNewRoutes,
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
                    label: Text('${AppLocalizations.of(context)!.reactivate} ${AppLocalizations.of(context)!.place}'),
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
                    label: Text('${AppLocalizations.of(context)!.remove} ${AppLocalizations.of(context)!.place}'),
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
        title: Text('${AppLocalizations.of(context)!.reject} ${AppLocalizations.of(context)!.place} ${AppLocalizations.of(context)!.suggestion}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${AppLocalizations.of(context)!.areYouSureYouWantToReject} "${place.name}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: '${AppLocalizations.of(context)!.rejectionReason} (${AppLocalizations.of(context)!.optional})',
                hintText: AppLocalizations.of(context)!.explainWhyThisPlaceWasRejected,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.reject),
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
          title: Text('${AppLocalizations.of(context)!.add} ${AppLocalizations.of(context)!.newPlace}'),
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
                      decoration: InputDecoration(
                        labelText: '${AppLocalizations.of(context)!.placeName} *',
                        hintText: AppLocalizations.of(context)!.enterPlaceName,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppLocalizations.of(context)!.placeNameIsRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.description,
                        hintText: AppLocalizations.of(context)!.briefDescriptionOfThePlace,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.address,
                        hintText: '${AppLocalizations.of(context)!.physicalAddress} (${AppLocalizations.of(context)!.optional})',
                        border: const OutlineInputBorder(),
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
                                Text(
                                  '${AppLocalizations.of(context)!.location} & ${AppLocalizations.of(context)!.geofence} *',
                                  style: const TextStyle(
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
                                              AppLocalizations.of(context)!.locationSelected,
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
                                            '${AppLocalizations.of(context)!.geofence}: ${geofenceRadius!.round()}m ${AppLocalizations.of(context)!.radius}',
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
                                    label: Text(selectedLocation == null ? AppLocalizations.of(context)!.selectLocationOnMap : AppLocalizations.of(context)!.changeLocation),
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
                              AppLocalizations.of(context)!.managerCreatedPlacesAreAutomaticallyApprovedAndReadyForUse,
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
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedLocation == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.pleaseSelectLocationOnMap),
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
              child: Text('${AppLocalizations.of(context)!.add} ${AppLocalizations.of(context)!.place}'),
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
        context.showSnackBar(AppLocalizations.of(context)!.authenticationRequired, isError: true);
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
    debugPrint('=== PLACE DELETION STARTED ===');
    debugPrint('Place ID: ${place.id}');
    debugPrint('Place Name: ${place.name}');
    
    // Check comprehensive place usage
    debugPrint('Checking place usage...');
    final usageDetails = await _checkPlaceUsageDetails(place.id);
    final hasUsage = usageDetails['inRoutes'] as bool || usageDetails['inVisits'] as bool;
    
    debugPrint('Usage check results:');
    debugPrint('- Has usage: $hasUsage');
    debugPrint('- In routes: ${usageDetails['inRoutes']}');
    debugPrint('- In visits: ${usageDetails['inVisits']}');
    debugPrint('- Route count: ${usageDetails['routeCount']}');
    debugPrint('- Visit count: ${usageDetails['visitCount']}');
    
    if (hasUsage) {
      debugPrint('Place has usage - showing usage dialog');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.cannotRemovePlace),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppLocalizations.of(context)!.thePlaceCannotBeDeletedBecauseItHasHistoricalDataOrIsCurrentlyInUse.replaceFirst('{placeName}', place.name)}:',
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
                                '${AppLocalizations.of(context)!.usedInRoutes.replaceFirst('{count}', usageDetails['routeCount'].toString())}:',
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
                              AppLocalizations.of(context)!.hasHistoricalVisitRecords.replaceFirst('{count}', usageDetails['visitCount'].toString()),
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
                              AppLocalizations.of(context)!.whatYouCanDo,
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
                            '• ${AppLocalizations.of(context)!.removeThisPlaceFromAllRoutesFirst}',
                            style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                          ),
                        if (usageDetails['inVisits'] as bool)
                          Text(
                            '• ${AppLocalizations.of(context)!.markThePlaceAsInactiveToHideItFromNewRoutesWhilePreservingHistory}',
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
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              if (usageDetails['inRoutes'] as bool)
                ElevatedButton(
                  onPressed: () {
                    debugPrint('USER CLICKED UNDERSTOOD - Closing dialog only');
                    Navigator.pop(context); // Only close the dialog, don't navigate away
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(AppLocalizations.of(context)!.ok),
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
                  child: Text('${AppLocalizations.of(context)!.deactivate} ${AppLocalizations.of(context)!.place}'),
                ),
            ],
          ),
        );
      }
      return;
    }

    // For places with no usage, show simple confirmation
    debugPrint('Place has no usage - showing confirmation dialog');
    if (!mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${AppLocalizations.of(context)!.remove} ${AppLocalizations.of(context)!.place}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppLocalizations.of(context)!.areYouSureYouWantToPermanentlyRemove} "${place.name}"?'),
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
                      AppLocalizations.of(context)!.thisPlaceIsNotUsedInAnyRoutesOrVisitsAndCanBeSafelyDeleted,
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
                      AppLocalizations.of(context)!.thisActionCannotBeUndoneThePlaceWillBePermanentlyDeletedFromTheSystem,
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
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.deletePermanently),
          ),
        ],
      ),
    );

    debugPrint('Confirmation dialog result: $confirmed');
    
    if (confirmed == true) {
      debugPrint('User confirmed deletion - proceeding with database delete');
      try {
        // Delete the place from the database
        debugPrint('Attempting to delete place with ID: ${place.id}');
        final deleteResponse = await supabase
            .from('places')
            .delete()
            .eq('id', place.id)
            .select(); // Add select() to get response details
        
        debugPrint('Delete response: $deleteResponse');
        
        // Verify the deletion by checking if place still exists
        final verificationResponse = await supabase
            .from('places')
            .select('id')
            .eq('id', place.id)
            .maybeSingle();
            
        if (verificationResponse != null) {
          debugPrint('WARNING: Place still exists after deletion attempt!');
          if (mounted) {
            context.showSnackBar('Error: Place was not removed. It may be protected by database constraints.', isError: true);
          }
          return;
        }
        
        debugPrint('Place successfully deleted and verified');
        if (mounted) {
          context.showSnackBar('Place removed successfully.');
          _loadPlaces(); // Refresh the list
        }

      } catch (e) {
        debugPrint('Error during place deletion: $e');
        if (mounted) {
          String errorMessage = 'Error removing place: $e';
          
          // Provide more specific error messages for common issues
          if (e.toString().contains('foreign key constraint')) {
            errorMessage = 'Cannot remove place: it is still referenced in routes or visits. Please remove from routes first.';
          } else if (e.toString().contains('RLS policy')) {
            errorMessage = 'Permission denied: you do not have rights to remove this place.';
          } else if (e.toString().contains('violates check constraint')) {
            errorMessage = 'Cannot remove place: it violates database constraints.';
          }
          
          context.showSnackBar(errorMessage, isError: true);
        }
      }
    } else {
      debugPrint('User cancelled place deletion');
    }
    
    debugPrint('=== PLACE DELETION ENDED ===');
  }

  Future<Map<String, dynamic>> _checkPlaceUsageDetails(String placeId) async {
    try {
      debugPrint('Checking usage details for place ID: $placeId');
      
      // Check all possible usages of the place
      final results = {
        'inRoutes': false,
        'inVisits': false,
        'routeCount': 0,
        'visitCount': 0,
        'routeNames': <String>[],
      };

      // Check route_places - places used in routes
      debugPrint('Checking route_places table...');
      final routePlacesResponse = await supabase
          .from('route_places')
          .select('route_id, routes!inner(name, status)')
          .eq('place_id', placeId);
      
      debugPrint('Found ${routePlacesResponse.length} route_places entries for place');

      if (routePlacesResponse.isNotEmpty) {
        results['inRoutes'] = true;
        results['routeCount'] = routePlacesResponse.length;
        results['routeNames'] = routePlacesResponse
            .map((rp) => rp['routes']['name'] as String)
            .toList();
        debugPrint('Place is used in routes: ${results['routeNames']}');
      }

      // Check place_visits - historical visit records
      debugPrint('Checking place_visits table...');
      final placeVisitsResponse = await supabase
          .from('place_visits')
          .select('id')
          .eq('place_id', placeId);
      
      debugPrint('Found ${placeVisitsResponse.length} place_visits entries for place');

      if (placeVisitsResponse.isNotEmpty) {
        results['inVisits'] = true;
        results['visitCount'] = placeVisitsResponse.length;
      }

      // Additional checks for other possible references
      debugPrint('Checking for additional references...');
      
      // Check if place is referenced in campaigns (if there's a direct relationship)
      try {
        final campaignPlacesResponse = await supabase
            .from('campaign_places')
            .select('campaign_id')
            .eq('place_id', placeId);
        
        if (campaignPlacesResponse.isNotEmpty) {
          debugPrint('WARNING: Place is also referenced in campaign_places table');
          results['inCampaigns'] = true;
          results['campaignCount'] = campaignPlacesResponse.length;
        }
      } catch (e) {
        // campaign_places table might not exist, that's fine
        debugPrint('campaign_places table check failed (table may not exist): $e');
      }
      
      // Check task assignments that might reference this place
      try {
        final taskAssignmentsResponse = await supabase
            .from('task_assignments')
            .select('id, tasks!inner(place_id)')
            .eq('tasks.place_id', placeId);
            
        if (taskAssignmentsResponse.isNotEmpty) {
          debugPrint('WARNING: Place is referenced in task_assignments through tasks');
          results['inTaskAssignments'] = true;
          results['taskAssignmentCount'] = taskAssignmentsResponse.length;
        }
      } catch (e) {
        debugPrint('task_assignments check failed: $e');
      }

      debugPrint('Usage check complete. Results: $results');
      return results;
      
    } catch (e) {
      debugPrint('Error checking place usage: $e');
      // Return conservative result - assume usage if we can't check
      return {
        'inRoutes': true,
        'inVisits': true,
        'routeCount': 0,
        'visitCount': 0,
        'routeNames': <String>[],
        'error': e.toString(),
      };
    }
  }

  Future<void> _deactivatePlace(Place place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${AppLocalizations.of(context)!.deactivate} ${AppLocalizations.of(context)!.place}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppLocalizations.of(context)!.areYouSureYouWantToDeactivate} "${place.name}"?'),
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
                      AppLocalizations.of(context)!.thePlaceWillBeHiddenFromNewRoutesButAllHistoricalDataWillBePreservedYouCanReactivateItLater,
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
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.deactivate),
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
          snippet: _isEditing ? AppLocalizations.of(context)!.tapToMoveLocation : widget.place.address,
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
              tooltip: AppLocalizations.of(context)!.editLocation,
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
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: const TextStyle(color: Colors.white),
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
                  : Text(
                      AppLocalizations.of(context)!.save,
                      style: const TextStyle(
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
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.editModeActive,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.tapOnTheMapOrDragTheMarkerToChangeTheLocation,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                        Text(
                          '${AppLocalizations.of(context)!.geofence} ${AppLocalizations.of(context)!.radius}:',
                          style: const TextStyle(
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