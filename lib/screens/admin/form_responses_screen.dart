// lib/screens/admin/form_responses_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../models/task_template.dart';
import '../../models/template_field.dart';
import '../../utils/constants.dart';

class FormResponsesScreen extends StatefulWidget {
  final Task task;

  const FormResponsesScreen({super.key, required this.task});

  @override
  State<FormResponsesScreen> createState() => _FormResponsesScreenState();
}

class _FormResponsesScreenState extends State<FormResponsesScreen> {
  late Future<FormResponseData> _responseDataFuture;

  @override
  void initState() {
    super.initState();
    _responseDataFuture = _loadFormResponses();
  }

  Future<FormResponseData> _loadFormResponses() async {
    try {
      // Get template and dynamic fields
      final templateResponse = await supabase
          .from('task_templates')
          .select('*')
          .eq('id', widget.task.templateId!)
          .single();
      
      final template = TaskTemplate.fromJson(templateResponse);
      
      // Get dynamic fields for this task
      final dynamicFieldsResponse = await supabase
          .from('task_dynamic_fields')
          .select('*')
          .eq('task_id', widget.task.id)
          .order('sort_order');
      
      final dynamicFields = dynamicFieldsResponse.map<TemplateField>((field) => TemplateField(
        id: field['id'],
        templateId: template.id,
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
        validationRules: {},
        sortOrder: field['sort_order'] ?? 0,
        createdAt: DateTime.parse(field['created_at']),
      )).toList();

      // Get form submissions from evidence table
      final evidenceResponse = await supabase
          .from('evidence')
          .select('''
            id,
            title,
            file_url,
            created_at,
            task_assignments!inner(
              id,
              task_id,
              agent_id,
              profiles!inner(email, full_name)
            )
          ''')
          .eq('task_assignments.task_id', widget.task.id)
          .eq('mime_type', 'application/json')
          .like('title', 'Form Data:%')
          .order('created_at', ascending: false);

      final responses = <FormResponse>[];
      
      for (final evidence in evidenceResponse) {
        try {
          // Decode base64 form data
          final base64Data = evidence['file_url'].toString().split(',')[1];
          final jsonString = utf8.decode(base64Decode(base64Data));
          final formData = jsonDecode(jsonString) as Map<String, dynamic>;
          
          final agentProfile = evidence['task_assignments']['profiles'];
          
          responses.add(FormResponse(
            id: evidence['id'],
            agentEmail: agentProfile['email'] ?? 'Unknown',
            agentName: agentProfile['full_name'] ?? agentProfile['email'] ?? 'Unknown',
            submittedAt: DateTime.parse(evidence['created_at']),
            formData: formData,
          ));
        } catch (e) {
          debugPrint('Failed to parse form response: $e');
        }
      }

      return FormResponseData(
        template: template,
        dynamicFields: dynamicFields,
        responses: responses,
      );
      
    } catch (e) {
      debugPrint('Failed to load form responses: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Form Responses: ${widget.task.title}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _exportResponses,
            icon: const Icon(Icons.download),
            tooltip: 'Export Data',
          ),
        ],
      ),
      body: FutureBuilder<FormResponseData>(
        future: _responseDataFuture,
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
                  Text('Error loading responses: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _responseDataFuture = _loadFormResponses();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          
          if (data.responses.isEmpty) {
            return _buildEmptyState();
          }

          return _buildResponsesList(data);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Form Responses Yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Agents haven\'t submitted any responses for this task yet.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResponsesList(FormResponseData data) {
    return Column(
      children: [
        _buildSummaryCard(data),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.responses.length,
            itemBuilder: (context, index) {
              final response = data.responses[index];
              return _buildResponseCard(response, data.dynamicFields);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(FormResponseData data) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.poll, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Survey Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildSummaryItem('Responses', data.responses.length.toString()),
                  const SizedBox(width: 24),
                  _buildSummaryItem('Fields', data.dynamicFields.length.toString()),
                  const SizedBox(width: 24),
                  _buildSummaryItem('Template', data.template.taskTypeDisplayName),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildResponseCard(FormResponse response, List<TemplateField> fields) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            response.agentName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(response.agentName),
        subtitle: Text(
          'Submitted ${DateFormat('MMM dd, yyyy at HH:mm').format(response.submittedAt)}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                ...fields.map((field) => _buildFieldResponse(field, response.formData)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldResponse(TemplateField field, Map<String, dynamic> formData) {
    final value = formData[field.fieldName];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              field.fieldLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              _formatFieldValue(field, value),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFieldValue(TemplateField field, dynamic value) {
    if (value == null) return 'No response';
    
    switch (field.fieldType) {
      case TemplateFieldType.multiselect:
        if (value is List) {
          return value.join(', ');
        }
        break;
      case TemplateFieldType.checkbox:
        return value == true ? 'Yes' : 'No';
      default:
        break;
    }
    
    return value.toString();
  }

  void _exportResponses() {
    // TODO: Implement CSV/Excel export functionality
    context.showSnackBar('Export functionality coming soon!');
  }
}

class FormResponseData {
  final TaskTemplate template;
  final List<TemplateField> dynamicFields;
  final List<FormResponse> responses;

  FormResponseData({
    required this.template,
    required this.dynamicFields,
    required this.responses,
  });
}

class FormResponse {
  final String id;
  final String agentEmail;
  final String agentName;
  final DateTime submittedAt;
  final Map<String, dynamic> formData;

  FormResponse({
    required this.id,
    required this.agentEmail,
    required this.agentName,
    required this.submittedAt,
    required this.formData,
  });
}