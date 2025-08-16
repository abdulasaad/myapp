// lib/screens/manager/survey_builder_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/touring_task.dart';
import '../../models/touring_survey.dart';
import '../../models/survey_field.dart';
import '../../services/survey_service.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/modern_notification.dart';

class SurveyBuilderScreen extends StatefulWidget {
  final TouringTask touringTask;
  final TouringSurvey? existingSurvey;

  const SurveyBuilderScreen({
    super.key,
    required this.touringTask,
    this.existingSurvey,
  });

  @override
  State<SurveyBuilderScreen> createState() => _SurveyBuilderScreenState();
}

class _SurveyBuilderScreenState extends State<SurveyBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _surveyService = SurveyService();
  
  bool _isRequired = true;
  bool _isLoading = false;
  bool _isSaving = false;
  
  List<SurveyField> _fields = [];
  TouringSurvey? _currentSurvey;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (widget.existingSurvey != null) {
      _currentSurvey = widget.existingSurvey;
      _titleController.text = widget.existingSurvey!.title;
      _descriptionController.text = widget.existingSurvey!.description ?? '';
      _isRequired = widget.existingSurvey!.isRequired;
      _loadSurveyFields();
    } else {
      _titleController.text = '${widget.touringTask.title} Survey';
    }
  }

  Future<void> _loadSurveyFields() async {
    if (_currentSurvey == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final surveyWithFields = await _surveyService.getSurveyWithFields(_currentSurvey!.id);
      if (surveyWithFields != null && surveyWithFields.fields != null) {
        setState(() {
          _fields = List.from(surveyWithFields.orderedFields);
        });
      }
    } catch (e) {
      if (mounted) {
        ModernNotification.error(
          context,
          message: 'Error loading survey fields',
          subtitle: e.toString(),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.existingSurvey != null ? 'Edit Survey' : 'Create Survey'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentSurvey != null)
            TextButton.icon(
              onPressed: _previewSurvey,
              icon: const Icon(Icons.preview, color: Colors.white),
              label: const Text('Preview', style: TextStyle(color: Colors.white)),
            ),
          TextButton.icon(
            onPressed: _isSaving ? null : _saveSurvey,
            icon: _isSaving 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save, color: Colors.white),
            label: Text(
              _isSaving ? 'Saving...' : 'Save',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSurveyInfoCard(),
                    const SizedBox(height: 24),
                    _buildFieldsSection(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addField,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Field'),
      ),
    );
  }

  Widget _buildSurveyInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.quiz, color: primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Survey Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Task Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.task, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Touring Task',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.touringTask.title,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Survey Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Survey Title',
                hintText: 'Enter a descriptive title for your survey',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Survey title is required';
                }
                if (value.length < 3) {
                  return 'Title must be at least 3 characters';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Survey Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Provide additional context or instructions',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 16),
            
            // Survey Options
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Required Survey'),
                    subtitle: const Text('Agents must complete this survey'),
                    value: _isRequired,
                    onChanged: (value) {
                      setState(() {
                        _isRequired = value ?? true;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list, color: primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Survey Fields',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_fields.length} fields',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            if (_fields.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.quiz_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No Fields Added',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add fields to start building your survey',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  // Show all fields in order
                  ..._fields.asMap().entries.map((entry) {
                    final index = entry.key;
                    final field = entry.value;
                    // Use a unique key combining field id and index to avoid duplicates
                    final uniqueKey = field.id.isNotEmpty ? field.id : 'temp_field_$index';
                    return _buildFieldCard(field, index, key: ValueKey(uniqueKey));
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldCard(SurveyField field, int index, {required Key key}) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getFieldTypeColor(field.fieldType),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              _getFieldTypeIcon(field.fieldType),
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        title: Text(
          field.fieldLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${field.typeDisplayName}${field.isRequired ? ' • Required' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
            if (field.hasOptions)
              Text(
                'Options: ${field.fieldOptions!.take(2).join(', ')}${field.fieldOptions!.length > 2 ? '...' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _editField(index),
              icon: const Icon(Icons.edit, size: 20),
              tooltip: 'Edit field',
            ),
            IconButton(
              onPressed: () => _deleteField(index),
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              tooltip: 'Delete field',
            ),
            const Icon(Icons.drag_handle),
          ],
        ),
      ),
    );
  }

  Color _getFieldTypeColor(SurveyFieldType type) {
    switch (type) {
      case SurveyFieldType.text:
      case SurveyFieldType.textarea:
        return Colors.blue;
      case SurveyFieldType.number:
      case SurveyFieldType.rating:
        return Colors.green;
      case SurveyFieldType.select:
      case SurveyFieldType.multiselect:
        return Colors.orange;
      case SurveyFieldType.boolean:
        return Colors.purple;
      case SurveyFieldType.date:
        return Colors.teal;
      case SurveyFieldType.photo:
        return Colors.pink;
    }
  }

  IconData _getFieldTypeIcon(SurveyFieldType type) {
    switch (type) {
      case SurveyFieldType.text:
        return Icons.text_fields;
      case SurveyFieldType.textarea:
        return Icons.subject;
      case SurveyFieldType.number:
        return Icons.numbers;
      case SurveyFieldType.rating:
        return Icons.star;
      case SurveyFieldType.select:
        return Icons.radio_button_checked;
      case SurveyFieldType.multiselect:
        return Icons.checklist;
      case SurveyFieldType.boolean:
        return Icons.toggle_on;
      case SurveyFieldType.date:
        return Icons.calendar_today;
      case SurveyFieldType.photo:
        return Icons.camera_alt;
    }
  }


  void _addField() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FieldEditorDialog(
          onFieldCreated: (field) {
            setState(() {
              _fields.add(field.copyWith(fieldOrder: _fields.length));
            });
          },
        ),
      ),
    );
  }

  void _editField(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FieldEditorDialog(
          field: _fields[index],
          onFieldUpdated: (field) {
            setState(() {
              _fields[index] = field;
            });
          },
        ),
      ),
    );
  }

  void _deleteField(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Field'),
        content: Text('Are you sure you want to delete "${_fields[index].fieldLabel}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _fields.removeAt(index);
                // Update field orders
                for (int i = 0; i < _fields.length; i++) {
                  _fields[i] = _fields[i].copyWith(fieldOrder: i);
                }
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _previewSurvey() {
    // TODO: Implement survey preview
    ModernNotification.info(
      context,
      message: 'Survey Preview',
      subtitle: 'Preview functionality coming soon',
    );
  }

  Future<void> _saveSurvey() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_fields.isEmpty) {
      ModernNotification.warning(
        context,
        message: 'No Fields Added',
        subtitle: 'Please add at least one field to the survey',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Check if this is a temporary task (during task creation)
      final isTemporaryTask = widget.touringTask.id.startsWith('temp_');
      
      if (isTemporaryTask) {
        // For temporary tasks, create a temporary survey object with all the configuration
        final tempSurvey = TouringSurvey(
          id: 'temp_survey_${DateTime.now().millisecondsSinceEpoch}',
          touringTaskId: widget.touringTask.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty 
              ? _descriptionController.text.trim() 
              : null,
          isRequired: _isRequired,
          isActive: true,
          createdAt: DateTime.now(),
          fields: _fields,
        );
        
        if (mounted) {
          ModernNotification.success(
            context,
            message: 'Survey Configuration Saved',
            subtitle: 'Survey will be created when the task is saved',
          );
          Navigator.pop(context, tempSurvey);
        }
        return;
      }
      
      // For real tasks, proceed with normal database operations
      TouringSurvey? survey;
      
      if (_currentSurvey == null) {
        // Create new survey
        survey = await _surveyService.createSurvey(
          touringTaskId: widget.touringTask.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty 
              ? _descriptionController.text.trim() 
              : null,
          isRequired: _isRequired,
        );
        
        if (survey == null) {
          throw Exception('Failed to create survey');
        }
        
        _currentSurvey = survey;
      } else {
        // Update existing survey
        survey = await _surveyService.updateSurvey(
          surveyId: _currentSurvey!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty 
              ? _descriptionController.text.trim() 
              : null,
          isRequired: _isRequired,
        );
        
        if (survey == null) {
          throw Exception('Failed to update survey');
        }
      }

      // Save all fields
      for (final field in _fields) {
        if (field.id.isEmpty || field.id.startsWith('temp_')) {
          // Create new field (empty ID or temporary ID)
          await _surveyService.createSurveyField(
            surveyId: survey.id,
            fieldName: field.fieldName,
            fieldType: field.fieldType,
            fieldLabel: field.fieldLabel,
            fieldPlaceholder: field.fieldPlaceholder,
            fieldOptions: field.fieldOptions,
            isRequired: field.isRequired,
            fieldOrder: field.fieldOrder,
            validationRules: field.validationRules,
          );
        } else {
          // Update existing field
          await _surveyService.updateSurveyField(
            fieldId: field.id,
            fieldName: field.fieldName,
            fieldType: field.fieldType,
            fieldLabel: field.fieldLabel,
            fieldPlaceholder: field.fieldPlaceholder,
            fieldOptions: field.fieldOptions,
            isRequired: field.isRequired,
            fieldOrder: field.fieldOrder,
            validationRules: field.validationRules,
          );
        }
      }

      if (mounted) {
        ModernNotification.success(
          context,
          message: 'Survey Saved',
          subtitle: 'Survey has been saved successfully',
        );
        Navigator.pop(context, survey);
      }

    } catch (e) {
      if (mounted) {
        ModernNotification.error(
          context,
          message: 'Error Saving Survey',
          subtitle: e.toString(),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }
}

// Field Editor Dialog
class FieldEditorDialog extends StatefulWidget {
  final SurveyField? field;
  final Function(SurveyField)? onFieldCreated;
  final Function(SurveyField)? onFieldUpdated;

  const FieldEditorDialog({
    super.key,
    this.field,
    this.onFieldCreated,
    this.onFieldUpdated,
  });

  @override
  State<FieldEditorDialog> createState() => _FieldEditorDialogState();
}

class _FieldEditorDialogState extends State<FieldEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _placeholderController = TextEditingController();
  final _optionsController = TextEditingController();
  
  SurveyFieldType _fieldType = SurveyFieldType.text;
  bool _isRequired = false;
  List<String> _options = [];
  
  // Validation controllers
  final _minLengthController = TextEditingController();
  final _maxLengthController = TextEditingController();
  final _minValueController = TextEditingController();
  final _maxValueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _placeholderController.dispose();
    _optionsController.dispose();
    _minLengthController.dispose();
    _maxLengthController.dispose();
    _minValueController.dispose();
    _maxValueController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (widget.field != null) {
      final field = widget.field!;
      _labelController.text = field.fieldLabel;
      _placeholderController.text = field.fieldPlaceholder ?? '';
      _fieldType = field.fieldType;
      _isRequired = field.isRequired;
      _options = List.from(field.fieldOptions ?? []);
      _optionsController.text = _options.join('\n');
      
      if (field.validationRules != null) {
        final validation = field.validationRules!;
        _minLengthController.text = validation.minLength?.toString() ?? '';
        _maxLengthController.text = validation.maxLength?.toString() ?? '';
        _minValueController.text = validation.minValue?.toString() ?? '';
        _maxValueController.text = validation.maxValue?.toString() ?? '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.field != null ? 'Edit Field' : 'Add Field'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveField,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
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
              _buildBasicFieldInfo(),
              const SizedBox(height: 24),
              if (_needsOptions()) _buildOptionsSection(),
              if (_needsOptions()) const SizedBox(height: 24),
              _buildValidationSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicFieldInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Field Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Field Label
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Field Label',
                hintText: 'Enter the question or label',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Field label is required';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Field Type
            DropdownButtonFormField<SurveyFieldType>(
              value: _fieldType,
              decoration: const InputDecoration(
                labelText: 'Field Type',
                border: OutlineInputBorder(),
              ),
              items: SurveyFieldType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(_getFieldTypeIcon(type), size: 20),
                      const SizedBox(width: 8),
                      Text(_getFieldTypeDisplayName(type)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _fieldType = value!;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Placeholder
            TextFormField(
              controller: _placeholderController,
              decoration: const InputDecoration(
                labelText: 'Placeholder (Optional)',
                hintText: 'Hint text for the field',
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Required checkbox
            CheckboxListTile(
              title: const Text('Required Field'),
              subtitle: const Text('Users must fill this field'),
              value: _isRequired,
              onChanged: (value) {
                setState(() {
                  _isRequired = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Field Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter each option on a new line',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _optionsController,
              decoration: const InputDecoration(
                labelText: 'Options',
                hintText: 'Option 1\nOption 2\nOption 3',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              onChanged: (value) {
                _options = value.split('\n')
                    .map((option) => option.trim())
                    .where((option) => option.isNotEmpty)
                    .toList();
              },
              validator: (value) {
                if (_needsOptions() && (value == null || value.trim().isEmpty)) {
                  return 'Please provide at least one option';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Validation Rules (Optional)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (_fieldType == SurveyFieldType.text || _fieldType == SurveyFieldType.textarea) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minLengthController,
                      decoration: const InputDecoration(
                        labelText: 'Min Length',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _maxLengthController,
                      decoration: const InputDecoration(
                        labelText: 'Max Length',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
            ],
            
            if (_fieldType == SurveyFieldType.number || _fieldType == SurveyFieldType.rating) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minValueController,
                      decoration: const InputDecoration(
                        labelText: 'Min Value',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _maxValueController,
                      decoration: const InputDecoration(
                        labelText: 'Max Value',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _needsOptions() {
    return _fieldType == SurveyFieldType.select || _fieldType == SurveyFieldType.multiselect;
  }

  IconData _getFieldTypeIcon(SurveyFieldType type) {
    switch (type) {
      case SurveyFieldType.text:
        return Icons.text_fields;
      case SurveyFieldType.textarea:
        return Icons.subject;
      case SurveyFieldType.number:
        return Icons.numbers;
      case SurveyFieldType.rating:
        return Icons.star;
      case SurveyFieldType.select:
        return Icons.radio_button_checked;
      case SurveyFieldType.multiselect:
        return Icons.checklist;
      case SurveyFieldType.boolean:
        return Icons.toggle_on;
      case SurveyFieldType.date:
        return Icons.calendar_today;
      case SurveyFieldType.photo:
        return Icons.camera_alt;
    }
  }

  String _getFieldTypeDisplayName(SurveyFieldType type) {
    switch (type) {
      case SurveyFieldType.text:
        return 'Text Input';
      case SurveyFieldType.textarea:
        return 'Long Text';
      case SurveyFieldType.number:
        return 'Number';
      case SurveyFieldType.rating:
        return 'Rating (1-5)';
      case SurveyFieldType.select:
        return 'Single Choice';
      case SurveyFieldType.multiselect:
        return 'Multiple Choice';
      case SurveyFieldType.boolean:
        return 'Yes/No';
      case SurveyFieldType.date:
        return 'Date';
      case SurveyFieldType.photo:
        return 'Photo Upload';
    }
  }

  void _saveField() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Create validation rules
    SurveyFieldValidation? validation;
    final minLength = int.tryParse(_minLengthController.text);
    final maxLength = int.tryParse(_maxLengthController.text);
    final minValue = num.tryParse(_minValueController.text);
    final maxValue = num.tryParse(_maxValueController.text);

    if (minLength != null || maxLength != null || minValue != null || maxValue != null) {
      validation = SurveyFieldValidation(
        minLength: minLength,
        maxLength: maxLength,
        minValue: minValue,
        maxValue: maxValue,
      );
    }

    // Generate field name from label
    final fieldName = _labelController.text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    final field = SurveyField(
      id: widget.field?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}_$fieldName',
      surveyId: widget.field?.surveyId ?? '',
      fieldName: fieldName,
      fieldType: _fieldType,
      fieldLabel: _labelController.text.trim(),
      fieldPlaceholder: _placeholderController.text.trim().isNotEmpty 
          ? _placeholderController.text.trim() 
          : null,
      fieldOptions: _needsOptions() ? _options : null,
      isRequired: _isRequired,
      fieldOrder: widget.field?.fieldOrder ?? 0,
      validationRules: validation,
      createdAt: widget.field?.createdAt ?? DateTime.now(),
    );

    if (widget.field != null) {
      widget.onFieldUpdated?.call(field);
    } else {
      widget.onFieldCreated?.call(field);
    }

    Navigator.pop(context);
  }
}