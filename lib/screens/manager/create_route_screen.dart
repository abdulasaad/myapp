// lib/screens/manager/create_route_screen.dart

import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../models/place.dart';
import '../../models/route_place.dart';

class CreateRouteScreen extends StatefulWidget {
  const CreateRouteScreen({super.key});

  @override
  State<CreateRouteScreen> createState() => _CreateRouteScreenState();
}

class _CreateRouteScreenState extends State<CreateRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;
  List<Place> _availablePlaces = [];
  List<RoutePlace> _selectedPlaces = [];
  bool _isLoading = false;
  bool _isLoadingPlaces = true;
  
  // Time input controllers for estimated duration
  final _estimatedHoursController = TextEditingController();
  final _estimatedMinutesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAvailablePlaces();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _estimatedHoursController.dispose();
    _estimatedMinutesController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailablePlaces() async {
    setState(() => _isLoadingPlaces = true);
    
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
          _availablePlaces = [];
          _isLoadingPlaces = false;
        });
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

      // Add current manager to the list to include their own places
      agentIds.add(currentUser.id);

      // Get approved places created by agents in manager's groups or by manager
      final placesResponse = await supabase
          .from('places')
          .select('*')
          .eq('approval_status', 'approved')
          .eq('status', 'active')
          .inFilter('created_by', agentIds)
          .order('name');

      final places = placesResponse.map((json) => Place.fromJson(json)).toList();

      setState(() {
        _availablePlaces = places;
        _isLoadingPlaces = false;
      });

    } catch (e) {
      setState(() => _isLoadingPlaces = false);
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
        title: const Text('Create Route'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveRoute,
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRouteDetailsSection(),
              const SizedBox(height: 24),
              _buildDateSection(),
              const SizedBox(height: 24),
              _buildPlacesSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteDetailsSection() {
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
                  'Route Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Route Name *',
                hintText: 'Enter route name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Route name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Brief description of the route',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimated Duration',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Hours input
                      Expanded(
                        child: TextFormField(
                          controller: _estimatedHoursController,
                          decoration: const InputDecoration(
                            labelText: 'Hours',
                            hintText: '0',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Minutes input
                      Expanded(
                        child: TextFormField(
                          controller: _estimatedMinutesController,
                          decoration: const InputDecoration(
                            labelText: 'Minutes',
                            hintText: '0',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Schedule',
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
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Start Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondaryColor,
                                  ),
                                ),
                                Text(
                                  _startDate != null
                                      ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                      : 'Select start date',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _startDate != null ? textPrimaryColor : Colors.grey,
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
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'End Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondaryColor,
                                  ),
                                ),
                                Text(
                                  _endDate != null
                                      ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                      : 'Select end date',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _endDate != null ? textPrimaryColor : Colors.grey,
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacesSection() {
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
                  'Route Places',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _showAddPlaceDialog,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_selectedPlaces.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No places added',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add places to create your route',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedPlaces.length,
                onReorder: _reorderPlaces,
                itemBuilder: (context, index) {
                  final routePlace = _selectedPlaces[index];
                  return _buildRouteePlaceCard(routePlace, index, key: ValueKey(routePlace.placeId));
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteePlaceCard(RoutePlace routePlace, int index, {required Key key}) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          routePlace.place?.name ?? 'Unknown Place',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Duration: ${routePlace.estimatedDurationMinutes}min • Evidence: ${routePlace.requiredEvidenceCount} • Visits: ${routePlace.visitFrequency}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _editRoutePlace(index),
              icon: const Icon(Icons.edit, size: 20),
            ),
            IconButton(
              onPressed: () => _removePlace(index),
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
            ),
            const Icon(Icons.drag_handle),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate 
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // If end date is before start date, clear it
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _showAddPlaceDialog() {
    if (_isLoadingPlaces) {
      context.showSnackBar('Loading places...', isError: false);
      return;
    }

    if (_availablePlaces.isEmpty) {
      context.showSnackBar('No approved places available. Ask agents to suggest places.', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _buildAddPlaceDialog(),
    );
  }

  Widget _buildAddPlaceDialog() {
    final availablePlaces = _availablePlaces.where((place) {
      return !_selectedPlaces.any((rp) => rp.placeId == place.id);
    }).toList();

    return AlertDialog(
      title: const Text('Add Place to Route'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: availablePlaces.isEmpty
            ? const Center(
                child: Text('All available places have been added to the route.'),
              )
            : ListView.builder(
                itemCount: availablePlaces.length,
                itemBuilder: (context, index) {
                  final place = availablePlaces[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(place.name),
                    subtitle: place.address?.isNotEmpty == true
                        ? Text(place.address!)
                        : Text('${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}'),
                    onTap: () {
                      Navigator.pop(context);
                      _addPlace(place);
                    },
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
    );
  }

  void _addPlace(Place place) {
    setState(() {
      _selectedPlaces.add(RoutePlace(
        id: '', // Will be generated when saved
        routeId: '', // Will be set when route is created
        placeId: place.id,
        visitOrder: _selectedPlaces.length + 1,
        estimatedDurationMinutes: 30, // Default
        requiredEvidenceCount: 1, // Default
        visitFrequency: 1, // Default
        instructions: null,
        createdAt: DateTime.now(),
        place: place,
      ));
    });
  }

  void _removePlace(int index) {
    setState(() {
      _selectedPlaces.removeAt(index);
      // Update visit orders
      for (int i = 0; i < _selectedPlaces.length; i++) {
        _selectedPlaces[i] = _selectedPlaces[i].copyWith(visitOrder: i + 1);
      }
    });
  }

  void _reorderPlaces(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final RoutePlace item = _selectedPlaces.removeAt(oldIndex);
      _selectedPlaces.insert(newIndex, item);
      
      // Update visit orders
      for (int i = 0; i < _selectedPlaces.length; i++) {
        _selectedPlaces[i] = _selectedPlaces[i].copyWith(visitOrder: i + 1);
      }
    });
  }

  void _editRoutePlace(int index) {
    final routePlace = _selectedPlaces[index];
    final durationHours = (routePlace.estimatedDurationMinutes ?? 30) ~/ 60;
    final durationMinutes = (routePlace.estimatedDurationMinutes ?? 30) % 60;
    final hoursController = TextEditingController(text: durationHours.toString());
    final minutesController = TextEditingController(text: durationMinutes.toString());
    final evidenceController = TextEditingController(text: routePlace.requiredEvidenceCount.toString());
    final frequencyController = TextEditingController(text: routePlace.visitFrequency.toString());
    final instructionsController = TextEditingController(text: routePlace.instructions ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${routePlace.place?.name ?? 'Place'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimated Duration',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Hours input
                      Expanded(
                        child: TextFormField(
                          controller: hoursController,
                          decoration: const InputDecoration(
                            labelText: 'Hours',
                            hintText: '0',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Minutes input
                      Expanded(
                        child: TextFormField(
                          controller: minutesController,
                          decoration: const InputDecoration(
                            labelText: 'Minutes',
                            hintText: '0',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: evidenceController,
                    decoration: const InputDecoration(
                      labelText: 'Required Evidence',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: frequencyController,
                    decoration: const InputDecoration(
                      labelText: 'Visit Frequency',
                      hintText: '1-10',
                      border: OutlineInputBorder(),
                      helperText: 'Times to visit',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (routePlace.visitFrequency > 1)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Agent must visit ${routePlace.visitFrequency} times with 12-hour cooldown between visits',
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: instructionsController,
              decoration: const InputDecoration(
                labelText: 'Instructions (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final hours = int.tryParse(hoursController.text) ?? 0;
              final minutes = int.tryParse(minutesController.text) ?? 0;
              final totalMinutes = (hours * 60) + minutes;
              final evidence = int.tryParse(evidenceController.text) ?? 1;
              final frequency = int.tryParse(frequencyController.text) ?? 1;
              
              // Validate frequency
              if (frequency < 1 || frequency > 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Visit frequency must be between 1 and 10')),
                );
                return;
              }
              
              setState(() {
                _selectedPlaces[index] = _selectedPlaces[index].copyWith(
                  estimatedDurationMinutes: totalMinutes,
                  requiredEvidenceCount: evidence,
                  visitFrequency: frequency,
                  instructions: instructionsController.text.trim().isNotEmpty 
                      ? instructionsController.text.trim()
                      : null,
                );
              });
              
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRoute() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPlaces.isEmpty) {
      context.showSnackBar('Please add at least one place to the route', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        context.showSnackBar('Authentication required', isError: true);
        return;
      }

      // Create the route
      final routeResponse = await supabase.from('routes').insert({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
        'created_by': currentUser.id,
        'assigned_manager_id': currentUser.id,
        'start_date': _startDate?.toIso8601String().split('T')[0],
        'end_date': _endDate?.toIso8601String().split('T')[0],
        'estimated_duration_hours': (() {
          final hours = int.tryParse(_estimatedHoursController.text) ?? 0;
          final minutes = int.tryParse(_estimatedMinutesController.text) ?? 0;
          final totalHours = hours + (minutes / 60.0);
          return totalHours > 0 ? totalHours.ceil() : null;
        })(),
        'status': 'active', // Create as active, bypassing draft
      }).select().single();

      final routeId = routeResponse['id'];

      // Add places to the route
      final routePlaces = _selectedPlaces.map((rp) => {
        'route_id': routeId,
        'place_id': rp.placeId,
        'visit_order': rp.visitOrder,
        'estimated_duration_minutes': rp.estimatedDurationMinutes,
        'required_evidence_count': rp.requiredEvidenceCount,
        'visit_frequency': rp.visitFrequency,
        'instructions': rp.instructions,
      }).toList();

      await supabase.from('route_places').insert(routePlaces);

      if (mounted) {
        context.showSnackBar('Route created successfully!');
        Navigator.pop(context, true); // Return true to indicate success
      }

    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error creating route: $e', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}