// lib/screens/tasks/create_evidence_task_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';
import './task_geofence_editor_screen.dart';

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
    }
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
      context.showSnackBar('Please select both start and end dates.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = widget.task == null
          ? await supabase.from('tasks').insert({
              'title': _nameController.text,
              'description': _descriptionController.text,
              'location_name': _locationNameController.text,
              'start_date': _startDate!.toIso8601String(),
              'end_date': _endDate!.toIso8601String(),
              'points': _enablePoints ? int.parse(_pointsController.text) : 0,
              'required_evidence_count': int.parse(_evidenceCountController.text),
              'enforce_geofence': _enforceGeofence,
              'created_by': supabase.auth.currentUser!.id,
            }).select().single()
          : await supabase.from('tasks').update({
              'title': _nameController.text,
              'description': _descriptionController.text,
              'location_name': _locationNameController.text,
              'start_date': _startDate!.toIso8601String(),
              'end_date': _endDate!.toIso8601String(),
              'points': _enablePoints ? int.parse(_pointsController.text) : 0,
              'required_evidence_count': int.parse(_evidenceCountController.text),
              'enforce_geofence': _enforceGeofence,
            }).eq('id', widget.task!.id).select().single();

      if (!mounted) {
        return;
      }

      context.showSnackBar('Task details saved. You can now define a geofence.');
      
      final bool isEditing = widget.task != null;
      setState(() {
        _createdTask = Task.fromJson(response);
      });

      if (isEditing && mounted) {
        Navigator.of(context).pop(); // Go back after saving edits
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to create task: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openGeofenceEditor() async {
    if (_createdTask == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => TaskGeofenceEditorScreen(task: _createdTask!)),
    );
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
