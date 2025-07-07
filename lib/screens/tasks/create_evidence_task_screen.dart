// lib/screens/tasks/create_evidence_task_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../models/template_field.dart';
import '../../models/app_user.dart';
import '../../services/user_management_service.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_field_editor.dart';
import './task_geofence_editor_screen.dart';
import './standalone_tasks_screen.dart'; // Added import for navigation

class CreateEvidenceTaskScreen extends StatefulWidget {
  final Task? task;
  const CreateEvidenceTaskScreen({super.key, this.task});

  @override
  State<CreateEvidenceTaskScreen> createState() => _CreateEvidenceTaskScreenState();
}

class _CreateEvidenceTaskScreenState extends State<CreateEvidenceTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  Task? _createdTask;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _evidenceCountController = TextEditingController(text: '1');
  final _pointsController = TextEditingController(text: '10');

  DateTime? _startDate;
  DateTime? _endDate;
  bool _enablePoints = true;
  bool _enforceGeofence = false;
  
  // Custom fields management
  List<TemplateField> _customFields = [];
  bool _customFieldsLoaded = false;
  
  // Manager assignment (for admin only)
  String? _selectedManagerId;
  List<AppUser> _managers = [];
  bool _isAdmin = false;
  bool _managersLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _nameController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description ?? '';
      _locationNameController.text = widget.task!.locationName ?? '';
      _startDate = widget.task!.startDate;
      _endDate = widget.task!.endDate;
      _enablePoints = widget.task!.points != 0;
      _pointsController.text = widget.task!.points.toString();
      _evidenceCountController.text = widget.task!.requiredEvidenceCount.toString();
      _enforceGeofence = widget.task!.enforceGeofence ?? false;
      _createdTask = widget.task;
      
      // Load custom fields for existing task
      _loadCustomFields();
    } else {
      _customFieldsLoaded = true; // No fields to load for new task
    }
    
    // Check if current user is admin and load managers
    _checkUserRoleAndLoadManagers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationNameController.dispose();
    _evidenceCountController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(bool isStart) async {
    if (!mounted) return;
    
    final initialDate = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? _startDate ?? DateTime.now());

    final newDate = await showDatePicker(context: context, initialDate: initialDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (!mounted || newDate == null) {
      return;
    }

    final newTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initialDate));
    if (!mounted || newTime == null) {
      return;
    }

    final finalDateTime = DateTime(newDate.year, newDate.month, newDate.day, newTime.hour, newTime.minute);

    setState(() {
      if (isStart) {
        _startDate = finalDateTime;
      } else {
        _endDate = finalDateTime;
      }
    });
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_startDate == null || _endDate == null) {
      if (mounted) {
        context.showSnackBar('Please select both start and end dates.', isError: true);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final taskData = {
        'title': _nameController.text,
        'description': _descriptionController.text,
        'location_name': _locationNameController.text,
        'start_date': _startDate!.toIso8601String(),
        'end_date': _endDate!.toIso8601String(),
        'points': _enablePoints ? int.parse(_pointsController.text) : 0,
        'required_evidence_count': int.parse(_evidenceCountController.text),
        'enforce_geofence': _enforceGeofence,
      };

      // Add assigned manager if admin selected one
      if (_isAdmin && _selectedManagerId != null) {
        taskData['assigned_manager_id'] = _selectedManagerId!;
      }

      final response = widget.task == null
          ? await supabase.from('tasks').insert({
              ...taskData,
              'created_by': supabase.auth.currentUser!.id,
            }).select().single()
          : await supabase.from('tasks').update(taskData).eq('id', widget.task!.id).select().single();

      if (!mounted) {
        return;
      }
      
      final bool isNewTask = widget.task == null;
      final Task newlySavedTask = Task.fromJson(response);

      setState(() {
        _createdTask = newlySavedTask; // Update state
      });

      // Save custom fields after task is saved
      await _saveCustomFields();

      if (mounted) {
        if (isNewTask) {
          // For a new task
          context.showSnackBar('Task created successfully.');
          // Pop back with success result
          Navigator.of(context).pop(true);
        } else {
          // For an existing task (editing)
          context.showSnackBar('Task details saved.');
          Navigator.of(context).pop(true); // Return true for success
        }
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to save task: $e', isError: true); // Generic error message
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCustomFields() async {
    if (widget.task == null) return;

    try {
      final response = await supabase
          .from('task_dynamic_fields')
          .select('*')
          .eq('task_id', widget.task!.id)
          .order('sort_order');

      setState(() {
        _customFields = response.map<TemplateField>((field) => TemplateField(
          id: field['id'],
          templateId: '', // Not used for dynamic fields
          fieldName: field['field_name'],
          fieldType: TemplateFieldType.values.firstWhere(
            (e) => e.name == field['field_type'],
            orElse: () => TemplateFieldType.text,
          ),
          fieldLabel: field['field_label'],
          placeholderText: field['placeholder_text'],
          isRequired: field['is_required'] ?? false,
          fieldOptions: field['field_options'] != null 
              ? List<String>.from(field['field_options'])
              : null,
          validationRules: field['validation_rules'] != null 
              ? Map<String, dynamic>.from(field['validation_rules'])
              : {},
          sortOrder: field['sort_order'] ?? 0,
          helpText: field['help_text'],
          createdAt: DateTime.parse(field['created_at']),
        )).toList();
        _customFieldsLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading custom fields: $e');
      setState(() {
        _customFieldsLoaded = true;
      });
    }
  }

  Future<void> _checkUserRoleAndLoadManagers() async {
    try {
      final userRole = await UserManagementService().getCurrentUserRole();
      final isAdmin = userRole == 'admin';
      
      debugPrint('[TaskCreation] User role: $userRole, isAdmin: $isAdmin');
      
      setState(() {
        _isAdmin = isAdmin;
      });
      
      if (isAdmin) {
        debugPrint('[TaskCreation] Loading managers for admin user...');
        await _loadManagers();
      } else {
        debugPrint('[TaskCreation] User is not admin, skipping manager loading');
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
      
      debugPrint('[TaskCreation] Loaded ${managers.length} managers: ${managers.map((m) => m.fullName).join(', ')}');
      
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

  Future<void> _saveCustomFields() async {
    if (_createdTask == null) return;

    try {
      // Delete existing dynamic fields
      await supabase
          .from('task_dynamic_fields')
          .delete()
          .eq('task_id', _createdTask!.id);

      // Insert updated fields
      if (_customFields.isNotEmpty) {
        final fieldsData = _customFields.asMap().entries.map((entry) {
          final index = entry.key;
          final field = entry.value;
          return {
            'task_id': _createdTask!.id,
            'field_name': field.fieldName,
            'field_type': field.fieldType.name,
            'field_label': field.fieldLabel,
            'placeholder_text': field.placeholderText,
            'is_required': field.isRequired,
            'field_options': field.fieldOptions,
            'validation_rules': field.validationRules,
            'sort_order': index,
            'help_text': field.helpText,
          };
        }).toList();

        await supabase.from('task_dynamic_fields').insert(fieldsData);
      }
    } catch (e) {
      debugPrint('Error saving custom fields: $e');
      if (mounted) {
        context.showSnackBar('Failed to save custom fields: $e', isError: true);
      }
    }
  }

  Future<void> _openGeofenceEditor() async {
    if (_createdTask == null) {
      return;
    }

    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => TaskGeofenceEditorScreen(task: _createdTask!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canDefineGeofence = _enforceGeofence && _createdTask != null;
    final bool isEditing = widget.task != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Evidence Task' : 'New Evidence Task')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Core Information', style: Theme.of(context).textTheme.headlineSmall),
              formSpacer,
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Task Name'), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
              formSpacer,
              TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
              formSpacer,
              TextFormField(controller: _locationNameController, decoration: const InputDecoration(labelText: 'Location Name')),
              formSpacer,
              Row(children: [
                Expanded(child: _buildDateTimePicker('Start Date/Time', _startDate, () => _selectDateTime(true))),
                formSpacerHorizontal,
                Expanded(child: _buildDateTimePicker('End Date/Time', _endDate, () => _selectDateTime(false))),
              ]),
              const Divider(height: 40),
              Text('Rules & Completion', style: Theme.of(context).textTheme.headlineSmall),
              formSpacer,
              TextFormField(controller: _evidenceCountController, decoration: const InputDecoration(labelText: 'Required Evidence Count'), keyboardType: TextInputType.number, validator: (v) => int.tryParse(v!) == null ? 'Invalid number' : null),
              SwitchListTile(
                title: const Text('Enable Task Points'),
                value: _enablePoints,
                onChanged: (val) => setState(() => _enablePoints = val),
              ),
              if (_enablePoints)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: TextFormField(
                    controller: _pointsController,
                    decoration: const InputDecoration(labelText: 'Points Awarded', hintText: 'e.g., 10, 50, 100'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_enablePoints) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null || int.parse(value) <= 0) {
                          return 'Must be a positive number';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              SwitchListTile(
                title: const Text('Enforce Geofence for Upload'),
                value: _enforceGeofence,
                onChanged: (val) => setState(() => _enforceGeofence = val),
                subtitle: Text(_enforceGeofence ? 'Agent must be inside the zone to upload' : 'Uploads allowed from anywhere'),
              ),
              // Manager Assignment Section (Admin only)
              // Debug: Show admin status and manager loading state
              if (kDebugMode) ...[
                const SizedBox(height: 8),
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
              ],
              if (_isAdmin && _managersLoaded) ...[
                const Divider(height: 40),
                Text('Manager Assignment', style: Theme.of(context).textTheme.headlineSmall),
                formSpacer,
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
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue[200]!),
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
              const Divider(height: 40),
              Text('Geofencing', style: Theme.of(context).textTheme.headlineSmall),
              formSpacer,
              Center(
                child: ElevatedButton.icon(
                  onPressed: canDefineGeofence ? _openGeofenceEditor : null,
                  icon: const Icon(Icons.map),
                  label: const Text('Define Geofence Zone'),
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: Colors.grey.withAlpha(80),
                  ),
                ),
              ),
              if (_enforceGeofence && _createdTask == null)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('You must save the task before defining a geofence.', style: TextStyle(color: Colors.grey)),
                )),
              // Custom Fields Section (only show if task is saved or being edited)
              if (_createdTask != null && _customFieldsLoaded) ...[
                const Divider(height: 40),
                CustomFieldEditor(
                  taskId: _createdTask!.id,
                  initialFields: _customFields,
                  onFieldsChanged: (fields) {
                    setState(() {
                      _customFields = fields;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _saveTask,
          label: Text(isEditing ? 'Save Changes' : 'Save & Continue'),
          icon: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Icon(isEditing ? Icons.save_as : Icons.save),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker(String label, DateTime? date, VoidCallback? onTap) {
    final text = date == null ? 'Select...' : DateFormat.yMd().add_jm().format(date);
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text),
            const Icon(Icons.calendar_today),
          ],
        ),
      ),
    );
  }
}
