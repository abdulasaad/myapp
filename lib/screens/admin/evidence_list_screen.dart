// lib/screens/admin/evidence_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import 'evidence_detail_screen.dart';

class EvidenceListScreen extends StatefulWidget {
  const EvidenceListScreen({super.key});

  @override
  State<EvidenceListScreen> createState() => _EvidenceListScreenState();
}

class _EvidenceListScreenState extends State<EvidenceListScreen> {
  late Future<List<EvidenceListItem>> _evidenceFuture;
  String _selectedStatus = 'all';
  String _searchQuery = '';
  String _sortBy = 'newest';
  
  @override
  void initState() {
    super.initState();
    _evidenceFuture = _loadEvidence();
  }

  Future<List<EvidenceListItem>> _loadEvidence() async {
    try {
      debugPrint('Loading evidence with simplified query...');
      
      // First, try a simple query to test basic evidence loading
      final simpleResponse = await supabase
          .from('evidence')
          .select('id, title, status, task_assignment_id')
          .limit(1);
      
      debugPrint('Simple query result: $simpleResponse');
      
      // Build base query matching the actual database structure
      dynamic query = supabase
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
            uploader_id,
            task_assignments!inner(
              id,
              agent_id,
              task_id,
              tasks!inner(
                id,
                title,
                campaign_id,
                campaigns(name)
              ),
              profiles!agent_id(
                id,
                full_name
              )
            ),
            profiles!uploader_id(
              id,
              full_name
            )
          ''');

      // Apply status filter
      if (_selectedStatus != 'all') {
        query = query.eq('status', _selectedStatus);
      }

      // Apply sorting
      switch (_sortBy) {
        case 'newest':
          query = query.order('created_at', ascending: false);
          break;
        case 'oldest':
          query = query.order('created_at', ascending: true);
          break;
        case 'agent':
          // Will sort by agent name in processing
          query = query.order('created_at', ascending: false);
          break;
      }

      final response = await query;
      final evidenceItems = <EvidenceListItem>[];
      
      for (final item in response) {
        debugPrint('Processing evidence item: ${item['id']}');
        debugPrint('Task assignment data: ${item['task_assignments']}');
        
        final taskAssignment = item['task_assignments'];
        if (taskAssignment == null) {
          debugPrint('Skipping evidence ${item['id']} - no task assignment found');
          // Create a minimal evidence item for records without task assignments
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
            agentId: 'unknown',
            agentName: 'Unknown Agent',
            taskId: 'unknown',
            taskTitle: 'Unknown Task',
            campaignId: null,
            campaignName: null,
            taskAssignmentId: item['task_assignment_id'] ?? 'unknown',
          );
          evidenceItems.add(evidenceItem);
          continue;
        }
        
        final task = taskAssignment['tasks'];
        final agent = taskAssignment['profiles'];
        final campaign = task?['campaigns'];
        
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
          agentId: agent?['id'] ?? 'unknown',
          agentName: agent?['full_name'] ?? 'Unknown Agent',
          taskId: task?['id'] ?? 'unknown',
          taskTitle: task?['title'] ?? 'Unknown Task',
          campaignId: task?['campaign_id'],
          campaignName: campaign?['name'],
          taskAssignmentId: taskAssignment['id'] ?? item['task_assignment_id'],
        );

        // Apply search filter
        if (_searchQuery.isEmpty || 
            evidenceItem.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            evidenceItem.agentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            evidenceItem.taskTitle.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (evidenceItem.campaignName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)) {
          evidenceItems.add(evidenceItem);
        }
      }
      
      // Apply agent sorting if needed
      if (_sortBy == 'agent') {
        evidenceItems.sort((a, b) => a.agentName.compareTo(b.agentName));
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

  void _onStatusChanged(String status) {
    setState(() {
      _selectedStatus = status;
      _evidenceFuture = _loadEvidence();
    });
  }

  void _onSortChanged(String sortBy) {
    setState(() {
      _sortBy = sortBy;
      _evidenceFuture = _loadEvidence();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _evidenceFuture = _loadEvidence();
    });
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
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: FutureBuilder<List<EvidenceListItem>>(
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
                          'Try adjusting your filters',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refreshEvidence(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: evidenceList.length,
                    itemBuilder: (context, index) {
                      final evidence = evidenceList[index];
                      return _buildEvidenceCard(evidence);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search evidence, agents, tasks...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: backgroundColor,
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          
          // Filter chips
          Row(
            children: [
              // Status filter
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all', _selectedStatus == 'all'),
                      _buildFilterChip('Pending', 'pending', _selectedStatus == 'pending'),
                      _buildFilterChip('Approved', 'approved', _selectedStatus == 'approved'),
                      _buildFilterChip('Rejected', 'rejected', _selectedStatus == 'rejected'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Sort dropdown
              PopupMenuButton<String>(
                initialValue: _sortBy,
                onSelected: _onSortChanged,
                icon: const Icon(Icons.sort),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'newest', child: Text('Newest First')),
                  const PopupMenuItem(value: 'oldest', child: Text('Oldest First')),
                  const PopupMenuItem(value: 'agent', child: Text('By Agent')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) => _onStatusChanged(value),
        backgroundColor: backgroundColor,
        selectedColor: primaryColor.withValues(alpha: 0.2),
        checkmarkColor: primaryColor,
      ),
    );
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
                    // Title and status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            evidence.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusBadge(evidence.status),
                      ],
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
              
              // Arrow indicator
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case 'pending':
      default:
        color = Colors.orange;
        icon = Icons.schedule;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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