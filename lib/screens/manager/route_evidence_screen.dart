// lib/screens/manager/route_evidence_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';

class RouteEvidenceScreen extends StatefulWidget {
  const RouteEvidenceScreen({super.key});

  @override
  State<RouteEvidenceScreen> createState() => _RouteEvidenceScreenState();
}

class _RouteEvidenceScreenState extends State<RouteEvidenceScreen> {
  bool _isLoading = true;
  List<RouteEvidenceItem> _evidenceList = [];
  String _selectedStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRouteEvidence();
  }

  Future<void> _loadRouteEvidence() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Get manager's groups
      final managerGroups = await supabase
          .from('user_groups')
          .select('group_id')
          .eq('user_id', currentUser.id);

      if (managerGroups.isEmpty) {
        setState(() {
          _evidenceList = [];
          _isLoading = false;
        });
        return;
      }

      final groupIds = managerGroups.map((g) => g['group_id']).toList();

      // Get agents in manager's groups
      final agentsInGroups = await supabase
          .from('user_groups')
          .select('user_id')
          .inFilter('group_id', groupIds);

      if (agentsInGroups.isEmpty) {
        setState(() {
          _evidenceList = [];
          _isLoading = false;
        });
        return;
      }

      final agentIds = agentsInGroups.map((a) => a['user_id'] as String).toList();

      // Build base query
      var queryBuilder = supabase
          .from('evidence')
          .select('''
            id,
            title,
            description,
            file_url,
            mime_type,
            file_size,
            status,
            created_at,
            latitude,
            longitude,
            place_visit_id,
            route_assignment_id,
            profiles!uploader_id(
              id,
              full_name
            ),
            place_visits!place_visit_id(
              id,
              place_id,
              checked_in_at,
              checked_out_at,
              places!place_id(
                id,
                name,
                address
              )
            ),
            route_assignments!route_assignment_id(
              id,
              route_id,
              routes!route_id(
                id,
                name
              )
            )
          ''')
          .not('route_assignment_id', 'is', null) // Only route evidence
          .inFilter('uploader_id', agentIds);

      // Apply status filter
      if (_selectedStatus != 'all') {
        queryBuilder = queryBuilder.eq('status', _selectedStatus);
      }

      final response = await queryBuilder.order('created_at', ascending: false);

      final evidenceList = response.map((json) {
        return RouteEvidenceItem.fromJson(json);
      }).toList();

      // Apply search filter
      final filteredList = evidenceList.where((evidence) {
        if (_searchQuery.isEmpty) return true;
        final query = _searchQuery.toLowerCase();
        return evidence.title.toLowerCase().contains(query) ||
               evidence.agentName.toLowerCase().contains(query) ||
               evidence.placeName.toLowerCase().contains(query) ||
               evidence.routeName.toLowerCase().contains(query);
      }).toList();

      setState(() {
        _evidenceList = filteredList;
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showSnackBar('Error loading evidence: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Route Evidence'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildEvidenceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _loadRouteEvidence();
            },
            decoration: InputDecoration(
              hintText: 'Search by agent, place, or route name...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          
          // Status filter
          Row(
            children: [
              const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('all', 'All'),
                      _buildStatusChip('pending', 'Pending'),
                      _buildStatusChip('approved', 'Approved'),
                      _buildStatusChip('rejected', 'Rejected'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String value, String label) {
    final isSelected = _selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedStatus = value);
          _loadRouteEvidence();
        },
        backgroundColor: isSelected ? primaryColor : Colors.grey[200],
        selectedColor: primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildEvidenceList() {
    if (_evidenceList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No route evidence found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Evidence submitted by agents will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _evidenceList.length,
      itemBuilder: (context, index) {
        final evidence = _evidenceList[index];
        return _buildEvidenceCard(evidence);
      },
    );
  }

  Widget _buildEvidenceCard(RouteEvidenceItem evidence) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(evidence.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getFileIcon(evidence.mimeType),
                    color: _getStatusColor(evidence.status),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        evidence.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimaryColor,
                        ),
                      ),
                      Text(
                        'by ${evidence.agentName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(evidence.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    evidence.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(evidence.status),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Route and place info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.route, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Route: ${evidence.routeName}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Place: ${evidence.placeName}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            if (evidence.description?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                evidence.description!,
                style: const TextStyle(fontSize: 14, color: textSecondaryColor),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Metadata
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  DateFormat.MMMd().add_jm().format(evidence.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (evidence.fileSize != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.storage, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatFileSize(evidence.fileSize!),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewEvidence(evidence),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                  ),
                ),
                if (evidence.status == 'pending') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectEvidence(evidence),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveEvidence(evidence),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.attachment;
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    return Icons.attachment;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  void _viewEvidence(RouteEvidenceItem evidence) {
    // TODO: Navigate to evidence detail screen or show preview
    context.showSnackBar('View evidence: ${evidence.title}');
  }

  void _approveEvidence(RouteEvidenceItem evidence) async {
    try {
      await supabase.from('evidence').update({
        'status': 'approved',
        'reviewed_by': supabase.auth.currentUser!.id,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', evidence.id);

      context.showSnackBar('Evidence approved successfully!');
      _loadRouteEvidence();
    } catch (e) {
      context.showSnackBar('Error approving evidence: $e', isError: true);
    }
  }

  void _rejectEvidence(RouteEvidenceItem evidence) async {
    final reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Evidence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to reject "${evidence.title}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (Optional)',
                hintText: 'Explain why this evidence was rejected',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await supabase.from('evidence').update({
          'status': 'rejected',
          'rejection_reason': reasonController.text.trim().isNotEmpty 
              ? reasonController.text.trim() 
              : null,
          'reviewed_by': supabase.auth.currentUser!.id,
          'reviewed_at': DateTime.now().toIso8601String(),
        }).eq('id', evidence.id);

        context.showSnackBar('Evidence rejected.');
        _loadRouteEvidence();
      } catch (e) {
        context.showSnackBar('Error rejecting evidence: $e', isError: true);
      }
    }
  }
}

class RouteEvidenceItem {
  final String id;
  final String title;
  final String? description;
  final String fileUrl;
  final String? mimeType;
  final int? fileSize;
  final String status;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String agentName;
  final String placeName;
  final String routeName;

  RouteEvidenceItem({
    required this.id,
    required this.title,
    this.description,
    required this.fileUrl,
    this.mimeType,
    this.fileSize,
    required this.status,
    required this.createdAt,
    this.latitude,
    this.longitude,
    required this.agentName,
    required this.placeName,
    required this.routeName,
  });

  factory RouteEvidenceItem.fromJson(Map<String, dynamic> json) {
    return RouteEvidenceItem(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      fileUrl: json['file_url'],
      mimeType: json['mime_type'],
      fileSize: json['file_size'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      agentName: json['profiles']?['full_name'] ?? 'Unknown',
      placeName: json['place_visits']?['places']?['name'] ?? 'Unknown Place',
      routeName: json['route_assignments']?['routes']?['name'] ?? 'Unknown Route',
    );
  }
}