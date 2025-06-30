// lib/screens/admin/simple_evidence_review_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import '../full_screen_image_viewer.dart';

class SimpleEvidenceReviewScreen extends StatefulWidget {
  const SimpleEvidenceReviewScreen({super.key});

  @override
  State<SimpleEvidenceReviewScreen> createState() => _SimpleEvidenceReviewScreenState();
}

class _SimpleEvidenceReviewScreenState extends State<SimpleEvidenceReviewScreen> {
  late Future<List<EvidenceItem>> _evidenceFuture;
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _evidenceFuture = _loadPendingEvidence();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<List<EvidenceItem>> _loadPendingEvidence() async {
    // Get current user to check role and group access
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('No authenticated user');
    
    // Get current user's profile to check role
    final userProfile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', currentUserId)
        .single();
    
    final isAdmin = userProfile['role'] == 'admin';
    
    // Get pending evidence with task and agent information (using LEFT JOIN for standalone evidence)
    var query = supabase
        .from('evidence')
        .select('''
          *,
          task_assignments(
            id,
            tasks(
              id,
              title,
              template_id,
              task_templates(name)
            ),
            profiles(
              id,
              full_name,
              user_groups!inner(group_id)
            )
          ),
          profiles!evidence_uploader_id_fkey(
            id,
            full_name,
            user_groups!inner(group_id)
          )
        ''')
        .eq('status', 'pending');
    
    // If manager, filter by group membership
    if (!isAdmin) {
      // Get manager's groups
      final managerGroups = await supabase
          .from('user_groups')
          .select('group_id')
          .eq('user_id', currentUserId);
      
      final groupIds = managerGroups.map((g) => g['group_id']).toList();
      
      if (groupIds.isEmpty) {
        return []; // Manager has no groups, no evidence to review
      }
      
      // Apply group filter - this is complex because we need to filter on either
      // task assignment agent's groups OR standalone uploader's groups
      // We'll handle this in the processing logic below
    }
    
    final response = await query.order('created_at', ascending: false);

    final evidenceItems = <EvidenceItem>[];
    
    // Get manager's group IDs for filtering (if not admin)
    Set<String>? managerGroupIds;
    if (!isAdmin) {
      final managerGroups = await supabase
          .from('user_groups')
          .select('group_id')
          .eq('user_id', currentUserId);
      managerGroupIds = managerGroups.map<String>((g) => g['group_id'].toString()).toSet();
    }
    
    for (final item in response) {
      final taskAssignment = item['task_assignments'];
      final uploader = item['profiles'];
      
      String agentId, agentName;
      String? taskId, taskTitle, templateName, taskAssignmentId;
      bool shouldInclude = isAdmin; // Admins see all evidence
      
      if (taskAssignment != null) {
        // Task-based evidence
        final task = taskAssignment['tasks'];
        final agent = taskAssignment['profiles'];
        final template = task?['task_templates'];
        final agentGroups = agent['user_groups'] as List<dynamic>?;
        
        agentId = agent['id'];
        agentName = agent['full_name'];
        taskId = task?['id'];
        taskTitle = task?['title'];
        templateName = template?['name'] ?? 'Custom Task';
        taskAssignmentId = taskAssignment['id'];
        
        // Check if manager has access to this agent
        if (!isAdmin && managerGroupIds != null && agentGroups != null) {
          final agentGroupIds = agentGroups.map((g) => g['group_id'].toString()).toSet();
          shouldInclude = managerGroupIds.intersection(agentGroupIds).isNotEmpty;
        }
      } else {
        // Standalone evidence
        final uploaderGroups = uploader['user_groups'] as List<dynamic>?;
        
        agentId = uploader['id'];
        agentName = uploader['full_name'];
        taskId = null;
        taskTitle = null;
        templateName = null;
        taskAssignmentId = null;
        
        // Check if manager has access to this uploader
        if (!isAdmin && managerGroupIds != null && uploaderGroups != null) {
          final uploaderGroupIds = uploaderGroups.map((g) => g['group_id'].toString()).toSet();
          shouldInclude = managerGroupIds.intersection(uploaderGroupIds).isNotEmpty;
        }
      }
      
      // Only include evidence if manager has access or if user is admin
      if (shouldInclude) {
        evidenceItems.add(EvidenceItem(
          id: item['id'],
          title: item['title'],
          description: item['description'],
          fileUrl: item['file_url'],
          mimeType: item['mime_type'],
          fileSize: item['file_size'],
          capturedAt: item['captured_at'] != null 
              ? DateTime.parse(item['captured_at']) 
              : DateTime.parse(item['created_at']),
          latitude: item['latitude']?.toDouble(),
          longitude: item['longitude']?.toDouble(),
          accuracy: item['accuracy']?.toDouble(),
          taskId: taskId,
          taskTitle: taskTitle,
          templateName: templateName,
          agentId: agentId,
          agentName: agentName,
          taskAssignmentId: taskAssignmentId,
          isStandalone: taskAssignmentId == null,
        ));
      }
    }
    
    return evidenceItems;
  }

  Future<void> _processEvidence(EvidenceItem evidence, bool approve, {String? rejectionReason}) async {
    if (_isProcessing) return;
    
    setState(() => _isProcessing = true);
    
    try {
      await supabase.from('evidence').update({
        'status': approve ? 'approved' : 'rejected',
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': supabase.auth.currentUser?.id,
        'rejection_reason': rejectionReason,
      }).eq('id', evidence.id);

      if (mounted) {
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Evidence approved!' : 'Evidence rejected'),
            backgroundColor: approve ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );

        // Move to next evidence or close if this was the last
        final evidenceList = await _evidenceFuture;
        final filteredList = evidenceList.where((e) => e.id != evidence.id).toList();
        
        if (filteredList.isEmpty) {
          // No more evidence, go back
          if (mounted) {
            Navigator.of(context).pop();
          }
        } else {
          // Update the future with filtered list
          setState(() {
            _evidenceFuture = Future.value(filteredList);
            if (_currentIndex >= filteredList.length) {
              _currentIndex = filteredList.length - 1;
            }
          });
          
          // Animate to next item or stay if it was the last
          if (_currentIndex < filteredList.length) {
            _pageController.animateToPage(
              _currentIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error processing evidence: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showRejectDialog(EvidenceItem evidence) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Evidence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you rejecting this evidence?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (reasonController.text.trim().isNotEmpty) {
                _processEvidence(evidence, false, rejectionReason: reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Review Evidence'),
        elevation: 0,
      ),
      body: FutureBuilder<List<EvidenceItem>>(
        future: _evidenceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.white70),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading evidence',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _evidenceFuture = _loadPendingEvidence();
                      });
                    },
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
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 64,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'All Caught Up!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No pending evidence to review',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Dashboard'),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemCount: evidenceList.length,
                itemBuilder: (context, index) {
                  final evidence = evidenceList[index];
                  return _buildEvidenceCard(evidence);
                },
              ),
              
              // Top overlay with progress and info
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: evidenceList.isNotEmpty ? _buildTopOverlay(evidenceList[_currentIndex]) : null,
                ),
              ),
              
              // Bottom action buttons
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: evidenceList.isNotEmpty ? _buildActionButtons(evidenceList[_currentIndex]) : null,
                ),
              ),
              
              // Processing overlay
              if (_isProcessing)
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopOverlay(EvidenceItem evidence) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress indicator
        FutureBuilder<List<EvidenceItem>>(
          future: _evidenceFuture,
          builder: (context, snapshot) {
            final evidenceList = snapshot.data ?? [];
            final total = evidenceList.length;
            return Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: total > 0 ? (_currentIndex + 1) / total : 0,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_currentIndex + 1} / $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        
        // Evidence title and type
        Text(
          evidence.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: evidence.isStandalone ? Colors.purple[600] : Colors.blue[600],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            evidence.isStandalone 
                ? '📤 Standalone Evidence' 
                : '📋 ${evidence.taskTitle ?? 'Task Evidence'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (evidence.description != null && evidence.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            evidence.description!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.person, size: 16, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              evidence.agentName,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(width: 16),
            Icon(Icons.schedule, size: 16, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              DateFormat.MMMd().add_jm().format(evidence.capturedAt),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        if (evidence.hasLocationData) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.green[300]),
              const SizedBox(width: 4),
              Text(
                'Location verified (±${evidence.accuracy?.toStringAsFixed(0) ?? '?'}m)',
                style: TextStyle(color: Colors.green[300]),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEvidenceCard(EvidenceItem evidence) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 80, 16, 120),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: evidence.isImage 
            ? _buildImagePreview(evidence)
            : _buildFilePreview(evidence),
      ),
    );
  }

  Widget _buildImagePreview(EvidenceItem evidence) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FullScreenImageViewer(
              imageUrl: evidence.fileUrl,
              heroTag: 'evidence-${evidence.id}',
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: FutureBuilder<Widget>(
          future: _buildImageWidget(evidence),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            return snapshot.data ?? _buildImageError(evidence);
          },
        ),
      ),
    );
  }

  Future<Widget> _buildImageWidget(EvidenceItem evidence) async {
    // Try multiple approaches to load the image
    
    // First, try with authentication headers
    try {
      return Image.network(
        evidence.fileUrl,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        headers: {
          'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken ?? ''}',
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Image load error with auth headers: $error');
          // If auth headers fail, try without them
          return Image.network(
            evidence.fileUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error2, stackTrace2) {
              debugPrint('Image load error without auth headers: $error2');
              return _buildImageError(evidence);
            },
          );
        },
      );
    } catch (e) {
      debugPrint('Error creating image widget: $e');
      return _buildImageError(evidence);
    }
  }

  Widget _buildImageError(EvidenceItem evidence) {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.white70),
            const SizedBox(height: 8),
            const Text(
              'Failed to load image',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'URL: ${evidence.fileUrl}',
              style: const TextStyle(color: Colors.white54, fontSize: 10),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                // Test URL access
                debugPrint('Testing URL: ${evidence.fileUrl}');
                // Extract file path from URL
                final uri = Uri.parse(evidence.fileUrl);
                final pathSegments = uri.pathSegments;
                // Find the path after 'task-evidence'
                final bucketIndex = pathSegments.indexOf('task-evidence');
                if (bucketIndex >= 0 && bucketIndex < pathSegments.length - 1) {
                  final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
                  debugPrint('Extracted file path: $filePath');
                  try {
                    final response = await supabase.storage
                        .from('task-evidence')
                        .download(filePath);
                    debugPrint('✅ File download successful: ${response.length} bytes');
                  } catch (e) {
                    debugPrint('❌ File download failed: $e');
                  }
                } else {
                  debugPrint('❌ Could not extract file path from URL');
                }
              },
              child: const Text('Test URL'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreview(EvidenceItem evidence) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                evidence.fileIcon,
                size: 64,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              evidence.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              evidence.fileTypeDisplay,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            if (evidence.fileSize != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatFileSize(evidence.fileSize!),
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Open file in external viewer or download
                // This would need platform-specific implementation
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(EvidenceItem evidence) {
    return Row(
      children: [
        // Reject button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _showRejectDialog(evidence),
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Approve button
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _processEvidence(evidence, true),
            icon: const Icon(Icons.check),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// Evidence item model for review
class EvidenceItem {
  final String id;
  final String title;
  final String? description;
  final String fileUrl;
  final String? mimeType;
  final int? fileSize;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? taskId;
  final String? taskTitle;
  final String? templateName;
  final String agentId;
  final String agentName;
  final String? taskAssignmentId;
  final bool isStandalone;

  EvidenceItem({
    required this.id,
    required this.title,
    this.description,
    required this.fileUrl,
    this.mimeType,
    this.fileSize,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.taskId,
    this.taskTitle,
    this.templateName,
    required this.agentId,
    required this.agentName,
    this.taskAssignmentId,
    required this.isStandalone,
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

  String get fileTypeDisplay {
    if (isImage) return 'Image';
    if (isPdf) return 'PDF';
    if (isVideo) return 'Video';
    if (isDocument) return 'Document';
    return 'File';
  }

  IconData get fileIcon {
    if (isImage) return Icons.image;
    if (isPdf) return Icons.picture_as_pdf;
    if (isVideo) return Icons.videocam;
    if (isDocument) return Icons.description;
    return Icons.attach_file;
  }
}