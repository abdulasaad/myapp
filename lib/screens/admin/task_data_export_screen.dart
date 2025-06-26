// lib/screens/admin/task_data_export_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/task.dart';
import '../../models/task_template.dart';
import '../../services/template_service.dart';
import '../../utils/constants.dart';

class TaskDataExportScreen extends StatefulWidget {
  final Task task;

  const TaskDataExportScreen({super.key, required this.task});

  @override
  State<TaskDataExportScreen> createState() => _TaskDataExportScreenState();
}

class _TaskDataExportScreenState extends State<TaskDataExportScreen> {
  late Future<TaskExportData> _exportDataFuture;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _exportDataFuture = _loadExportData();
  }

  Future<TaskExportData> _loadExportData() async {
    // Get task template if exists
    TaskTemplate? template;
    if (widget.task.templateId != null) {
      template = await TemplateService().getTemplateById(widget.task.templateId!);
    }

    // Get all task assignments and their data
    final assignments = await supabase
        .from('task_assignments')
        .select('''
          id,
          status,
          assigned_at,
          completed_at,
          profiles!inner(id, full_name),
          evidence!left(
            id,
            title,
            file_url,
            status,
            created_at
          )
        ''')
        .eq('task_id', widget.task.id)
        .order('completed_at', ascending: false);

    // Get custom field data from tasks
    final taskData = await supabase
        .from('tasks')
        .select('custom_fields')
        .eq('id', widget.task.id)
        .single();

    return TaskExportData(
      task: widget.task,
      template: template,
      assignments: assignments,
      customFields: taskData['custom_fields'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Task Data'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              _exportDataFuture = _loadExportData();
            }),
          ),
        ],
      ),
      body: FutureBuilder<TaskExportData>(
        future: _exportDataFuture,
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
                  Text('Error loading export data: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _exportDataFuture = _loadExportData();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final exportData = snapshot.data!;
          return _buildExportScreen(exportData);
        },
      ),
    );
  }

  Widget _buildExportScreen(TaskExportData exportData) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTaskHeader(exportData),
          const SizedBox(height: 20),
          _buildDataSummary(exportData),
          const SizedBox(height: 20),
          _buildExportOptions(exportData),
          const SizedBox(height: 20),
          Expanded(
            child: _buildDataPreview(exportData),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskHeader(TaskExportData exportData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exportData.task.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (exportData.task.description != null) ...[
              const SizedBox(height: 8),
              Text(
                exportData.task.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (exportData.template != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      exportData.template!.taskTypeDisplayName,
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${exportData.task.points} points',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  Widget _buildDataSummary(TaskExportData exportData) {
    final completedCount = exportData.assignments.where((a) => a['status'] == 'completed').length;
    final evidenceCount = exportData.assignments
        .expand((a) => a['evidence'] as List? ?? [])
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Assignments',
                    exportData.assignments.length.toString(),
                    Icons.assignment,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Completed',
                    completedCount.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Evidence Files',
                    evidenceCount.toString(),
                    Icons.attachment,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildExportOptions(TaskExportData exportData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Options',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : () => _exportAsCSV(exportData),
                    icon: _isExporting 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.table_chart),
                    label: const Text('Export as CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isExporting ? null : () => _exportAsJSON(exportData),
                    icon: const Icon(Icons.code),
                    label: const Text('Export as JSON'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataPreview(TaskExportData exportData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Preview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: exportData.assignments.isEmpty
                  ? const Center(
                      child: Text('No assignment data available'),
                    )
                  : ListView.builder(
                      itemCount: exportData.assignments.length,
                      itemBuilder: (context, index) {
                        final assignment = exportData.assignments[index];
                        return _buildAssignmentPreview(assignment);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentPreview(Map<String, dynamic> assignment) {
    final profile = assignment['profiles'];
    final evidence = assignment['evidence'] as List? ?? [];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    profile['full_name'] ?? 'Unknown Agent',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(assignment['status']).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    assignment['status']?.toUpperCase() ?? 'UNKNOWN',
                    style: TextStyle(
                      color: _getStatusColor(assignment['status']),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (assignment['completed_at'] != null)
              Text(
                'Completed: ${DateFormat.yMMMd().add_jm().format(DateTime.parse(assignment['completed_at']))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (evidence.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Evidence: ${evidence.length} file(s)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.blue[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'assigned':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _exportAsCSV(TaskExportData exportData) async {
    setState(() => _isExporting = true);

    try {
      final csvData = _generateCSVData(exportData);
      await _saveAndShareFile(csvData, 'task_data.csv', 'text/csv');
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to export CSV: $e', isError: true);
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportAsJSON(TaskExportData exportData) async {
    setState(() => _isExporting = true);

    try {
      final jsonData = _generateJSONData(exportData);
      await _saveAndShareFile(jsonData, 'task_data.json', 'application/json');
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to export JSON: $e', isError: true);
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  String _generateCSVData(TaskExportData exportData) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Agent Name,Status,Assigned Date,Completed Date,Evidence Count');
    
    // Data rows
    for (final assignment in exportData.assignments) {
      final profile = assignment['profiles'];
      final evidence = assignment['evidence'] as List? ?? [];
      
      buffer.writeln([
        '"${profile['full_name'] ?? 'Unknown'}"',
        assignment['status'] ?? 'unknown',
        assignment['assigned_at'] ?? '',
        assignment['completed_at'] ?? '',
        evidence.length,
      ].join(','));
    }
    
    return buffer.toString();
  }

  String _generateJSONData(TaskExportData exportData) {
    final data = {
      'task': {
        'id': exportData.task.id,
        'title': exportData.task.title,
        'description': exportData.task.description,
        'points': exportData.task.points,
        'status': exportData.task.status,
      },
      'template': exportData.template != null ? {
        'name': exportData.template!.name,
        'type': exportData.template!.taskTypeDisplayName,
        'description': exportData.template!.description,
      } : null,
      'custom_fields': exportData.customFields,
      'assignments': exportData.assignments.map((assignment) => {
        'agent_name': assignment['profiles']['full_name'],
        'status': assignment['status'],
        'assigned_at': assignment['assigned_at'],
        'completed_at': assignment['completed_at'],
        'evidence': (assignment['evidence'] as List? ?? []).map((evidence) => {
          'title': evidence['title'],
          'file_url': evidence['file_url'],
          'status': evidence['status'],
          'created_at': evidence['created_at'],
        }).toList(),
      }).toList(),
      'exported_at': DateTime.now().toIso8601String(),
    };
    
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> _saveAndShareFile(String content, String filename, String mimeType) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(content);
    
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      subject: 'Task Data Export: ${widget.task.title}',
    );
    
    if (mounted) {
      context.showSnackBar('Export completed and shared!');
    }
  }
}

class TaskExportData {
  final Task task;
  final TaskTemplate? template;
  final List<Map<String, dynamic>> assignments;
  final Map<String, dynamic> customFields;

  TaskExportData({
    required this.task,
    this.template,
    required this.assignments,
    required this.customFields,
  });
}