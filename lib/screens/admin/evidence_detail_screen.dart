// lib/screens/admin/evidence_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../utils/constants.dart';
import '../full_screen_image_viewer.dart';
import 'evidence_location_viewer.dart';

class EvidenceDetailScreen extends StatefulWidget {
  final String evidenceId;

  const EvidenceDetailScreen({
    super.key,
    required this.evidenceId,
  });

  @override
  State<EvidenceDetailScreen> createState() => _EvidenceDetailScreenState();
}

class _EvidenceDetailScreenState extends State<EvidenceDetailScreen> {
  late Future<EvidenceDetail> _evidenceFuture;

  @override
  void initState() {
    super.initState();
    _evidenceFuture = _loadEvidenceDetail();
  }

  Future<EvidenceDetail> _loadEvidenceDetail() async {
    try {
      debugPrint('Loading evidence detail for ID: ${widget.evidenceId}');
      
      // Get basic evidence data first
      final evidenceResponse = await supabase
          .from('evidence')
          .select('*')
          .eq('id', widget.evidenceId)
          .single();
      
      debugPrint('Evidence data: $evidenceResponse');
      debugPrint('task_assignment_id: ${evidenceResponse['task_assignment_id']}');
      debugPrint('place_visit_id: ${evidenceResponse['place_visit_id']}');
      
      // Initialize variables for related data
      String taskAssignmentId = 'unknown';
      String taskId = 'unknown';
      String taskTitle = 'Unknown Task';
      String? taskDescription;
      int? taskPoints;
      String? campaignId;
      String? campaignName;
      String? campaignDescription;
      String agentId = 'unknown';
      String agentName = 'Unknown Agent';
      String agentRole = 'agent';
      String agentStatus = 'active';
      
      // Check if this is task-based evidence
      if (evidenceResponse['task_assignment_id'] != null) {
        try {
          final taskAssignmentResponse = await supabase
              .from('task_assignments')
              .select('''
                id,
                task_id,
                agent_id,
                tasks(
                  id,
                  title,
                  description,
                  points,
                  campaign_id,
                  location_name,
                  campaigns(name, description)
                ),
                profiles:profiles!agent_id(
                  id,
                  full_name,
                  role,
                  status
                )
              ''')
              .eq('id', evidenceResponse['task_assignment_id'])
              .single();
          
          taskAssignmentId = taskAssignmentResponse['id'];
          agentId = taskAssignmentResponse['agent_id'];
          
          final task = taskAssignmentResponse['tasks'];
          final agent = taskAssignmentResponse['profiles'];
          final campaign = task?['campaigns'];
          
          if (task != null) {
            taskId = task['id'];
            taskTitle = task['title'] ?? 'Unknown Task';
            taskDescription = task['description'];
            taskPoints = task['points'];
            campaignId = task['campaign_id'];
          }
          
          if (campaign != null) {
            campaignName = campaign['name'];
            campaignDescription = campaign['description'];
          }
          
          if (agent != null) {
            agentName = agent['full_name'] ?? 'Unknown Agent';
            agentRole = agent['role'] ?? 'agent';
            agentStatus = agent['status'] ?? 'active';
          }
          
        } catch (e) {
          debugPrint('Error loading task assignment data: $e');
        }
      }
      // Check if this is route-based evidence
      else if (evidenceResponse['place_visit_id'] != null) {
        try {
          final placeVisitResponse = await supabase
              .from('place_visits')
              .select('''
                id,
                agent_id,
                place_id,
                route_assignment_id,
                places(name, description),
                route_assignments(
                  id,
                  route_id,
                  agent_id,
                  routes(name, description)
                )
              ''')
              .eq('id', evidenceResponse['place_visit_id'])
              .single();
          
          agentId = placeVisitResponse['agent_id'];
          taskAssignmentId = placeVisitResponse['route_assignment_id'] ?? 'unknown';
          
          final place = placeVisitResponse['places'];
          final routeAssignment = placeVisitResponse['route_assignments'];
          final route = routeAssignment?['routes'];
          
          // Create descriptive task info for route evidence
          if (place != null) {
            taskTitle = 'Route Visit: ${place['name']}';
            taskDescription = place['description'];
            taskId = placeVisitResponse['place_id'] ?? 'unknown';
          }
          
          if (route != null) {
            campaignName = 'Route: ${route['name']}';
            campaignDescription = route['description'];
            campaignId = routeAssignment?['route_id'];
          }
          
          // Get agent profile
          final agentResponse = await supabase
              .from('profiles')
              .select('id, full_name, role, status')
              .eq('id', agentId)
              .maybeSingle();
          
          if (agentResponse != null) {
            agentName = agentResponse['full_name'] ?? 'Unknown Agent';
            agentRole = agentResponse['role'] ?? 'agent';
            agentStatus = agentResponse['status'] ?? 'active';
          }
          
        } catch (e) {
          debugPrint('Error loading place visit data: $e');
        }
      }
      // Handle standalone evidence
      else {
        taskTitle = 'Standalone Evidence';
        campaignName = 'Standalone Upload';
        
        // Get uploader info
        final uploaderResponse = await supabase
            .from('profiles')
            .select('id, full_name, role, status')
            .eq('id', evidenceResponse['uploader_id'])
            .maybeSingle();
        
        if (uploaderResponse != null) {
          agentId = uploaderResponse['id'];
          agentName = uploaderResponse['full_name'] ?? 'Unknown Agent';
          agentRole = uploaderResponse['role'] ?? 'agent';
          agentStatus = uploaderResponse['status'] ?? 'active';
        }
      }
      
      return EvidenceDetail(
        id: evidenceResponse['id'],
        title: evidenceResponse['title'] ?? 'Evidence',
        description: evidenceResponse['description'],
        fileUrl: evidenceResponse['file_url'],
        mimeType: evidenceResponse['mime_type'],
        fileSize: evidenceResponse['file_size'],
        status: evidenceResponse['status'] ?? 'pending',
        createdAt: DateTime.parse(evidenceResponse['created_at']),
        capturedAt: evidenceResponse['captured_at'] != null 
            ? DateTime.parse(evidenceResponse['captured_at']) 
            : DateTime.parse(evidenceResponse['created_at']),
        latitude: evidenceResponse['latitude']?.toDouble(),
        longitude: evidenceResponse['longitude']?.toDouble(),
        accuracy: evidenceResponse['accuracy']?.toDouble(),
        rejectionReason: evidenceResponse['rejection_reason'],
        reviewedAt: evidenceResponse['reviewed_at'] != null 
            ? DateTime.parse(evidenceResponse['reviewed_at']) 
            : null,
        reviewedBy: evidenceResponse['reviewed_by'],
        taskAssignmentId: taskAssignmentId,
        taskId: taskId,
        taskTitle: taskTitle,
        taskDescription: taskDescription,
        taskPoints: taskPoints ?? 0,
        taskGeofenceCenterLat: null,
        taskGeofenceCenterLng: null,
        taskGeofenceRadius: null,
        campaignId: campaignId,
        campaignName: campaignName,
        campaignDescription: campaignDescription,
        agentId: agentId,
        agentName: agentName,
        agentRole: agentRole,
        agentStatus: agentStatus,
      );
    } catch (e) {
      debugPrint('Error loading evidence detail: $e');
      rethrow;
    }
  }


  Future<void> _downloadEvidence(EvidenceDetail evidence) async {
    try {
      // Show downloading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Downloading...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Download the file
      final response = await http.get(Uri.parse(evidence.fileUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      // Get file extension and MIME type
      String extension = '';
      String mimeType = evidence.mimeType ?? 'application/octet-stream';
      
      if (evidence.fileUrl.contains('.')) {
        extension = evidence.fileUrl.split('.').last.split('?').first.toLowerCase();
      } else if (evidence.mimeType != null) {
        switch (evidence.mimeType) {
          case 'image/jpeg':
            extension = 'jpg';
            break;
          case 'image/png':
            extension = 'png';
            break;
          case 'application/pdf':
            extension = 'pdf';
            break;
          default:
            extension = 'file';
        }
      }

      // Create filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanTitle = evidence.title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      final fileName = 'evidence_${cleanTitle}_$timestamp.$extension';

      String? filePath;

      if (Platform.isAndroid) {
        // Use MediaStore API for Android to save to public Downloads
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        
        if (androidInfo.version.sdkInt >= 29) {
          // Android 10+ (API 29+) - Use MediaStore
          try {
            const platform = MethodChannel('com.example.myapp/download');
            filePath = await platform.invokeMethod('saveToDownloads', {
              'fileName': fileName,
              'mimeType': mimeType,
              'data': response.bodyBytes,
            });
          } catch (e) {
            debugPrint('MediaStore method failed: $e');
            // Fallback to legacy method
            final directory = await getExternalStorageDirectory();
            if (directory != null) {
              final downloadsDir = Directory('${directory.path}/Download');
              if (!await downloadsDir.exists()) {
                await downloadsDir.create(recursive: true);
              }
              final file = File('${downloadsDir.path}/$fileName');
              await file.writeAsBytes(response.bodyBytes);
              filePath = file.path;
            }
          }
        } else {
          // Android 9 and below - Use legacy storage
          final directory = Directory('/storage/emulated/0/Download');
          if (await directory.exists()) {
            final file = File('${directory.path}/$fileName');
            await file.writeAsBytes(response.bodyBytes);
            filePath = file.path;
          } else {
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              final file = File('${externalDir.path}/$fileName');
              await file.writeAsBytes(response.bodyBytes);
              filePath = file.path;
            }
          }
        }
      } else if (Platform.isIOS) {
        // iOS - Save to Documents directory
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        filePath = file.path;
      }

      if (filePath == null) {
        throw Exception('Could not save file');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Downloaded: $fileName'),
                if (Platform.isAndroid && filePath.contains('Download'))
                  const Text(
                    'Check your Downloads folder',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Evidence Details'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<EvidenceDetail>(
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
                    onPressed: () => setState(() => _evidenceFuture = _loadEvidenceDetail()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final evidence = snapshot.data!;
          
          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEvidencePreview(evidence),
                          const SizedBox(height: 24),
                          _buildEvidenceInfo(evidence),
                          const SizedBox(height: 24),
                          _buildAgentInfo(evidence),
                          const SizedBox(height: 24),
                          _buildTaskInfo(evidence),
                          if (evidence.hasLocationData) ...[
                            const SizedBox(height: 24),
                            _buildLocationInfo(evidence),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
            ],
          );
        },
      ),
    );
  }

  Widget _buildEvidencePreview(EvidenceDetail evidence) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    evidence.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusBadge(evidence.status),
              ],
            ),
            const SizedBox(height: 8),
            
            // Download button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _downloadEvidence(evidence),
                icon: const Icon(Icons.download),
                label: Text('Download ${evidence.fileTypeDisplay}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            if (evidence.description != null) ...[
              const SizedBox(height: 8),
              Text(
                evidence.description!,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),
            ],
            const SizedBox(height: 16),
            
            // Evidence preview
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: evidence.isImage
                  ? GestureDetector(
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildImageWidget(evidence.fileUrl),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(evidence.fileIcon, size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            evidence.fileTypeDisplay,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (evidence.fileSize != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _formatFileSize(evidence.fileSize!),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceInfo(EvidenceDetail evidence) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Evidence Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Upload Time', DateFormat.yMMMd().add_jms().format(evidence.createdAt)),
            _buildInfoRow('Capture Time', DateFormat.yMMMd().add_jms().format(evidence.capturedAt)),
            if (evidence.fileSize != null)
              _buildInfoRow('File Size', _formatFileSize(evidence.fileSize!)),
            _buildInfoRow('File Type', evidence.fileTypeDisplay),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentInfo(EvidenceDetail evidence) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Submitted By',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor,
                  child: Text(
                    evidence.agentName.isNotEmpty ? evidence.agentName[0].toUpperCase() : 'A',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        evidence.agentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Role: ${evidence.agentRole.toUpperCase()}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: evidence.agentStatus == 'active' ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    evidence.agentStatus.toUpperCase(),
                    style: TextStyle(
                      color: evidence.agentStatus == 'active' ? Colors.green : Colors.grey[600],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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

  Widget _buildTaskInfo(EvidenceDetail evidence) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Related Task',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              evidence.taskTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            if (evidence.taskDescription != null) ...[
              const SizedBox(height: 8),
              Text(
                evidence.taskDescription!,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (evidence.campaignName != null) ...[
                  Icon(Icons.campaign, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Campaign: ${evidence.campaignName}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                if (evidence.taskPoints != null) ...[
                  Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${evidence.taskPoints} points',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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

  Widget _buildLocationInfo(EvidenceDetail evidence) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Location validation
            if (evidence.hasTaskGeofence) ...[
              _buildLocationValidation(evidence),
              const SizedBox(height: 12),
            ],
            
            // View on Map button - full width
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EvidenceLocationViewer(evidence: evidence),
                    ),
                  );
                },
                icon: const Icon(Icons.map),
                label: const Text('View on Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationValidation(EvidenceDetail evidence) {
    final distance = evidence.distanceFromTaskCenter;
    final isWithinGeofence = evidence.isWithinTaskGeofence;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWithinGeofence ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWithinGeofence ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isWithinGeofence ? Icons.check_circle : Icons.warning,
            color: isWithinGeofence ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWithinGeofence ? 'Location Verified' : 'Location Warning',
                  style: TextStyle(
                    color: isWithinGeofence ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  distance != null 
                      ? '${distance.toStringAsFixed(0)}m from task center'
                      : 'Could not verify location',
                  style: TextStyle(
                    color: isWithinGeofence ? Colors.green[700] : Colors.orange[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewInfo(EvidenceDetail evidence) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Review Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Status', evidence.status.toUpperCase()),
            if (evidence.reviewedAt != null)
              _buildInfoRow('Reviewed At', DateFormat.yMMMd().add_jms().format(evidence.reviewedAt!)),
            if (evidence.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rejection Reason:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      evidence.rejectionReason!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildImageWidget(String imageUrl) {
    // Check if it's a local file path or network URL
    if (imageUrl.startsWith('/') || imageUrl.startsWith('file://')) {
      // Local file path - use File image
      try {
        final file = File(imageUrl.replaceFirst('file://', ''));
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
          );
        } else {
          return _buildErrorWidget('Local file not found');
        }
      } catch (e) {
        return _buildErrorWidget('Error loading local file');
      }
    } else if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      // Network URL - use Network image
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget('Failed to load image from network'),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    } else {
      // Invalid URL format
      return _buildErrorWidget('Invalid image URL format');
    }
  }

  Widget _buildErrorWidget([String? message]) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            message ?? 'Failed to load image',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// Comprehensive evidence detail model
class EvidenceDetail {
  final String id;
  final String title;
  final String? description;
  final String fileUrl;
  final String? mimeType;
  final int? fileSize;
  final String status;
  final DateTime createdAt;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  
  // Task assignment info
  final String taskAssignmentId;
  final String taskId;
  final String taskTitle;
  final String? taskDescription;
  final int? taskPoints;
  final double? taskGeofenceCenterLat;
  final double? taskGeofenceCenterLng;
  final double? taskGeofenceRadius;
  
  // Campaign info
  final String? campaignId;
  final String? campaignName;
  final String? campaignDescription;
  
  // Agent info
  final String agentId;
  final String agentName;
  final String agentRole;
  final String agentStatus;

  EvidenceDetail({
    required this.id,
    required this.title,
    this.description,
    required this.fileUrl,
    this.mimeType,
    this.fileSize,
    required this.status,
    required this.createdAt,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedBy,
    required this.taskAssignmentId,
    required this.taskId,
    required this.taskTitle,
    this.taskDescription,
    this.taskPoints,
    this.taskGeofenceCenterLat,
    this.taskGeofenceCenterLng,
    this.taskGeofenceRadius,
    this.campaignId,
    this.campaignName,
    this.campaignDescription,
    required this.agentId,
    required this.agentName,
    required this.agentRole,
    required this.agentStatus,
  });

  bool get hasLocationData => latitude != null && longitude != null;
  bool get hasTaskGeofence => taskGeofenceCenterLat != null && taskGeofenceCenterLng != null && taskGeofenceRadius != null;
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

  // Calculate distance from task center (if both have location data)
  double? get distanceFromTaskCenter {
    if (!hasLocationData || !hasTaskGeofence) return null;
    
    // Simplified distance calculation (for more accuracy, use proper geospatial calculations)
    final lat1 = latitude! * (3.14159265359 / 180);
    final lat2 = taskGeofenceCenterLat! * (3.14159265359 / 180);
    final deltaLat = (taskGeofenceCenterLat! - latitude!) * (3.14159265359 / 180);
    final deltaLng = (taskGeofenceCenterLng! - longitude!) * (3.14159265359 / 180);

    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    final c = 2 * math.asin(math.sqrt(a));

    return 6371000 * c; // Distance in meters
  }

  // Check if evidence location is within task geofence
  bool get isWithinTaskGeofence {
    final distance = distanceFromTaskCenter;
    if (distance == null || taskGeofenceRadius == null) return false;
    return distance <= taskGeofenceRadius!;
  }
}