// lib/screens/agent/data_collection_task_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signature/signature.dart';
import '../../models/task.dart';
import '../../models/task_template.dart';
import '../../models/template_field.dart';
import '../../services/template_service.dart';
import '../../utils/constants.dart';

class DataCollectionTaskScreen extends StatefulWidget {
  final Task task;
  final TaskTemplate template;

  const DataCollectionTaskScreen({
    super.key,
    required this.task,
    required this.template,
  });

  @override
  State<DataCollectionTaskScreen> createState() => _DataCollectionTaskScreenState();
}

class _DataCollectionTaskScreenState extends State<DataCollectionTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  final Map<String, TextEditingController> _controllers = {};
  late Future<List<TemplateField>> _fieldsFuture;
  SignatureController? _signatureController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // First check for task-specific dynamic fields, then fall back to template fields
    _fieldsFuture = _loadTaskFields();
    
    if (widget.template.requiresSignature) {
      _signatureController = SignatureController(
        penStrokeWidth: 2,
        penColor: Colors.black,
        exportBackgroundColor: Colors.white,
      );
    }
  }
  
  Future<List<TemplateField>> _loadTaskFields() async {
    debugPrint('[DataCollection] Loading fields for task ID: ${widget.task.id}');
    debugPrint('[DataCollection] Template ID: ${widget.template.id}');
    
    try {
      // Check if this task has dynamic fields created by the manager
      debugPrint('[DataCollection] Querying task_dynamic_fields table...');
      final dynamicFieldsResponse = await supabase
          .from('task_dynamic_fields')
          .select('*')
          .eq('task_id', widget.task.id)
          .order('sort_order');
      
      debugPrint('[DataCollection] Dynamic fields response: $dynamicFieldsResponse');
      debugPrint('[DataCollection] Dynamic fields count: ${dynamicFieldsResponse.length}');
      
      if (dynamicFieldsResponse.isNotEmpty) {
        debugPrint('[DataCollection] Converting ${dynamicFieldsResponse.length} dynamic fields to TemplateField format');
        // Convert dynamic fields to TemplateField format
        return dynamicFieldsResponse.map<TemplateField>((field) => TemplateField(
          id: field['id'],
          templateId: widget.template.id,
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
      } else {
        debugPrint('[DataCollection] No dynamic fields found, checking template fields...');
      }
    } catch (e) {
      debugPrint('[DataCollection] Failed to load dynamic fields: $e');
    }
    
    // Fall back to template fields if no dynamic fields found
    debugPrint('[DataCollection] Falling back to template fields...');
    final templateFields = await TemplateService().getTemplateFields(widget.template.id);
    debugPrint('[DataCollection] Template fields count: ${templateFields.length}');
    return templateFields;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _signatureController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<TemplateField>>(
        future: _fieldsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return preloader;
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text('Error loading form: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _fieldsFuture = TemplateService().getTemplateFields(widget.template.id);
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final fields = snapshot.data ?? [];
          if (fields.isEmpty) {
            return _buildEmptyState();
          }

          return _buildForm(fields);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Form Fields',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'This template has no custom fields configured.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildForm(List<TemplateField> fields) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTaskHeader(),
                  const SizedBox(height: 20),
                  ...fields.map((field) => _buildField(field)),
                  if (widget.template.requiresSignature) ...[
                    const SizedBox(height: 20),
                    _buildSignatureField(),
                  ],
                  const SizedBox(height: 100), // Space for submit button
                ],
              ),
            ),
          ),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildTaskHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getTaskTypeIcon(),
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.template.taskTypeDisplayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.task.description ?? widget.template.taskTypeDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTaskTypeIcon() {
    switch (widget.template.taskType) {
      case TaskType.dataCollection:
        return Icons.assignment;
      case TaskType.inspection:
        return Icons.fact_check;
      case TaskType.survey:
        return Icons.poll;
      case TaskType.maintenance:
        return Icons.build;
      default:
        return Icons.assignment;
    }
  }

  Widget _buildField(TemplateField field) {
    // Initialize controller if not exists
    if (!_controllers.containsKey(field.fieldName)) {
      _controllers[field.fieldName] = TextEditingController();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      field.fieldLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (field.isRequired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Required',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                ],
              ),
              if (field.helpText != null) ...[
                const SizedBox(height: 4),
                Text(
                  field.helpText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _buildFieldInput(field),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldInput(TemplateField field) {
    switch (field.fieldType) {
      case TemplateFieldType.text:
        return _buildTextInput(field);
      case TemplateFieldType.number:
        return _buildNumberInput(field);
      case TemplateFieldType.email:
        return _buildEmailInput(field);
      case TemplateFieldType.phone:
        return _buildPhoneInput(field);
      case TemplateFieldType.select:
        return _buildSelectInput(field);
      case TemplateFieldType.multiselect:
        return _buildMultiSelectInput(field);
      case TemplateFieldType.textarea:
        return _buildTextAreaInput(field);
      case TemplateFieldType.date:
        return _buildDateInput(field);
      case TemplateFieldType.time:
        return _buildTimeInput(field);
      case TemplateFieldType.checkbox:
        return _buildCheckboxInput(field);
      case TemplateFieldType.radio:
        return _buildRadioInput(field);
      default:
        return _buildTextInput(field);
    }
  }

  Widget _buildTextInput(TemplateField field) {
    return TextFormField(
      controller: _controllers[field.fieldName],
      decoration: InputDecoration(
        hintText: field.placeholderText,
        border: const OutlineInputBorder(),
      ),
      validator: (value) => _validateField(field, value),
      onSaved: (value) => _formData[field.fieldName] = value,
    );
  }

  Widget _buildNumberInput(TemplateField field) {
    return TextFormField(
      controller: _controllers[field.fieldName],
      decoration: InputDecoration(
        hintText: field.placeholderText,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      validator: (value) => _validateField(field, value),
      onSaved: (value) => _formData[field.fieldName] = double.tryParse(value ?? ''),
    );
  }

  Widget _buildEmailInput(TemplateField field) {
    return TextFormField(
      controller: _controllers[field.fieldName],
      decoration: InputDecoration(
        hintText: field.placeholderText ?? 'Enter email address',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.email),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) => _validateField(field, value),
      onSaved: (value) => _formData[field.fieldName] = value,
    );
  }

  Widget _buildPhoneInput(TemplateField field) {
    return TextFormField(
      controller: _controllers[field.fieldName],
      decoration: InputDecoration(
        hintText: field.placeholderText ?? 'Enter phone number',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.phone),
      ),
      keyboardType: TextInputType.phone,
      validator: (value) => _validateField(field, value),
      onSaved: (value) => _formData[field.fieldName] = value,
    );
  }

  Widget _buildTextAreaInput(TemplateField field) {
    return TextFormField(
      controller: _controllers[field.fieldName],
      decoration: InputDecoration(
        hintText: field.placeholderText,
        border: const OutlineInputBorder(),
      ),
      maxLines: 4,
      validator: (value) => _validateField(field, value),
      onSaved: (value) => _formData[field.fieldName] = value,
    );
  }

  Widget _buildSelectInput(TemplateField field) {
    final options = field.fieldOptions ?? [];
    
    return DropdownButtonFormField<String>(
      value: _formData[field.fieldName],
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
      ),
      hint: Text(field.placeholderText ?? 'Select an option'),
      items: options.map((option) => DropdownMenuItem(
        value: option,
        child: Text(option),
      )).toList(),
      validator: (value) => _validateField(field, value),
      onChanged: (value) => setState(() => _formData[field.fieldName] = value),
    );
  }

  Widget _buildMultiSelectInput(TemplateField field) {
    final options = field.fieldOptions ?? [];
    final selectedValues = (_formData[field.fieldName] as List<String>?) ?? [];
    
    return Column(
      children: options.map((option) => CheckboxListTile(
        title: Text(option),
        value: selectedValues.contains(option),
        onChanged: (checked) {
          setState(() {
            final currentList = List<String>.from(selectedValues);
            if (checked == true) {
              currentList.add(option);
            } else {
              currentList.remove(option);
            }
            _formData[field.fieldName] = currentList;
          });
        },
      )).toList(),
    );
  }

  Widget _buildCheckboxInput(TemplateField field) {
    return CheckboxListTile(
      title: Text(field.fieldLabel),
      value: _formData[field.fieldName] == true,
      onChanged: (value) => setState(() => _formData[field.fieldName] = value),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildRadioInput(TemplateField field) {
    final options = field.fieldOptions ?? [];
    
    return Column(
      children: options.map((option) => RadioListTile<String>(
        title: Text(option),
        value: option,
        groupValue: _formData[field.fieldName],
        onChanged: (value) => setState(() => _formData[field.fieldName] = value),
      )).toList(),
    );
  }

  Widget _buildDateInput(TemplateField field) {
    return TextFormField(
      controller: _controllers[field.fieldName],
      decoration: InputDecoration(
        hintText: field.placeholderText ?? 'Select date',
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      readOnly: true,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          final formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          _controllers[field.fieldName]!.text = formattedDate;
          _formData[field.fieldName] = formattedDate;
        }
      },
      validator: (value) => _validateField(field, value),
    );
  }

  Widget _buildTimeInput(TemplateField field) {
    return TextFormField(
      controller: _controllers[field.fieldName],
      decoration: InputDecoration(
        hintText: field.placeholderText ?? 'Select time',
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.access_time),
      ),
      readOnly: true,
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (time != null) {
          final formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          _controllers[field.fieldName]!.text = formattedTime;
          _formData[field.fieldName] = formattedTime;
        }
      },
      validator: (value) => _validateField(field, value),
    );
  }

  Widget _buildSignatureField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Signature',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Please sign below to confirm completion',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Signature(
                controller: _signatureController!,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _signatureController!.clear(),
              icon: const Icon(Icons.clear),
              label: const Text('Clear Signature'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
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
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submitForm,
          icon: _isSubmitting 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(_isSubmitting ? 'Submitting...' : 'Submit Form'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  String? _validateField(TemplateField field, String? value) {
    if (field.isRequired && (value == null || value.trim().isEmpty)) {
      return '${field.fieldLabel} is required';
    }

    if (value != null && value.isNotEmpty) {
      switch (field.fieldType) {
        case TemplateFieldType.email:
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'Please enter a valid email address';
          }
          break;
        case TemplateFieldType.phone:
          if (!RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(value)) {
            return 'Please enter a valid phone number';
          }
          break;
        case TemplateFieldType.number:
          if (double.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          break;
        default:
          break;
      }

      // Check validation rules
      final rules = field.validationRules;
      if (rules['minLength'] != null && value.length < rules['minLength']) {
        return '${field.fieldLabel} must be at least ${rules['minLength']} characters';
      }
      if (rules['maxLength'] != null && value.length > rules['maxLength']) {
        return '${field.fieldLabel} must be no more than ${rules['maxLength']} characters';
      }
    }

    return null;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      context.showSnackBar('Please fix the errors in the form', isError: true);
      return;
    }

    // Check signature if required
    if (widget.template.requiresSignature) {
      if (_signatureController!.isEmpty) {
        context.showSnackBar('Signature is required', isError: true);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      _formKey.currentState!.save();

      // Add signature if present
      if (widget.template.requiresSignature && _signatureController!.isNotEmpty) {
        final signatureBytes = await _signatureController!.toPngBytes();
        _formData['signature'] = base64Encode(signatureBytes!);
      }

      // Submit form data
      await _submitFormData();
      
      if (mounted) {
        context.showSnackBar('Form submitted successfully!');
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to submit form: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitFormData() async {
    // Store form data in task custom fields
    await supabase.from('tasks')
        .update({'custom_fields': _formData})
        .eq('id', widget.task.id);

    // Update task assignment status
    await supabase.from('task_assignments')
        .update({
          'status': 'completed',
          'completed_at': DateTime.now().toIso8601String(),
        })
        .match({
          'task_id': widget.task.id,
          'agent_id': supabase.auth.currentUser!.id,
        });

    // Optionally create an evidence entry for the form data
    await supabase.from('evidence').insert({
      'task_assignment_id': await _getTaskAssignmentId(),
      'uploader_id': supabase.auth.currentUser!.id,
      'title': 'Form Data: ${widget.task.title}',
      'file_url': 'data:application/json;base64,${base64Encode(utf8.encode(jsonEncode(_formData)))}',
      'mime_type': 'application/json',
      'status': 'approved', // Auto-approve form submissions
    });
  }

  Future<String> _getTaskAssignmentId() async {
    final response = await supabase
        .from('task_assignments')
        .select('id')
        .match({
          'task_id': widget.task.id,
          'agent_id': supabase.auth.currentUser!.id,
        })
        .single();
    
    return response['id'];
  }
}