// lib/screens/manager/global_survey_dashboard_screen.dart

import 'package:flutter/material.dart';
import '../../services/global_survey_service.dart';
import '../../services/group_service.dart';
import '../../models/global_survey.dart';
import '../../models/survey_field.dart';
import '../../models/app_user.dart';
import '../../utils/constants.dart';
import '../../widgets/modern_notification.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class GlobalSurveyDashboardScreen extends StatefulWidget {
  const GlobalSurveyDashboardScreen({super.key});

  @override
  State<GlobalSurveyDashboardScreen> createState() => _GlobalSurveyDashboardScreenState();
}

class _GlobalSurveyDashboardScreenState extends State<GlobalSurveyDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = GlobalSurveyService();
  List<GlobalSurvey> _surveys = [];
  bool _loading = true;
  GlobalSurvey? _selectedForResults;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _service.getManagerSurveys();
    setState(() {
      _surveys = data;
      _loading = false;
      if (_surveys.isNotEmpty && _selectedForResults == null) {
        _selectedForResults = _surveys.first;
      }
    });
  }

  Future<void> _createSurveyDialog() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GlobalSurveyBuilderScreen(survey: null),
      ),
    );
    _load(); // Refresh the list after returning
  }

  Future<void> _deleteSurvey(GlobalSurvey s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Survey'),
        content: Text('Delete "${s.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await _service.deleteSurvey(s.id);
      if (mounted) {
        if (ok) {
          ModernNotification.success(context, message: 'Survey deleted');
          _load();
        } else {
          ModernNotification.error(context, message: 'Failed to delete');
        }
      }
    }
  }

  Future<void> _exportSurveyToExcel(GlobalSurvey survey) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get submissions and survey fields
      final submissions = await _service.getManagerSurveySubmissions(survey.id);
      final fields = await _service.getSurveyFields(survey.id);

      if (submissions.isEmpty) {
        Navigator.pop(context); // Close loading
        ModernNotification.error(context, message: 'No submissions to export');
        return;
      }

      // Create Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel['Survey_Results'];

      // Create headers
      List<String> headers = ['Submission #', 'Submitted At'];
      
      // Add field labels as headers
      for (final field in fields) {
        headers.add(field.fieldLabel);
      }
      
      // Add location headers if any submission has coordinates
      final hasLocation = submissions.any((s) => s.latitude != null && s.longitude != null);
      if (hasLocation) {
        headers.addAll(['Latitude', 'Longitude']);
      }

      // Set headers
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(bold: true);
      }

      // Add data rows
      for (int rowIndex = 0; rowIndex < submissions.length; rowIndex++) {
        final submission = submissions[rowIndex];
        final excelRowIndex = rowIndex + 1; // Skip header row
        
        int colIndex = 0;
        
        // Submission number
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: excelRowIndex))
            .value = TextCellValue('${rowIndex + 1}');
        
        // Submitted at
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: excelRowIndex))
            .value = TextCellValue(submission.submittedAt.toString());
        
        // Field values
        for (final field in fields) {
          final value = submission.submissionData[field.fieldName]?.toString() ?? '';
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: excelRowIndex))
              .value = TextCellValue(value);
        }
        
        // Location data
        if (hasLocation) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: excelRowIndex))
              .value = TextCellValue(submission.latitude?.toString() ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: excelRowIndex))
              .value = TextCellValue(submission.longitude?.toString() ?? '');
        }
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'survey_${survey.title.replaceAll(RegExp(r'[^\w\s-]'), '')}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      await file.writeAsBytes(excel.encode()!);

      Navigator.pop(context); // Close loading

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Survey Results: ${survey.title}',
      );

      if (mounted) {
        ModernNotification.success(context, message: 'Excel file exported successfully');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading if still open
      if (mounted) {
        ModernNotification.error(context, message: 'Export failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Surveys'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Surveys'),
            Tab(text: 'Results'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSurveysTab(),
                _buildResultsTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _createSurveyDialog,
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Survey'),
            )
          : null,
    );
  }

  Widget _buildSurveysTab() {
    if (_surveys.isEmpty) {
      return const Center(child: Text('No surveys yet'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _surveys.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final s = _surveys[i];
          return ListTile(
            tileColor: surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(s.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GlobalSurveyBuilderScreen(survey: s),
                      ),
                    );
                    if (mounted) _load();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteSurvey(s),
                ),
              ],
            ),
            onTap: () {
              setState(() => _selectedForResults = s);
              _tabController.index = 1;
            },
          );
        },
      ),
    );
  }

  Widget _buildResultsTab() {
    if (_surveys.isEmpty) {
      return const Center(child: Text('No surveys available'));
    }
    final selected = _selectedForResults ?? _surveys.first;
    
    // Ensure unique surveys by ID to prevent dropdown assertion error
    final uniqueSurveys = <String, GlobalSurvey>{};
    for (final survey in _surveys) {
      uniqueSurveys[survey.id] = survey;
    }
    final uniqueSurveyList = uniqueSurveys.values.toList();
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: uniqueSurveys.containsKey(selected.id) ? selected.id : null,
                  items: uniqueSurveyList
                      .map((s) => DropdownMenuItem(value: s.id, child: Text(s.title)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedForResults = uniqueSurveys[v];
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Survey'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _exportSurveyToExcel(selected),
                icon: Icon(Icons.download, color: primaryColor),
                tooltip: 'Export to Excel',
                style: IconButton.styleFrom(
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _ManagerSurveyResultsList(surveyId: selected.id),
        ),
      ],
    );
  }
}

class GlobalSurveyBuilderScreen extends StatefulWidget {
  final GlobalSurvey? survey;
  const GlobalSurveyBuilderScreen({super.key, this.survey});

  @override
  State<GlobalSurveyBuilderScreen> createState() => _GlobalSurveyBuilderScreenState();
}

class _GlobalSurveyBuilderScreenState extends State<GlobalSurveyBuilderScreen> {
  final _service = GlobalSurveyService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  List<SurveyField> _fields = [];
  List<AppUser> _availableAgents = [];
  List<String> _selectedAgentIds = [];
  bool _loading = true;
  bool _isRequired = true;
  bool _isActive = true;
  bool _isCreating = false;
  bool _loadingAgents = false;
  
  GlobalSurvey? _currentSurvey;

  @override
  void initState() {
    super.initState();
    _currentSurvey = widget.survey;
    if (_currentSurvey != null) {
      _titleController.text = _currentSurvey!.title;
      _descriptionController.text = _currentSurvey!.description ?? '';
      _isRequired = _currentSurvey!.isRequired;
      _isActive = _currentSurvey!.isActive;
      _loadFields();
    } else {
      setState(() => _loading = false);
    }
    _loadAvailableAgents();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadFields() async {
    if (_currentSurvey == null) return;
    setState(() => _loading = true);
    final f = await _service.getSurveyFields(_currentSurvey!.id);
    final assignedAgentIds = await _service.getSurveyAssignedAgentIds(_currentSurvey!.id);
    setState(() {
      _fields = f;
      _selectedAgentIds = assignedAgentIds;
      _loading = false;
    });
  }

  Future<void> _loadAvailableAgents() async {
    setState(() => _loadingAgents = true);
    try {
      final groupService = GroupService();
      final agents = await groupService.getAgents();
      setState(() {
        _availableAgents = agents;
        _loadingAgents = false;
      });
    } catch (e) {
      setState(() => _loadingAgents = false);
      if (mounted) {
        ModernNotification.error(context, message: 'Failed to load agents');
      }
    }
  }

  Future<void> _saveSurvey() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isCreating = true);
    try {
      if (_currentSurvey == null) {
        // Create new survey
        final survey = await _service.createSurvey(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          isRequired: _isRequired,
          isActive: _isActive,
        );
        
        if (survey != null) {
          setState(() => _currentSurvey = survey);
          
          // Save agent assignments
          await _service.assignAgentsToSurvey(survey.id, _selectedAgentIds);
          
          if (mounted) {
            ModernNotification.success(context, message: 'Survey created successfully');
          }
        } else {
          throw Exception('Failed to create survey');
        }
      } else {
        // Update existing survey
        final updatedSurvey = await _service.updateSurvey(
          surveyId: _currentSurvey!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          isRequired: _isRequired,
          isActive: _isActive,
        );
        
        if (updatedSurvey != null) {
          setState(() => _currentSurvey = updatedSurvey);
          
          // Save agent assignments
          await _service.assignAgentsToSurvey(_currentSurvey!.id, _selectedAgentIds);
          
          if (mounted) {
            ModernNotification.success(context, message: 'Survey updated successfully');
          }
        } else {
          throw Exception('Failed to update survey');
        }
      }
    } catch (e) {
      if (mounted) {
        ModernNotification.error(context, message: 'Failed to save survey: $e');
      }
    } finally {
      setState(() => _isCreating = false);
    }
  }

  Future<void> _addField() async {
    if (_currentSurvey == null) {
      ModernNotification.error(context, message: 'Save survey first before adding fields');
      return;
    }
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _FieldEditorSheet(
          onSave: (field) async {
            // Get the highest field order and add 1 to ensure it goes to the end
            final maxOrder = _fields.isEmpty ? 0 : _fields.map((f) => f.fieldOrder).reduce((a, b) => a > b ? a : b);
            await _service.createSurveyField(
              surveyId: _currentSurvey!.id,
              fieldName: field.fieldName,
              fieldType: field.fieldType,
              fieldLabel: field.fieldLabel,
              fieldPlaceholder: field.fieldPlaceholder,
              fieldOptions: field.fieldOptions,
              isRequired: field.isRequired,
              fieldOrder: maxOrder + 1,
              validationRules: field.validationRules,
            );
            if (mounted) _loadFields();
          },
        );
      },
    );
  }

  Future<void> _moveFieldUp(int index) async {
    if (index <= 0) return;
    
    final field1 = _fields[index];
    final field2 = _fields[index - 1];
    
    // Swap the field orders
    await _service.updateSurveyField(
      fieldId: field1.id,
      fieldOrder: field2.fieldOrder,
    );
    await _service.updateSurveyField(
      fieldId: field2.id,
      fieldOrder: field1.fieldOrder,
    );
    
    if (mounted) _loadFields();
  }

  Future<void> _moveFieldDown(int index) async {
    if (index >= _fields.length - 1) return;
    
    final field1 = _fields[index];
    final field2 = _fields[index + 1];
    
    // Swap the field orders
    await _service.updateSurveyField(
      fieldId: field1.id,
      fieldOrder: field2.fieldOrder,
    );
    await _service.updateSurveyField(
      fieldId: field2.id,
      fieldOrder: field1.fieldOrder,
    );
    
    if (mounted) _loadFields();
  }

  Future<void> _editField(SurveyField field) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _FieldEditorSheet(
          existingField: field,
          onSave: (editedField) async {
            await _service.updateSurveyField(
              fieldId: field.id,
              fieldName: editedField.fieldName,
              fieldType: editedField.fieldType,
              fieldLabel: editedField.fieldLabel,
              fieldPlaceholder: editedField.fieldPlaceholder,
              fieldOptions: editedField.fieldOptions,
              isRequired: editedField.isRequired,
              // Keep the same order
              fieldOrder: field.fieldOrder,
              validationRules: editedField.validationRules,
            );
            if (mounted) _loadFields();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _currentSurvey != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Survey' : 'Create Survey'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (isEditing)
            IconButton(onPressed: _addField, icon: const Icon(Icons.add)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Survey basic info form
                Container(
                  padding: const EdgeInsets.all(16),
                  color: surfaceColor,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Survey Title',
                            hintText: 'Enter title in Arabic or English',
                            border: OutlineInputBorder(),
                          ),
                          textDirection: TextDirection.ltr, // Allow auto-detection
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description (Optional)',
                            hintText: 'Enter description',
                            border: OutlineInputBorder(),
                          ),
                          textDirection: TextDirection.ltr,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SwitchListTile(
                                value: _isRequired,
                                onChanged: (v) => setState(() => _isRequired = v),
                                title: const Text('Required'),
                                dense: true,
                              ),
                            ),
                            Expanded(
                              child: SwitchListTile(
                                value: _isActive,
                                onChanged: (v) => setState(() => _isActive = v),
                                title: const Text('Active'),
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Agent Assignment Section
                        ExpansionTile(
                          title: Row(
                            children: [
                              Icon(Icons.people, color: primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Text('Agent Assignment (${_selectedAgentIds.length} selected)'),
                            ],
                          ),
                          initiallyExpanded: false,
                          children: [
                            if (_loadingAgents)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else if (_availableAgents.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No agents found'),
                              )
                            else
                              Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _availableAgents.length,
                                  itemBuilder: (context, index) {
                                    final agent = _availableAgents[index];
                                    final isSelected = _selectedAgentIds.contains(agent.id);
                                    return CheckboxListTile(
                                      title: Text(agent.fullName),
                                      subtitle: Text(agent.email ?? ''),
                                      value: isSelected,
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedAgentIds.add(agent.id);
                                          } else {
                                            _selectedAgentIds.remove(agent.id);
                                          }
                                        });
                                      },
                                      dense: true,
                                    );
                                  },
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedAgentIds.clear();
                                      });
                                    },
                                    child: const Text('Select None'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedAgentIds.clear();
                                        _selectedAgentIds.addAll(
                                          _availableAgents.map((a) => a.id),
                                        );
                                      });
                                    },
                                    child: const Text('Select All'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isCreating ? null : _saveSurvey,
                            icon: _isCreating 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Icon(isEditing ? Icons.save : Icons.create),
                            label: Text(_isCreating ? 'Saving...' : (isEditing ? 'Update Survey' : 'Create Survey')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Fields list
                if (isEditing) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.list, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Survey Fields (${_fields.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _fields.isEmpty
                        ? const Center(child: Text('No fields. Tap + to add fields.'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _fields.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final f = _fields[i];
                              return Card(
                                color: surfaceColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      // Order controls
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                                            onPressed: i > 0 ? () => _moveFieldUp(i) : null,
                                            tooltip: 'Move up',
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            padding: EdgeInsets.zero,
                                          ),
                                          Text(
                                            '${i + 1}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                            onPressed: i < _fields.length - 1 ? () => _moveFieldDown(i) : null,
                                            tooltip: 'Move down',
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      // Field info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              f.fieldLabel,
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            Text(
                                              '${f.typeDisplayName}${f.isRequired ? ' • Required' : ''}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Edit button
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                        onPressed: () => _editField(f),
                                        tooltip: 'Edit field',
                                      ),
                                      // Delete button
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                        onPressed: () async {
                                          await _service.deleteSurveyField(f.id);
                                          if (mounted) _loadFields();
                                        },
                                        tooltip: 'Delete field',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _FieldEditorSheet extends StatefulWidget {
  final Function(SurveyField) onSave;
  final SurveyField? existingField;
  const _FieldEditorSheet({required this.onSave, this.existingField});

  @override
  State<_FieldEditorSheet> createState() => _FieldEditorSheetState();
}

class _FieldEditorSheetState extends State<_FieldEditorSheet> {
  final _labelCtrl = TextEditingController();
  final _placeholderCtrl = TextEditingController();
  final _optionsCtrl = TextEditingController();
  SurveyFieldType _type = SurveyFieldType.text;
  bool _required = false;

  @override
  void initState() {
    super.initState();
    // Initialize with existing field data if editing
    if (widget.existingField != null) {
      final field = widget.existingField!;
      _labelCtrl.text = field.fieldLabel;
      _placeholderCtrl.text = field.fieldPlaceholder ?? '';
      _type = field.fieldType;
      _required = field.isRequired;
      
      // Initialize options if they exist
      if (field.fieldOptions != null && field.fieldOptions!.isNotEmpty) {
        _optionsCtrl.text = field.fieldOptions!.join('\n');
      }
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _placeholderCtrl.dispose();
    _optionsCtrl.dispose();
    super.dispose();
  }

  bool get _needsOptions => _type == SurveyFieldType.select || _type == SurveyFieldType.multiselect;

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingField != null;
    
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isEditing ? Icons.edit : Icons.add_circle, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Edit Field' : 'Add Field', 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Field Label',
                hintText: 'e.g., اسم العميل or Customer Name',
                border: OutlineInputBorder(),
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SurveyFieldType>(
              value: _type,
              items: SurveyFieldType.values.map((t) {
                String displayName;
                switch (t) {
                  case SurveyFieldType.text:
                    displayName = 'Text Input';
                    break;
                  case SurveyFieldType.textarea:
                    displayName = 'Long Text';
                    break;
                  case SurveyFieldType.number:
                    displayName = 'Number';
                    break;
                  case SurveyFieldType.select:
                    displayName = 'Single Choice';
                    break;
                  case SurveyFieldType.multiselect:
                    displayName = 'Multiple Choice';
                    break;
                  case SurveyFieldType.boolean:
                    displayName = 'Yes/No';
                    break;
                  case SurveyFieldType.date:
                    displayName = 'Date';
                    break;
                  case SurveyFieldType.rating:
                    displayName = 'Rating (1-5)';
                    break;
                  case SurveyFieldType.photo:
                    displayName = 'Photo Upload';
                    break;
                }
                return DropdownMenuItem(value: t, child: Text(displayName));
              }).toList(),
              onChanged: (v) => setState(() => _type = v ?? SurveyFieldType.text),
              decoration: const InputDecoration(
                labelText: 'Field Type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _placeholderCtrl,
              decoration: const InputDecoration(
                labelText: 'Placeholder (Optional)',
                hintText: 'Enter your answer here...',
                border: OutlineInputBorder(),
              ),
              textDirection: TextDirection.ltr,
            ),
            if (_needsOptions) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _optionsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Options (one per line)',
                  hintText: 'Option 1\nOption 2\nOption 3',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                textDirection: TextDirection.ltr,
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              value: _required,
              onChanged: (v) => setState(() => _required = v),
              title: const Text('Required Field'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    final label = _labelCtrl.text.trim();
                    if (label.isEmpty) return;
                    
                    // Generate field name from label
                    String fieldName = label
                        .toLowerCase()
                        .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9\s]'), '') // Keep Arabic, English, numbers
                        .replaceAll(RegExp(r'\s+'), '_')
                        .replaceAll(RegExp(r'_+'), '_')
                        .replaceAll(RegExp(r'^_|_$'), '');
                    
                    if (fieldName.isEmpty) {
                      fieldName = 'field_${DateTime.now().millisecondsSinceEpoch}';
                    }
                    
                    // Parse options if needed
                    List<String>? options;
                    if (_needsOptions && _optionsCtrl.text.trim().isNotEmpty) {
                      options = _optionsCtrl.text.trim().split('\n')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                    }
                    
                    final f = SurveyField(
                      id: '',
                      surveyId: '',
                      fieldName: fieldName,
                      fieldType: _type,
                      fieldLabel: label,
                      fieldPlaceholder: _placeholderCtrl.text.trim().isEmpty ? null : _placeholderCtrl.text.trim(),
                      fieldOptions: options,
                      isRequired: _required,
                      fieldOrder: 0,
                      validationRules: null,
                      createdAt: DateTime.now(),
                    );
                    widget.onSave(f);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.save),
                  label: Text(isEditing ? 'Update Field' : 'Add Field'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerSurveyResultsList extends StatefulWidget {
  final String surveyId;
  const _ManagerSurveyResultsList({required this.surveyId});

  @override
  State<_ManagerSurveyResultsList> createState() => _ManagerSurveyResultsListState();
}

class _ManagerSurveyResultsListState extends State<_ManagerSurveyResultsList> {
  final Set<int> _expandedItems = {};

  String _getFirstFieldValue(Map<String, dynamic> data) {
    if (data.isEmpty) return 'No data';
    final firstEntry = data.entries.first;
    final value = firstEntry.value?.toString() ?? 'No value';
    return value.length > 30 ? '${value.substring(0, 30)}...' : value;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final service = GlobalSurveyService();
    return FutureBuilder(
      future: service.getManagerSurveySubmissions(widget.surveyId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) return const Center(child: Text('No submissions yet'));
        
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final submission = list[index];
            final isExpanded = _expandedItems.contains(index);
            final submissionNumber = index + 1;
            final firstFieldValue = _getFirstFieldValue(submission.submissionData);
            
            return Card(
              color: surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      '$submissionNumber. $firstFieldValue',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('Submitted: ${_formatDateTime(submission.submittedAt)}'),
                    trailing: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: primaryColor,
                    ),
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedItems.remove(index);
                        } else {
                          _expandedItems.add(index);
                        }
                      });
                    },
                  ),
                  if (isExpanded) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (submission.submissionData.isNotEmpty) ...[
                            Text(
                              'Submission Data:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...submission.submissionData.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${entry.key}:',
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        entry.value?.toString() ?? 'No value',
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          if (submission.latitude != null && submission.longitude != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: primaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Location: ${submission.latitude!.toStringAsFixed(6)}, ${submission.longitude!.toStringAsFixed(6)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

