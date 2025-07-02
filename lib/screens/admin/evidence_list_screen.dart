// lib/screens/admin/evidence_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import 'evidence_detail_screen.dart';
import '../../widgets/modern_notification.dart';

class EvidenceListScreen extends StatefulWidget {
  const EvidenceListScreen({super.key});

  @override
  State<EvidenceListScreen> createState() => _EvidenceListScreenState();
}

class _EvidenceListScreenState extends State<EvidenceListScreen> {
  late Future<List<EvidenceListItem>> _evidenceFuture;
  String? _userRole;
  
  @override
  void initState() {
    super.initState();
    _evidenceFuture = _loadEvidence();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await _getUserRole();
    setState(() {
      _userRole = role;
    });
  }

  Future<List<EvidenceListItem>> _loadEvidence() async {
    try {
      debugPrint('Loading evidence - including both task and route evidence...');
      
      // Get current user's role
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final userResponse = await supabase
          .from('profiles')
          .select('role')
          .eq('id', currentUserId)
          .single();
      
      final userRole = userResponse['role'] as String;
      debugPrint('Current user role: $userRole');
      
      // Get all evidence first, then separately fetch related data
      dynamic baseQuery = supabase
          .from('evidence')
          .select('''
            id,
            title,
            file_url,
            mime_type,
            status,
            created_at,
            latitude,
            longitude,
            accuracy,
            task_assignment_id,
            place_visit_id,
            uploader_id
          ''');

      // Apply filtering based on role
      if (userRole == 'manager') {
        // Get all groups where current user is a member (not just manager)
        final userGroupsResponse = await supabase
            .from('user_groups')
            .select('group_id')
            .eq('user_id', currentUserId);
        
        final groupIds = (userGroupsResponse as List).map((g) => g['group_id']).toList();
        debugPrint('Manager is member of groups: $groupIds');
        
        if (groupIds.isNotEmpty) {
          // Get all user IDs from those groups (including agents and other managers)
          final groupMembersResponse = await supabase
              .from('user_groups')
              .select('user_id')
              .inFilter('group_id', groupIds);
          
          final memberIds = (groupMembersResponse as List).map((m) => m['user_id']).toSet().toList();
          debugPrint('All members in manager groups: $memberIds');
          
          if (memberIds.isNotEmpty) {
            // Filter evidence by uploader_id being any member of the same groups
            baseQuery = baseQuery.inFilter('uploader_id', memberIds);
          } else {
            // No members in groups, return empty list
            return [];
          }
        } else {
          // Manager is not in any groups, return empty list
          return [];
        }
      }
      // If user is admin or any other role, show all evidence (no filtering)
      // If admin, no filtering needed - they see all evidence

      baseQuery = baseQuery.order('created_at', ascending: false);

      final response = await baseQuery;
      final evidenceItems = <EvidenceListItem>[];
      
      for (final item in response) {
        debugPrint('Processing evidence item: ${item['id']}');
        debugPrint('Task assignment ID: ${item['task_assignment_id']}');
        debugPrint('Place visit ID: ${item['place_visit_id']}');
        
        String agentName = 'Unknown Agent';
        String agentId = 'unknown';
        String taskTitle = 'Unknown Task';
        String taskId = 'unknown';
        String? campaignName;
        String? campaignId;
        String taskAssignmentId = 'unknown';

        // Get uploader info
        final uploaderResponse = await supabase
            .from('profiles')
            .select('id, full_name')
            .eq('id', item['uploader_id'])
            .maybeSingle();
        
        if (uploaderResponse != null) {
          agentName = uploaderResponse['full_name'] ?? 'Unknown Agent';
          agentId = uploaderResponse['id'] ?? 'unknown';
        }

        // Check if this is task-based evidence
        if (item['task_assignment_id'] != null) {
          try {
            final taskAssignmentResponse = await supabase
                .from('task_assignments')
                .select('''
                  id,
                  agent_id,
                  task_id,
                  tasks(
                    id,
                    title,
                    campaign_id,
                    campaigns(name)
                  )
                ''')
                .eq('id', item['task_assignment_id'])
                .maybeSingle();
            
            if (taskAssignmentResponse != null) {
              taskAssignmentId = taskAssignmentResponse['id'] ?? 'unknown';
              agentId = taskAssignmentResponse['agent_id'] ?? agentId;
              taskId = taskAssignmentResponse['task_id'] ?? 'unknown';
              
              final task = taskAssignmentResponse['tasks'];
              if (task != null) {
                taskTitle = task['title'] ?? 'Unknown Task';
                campaignId = task['campaign_id'];
                
                final campaign = task['campaigns'];
                if (campaign != null) {
                  campaignName = campaign['name'];
                }
              }

              // Get agent name from assignment
              final agentResponse = await supabase
                  .from('profiles')
                  .select('full_name')
                  .eq('id', agentId)
                  .maybeSingle();
              
              if (agentResponse != null) {
                agentName = agentResponse['full_name'] ?? agentName;
              }
            }
          } catch (e) {
            debugPrint('Error loading task assignment data: $e');
          }
        }
        // Check if this is route-based evidence
        else if (item['place_visit_id'] != null) {
          try {
            final placeVisitResponse = await supabase
                .from('place_visits')
                .select('''
                  id,
                  agent_id,
                  place_id,
                  route_assignment_id,
                  places(name),
                  route_assignments(
                    route_id,
                    routes(name)
                  )
                ''')
                .eq('id', item['place_visit_id'])
                .maybeSingle();
            
            if (placeVisitResponse != null) {
              agentId = placeVisitResponse['agent_id'] ?? agentId;
              
              final place = placeVisitResponse['places'];
              final routeAssignment = placeVisitResponse['route_assignments'];
              final route = routeAssignment?['routes'];
              
              // Create descriptive task title for route evidence
              final placeName = place?['name'] ?? 'Unknown Place';
              final routeName = route?['name'] ?? 'Unknown Route';
              taskTitle = 'Route Visit: $placeName';
              campaignName = 'Route: $routeName';
              taskId = placeVisitResponse['place_id'] ?? 'unknown';
              taskAssignmentId = placeVisitResponse['route_assignment_id'] ?? 'unknown';

              // Get agent name
              final agentResponse = await supabase
                  .from('profiles')
                  .select('full_name')
                  .eq('id', agentId)
                  .maybeSingle();
              
              if (agentResponse != null) {
                agentName = agentResponse['full_name'] ?? agentName;
              }
            }
          } catch (e) {
            debugPrint('Error loading place visit data: $e');
          }
        }

        final evidenceItem = EvidenceListItem(
          id: item['id'],
          title: item['title'] ?? 'Evidence',
          fileUrl: item['file_url'] ?? '',
          mimeType: item['mime_type'],
          status: item['status'] ?? 'pending',
          createdAt: DateTime.parse(item['created_at']),
          latitude: item['latitude']?.toDouble(),
          longitude: item['longitude']?.toDouble(),
          accuracy: item['accuracy']?.toDouble(),
          agentId: agentId,
          agentName: agentName,
          taskId: taskId,
          taskTitle: taskTitle,
          campaignId: campaignId,
          campaignName: campaignName,
          taskAssignmentId: taskAssignmentId,
        );

        evidenceItems.add(evidenceItem);
      }
      
      return evidenceItems;
    } catch (e) {
      debugPrint('Error loading evidence: $e');
      rethrow;
    }
  }

  void _refreshEvidence() {
    setState(() {
      _evidenceFuture = _loadEvidence();
    });
  }

  Future<String> _getUserRole() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return 'agent';
    
    try {
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', currentUserId)
          .single();
      
      return response['role'] as String? ?? 'agent';
    } catch (e) {
      return 'agent';
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Evidence Review'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshEvidence,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<EvidenceListItem>>(
              future: _evidenceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading evidence',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _refreshEvidence,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final evidenceList = snapshot.data ?? [];
                
                if (evidenceList.isEmpty) {
                  return FutureBuilder<String>(
                    future: _getUserRole(),
                    builder: (context, roleSnapshot) {
                      final role = roleSnapshot.data;
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No evidence found',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              role == 'manager' 
                                  ? 'No evidence from members in your groups'
                                  : 'No evidence uploaded yet',
                              style: TextStyle(color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refreshEvidence(),
                  child: FutureBuilder<String>(
                    future: _getUserRole(),
                    builder: (context, roleSnapshot) {
                      final role = roleSnapshot.data;
                      return Column(
                        children: [
                          if (role == 'manager') ...[
                            Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Showing evidence from all members in your groups',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: evidenceList.length,
                              itemBuilder: (context, index) {
                                final evidence = evidenceList[index];
                                return _buildEvidenceCard(evidence);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
    );
  }



  Future<void> _showDeleteConfirmation(EvidenceListItem evidence) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Evidence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this evidence?'),
            const SizedBox(height: 16),
            Text(
              'Title: ${evidence.title}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('Agent: ${evidence.agentName}'),
            Text('Date: ${DateFormat.yMMMd().format(evidence.createdAt)}'),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteEvidence(evidence);
    }
  }

  Future<void> _deleteEvidence(EvidenceListItem evidence) async {
    try {
      // First delete the file from storage if it exists
      if (evidence.fileUrl.isNotEmpty) {
        try {
          // Extract the file path from the URL
          final uri = Uri.parse(evidence.fileUrl);
          final pathSegments = uri.pathSegments;
          final bucketIndex = pathSegments.indexOf('task-evidence');
          if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
            final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
            await supabase.storage.from('task-evidence').remove([filePath]);
          }
        } catch (e) {
          debugPrint('Error deleting file from storage: $e');
          // Continue with database deletion even if file deletion fails
        }
      }

      // Delete the evidence record from database
      await supabase
          .from('evidence')
          .delete()
          .eq('id', evidence.id);

      if (mounted) {
        // Show success notification
        ModernNotification.success(
          context,
          message: 'Evidence deleted successfully',
        );
        
        // Refresh the list
        _refreshEvidence();
      }
    } catch (e) {
      debugPrint('Error deleting evidence: $e');
      if (mounted) {
        ModernNotification.error(
          context,
          message: 'Failed to delete evidence: ${e.toString()}',
        );
      }
    }
  }

  Widget _buildEvidenceCard(EvidenceListItem evidence) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EvidenceDetailScreen(evidenceId: evidence.id),
            ),
          ).then((_) => _refreshEvidence()); // Refresh when returning
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Evidence thumbnail/icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: evidence.isImage ? Colors.blue[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: evidence.isImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          evidence.fileUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                              Icon(Icons.image, color: Colors.grey[400]),
                        ),
                      )
                    : Icon(
                        evidence.fileIcon,
                        color: Colors.grey[600],
                        size: 28,
                      ),
              ),
              const SizedBox(width: 16),
              
              // Evidence details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      evidence.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Agent name
                    Row(
                      children: [
                        Icon(Icons.person, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          evidence.agentName,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    
                    // Task/Campaign info
                    Row(
                      children: [
                        Icon(Icons.assignment, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            evidence.campaignName != null 
                                ? '${evidence.campaignName} - ${evidence.taskTitle}'
                                : evidence.taskTitle,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    
                    // Date and location
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat.MMMd().add_jm().format(evidence.createdAt),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                        if (evidence.hasLocationData) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.location_on, size: 14, color: Colors.green[600]),
                          const SizedBox(width: 2),
                          Text(
                            'Located',
                            style: TextStyle(
                              color: Colors.green[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delete button for admins
                  if (_userRole == 'admin')
                    IconButton(
                      onPressed: () => _showDeleteConfirmation(evidence),
                      icon: const Icon(Icons.delete, size: 20),
                      color: Colors.red[600],
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: const EdgeInsets.all(8),
                      tooltip: 'Delete evidence',
                    ),
                  // Arrow indicator
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


}

// Data model for evidence list items
class EvidenceListItem {
  final String id;
  final String title;
  final String fileUrl;
  final String? mimeType;
  final String status;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String agentId;
  final String agentName;
  final String taskId;
  final String taskTitle;
  final String? campaignId;
  final String? campaignName;
  final String taskAssignmentId;

  EvidenceListItem({
    required this.id,
    required this.title,
    required this.fileUrl,
    this.mimeType,
    required this.status,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.accuracy,
    required this.agentId,
    required this.agentName,
    required this.taskId,
    required this.taskTitle,
    this.campaignId,
    this.campaignName,
    required this.taskAssignmentId,
  });

  bool get hasLocationData => latitude != null && longitude != null;
  bool get isImage => mimeType?.startsWith('image/') ?? false;
  bool get isPdf => mimeType == 'application/pdf';
  bool get isVideo => mimeType?.startsWith('video/') ?? false;
  bool get isDocument => 
      mimeType?.contains('document') == true ||
      mimeType?.contains('msword') == true ||
      mimeType?.contains('spreadsheet') == true ||
      mimeType?.contains('presentation') == true;

  IconData get fileIcon {
    if (isImage) return Icons.image;
    if (isPdf) return Icons.picture_as_pdf;
    if (isVideo) return Icons.videocam;
    if (isDocument) return Icons.description;
    return Icons.attach_file;
  }
}