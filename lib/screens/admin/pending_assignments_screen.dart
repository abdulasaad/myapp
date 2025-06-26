// lib/screens/admin/pending_assignments_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/task_assignment_service.dart';
import '../../utils/constants.dart';

class PendingAssignmentsScreen extends StatefulWidget {
  const PendingAssignmentsScreen({super.key});

  @override
  State<PendingAssignmentsScreen> createState() => _PendingAssignmentsScreenState();
}

class _PendingAssignmentsScreenState extends State<PendingAssignmentsScreen> {
  late Future<List<PendingTaskAssignment>> _assignmentsFuture;
  final TextEditingController _rejectionReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _assignmentsFuture = TaskAssignmentService().getPendingAssignments();
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  void _refreshAssignments() {
    setState(() {
      _assignmentsFuture = TaskAssignmentService().getPendingAssignments();
    });
  }

  Future<void> _approveAssignment(PendingTaskAssignment assignment) async {
    try {
      await TaskAssignmentService().approveAssignment(assignment.id);
      if (mounted) {
        context.showSnackBar('Assignment approved for ${assignment.agentName}');
        _refreshAssignments();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to approve assignment: $e', isError: true);
      }
    }
  }

  Future<void> _rejectAssignment(PendingTaskAssignment assignment) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Assignment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject ${assignment.agentName}\'s request for "${assignment.taskTitle}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: _rejectionReasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Enter reason for rejection...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = _rejectionReasonController.text.trim();
              Navigator.of(context).pop(reason.isNotEmpty ? reason : null);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (reason != null) {
      try {
        await TaskAssignmentService().rejectAssignment(assignment.id, reason);
        if (mounted) {
          context.showSnackBar('Assignment rejected');
          _refreshAssignments();
        }
      } catch (e) {
        if (mounted) {
          context.showSnackBar('Failed to reject assignment: $e', isError: true);
        }
      }
      _rejectionReasonController.clear();
    }
  }

  Future<void> _approveAllAssignments(List<PendingTaskAssignment> assignments) async {
    final shouldApprove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve All Assignments'),
        content: Text('Approve all ${assignments.length} pending assignments?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Approve All'),
          ),
        ],
      ),
    );

    if (shouldApprove == true) {
      try {
        for (final assignment in assignments) {
          await TaskAssignmentService().approveAssignment(assignment.id);
        }
        if (mounted) {
          context.showSnackBar('All assignments approved');
          _refreshAssignments();
        }
      } catch (e) {
        if (mounted) {
          context.showSnackBar('Failed to approve all assignments: $e', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Assignments'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAssignments,
          ),
        ],
      ),
      body: FutureBuilder<List<PendingTaskAssignment>>(
        future: _assignmentsFuture,
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
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshAssignments,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          final assignments = snapshot.data ?? [];

          if (assignments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Pending Assignments',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All task assignment requests have been processed.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              if (assignments.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${assignments.length} pending assignment${assignments.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _approveAllAssignments(assignments),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Approve All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _refreshAssignments(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: assignments.length,
                    itemBuilder: (context, index) {
                      final assignment = assignments[index];
                      return _buildAssignmentCard(assignment);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAssignmentCard(PendingTaskAssignment assignment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with agent name and request time
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    assignment.agentName.split(' ').map((e) => e[0]).take(2).join(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.agentName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Requested ${DateFormat.yMMMd().add_jm().format(assignment.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Task details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.taskTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (assignment.taskDescription != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      assignment.taskDescription!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.stars, size: 16, color: Colors.amber[600]),
                      const SizedBox(width: 4),
                      Text('${assignment.points} points'),
                      const SizedBox(width: 16),
                      Icon(Icons.upload_file, size: 16, color: Colors.blue[600]),
                      const SizedBox(width: 4),
                      Text('${assignment.requiredEvidenceCount} evidence'),
                      if (assignment.locationName != null) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.location_on, size: 16, color: Colors.red[600]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            assignment.locationName!,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectAssignment(assignment),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _approveAssignment(assignment),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve Assignment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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
}