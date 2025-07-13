// lib/widgets/custom_field_editor.dart

import 'package:flutter/material.dart';
import '../models/template_field.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';

class CustomFieldEditor extends StatefulWidget {
  final String taskId;
  final List<TemplateField> initialFields;
  final Function(List<TemplateField>) onFieldsChanged;

  const CustomFieldEditor({
    super.key,
    required this.taskId,
    required this.initialFields,
    required this.onFieldsChanged,
  });

  @override
  State<CustomFieldEditor> createState() => _CustomFieldEditorState();
}

class _CustomFieldEditorState extends State<CustomFieldEditor> {
  late List<TemplateField> _fields;

  @override
  void initState() {
    super.initState();
    _fields = List.from(widget.initialFields);
  }

  void _addNewField() {
    showDialog(
      context: context,
      builder: (context) => _FieldEditDialog(
        field: null,
        onSave: (field) {
          setState(() {
            _fields.add(field);
            widget.onFieldsChanged(_fields);
          });
        },
      ),
    );
  }

  void _editField(int index) {
    showDialog(
      context: context,
      builder: (context) => _FieldEditDialog(
        field: _fields[index],
        onSave: (field) {
          setState(() {
            _fields[index] = field;
            widget.onFieldsChanged(_fields);
          });
        },
      ),
    );
  }

  void _deleteField(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteField),
        content: Text(AppLocalizations.of(context)!.confirmDeleteField(_fields[index].fieldLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _fields.removeAt(index);
                widget.onFieldsChanged(_fields);
              });
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Custom Form Fields',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            ElevatedButton.icon(
              onPressed: _addNewField,
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context)!.addField),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_fields.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Icon(Icons.assignment, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No custom fields added yet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add custom fields to collect additional data from agents',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _fields.length,
            itemBuilder: (context, index) {
              final field = _fields[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFieldIcon(field.fieldType),
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    field.fieldLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(field.fieldType.displayName),
                      if (field.isRequired)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Required',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _editField(index),
                        icon: const Icon(Icons.edit),
                        iconSize: 20,
                      ),
                      IconButton(
                        onPressed: () => _deleteField(index),
                        icon: const Icon(Icons.delete),
                        iconSize: 20,
                        color: Colors.red[600],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  IconData _getFieldIcon(TemplateFieldType type) {
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
        return Icons.toggle_on;
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
}

class _FieldEditDialog extends StatefulWidget {
  final TemplateField? field;
  final Function(TemplateField) onSave;

  const _FieldEditDialog({
    this.field,
    required this.onSave,
  });

  @override
  State<_FieldEditDialog> createState() => _FieldEditDialogState();
}

class _FieldEditDialogState extends State<_FieldEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _labelController;
  late TextEditingController _nameController;
  late TextEditingController _placeholderController;
  late TextEditingController _helpTextController;
  late TextEditingController _optionsController;
  
  late TemplateFieldType _selectedType;
  late bool _isRequired;
  
  bool get _isEditing => widget.field != null;

  @override
  void initState() {
    super.initState();
    
    if (_isEditing) {
      _labelController = TextEditingController(text: widget.field!.fieldLabel);
      _nameController = TextEditingController(text: widget.field!.fieldName);
      _placeholderController = TextEditingController(text: widget.field!.placeholderText ?? '');
      _helpTextController = TextEditingController(text: widget.field!.helpText ?? '');
      _optionsController = TextEditingController(
        text: widget.field!.fieldOptions?.join('\n') ?? '',
      );
      _selectedType = widget.field!.fieldType;
      _isRequired = widget.field!.isRequired;
    } else {
      _labelController = TextEditingController();
      _nameController = TextEditingController();
      _placeholderController = TextEditingController();
      _helpTextController = TextEditingController();
      _optionsController = TextEditingController();
      _selectedType = TemplateFieldType.text;
      _isRequired = false;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _nameController.dispose();
    _placeholderController.dispose();
    _helpTextController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  void _generateFieldName() {
    final label = _labelController.text.trim();
    if (label.isNotEmpty && _nameController.text.isEmpty) {
      final fieldName = label
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), '_');
      _nameController.text = fieldName;
    }
  }

  bool get _needsOptions {
    return _selectedType == TemplateFieldType.select ||
           _selectedType == TemplateFieldType.multiselect ||
           _selectedType == TemplateFieldType.radio;
  }

  void _saveField() {
    if (!_formKey.currentState!.validate()) return;

    final field = TemplateField(
      id: widget.field?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      templateId: '',
      fieldName: _nameController.text.trim(),
      fieldType: _selectedType,
      fieldLabel: _labelController.text.trim(),
      placeholderText: _placeholderController.text.trim().isEmpty 
          ? null 
          : _placeholderController.text.trim(),
      isRequired: _isRequired,
      fieldOptions: _needsOptions && _optionsController.text.trim().isNotEmpty
          ? _optionsController.text.trim().split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : null,
      validationRules: {},
      sortOrder: widget.field?.sortOrder ?? 0,
      helpText: _helpTextController.text.trim().isEmpty 
          ? null 
          : _helpTextController.text.trim(),
      createdAt: widget.field?.createdAt ?? DateTime.now(),
    );

    widget.onSave(field);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEditing ? Icons.edit : Icons.add,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit Field' : 'Add Custom Field',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Field Label
                      TextFormField(
                        controller: _labelController,
                        decoration: const InputDecoration(
                          labelText: 'Field Label *',
                          hintText: 'e.g., Customer Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.trim().isEmpty == true ? 'Label is required' : null,
                        onChanged: (_) => _generateFieldName(),
                      ),
                      const SizedBox(height: 16),
                      
                      // Field Name (auto-generated)
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Field Name *',
                          hintText: 'e.g., customer_name',
                          border: OutlineInputBorder(),
                          helperText: 'Used internally for data storage',
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty == true) return 'Field name is required';
                          if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value!)) {
                            return 'Use lowercase letters, numbers, and underscores only';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Field Type
                      DropdownButtonFormField<TemplateFieldType>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Field Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: TemplateFieldType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Placeholder Text
                      TextFormField(
                        controller: _placeholderController,
                        decoration: const InputDecoration(
                          labelText: 'Placeholder Text',
                          hintText: 'e.g., Enter customer name...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Options (for select types)
                      if (_needsOptions) ...[
                        TextFormField(
                          controller: _optionsController,
                          decoration: const InputDecoration(
                            labelText: 'Options *',
                            hintText: 'Enter each option on a new line',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 4,
                          validator: (value) {
                            if (_needsOptions && (value?.trim().isEmpty == true)) {
                              return 'Options are required for this field type';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Help Text
                      TextFormField(
                        controller: _helpTextController,
                        decoration: const InputDecoration(
                          labelText: 'Help Text',
                          hintText: 'Additional instructions for agents',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      
                      // Required checkbox
                      CheckboxListTile(
                        title: const Text('Required Field'),
                        subtitle: const Text('Agents must fill this field'),
                        value: _isRequired,
                        onChanged: (value) {
                          setState(() {
                            _isRequired = value ?? false;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.of(context)!.cancel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveField,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_isEditing ? AppLocalizations.of(context)!.update : AppLocalizations.of(context)!.addField),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}