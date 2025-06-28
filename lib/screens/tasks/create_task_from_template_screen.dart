// lib/screens/tasks/create_task_from_template_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/task_template.dart';
import '../../models/template_field.dart';
import '../../models/task.dart';
import '../../models/app_user.dart';
import '../../services/template_service.dart';
import '../../services/location_service.dart';
import '../../services/user_management_service.dart';
import '../../utils/constants.dart';
import '../tasks/task_geofence_editor_screen.dart';

class CreateTaskFromTemplateScreen extends StatefulWidget {
  final TaskTemplate template;

  const CreateTaskFromTemplateScreen({super.key, required this.template});

  @override
  State<CreateTaskFromTemplateScreen> createState() => _CreateTaskFromTemplateScreenState();
}

class _CreateTaskFromTemplateScreenState extends State<CreateTaskFromTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final TemplateService _templateService = TemplateService();
  
  late Future<TaskTemplate?> _templateWithFieldsFuture;
  bool _isLoading = false;

  // Basic task fields
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _pointsController = TextEditingController();
  final _evidenceCountController = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;
  bool _enableGeofence = false;
  List<LatLng>? _geofencePoints; // Store geofence points before task creation
  
  // Custom fields values
  final Map<String, dynamic> _customFieldValues = {};
  final Map<String, TextEditingController> _customFieldControllers = {};
  
  // Dynamic field builder for managers
  final List<TemplateField> _dynamicFields = [];
  
  // Manager assignment (for admin only)
  String? _selectedManagerId;
  List<AppUser> _managers = [];
  bool _isAdmin = false;
  bool _managersLoaded = false;

  @override
  void initState() {
    super.initState();
    _templateWithFieldsFuture = _templateService.getTemplateWithFields(widget.template.id);
    _initializeFields();
    
    // Check if current user is admin and load managers
    _checkUserRoleAndLoadManagers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationNameController.dispose();
    _pointsController.dispose();
    _evidenceCountController.dispose();
    
    // Dispose custom field controllers
    for (final controller in _customFieldControllers.values) {
      controller.dispose();
    }
    
    super.dispose();
  }

  void _initializeFields() {
    _titleController.text = '';
    _descriptionController.text = widget.template.description;
    _pointsController.text = widget.template.defaultPoints.toString();
    _evidenceCountController.text = widget.template.defaultEvidenceCount.toString();
    _enableGeofence = widget.template.requiresGeofence;
  }

  void _initializeCustomFields(List<TemplateField> fields) {
    for (final field in fields) {
      if (!_customFieldControllers.containsKey(field.fieldName)) {
        _customFieldControllers[field.fieldName] = TextEditingController();
      }
      
      // Set default values for some field types
      if (field.fieldType == TemplateFieldType.boolean) {
        _customFieldValues[field.fieldName] = false;
      }
    }
  }

  bool _isDataCollectionTemplate(TaskTemplate template) {
    return template.taskType == TaskType.dataCollection || 
           template.taskType == TaskType.survey ||
           template.taskType == TaskType.inspection;
  }

  Future<void> _checkUserRoleAndLoadManagers() async {
    try {
      final userRole = await UserManagementService().getCurrentUserRole();
      final isAdmin = userRole == 'admin';
      
      debugPrint('[TemplateTaskCreation] User role: $userRole, isAdmin: $isAdmin');
      
      setState(() {
        _isAdmin = isAdmin;
      });
      
      if (isAdmin) {
        debugPrint('[TemplateTaskCreation] Loading managers for admin user...');
        await _loadManagers();
      } else {
        debugPrint('[TemplateTaskCreation] User is not admin, skipping manager loading');
        setState(() {
          _managersLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error checking user role: $e');
      setState(() {
        _managersLoaded = true;
      });
    }
  }

  Future<void> _loadManagers() async {
    try {
      final managers = await UserManagementService().getUsers(
        roleFilter: 'manager',
        statusFilter: 'active',
      );
      
      debugPrint('[TemplateTaskCreation] Loaded ${managers.length} managers: ${managers.map((m) => m.fullName).join(', ')}');
      
      setState(() {
        _managers = managers;
        _managersLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading managers: $e');
      setState(() {
        _managersLoaded = true;
      });
    }
  }

  Widget _buildDynamicFieldsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Custom Form Fields',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addDynamicField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Field'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Create custom fields that agents will fill out when completing this task',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            if (_dynamicFields.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.text_fields, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No custom fields yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Click "Add Field" to create form fields',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._dynamicFields.asMap().entries.map((entry) => 
                _buildDynamicFieldItem(entry.key, entry.value)
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicFieldItem(int index, TemplateField field) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getFieldTypeIcon(field.fieldType),
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  field.fieldLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _editDynamicField(index),
                icon: const Icon(Icons.edit, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _removeDynamicField(index),
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  field.fieldType.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (field.isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          if (field.placeholderText != null && field.placeholderText!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Placeholder: ${field.placeholderText}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
          if (field.fieldOptions != null && field.fieldOptions!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Options: ${field.fieldOptions!.join(', ')}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getFieldTypeIcon(TemplateFieldType type) {
    switch (type) {
      case TemplateFieldType.text:
        return Icons.text_fields;
      case TemplateFieldType.number:
        return Icons.numbers;
      case TemplateFieldType.date:
        return Icons.calendar_today;
      case TemplateFieldType.time:
        return Icons.access_time;
      case TemplateFieldType.boolean:
      case TemplateFieldType.checkbox:
        return Icons.check_box;
      case TemplateFieldType.radio:
        return Icons.radio_button_checked;
      case TemplateFieldType.select:
        return Icons.arrow_drop_down_circle;
      case TemplateFieldType.multiselect:
        return Icons.checklist;
      case TemplateFieldType.textarea:
        return Icons.notes;
      case TemplateFieldType.email:
        return Icons.email;
      case TemplateFieldType.phone:
        return Icons.phone;
    }
  }

  void _addDynamicField() {
    _showFieldEditorDialog();
  }

  void _editDynamicField(int index) {
    _showFieldEditorDialog(field: _dynamicFields[index], index: index);
  }

  void _removeDynamicField(int index) {
    setState(() {
      _dynamicFields.removeAt(index);
    });
  }

  void _showFieldEditorDialog({TemplateField? field, int? index}) {
    final isEditing = field != null;
    final labelController = TextEditingController(text: field?.fieldLabel ?? '');
    final placeholderController = TextEditingController(text: field?.placeholderText ?? '');
    final optionsController = TextEditingController(
      text: field?.fieldOptions?.join(', ') ?? ''
    );
    
    TemplateFieldType selectedType = field?.fieldType ?? TemplateFieldType.text;
    bool isRequired = field?.isRequired ?? false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? 'Edit Field' : 'Add Custom Field'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Field Label*',
                    hintText: 'e.g., Customer Name, Satisfaction Level',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TemplateFieldType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Field Type',
                    border: OutlineInputBorder(),
                  ),
                  items: TemplateFieldType.values.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: placeholderController,
                  decoration: const InputDecoration(
                    labelText: 'Placeholder Text (Optional)',
                    hintText: 'Hint text shown in the field',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (selectedType == TemplateFieldType.select || 
                    selectedType == TemplateFieldType.multiselect ||
                    selectedType == TemplateFieldType.radio) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: optionsController,
                    decoration: const InputDecoration(
                      labelText: 'Options (comma separated)*',
                      hintText: 'Option 1, Option 2, Option 3',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Required Field'),
                  subtitle: const Text('Agent must fill this field'),
                  value: isRequired,
                  onChanged: (value) => setState(() => isRequired = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (labelController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Field label is required')),
                  );
                  return;
                }

                List<String>? options;
                if (selectedType == TemplateFieldType.select || 
                    selectedType == TemplateFieldType.multiselect ||
                    selectedType == TemplateFieldType.radio) {
                  options = optionsController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  
                  if (options.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Options are required for this field type')),
                    );
                    return;
                  }
                }

                final newField = TemplateField(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  templateId: widget.template.id,
                  fieldName: labelController.text.toLowerCase().replaceAll(' ', '_'),
                  fieldType: selectedType,
                  fieldLabel: labelController.text.trim(),
                  placeholderText: placeholderController.text.trim().isEmpty ? null : placeholderController.text.trim(),
                  isRequired: isRequired,
                  fieldOptions: options,
                  validationRules: {},
                  sortOrder: index ?? _dynamicFields.length,
                  createdAt: DateTime.now(),
                );

                Navigator.of(context).pop();
                
                this.setState(() {
                  if (isEditing && index != null) {
                    _dynamicFields[index] = newField;
                  } else {
                    _dynamicFields.add(newField);
                  }
                });
              },
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTask(TaskTemplate template) async {
    debugPrint('[TaskCreation] Starting task creation...');
    debugPrint('[TaskCreation] Form validation...');
    if (!_formKey.currentState!.validate()) {
      debugPrint('[TaskCreation] Form validation failed');
      return;
    }

    debugPrint('[TaskCreation] Dynamic fields count: ${_dynamicFields.length}');
    
    // Check for required title
    if (_titleController.text.trim().isEmpty) {
      debugPrint('[TaskCreation] Title is empty');
      context.showSnackBar('Task title is required', isError: true);
      return;
    }

    // Validate custom fields
    final fields = template.fields ?? [];
    final validationErrors = _templateService.validateCustomFields(fields, _customFieldValues);
    
    if (validationErrors.isNotEmpty) {
      debugPrint('[TaskCreation] Validation errors: $validationErrors');
      _showValidationErrors(validationErrors);
      return;
    }

    debugPrint('[TaskCreation] Setting loading state...');
    setState(() => _isLoading = true);

    try {
      debugPrint('[TaskCreation] Calling template service...');
      final task = await _templateService.createTaskFromTemplate(
        templateId: template.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        locationName: _locationNameController.text.trim().isEmpty 
            ? null 
            : _locationNameController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        customFieldValues: _customFieldValues.isEmpty ? null : _customFieldValues,
        overridePoints: int.tryParse(_pointsController.text),
        overrideGeofence: _enableGeofence,
        overrideEvidenceCount: int.tryParse(_evidenceCountController.text),
        assignedManagerId: _selectedManagerId,
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        debugPrint('[TaskCreation] Task created successfully with ID: ${task.id}');
        debugPrint('[TaskCreation] Geofence enabled: $_enableGeofence');
        debugPrint('[TaskCreation] Geofence points count: ${_geofencePoints?.length ?? 0}');
        
        // Save dynamic fields if any were created
        if (_dynamicFields.isNotEmpty) {
          debugPrint('[TaskCreation] Saving ${_dynamicFields.length} dynamic fields...');
          await _saveDynamicFields(task.id);
        }
        
        if (mounted) {
          context.showSnackBar('Task created successfully!');
        }
        
        // If geofence is enabled and points were set, save them automatically
        if (_enableGeofence && _geofencePoints != null && _geofencePoints!.isNotEmpty) {
          debugPrint('[TaskCreation] About to save geofence...');
          await _saveGeofenceToTask(task, _geofencePoints!);
          if (mounted) {
            Navigator.of(context).pop(task);
          }
        } else if (_enableGeofence) {
          // If geofence is enabled but no points set, ask if they want to set it up
          debugPrint('[TaskCreation] Geofence enabled but no points set, showing dialog');
          if (mounted) {
            _showGeofenceSetupDialog(task);
          }
        } else {
          debugPrint('[TaskCreation] No geofence needed, returning');
          if (mounted) {
            Navigator.of(context).pop(task);
          }
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showSnackBar('Failed to create task: $e', isError: true);
      }
    }
  }

  void _showValidationErrors(Map<String, String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Validation Errors'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: errors.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('• ${entry.value}'),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openGeofenceEditor() async {
    // Navigate to a special geofence editor that returns points instead of saving to DB
    final result = await Navigator.of(context).push<List<LatLng>>(
      MaterialPageRoute(
        builder: (context) => _GeofencePreviewScreen(
          initialPoints: _geofencePoints,
          taskTitle: _titleController.text.isNotEmpty ? _titleController.text : 'New Task',
        ),
      ),
    );
    
    if (result != null && mounted) {
      setState(() {
        _geofencePoints = result;
      });
    }
  }

  Future<void> _saveDynamicFields(String taskId) async {
    debugPrint('[TaskCreation] _saveDynamicFields called with taskId: $taskId');
    debugPrint('[TaskCreation] Dynamic fields to save: ${_dynamicFields.length}');
    
    try {
      // Save each dynamic field to the database
      for (int i = 0; i < _dynamicFields.length; i++) {
        final field = _dynamicFields[i];
        debugPrint('[TaskCreation] Saving field $i: ${field.fieldLabel} (${field.fieldType.name})');
        
        final fieldData = {
          'task_id': taskId,
          'field_name': field.fieldName,
          'field_type': field.fieldType.name,
          'field_label': field.fieldLabel,
          'placeholder_text': field.placeholderText,
          'is_required': field.isRequired,
          'field_options': field.fieldOptions,
          'sort_order': i,
          'created_at': DateTime.now().toIso8601String(),
          'created_by': supabase.auth.currentUser?.id,
        };
        
        debugPrint('[TaskCreation] Field data: $fieldData');
        
        final result = await supabase.from('task_dynamic_fields').insert(fieldData);
        debugPrint('[TaskCreation] Insert result for field $i: $result');
      }
      debugPrint('[TaskCreation] All ${_dynamicFields.length} dynamic fields saved successfully');
    } catch (e) {
      debugPrint('[TaskCreation] Failed to save dynamic fields: $e');
      debugPrint('[TaskCreation] Error type: ${e.runtimeType}');
      // Don't throw - let the task creation succeed even if fields fail
    }
  }

  Future<void> _saveGeofenceToTask(Task task, List<LatLng> points) async {
    try {
      // Convert points to WKT format - matching the existing geofence editor format
      final pointsWkt = points.map((p) => '${p.longitude} ${p.latitude}').join(', ');
      final wktPolygon = 'POLYGON(($pointsWkt, ${points.first.longitude} ${points.first.latitude}))';
      
      debugPrint('[GeofenceSave] Saving geofence for task_id: ${task.id}');
      debugPrint('[GeofenceSave] WKT String to save: $wktPolygon');
      
      // Check if geofence already exists (in case this is called multiple times)
      final existing = await supabase
          .from('geofences')
          .select('id')
          .eq('task_id', task.id)
          .maybeSingle();
      
      if (existing != null) {
        // Update existing geofence
        await supabase.from('geofences').update({
          'name': '${task.title} Geofence',
          'area_text': wktPolygon,
        }).eq('task_id', task.id);
        debugPrint('[GeofenceSave] Updated existing geofence');
      } else {
        // Insert new geofence using a custom RPC function that handles PostGIS conversion
        await supabase.rpc('insert_task_geofence', params: {
          'task_id_param': task.id,
          'geofence_name': '${task.title} Geofence',
          'wkt_polygon': wktPolygon,
        });
        debugPrint('[GeofenceSave] Inserted new geofence using RPC function');
      }
      
      debugPrint('Geofence saved successfully for task ${task.id}');
      
      if (mounted) {
        context.showSnackBar('Task created with geofence successfully!');
      }
    } catch (e) {
      debugPrint('Error saving geofence: $e');
      if (mounted) {
        context.showSnackBar('Warning: Task created but geofence could not be saved: $e', isError: true);
      }
    }
  }

  void _showGeofenceSetupDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Up Geofence'),
        content: const Text('This task requires a location boundary. Would you like to set up the geofence now?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(this.context).pop(task);
            },
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(this.context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => TaskGeofenceEditorScreen(task: task),
                ),
              );
            },
            child: const Text('Set Up Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create from ${widget.template.name}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: FutureBuilder<TaskTemplate?>(
        future: _templateWithFieldsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return preloader;
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading template details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final template = snapshot.data ?? widget.template;
          final fields = template.fields ?? [];
          
          // Initialize custom fields if not already done
          if (fields.isNotEmpty) {
            _initializeCustomFields(fields);
          }

          return _isLoading 
              ? preloader
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTemplateInfoCard(template),
                        const SizedBox(height: 16),
                        _buildBasicFieldsCard(),
                        const SizedBox(height: 16),
                        _buildConfigurationCard(),
                        // Manager Assignment Section (Admin only)
                        if (_isAdmin && _managersLoaded) ...[
                          const SizedBox(height: 16),
                          _buildManagerAssignmentCard(),
                        ],
                        if (fields.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildCustomFieldsCard(fields),
                        ],
                        // Add dynamic field builder for data collection/survey tasks
                        if (_isDataCollectionTemplate(template)) ...[
                          const SizedBox(height: 16),
                          _buildDynamicFieldsCard(),
                        ],
                        const SizedBox(height: 24),
                        _buildCreateButton(template),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
        },
      ),
    );
  }

  Widget _buildTemplateInfoCard(TaskTemplate template) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.article, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Text(
                  'Template: ${template.name}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (template.customInstructions != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.customInstructions!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBasicFieldsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Task Title *',
                hintText: 'Enter a descriptive title for this task',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Task title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional: Add more details about this task',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationNameController,
              decoration: const InputDecoration(
                labelText: 'Location Name',
                hintText: 'Optional: Name of the location (e.g., Main Hospital)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuration',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _pointsController,
                    decoration: const InputDecoration(
                      labelText: 'Points',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.stars),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Points required';
                      if (int.tryParse(value) == null) return 'Invalid number';
                      if (int.parse(value) < 0) return 'Must be positive';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _evidenceCountController,
                    decoration: const InputDecoration(
                      labelText: 'Evidence Files',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.upload_file),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Evidence count required';
                      if (int.tryParse(value) == null) return 'Invalid number';
                      if (int.parse(value) < 1) return 'Must be at least 1';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    'Start Date',
                    _startDate,
                    (date) => setState(() => _startDate = date),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    'End Date',
                    _endDate,
                    (date) => setState(() => _endDate = date),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Require Location Verification'),
              subtitle: const Text('Agent must be at the correct location to submit evidence'),
              value: _enableGeofence,
              onChanged: (value) => setState(() => _enableGeofence = value),
              contentPadding: EdgeInsets.zero,
            ),
            if (_enableGeofence) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _geofencePoints != null ? Icons.check_circle : Icons.location_on,
                          color: _geofencePoints != null ? Colors.green : Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _geofencePoints != null 
                                ? 'Geofence configured (${_geofencePoints!.length} points)'
                                : 'Geofence not set',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: _geofencePoints != null ? Colors.green[700] : Colors.blue[700],
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _openGeofenceEditor,
                          icon: Icon(_geofencePoints != null ? Icons.edit : Icons.add_location),
                          label: Text(_geofencePoints != null ? 'Edit' : 'Set Geofence'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Define the area where agents must be located to complete this task.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFieldsCard(List<TemplateField> fields) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This template requires additional information to be collected from agents.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ...fields.map((field) => _buildCustomFieldWidget(field)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFieldWidget(TemplateField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldByType(field),
          if (field.helpText != null) ...[
            const SizedBox(height: 4),
            Text(
              field.helpText!,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldByType(TemplateField field) {
    switch (field.fieldType) {
      case TemplateFieldType.text:
      case TemplateFieldType.email:
      case TemplateFieldType.phone:
        return _buildTextFieldWidget(field);
      case TemplateFieldType.textarea:
        return _buildTextAreaWidget(field);
      case TemplateFieldType.number:
        return _buildNumberFieldWidget(field);
      case TemplateFieldType.date:
        return _buildDateFieldWidget(field);
      case TemplateFieldType.time:
        return _buildTimeFieldWidget(field);
      case TemplateFieldType.boolean:
      case TemplateFieldType.checkbox:
        return _buildBooleanFieldWidget(field);
      case TemplateFieldType.radio:
      case TemplateFieldType.select:
        return _buildSelectFieldWidget(field);
      case TemplateFieldType.multiselect:
        return _buildMultiSelectFieldWidget(field);
      default:
        // Fallback for any unknown field types
        return _buildTextFieldWidget(field);
    }
  }

  Widget _buildTextFieldWidget(TemplateField field) {
    return TextFormField(
      controller: _customFieldControllers[field.fieldName],
      decoration: InputDecoration(
        labelText: field.fieldLabel + (field.isRequired ? ' *' : ''),
        hintText: field.placeholderText,
        border: const OutlineInputBorder(),
      ),
      keyboardType: field.fieldType == TemplateFieldType.email 
          ? TextInputType.emailAddress 
          : field.fieldType == TemplateFieldType.phone 
              ? TextInputType.phone 
              : TextInputType.text,
      onChanged: (value) => _customFieldValues[field.fieldName] = value,
      validator: field.isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '${field.fieldLabel} is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildTextAreaWidget(TemplateField field) {
    return TextFormField(
      controller: _customFieldControllers[field.fieldName],
      decoration: InputDecoration(
        labelText: field.fieldLabel + (field.isRequired ? ' *' : ''),
        hintText: field.placeholderText,
        border: const OutlineInputBorder(),
      ),
      maxLines: 4,
      onChanged: (value) => _customFieldValues[field.fieldName] = value,
      validator: field.isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '${field.fieldLabel} is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildNumberFieldWidget(TemplateField field) {
    return TextFormField(
      controller: _customFieldControllers[field.fieldName],
      decoration: InputDecoration(
        labelText: field.fieldLabel + (field.isRequired ? ' *' : ''),
        hintText: field.placeholderText,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        final number = double.tryParse(value);
        _customFieldValues[field.fieldName] = number;
      },
      validator: (value) {
        if (field.isRequired && (value == null || value.trim().isEmpty)) {
          return '${field.fieldLabel} is required';
        }
        if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
          return '${field.fieldLabel} must be a valid number';
        }
        return null;
      },
    );
  }

  Widget _buildDateFieldWidget(TemplateField field) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) {
          setState(() {
            _customFieldValues[field.fieldName] = date.toIso8601String();
            _customFieldControllers[field.fieldName]!.text = 
                DateFormat.yMMMd().format(date);
          });
        }
      },
      child: IgnorePointer(
        child: TextFormField(
          controller: _customFieldControllers[field.fieldName],
          decoration: InputDecoration(
            labelText: field.fieldLabel + (field.isRequired ? ' *' : ''),
            hintText: field.placeholderText ?? 'Tap to select date',
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          validator: field.isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '${field.fieldLabel} is required';
                  }
                  return null;
                }
              : null,
        ),
      ),
    );
  }

  Widget _buildTimeFieldWidget(TemplateField field) {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (time != null) {
          setState(() {
            _customFieldValues[field.fieldName] = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
            _customFieldControllers[field.fieldName]!.text = time.format(context);
          });
        }
      },
      child: IgnorePointer(
        child: TextFormField(
          controller: _customFieldControllers[field.fieldName],
          decoration: InputDecoration(
            labelText: field.fieldLabel + (field.isRequired ? ' *' : ''),
            hintText: field.placeholderText ?? 'Tap to select time',
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.access_time),
          ),
          validator: field.isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '${field.fieldLabel} is required';
                  }
                  return null;
                }
              : null,
        ),
      ),
    );
  }

  Widget _buildBooleanFieldWidget(TemplateField field) {
    return SwitchListTile(
      title: Text(field.fieldLabel + (field.isRequired ? ' *' : '')),
      subtitle: field.placeholderText != null ? Text(field.placeholderText!) : null,
      value: _customFieldValues[field.fieldName] ?? false,
      onChanged: (value) => setState(() => _customFieldValues[field.fieldName] = value),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSelectFieldWidget(TemplateField field) {
    return DropdownButtonFormField<String>(
      value: _customFieldValues[field.fieldName],
      decoration: InputDecoration(
        labelText: field.fieldLabel + (field.isRequired ? ' *' : ''),
        border: const OutlineInputBorder(),
      ),
      hint: Text(field.placeholderText ?? 'Select an option'),
      items: field.fieldOptions?.map((option) {
        return DropdownMenuItem(
          value: option,
          child: Text(option),
        );
      }).toList(),
      onChanged: (value) => setState(() => _customFieldValues[field.fieldName] = value),
      validator: field.isRequired
          ? (value) {
              if (value == null || value.isEmpty) {
                return '${field.fieldLabel} is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildMultiSelectFieldWidget(TemplateField field) {
    final selectedValues = _customFieldValues[field.fieldName] as List<String>? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.fieldLabel + (field.isRequired ? ' *' : ''),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: field.fieldOptions?.map((option) {
              final isSelected = selectedValues.contains(option);
              return CheckboxListTile(
                title: Text(option),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      selectedValues.add(option);
                    } else {
                      selectedValues.remove(option);
                    }
                    _customFieldValues[field.fieldName] = selectedValues;
                  });
                },
                dense: true,
              );
            }).toList() ?? [],
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, DateTime? date, Function(DateTime?) onChanged) {
    return InkWell(
      onTap: () async {
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (selectedDate != null) {
          onChanged(selectedDate);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          date != null ? DateFormat.yMMMd().format(date) : 'Tap to select',
          style: TextStyle(
            color: date != null ? null : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateButton(TaskTemplate template) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : () => _createTask(template),
        icon: _isLoading 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_task),
        label: Text(_isLoading ? 'Creating Task...' : 'Create Task'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildManagerAssignmentCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.manage_accounts, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  'Manager Assignment',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Debug info in development mode
            if (kDebugMode) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.yellow[100],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.yellow[400]!),
                ),
                child: Text(
                  'DEBUG: isAdmin=$_isAdmin, managersLoaded=$_managersLoaded, managers=${_managers.length}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              const SizedBox(height: 8),
            ],
            DropdownButtonFormField<String>(
              value: _selectedManagerId,
              decoration: const InputDecoration(
                labelText: 'Assign to Manager',
                hintText: 'Select a manager to oversee this task',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('No specific manager'),
                ),
                ..._managers.map((manager) {
                  return DropdownMenuItem<String>(
                    value: manager.id,
                    child: Text(manager.fullName),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedManagerId = value;
                });
              },
            ),
            if (_selectedManagerId != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This task will be assigned to the selected manager. Only they and their agents will be able to see and work on this task.',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Simple geofence preview screen that returns points without saving to database
class _GeofencePreviewScreen extends StatefulWidget {
  final List<LatLng>? initialPoints;
  final String taskTitle;

  const _GeofencePreviewScreen({
    this.initialPoints,
    required this.taskTitle,
  });

  @override
  State<_GeofencePreviewScreen> createState() => _GeofencePreviewScreenState();
}

class _GeofencePreviewScreenState extends State<_GeofencePreviewScreen> {
  final List<LatLng> _points = [];
  final Set<Polygon> _polygons = {};
  late GoogleMapController _mapController;
  
  // Default camera position - will be updated with admin location
  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(24.7136, 46.6753), // Fallback to Riyadh coordinates
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _initializeMapLocation();
    if (widget.initialPoints != null) {
      _points.addAll(widget.initialPoints!);
      _updatePolygon();
    }
  }
  
  // Initialize map with admin's current location
  Future<void> _initializeMapLocation() async {
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();
      
      if (position != null && mounted) {
        setState(() {
          _initialCameraPosition = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          );
        });
        
        // If map is already created, animate to the new location
        try {
          await _mapController.animateCamera(
            CameraUpdate.newCameraPosition(_initialCameraPosition),
          );
        } catch (e) {
          // Map controller might not be ready yet
        }
      }
    } catch (e) {
      debugPrint('[GeofencePreview] Failed to get admin location: $e');
      // Keep the default Riyadh coordinates as fallback
    }
  }

  void _updatePolygon() {
    if (_points.length < 3) {
      _polygons.clear();
      return;
    }

    setState(() {
      _polygons.clear();
      _polygons.add(
        Polygon(
          polygonId: const PolygonId('geofence'),
          points: _points,
          strokeColor: Colors.blue,
          strokeWidth: 2,
          fillColor: Colors.blue.withValues(alpha: 0.2),
        ),
      );
    });
  }

  void _onMapTap(LatLng point) {
    setState(() {
      _points.add(point);
    });
    _updatePolygon();
  }

  void _clearPoints() {
    setState(() {
      _points.clear();
      _polygons.clear();
    });
  }

  void _saveAndExit() {
    if (_points.length >= 3) {
      Navigator.of(context).pop(_points);
    } else {
      context.showSnackBar('Please add at least 3 points to create a geofence', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Set Geofence - ${widget.taskTitle}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _clearPoints,
            icon: const Icon(Icons.clear),
            tooltip: 'Clear all points',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap on the map to add points. You need at least 3 points to create a geofence.',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) async {
                _mapController = controller;
                // If admin location was loaded after map creation, animate to it
                if (_initialCameraPosition.target.latitude != 24.7136 || 
                    _initialCameraPosition.target.longitude != 46.6753) {
                  try {
                    await controller.animateCamera(
                      CameraUpdate.newCameraPosition(_initialCameraPosition),
                    );
                  } catch (e) {
                    // Silent fail if animation fails
                  }
                }
              },
              onTap: _onMapTap,
              initialCameraPosition: _initialCameraPosition,
              polygons: _polygons,
              markers: _points.asMap().entries.map((entry) {
                return Marker(
                  markerId: MarkerId('point_${entry.key}'),
                  position: entry.value,
                  infoWindow: InfoWindow(title: 'Point ${entry.key + 1}'),
                );
              }).toSet(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _points.length >= 3 ? Icons.check_circle : Icons.location_on,
                      color: _points.length >= 3 ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_points.length} points added',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: _points.length >= 3 ? Colors.green : Colors.orange,
                      ),
                    ),
                    if (_points.length >= 3) ...[
                      const SizedBox(width: 8),
                      const Text(
                        '(Ready to save)',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _points.length >= 3 ? _saveAndExit : null,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Geofence'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}