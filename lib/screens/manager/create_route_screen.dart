// lib/screens/manager/create_route_screen.dart

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
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
  final _pointsController = TextEditingController();

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
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailablePlaces() async {
    setState(() => _isLoadingPlaces = true);
    
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Always include the current manager's places
      List<String> agentIds = [currentUser.id];

      // Get manager's groups
      final managerGroups = await supabase
          .from('user_groups')
          .select('group_id')
          .eq('user_id', currentUser.id);

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
        title: Text('${AppLocalizations.of(context)!.create} ${AppLocalizations.of(context)!.route}'),
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
                : Text(
                    AppLocalizations.of(context)!.save,
                    style: const TextStyle(
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
                Text(
                  '${AppLocalizations.of(context)!.route} ${AppLocalizations.of(context)!.details}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '${AppLocalizations.of(context)!.routeName} *',
                hintText: AppLocalizations.of(context)!.enterRouteName,
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppLocalizations.of(context)!.routeNameIsRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.description,
                hintText: AppLocalizations.of(context)!.briefDescriptionOfTheRoute,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pointsController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.pointsAwarded,
                hintText: AppLocalizations.of(context)!.pointsAwardedHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.stars),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return null; // Points are optional
                }
                final points = int.tryParse(value.trim());
                if (points == null || points < 0) {
                  return 'Please enter a valid number (0 or greater)';
                }
                return null;
              },
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
                  Text(
                    AppLocalizations.of(context)!.estimatedDuration,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Hours input
                      Expanded(
                        child: TextFormField(
                          controller: _estimatedHoursController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.hours,
                            hintText: '0',
                            border: const OutlineInputBorder(),
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
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.minutes,
                            hintText: '0',
                            border: const OutlineInputBorder(),
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
                Text(
                  AppLocalizations.of(context)!.schedule,
                  style: const TextStyle(
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
                                Text(
                                  AppLocalizations.of(context)!.startDate,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: textSecondaryColor,
                                  ),
                                ),
                                Text(
                                  _startDate != null
                                      ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                      : AppLocalizations.of(context)!.selectDays,
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
                                Text(
                                  AppLocalizations.of(context)!.endDate,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: textSecondaryColor,
                                  ),
                                ),
                                Text(
                                  _endDate != null
                                      ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                      : AppLocalizations.of(context)!.selectDays,
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
                Text(
                  '${AppLocalizations.of(context)!.route} ${AppLocalizations.of(context)!.places}',
                  style: const TextStyle(
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
                      AppLocalizations.of(context)!.noPlacesAdded,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)!.addPlacesToCreateYourRoute,
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
          '${AppLocalizations.of(context)!.duration}: ${routePlace.estimatedDurationMinutes}min • ${AppLocalizations.of(context)!.evidence}: ${routePlace.requiredEvidenceCount} • ${AppLocalizations.of(context)!.visits}: ${routePlace.visitFrequency}',
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
      firstDate: isStartDate 
          ? DateTime.now() 
          : (_startDate ?? DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = DateTime(picked.year, picked.month, picked.day);
          // If end date is before start date, clear it
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = DateTime(picked.year, picked.month, picked.day);
        }
      });
    }
  }

  void _showAddPlaceDialog() {
    if (_isLoadingPlaces) {
      context.showSnackBar(AppLocalizations.of(context)!.loadingPlaces, isError: false);
      return;
    }

    if (_availablePlaces.isEmpty) {
      context.showSnackBar(AppLocalizations.of(context)!.noApprovedPlacesAvailableAskAgentsToSuggestPlaces, isError: true);
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
      title: Text('${AppLocalizations.of(context)!.add} ${AppLocalizations.of(context)!.place} ${AppLocalizations.of(context)!.to} ${AppLocalizations.of(context)!.route}'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: availablePlaces.isEmpty
            ? Center(
                child: Text(AppLocalizations.of(context)!.allAvailablePlacesHaveBeenAddedToTheRoute),
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
          child: Text(AppLocalizations.of(context)!.cancel),
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
    final durationHours = routePlace.estimatedDurationMinutes ~/ 60;
    final durationMinutes = routePlace.estimatedDurationMinutes % 60;
    final hoursController = TextEditingController(text: durationHours.toString());
    final minutesController = TextEditingController(text: durationMinutes.toString());
    final evidenceController = TextEditingController(text: routePlace.requiredEvidenceCount.toString());
    final frequencyController = TextEditingController(text: routePlace.visitFrequency.toString());
    final instructionsController = TextEditingController(text: routePlace.instructions ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${AppLocalizations.of(context)!.edit} ${routePlace.place?.name ?? AppLocalizations.of(context)!.place}'),
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
                  Text(
                    AppLocalizations.of(context)!.estimatedDuration,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Hours input
                      Expanded(
                        child: TextFormField(
                          controller: hoursController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.hours,
                            hintText: '0',
                            border: const OutlineInputBorder(),
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
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.minutes,
                            hintText: '0',
                            border: const OutlineInputBorder(),
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
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.requiredEvidence,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: frequencyController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.visitFrequency,
                      hintText: '1-10',
                      border: const OutlineInputBorder(),
                      helperText: AppLocalizations.of(context)!.timesToVisit,
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
                        AppLocalizations.of(context)!.agentMustVisitTimesWithCooldown(routePlace.visitFrequency, 24),
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: instructionsController,
              decoration: InputDecoration(
                labelText: '${AppLocalizations.of(context)!.instructions} (${AppLocalizations.of(context)!.optional})',
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
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
                  SnackBar(content: Text(AppLocalizations.of(context)!.visitFrequencyMustBeBetween1And10)),
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
            child: Text(AppLocalizations.of(context)!.save),
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
      context.showSnackBar(AppLocalizations.of(context)!.pleaseAddAtLeastOnePlaceToTheRoute, isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        context.showSnackBar(AppLocalizations.of(context)!.authenticationRequired, isError: true);
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
        'points': int.tryParse(_pointsController.text) ?? 0,
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
        context.showSnackBar(AppLocalizations.of(context)!.routeCreatedSuccessfully);
        Navigator.pop(context, true); // Return true to indicate success
      }

    } catch (e) {
      if (mounted) {
        context.showSnackBar('${AppLocalizations.of(context)!.errorCreatingRoute}: $e', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}