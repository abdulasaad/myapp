// lib/screens/agent/task_execution_router.dart

import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/task_template.dart';
import '../../services/template_service.dart';
import '../../utils/constants.dart';
import 'evidence_submission_screen.dart';
import 'geofence_stay_task_screen.dart';
import 'data_collection_task_screen.dart';

class TaskExecutionRouter extends StatelessWidget {
  final Task task;

  const TaskExecutionRouter({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    if (task.templateId == null) {
      // Legacy task without template - use evidence submission screen
      return EvidenceSubmissionScreen(task: task);
    }

    return FutureBuilder<TaskTemplate?>(
      future: TemplateService().getTemplateById(task.templateId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: Text(task.title),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            body: preloader,
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(task.title),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Template not found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This task template could not be loaded.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final template = snapshot.data!;

        // Route to appropriate screen based on task type
        switch (template.taskType) {
          case TaskType.geofenceStay:
            return GeofenceStayTaskScreen(task: task, template: template);
          
          case TaskType.dataCollection:
          case TaskType.inspection:
          case TaskType.survey:
          case TaskType.maintenance:
            return DataCollectionTaskScreen(task: task, template: template);
          
          case TaskType.delivery:
            // For delivery tasks, use data collection with signature requirement
            return DataCollectionTaskScreen(task: task, template: template);
          
          case TaskType.monitoring:
            // For monitoring tasks, use enhanced evidence submission
            return EnhancedEvidenceSubmissionScreen(task: task, template: template);
          
          case TaskType.simpleEvidence:
          default:
            // Default to evidence submission screen
            return EvidenceSubmissionScreen(task: task);
        }
      },
    );
  }
}

/// Enhanced evidence submission screen for monitoring and complex evidence tasks
class EnhancedEvidenceSubmissionScreen extends StatelessWidget {
  final Task task;
  final TaskTemplate template;

  const EnhancedEvidenceSubmissionScreen({
    super.key,
    required this.task,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(task.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTaskTypeHeader(context),
            const SizedBox(height: 20),
            Expanded(
              child: EvidenceSubmissionScreen(task: task),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTypeHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getTaskTypeColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getTaskTypeIcon(),
                    color: _getTaskTypeColor(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.taskTypeDisplayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        template.taskTypeDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (template.customInstructions != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        template.customInstructions!,
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
            const SizedBox(height: 12),
            _buildTaskRequirements(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskRequirements(BuildContext context) {
    final requirements = <Widget>[];

    // Evidence requirements
    requirements.add(
      _buildRequirementChip(
        Icons.upload_file,
        '${template.defaultEvidenceCount} evidence required',
        Colors.blue,
      ),
    );

    // Geofence requirement
    if (template.requiresGeofence) {
      requirements.add(
        _buildRequirementChip(
          Icons.location_on,
          'Location verification required',
          Colors.red,
        ),
      );
    }

    // Points
    requirements.add(
      _buildRequirementChip(
        Icons.stars,
        '${template.defaultPoints} points',
        Colors.amber,
      ),
    );

    // Duration estimate
    if (template.estimatedDuration != null) {
      requirements.add(
        _buildRequirementChip(
          Icons.schedule,
          template.estimatedDurationDisplay,
          Colors.green,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: requirements,
    );
  }

  Widget _buildRequirementChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTaskTypeIcon() {
    switch (template.taskType) {
      case TaskType.monitoring:
        return Icons.monitor;
      case TaskType.inspection:
        return Icons.fact_check;
      case TaskType.maintenance:
        return Icons.build;
      case TaskType.delivery:
        return Icons.local_shipping;
      default:
        return Icons.assignment;
    }
  }

  Color _getTaskTypeColor() {
    switch (template.taskType) {
      case TaskType.monitoring:
        return Colors.purple;
      case TaskType.inspection:
        return Colors.orange;
      case TaskType.maintenance:
        return Colors.green;
      case TaskType.delivery:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}