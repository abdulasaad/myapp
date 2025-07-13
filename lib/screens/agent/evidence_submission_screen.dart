// lib/screens/agent/evidence_submission_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';
import '../../services/profile_service.dart';
import '../../services/location_service.dart';
import '../../widgets/task_submission_preview.dart';
import '../full_screen_image_viewer.dart';
import '../../l10n/app_localizations.dart';

class Evidence {
  final String id;
  final String title;
  final String fileUrl;
  final String? mimeType;
  final int? fileSize;
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final DateTime? capturedAt;
  final double? latitude;
  final double? longitude;
  final double? accuracy;

  Evidence({
    required this.id,
    required this.title,
    required this.fileUrl,
    this.mimeType,
    this.fileSize,
    required this.status,
    this.rejectionReason,
    this.reviewedAt,
    this.capturedAt,
    this.latitude,
    this.longitude,
    this.accuracy,
  });

  factory Evidence.fromJson(Map<String, dynamic> json) => Evidence(
        id: json['id'],
        title: json['title'],
        fileUrl: json['file_url'],
        mimeType: json['mime_type'],
        fileSize: json['file_size'],
        status: json['status'] ?? 'pending',
        rejectionReason: json['rejection_reason'],
        reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at']) : null,
        capturedAt: json['captured_at'] != null ? DateTime.parse(json['captured_at']) : null,
        latitude: json['latitude']?.toDouble(),
        longitude: json['longitude']?.toDouble(),
        accuracy: json['accuracy']?.toDouble(),
      );

  bool get hasLocationData => latitude != null && longitude != null;

  bool get isImage => mimeType?.startsWith('image/') ?? false;
  bool get isPdf => mimeType == 'application/pdf';
  bool get isVideo => mimeType?.startsWith('video/') ?? false;
  bool get isDocument => 
      mimeType?.contains('document') == true ||
      mimeType?.contains('msword') == true ||
      mimeType?.contains('spreadsheet') == true ||
      mimeType?.contains('presentation') == true;

  String fileTypeDisplay(AppLocalizations l10n) {
    if (isImage) return l10n.image;
    if (isPdf) return l10n.pdf;
    if (isVideo) return l10n.video;
    if (isDocument) return l10n.document;
    return l10n.file;
  }

  IconData get fileIcon {
    if (isImage) return Icons.image;
    if (isPdf) return Icons.picture_as_pdf;
    if (isVideo) return Icons.videocam;
    if (isDocument) return Icons.description;
    return Icons.attach_file;
  }
}

class EvidenceSubmissionScreen extends StatefulWidget {
  final Task task;
  const EvidenceSubmissionScreen({super.key, required this.task});

  @override
  State<EvidenceSubmissionScreen> createState() =>
      _EvidenceSubmissionScreenState();
}

class _EvidenceSubmissionScreenState extends State<EvidenceSubmissionScreen> {
  late Future<List<Evidence>> _evidenceFuture;
  String _taskAssignmentId = '';
  String _assignmentStatus = 'pending';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize _evidenceFuture immediately to prevent LateInitializationError
    _evidenceFuture = Future.value([]);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final assignment = await supabase
          .from('task_assignments')
          .select('id, status')
          .match({
        'task_id': widget.task.id,
        'agent_id': supabase.auth.currentUser!.id
      }).maybeSingle();

      if (assignment != null) {
        _taskAssignmentId = assignment['id'];
        _assignmentStatus = assignment['status'];
        
        // Check if assignment is pending
        if (_assignmentStatus == 'pending') {
          if (mounted) {
            // Show dialog and navigate back
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showPendingAssignmentDialog();
            });
          }
        }
      } else {
        // No assignment exists, allow viewing but not submitting
        _assignmentStatus = 'not_assigned';
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.errorLoadingTaskAssignment(e.toString()),
            isError: true);
      }
    } finally {
      // Always set _evidenceFuture to prevent LateInitializationError
      _evidenceFuture = _fetchEvidence();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPendingAssignmentDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange[700]),
            const SizedBox(width: 8),
            Text(l10n.assignmentPending),
          ],
        ),
        content: Text(l10n.assignmentPendingMessage),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: Text(l10n.goBack),
          ),
        ],
      ),
    );
  }

  Future<List<Evidence>> _fetchEvidence() async {
    final isManager = ProfileService.instance.canManageCampaigns;
    var query = supabase.from('evidence').select('id, title, file_url, mime_type, file_size, status, rejection_reason, reviewed_at, captured_at, latitude, longitude, accuracy');

    if (!isManager) {
      if (_taskAssignmentId.isNotEmpty) {
        query = query.eq('task_assignment_id', _taskAssignmentId);
      } else {
        // Return empty list if no assignment
        return [];
      }
    } else {
      query = query.eq('task_id', widget.task.id);
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List<dynamic>)
        .map<Evidence>(
            (json) => Evidence.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> _deleteEvidence(Evidence evidence) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeletion),
        content: Text(l10n.confirmDeleteEvidence(evidence.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(evidence.fileUrl);
      final filePath = uri.pathSegments
          .sublist(uri.pathSegments.indexOf('task-evidence') + 1)
          .join('/');
      await supabase.storage.from('task-evidence').remove([filePath]);
      await supabase.from('evidence').delete().eq('id', evidence.id);

      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.evidenceDeletedSuccess);
        final remainingEvidence = await _fetchEvidence();
        if (remainingEvidence.isEmpty && _assignmentStatus == 'completed') {
          await supabase.from('task_assignments').update({
            'status': 'pending',
            'completed_at': null,
          }).eq('id', _taskAssignmentId);

          if (mounted) {
            context.showSnackBar(AppLocalizations.of(context)!.taskStatusReverted);
            setState(() {
              _assignmentStatus = 'pending';
              _evidenceFuture = Future.value(remainingEvidence);
            });
          }
        } else {
          setState(() {
            _evidenceFuture = Future.value(remainingEvidence);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.evidenceDeleteFailed(e.toString()), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markTaskAsCompleted() async {
    final l10n = AppLocalizations.of(context)!;
    final shouldComplete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmCompletion),
        content: Text(l10n.confirmMarkTaskDone),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (shouldComplete != true || !mounted) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.from('task_assignments').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', _taskAssignmentId);

      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.taskCompletedSuccess);
        setState(() {
          _assignmentStatus = 'completed';
        });
      }
    } catch (e) {
      if (mounted) context.showSnackBar(AppLocalizations.of(context)!.uploadFailed(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showUploadDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    dynamic selectedFile; // Can be XFile or PlatformFile

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.uploadEvidence),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: l10n.evidenceName,
                    hintText: l10n.enterEvidenceName,
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? l10n.evidenceNameRequired
                      : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showFileTypeSelector(setState, (file) {
                          selectedFile = file;
                        }),
                        icon: const Icon(Icons.attach_file),
                        label: Text(selectedFile == null
                            ? l10n.selectFile
                            : l10n.changeFile),
                      ),
                    ),
                  ],
                ),
                if (selectedFile != null) ...[
                  const SizedBox(height: 8),
                  _buildSelectedFileInfo(selectedFile),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: selectedFile == null
                  ? null
                  : () {
                      if (formKey.currentState!.validate()) {
                        final title = titleController.text;
                        Navigator.of(context).pop();
                        _uploadEvidenceFile(title, selectedFile);
                      }
                    },
              child: Text(l10n.upload),
            ),
          ],
        ),
      ),
    );
  }

  void _showFileTypeSelector(StateSetter setState, Function(dynamic) onFileSelected) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(l10n.takePhoto),
              subtitle: Text(l10n.captureWithCamera),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final imageFile = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                  maxWidth: 1024,
                );
                if (imageFile != null) {
                  setState(() => onFileSelected(imageFile));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.chooseImage),
              subtitle: Text(l10n.selectFromGallery),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final imageFile = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                  maxWidth: 1024,
                );
                if (imageFile != null) {
                  setState(() => onFileSelected(imageFile));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: Text(l10n.recordVideo),
              subtitle: Text(l10n.captureVideo),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final videoFile = await picker.pickVideo(
                  source: ImageSource.camera,
                  maxDuration: const Duration(minutes: 5),
                );
                if (videoFile != null) {
                  setState(() => onFileSelected(videoFile));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: Text(l10n.chooseVideo),
              subtitle: Text(l10n.selectVideoFromGallery),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final videoFile = await picker.pickVideo(
                  source: ImageSource.gallery,
                  maxDuration: const Duration(minutes: 5),
                );
                if (videoFile != null) {
                  setState(() => onFileSelected(videoFile));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: Text(l10n.chooseDocument),
              subtitle: Text(l10n.documentTypes),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'],
                  allowMultiple: false,
                );
                if (result != null && result.files.isNotEmpty) {
                  setState(() => onFileSelected(result.files.first));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_present),
              title: Text(l10n.anyFile),
              subtitle: Text(l10n.browseAllFiles),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles(
                  allowMultiple: false,
                );
                if (result != null && result.files.isNotEmpty) {
                  setState(() => onFileSelected(result.files.first));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFileInfo(dynamic file) {
    String fileName;
    String fileSize = '';
    IconData icon;
    
    if (file is XFile) {
      fileName = file.name;
      icon = file.mimeType?.startsWith('video/') == true ? Icons.videocam : Icons.image;
    } else if (file is PlatformFile) {
      fileName = file.name;
      if (file.size > 0) {
        fileSize = ' (${_formatFileSize(file.size)})';
      }
      icon = _getFileIcon(file.extension);
    } else {
      fileName = AppLocalizations.of(context)!.unknownFile;
      icon = Icons.attach_file;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$fileName$fileSize',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.attach_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Future<void> _uploadEvidenceFile(String title, dynamic file) async {
    setState(() => _isLoading = true);
    try {
      // Capture location metadata
      final locationService = LocationService();
      final currentLocation = await locationService.getCurrentLocation();
      
      // Check geofence validation if enforcement is enabled
      if (widget.task.enforceGeofence == true) {
        if (mounted) {
          context.showSnackBar(AppLocalizations.of(context)!.checkingLocation, isError: false);
        }
        
        final isInGeofence = await locationService.isAgentInTaskGeofence(widget.task.id);
        
        if (!isInGeofence) {
          if (mounted) {
            context.showSnackBar(
              AppLocalizations.of(context)!.geofenceValidationFailed,
              isError: true
            );
          }
          return;
        }
        
        if (mounted) {
          context.showSnackBar(AppLocalizations.of(context)!.locationVerified, isError: false);
        }
      }

      late final Uint8List fileBytes;
      late final String fileName;
      late final String mimeType;
      late final int fileSize;

      if (file is XFile) {
        final bytes = await file.readAsBytes();
        fileBytes = Uint8List.fromList(bytes);
        final detectedMimeType = lookupMimeType(file.name, headerBytes: fileBytes);
        mimeType = detectedMimeType ?? (file.mimeType ?? 'application/octet-stream');
        final fileExt = extensionFromMime(mimeType);
        fileName = '${supabase.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        fileSize = fileBytes.length;
      } else if (file is PlatformFile) {
        if (file.bytes != null) {
          fileBytes = file.bytes!;
        } else if (file.path != null) {
          final bytes = await File(file.path!).readAsBytes();
          fileBytes = Uint8List.fromList(bytes);
        } else {
          throw Exception('File has no data');
        }
        mimeType = lookupMimeType(file.name, headerBytes: fileBytes) ?? 'application/octet-stream';
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final sanitizedName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        fileName = '${supabase.auth.currentUser!.id}/$timestamp-$sanitizedName';
        fileSize = file.size;
      } else {
        throw Exception('Unsupported file type');
      }

      // Check file size (limit to 50MB)
      if (fileSize > 50 * 1024 * 1024) {
        if (mounted) {
          context.showSnackBar(AppLocalizations.of(context)!.fileTooLarge, isError: true);
        }
        return;
      }

      await supabase.storage.from('task-evidence').uploadBinary(
            fileName,
            fileBytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );

      final fileUrl = supabase.storage.from('task-evidence').getPublicUrl(fileName);

      final capturedAt = DateTime.now();
      final evidenceData = {
        'task_assignment_id': _taskAssignmentId,
        'uploader_id': supabase.auth.currentUser!.id,
        'title': title,
        'file_url': fileUrl,
        'mime_type': mimeType,
        'file_size': fileSize,
        'captured_at': capturedAt.toIso8601String(),
        'latitude': currentLocation?.latitude,
        'longitude': currentLocation?.longitude,
        'accuracy': currentLocation?.accuracy,
      };
      
      await supabase.from('evidence').insert(evidenceData);

      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.evidenceUploadedSuccess);
        setState(() {
          _evidenceFuture = _fetchEvidence();
        });
      }
    } catch (e) {
      if (mounted) context.showSnackBar(AppLocalizations.of(context)!.uploadFailed(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _viewEvidence(Evidence evidence) {
    if (evidence.isImage) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullScreenImageViewer(
            imageUrl: evidence.fileUrl,
            heroTag: evidence.fileUrl,
          ),
        ),
      );
    } else {
      // For non-image files, show details and option to download/open
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(evidence.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(evidence.fileIcon, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          evidence.fileTypeDisplay(AppLocalizations.of(context)!),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (evidence.fileSize != null)
                          Text(
                            _formatFileSize(evidence.fileSize!),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (evidence.isPdf || evidence.isDocument)
                Text(AppLocalizations.of(context)!.fileViewerInfo)
              else if (evidence.isVideo)
                Text(AppLocalizations.of(context)!.videoPlayerInfo)
              else
                Text(AppLocalizations.of(context)!.compatibleAppInfo),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.close),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _openExternalFile(evidence.fileUrl);
              },
              icon: const Icon(Icons.open_in_new),
              label: Text(AppLocalizations.of(context)!.open),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openExternalFile(String url) async {
    try {
      // You can use url_launcher package here to open the file
      // For now, just copy to clipboard or show URL
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.fileUrl),
          content: SelectableText(url),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.close),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.couldNotOpenFile(e.toString()), isError: true);
      }
    }
  }

  Widget _buildEvidenceStatusChip(Evidence evidence) {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    IconData icon;
    String text;

    switch (evidence.status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle;
        text = l10n.approved;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        text = l10n.rejected;
        break;
      default:
        color = Colors.orange;
        icon = Icons.pending;
        text = l10n.pendingReview;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEvidenceMetadata(Evidence evidence) {
    final metadata = <Widget>[];
    
    if (evidence.capturedAt != null) {
      metadata.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              DateFormat('MMM dd, HH:mm').format(evidence.capturedAt!),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    if (evidence.hasLocationData) {
      metadata.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              '${evidence.latitude!.toStringAsFixed(6)}, ${evidence.longitude!.toStringAsFixed(6)}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
            if (evidence.accuracy != null) ...[
              const SizedBox(width: 4),
              Text(
                '(±${evidence.accuracy!.toStringAsFixed(0)}m)',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (metadata.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 2,
      children: metadata,
    );
  }

  Widget _buildApprovalActions(Evidence evidence) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _rejectEvidence(evidence),
              icon: const Icon(Icons.cancel, color: Colors.red),
              label: Text(l10n.reject, style: const TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _approveEvidence(evidence),
              icon: const Icon(Icons.check_circle),
              label: Text(l10n.approve),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionInfo(Evidence evidence) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.red[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.rejectionReason,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  evidence.rejectionReason!,
                  style: TextStyle(color: Colors.red[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveEvidence(Evidence evidence) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldApprove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.approveEvidence),
        content: Text(l10n.confirmApproveEvidence(evidence.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(l10n.approve),
          ),
        ],
      ),
    );

    if (shouldApprove != true || !mounted) return;

    try {
      await supabase.from('evidence').update({
        'status': 'approved',
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': supabase.auth.currentUser!.id,
      }).eq('id', evidence.id);

      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.evidenceApprovedSuccess);
        setState(() {
          _evidenceFuture = _fetchEvidence();
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.evidenceApproveFailed(e.toString()), isError: true);
      }
    }
  }

  Future<void> _rejectEvidence(Evidence evidence) async {
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.rejectEvidence),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.confirmRejectEvidence(evidence.title)),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: l10n.rejectionReasonLabel,
                  hintText: l10n.rejectionReasonHint,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.rejectionReasonRequired;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.reject),
          ),
        ],
      ),
    );

    if (shouldReject != true || !mounted) return;

    try {
      await supabase.from('evidence').update({
        'status': 'rejected',
        'rejection_reason': reasonController.text.trim(),
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': supabase.auth.currentUser!.id,
      }).eq('id', evidence.id);

      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.evidenceRejectedSuccess);
        setState(() {
          _evidenceFuture = _fetchEvidence();
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.evidenceRejectFailed(e.toString()), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.task.title)),
      body: _isLoading
          ? preloader
          : FutureBuilder<List<Evidence>>(
              future: _evidenceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return preloader;
                }
                if (snapshot.hasError) {
                  return Center(child: Text('${AppLocalizations.of(context)!.error}: ${snapshot.error}'));
                }

                final evidenceList = snapshot.data ?? [];
                final requiredCount = widget.task.requiredEvidenceCount!;
                final taskIsCompleted = _assignmentStatus == 'completed';

                final progressValue = requiredCount > 0
                    ? evidenceList.length / requiredCount
                    : 1.0;

                // ===================================================================
                // THE FIX: Move the "Mark as Done" button to the bottomNavigationBar
                // of the Scaffold to prevent it from overlapping with the FAB.
                // ===================================================================
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.task.description ?? AppLocalizations.of(context)!.noDescription),
                          formSpacer,
                          Text(
                              '${AppLocalizations.of(context)!.location}: ${widget.task.locationName ?? AppLocalizations.of(context)!.noLocationName}'),
                          formSpacer,
                          LinearProgressIndicator(value: progressValue),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                                AppLocalizations.of(context)!.progressLabel(evidenceList.length.toString(), requiredCount.toString())),
                          ),
                          if (taskIsCompleted)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(AppLocalizations.of(context)!.statusCompleted,
                                  style: TextStyle(
                                      color: Colors.green[400],
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TaskSubmissionPreview(
                        taskId: widget.task.id,
                        taskTitle: widget.task.title,
                      ),
                    ),
                    const Divider(),
                    Text(
                        AppLocalizations.of(context)!.isManager(ProfileService.instance.canManageCampaigns)),
                    Expanded(
                      child: evidenceList.isEmpty
                          ? Center(
                              child: Text(AppLocalizations.of(context)!.noEvidenceSubmitted))
                          : ListView.builder(
                              itemCount: evidenceList.length,
                              itemBuilder: (context, index) {
                                final evidence = evidenceList[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Column(
                                    children: [
                                      ListTile(
                                        leading: Icon(evidence.fileIcon),
                                        title: Text(evidence.title),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${evidence.fileTypeDisplay(AppLocalizations.of(context)!)}${evidence.fileSize != null ? ' • ${_formatFileSize(evidence.fileSize!)}' : ''}',
                                            ),
                                            const SizedBox(height: 4),
                                            _buildEvidenceStatusChip(evidence),
                                            if (evidence.capturedAt != null || evidence.hasLocationData) ...[
                                              const SizedBox(height: 4),
                                              _buildEvidenceMetadata(evidence),
                                            ],
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.visibility_outlined),
                                              tooltip: AppLocalizations.of(context)!.viewEvidence,
                                              onPressed: () => _viewEvidence(evidence),
                                            ),
                                            if (!ProfileService.instance.canManageCampaigns || evidence.status == 'pending')
                                              IconButton(
                                                icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                                                tooltip: AppLocalizations.of(context)!.deleteEvidence,
                                                onPressed: () => _deleteEvidence(evidence),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (ProfileService.instance.canManageCampaigns && evidence.status == 'pending')
                                        _buildApprovalActions(evidence),
                                      if (evidence.status == 'rejected' && evidence.rejectionReason != null)
                                        _buildRejectionInfo(evidence),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: FutureBuilder<List<Evidence>>(
        future: _evidenceFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink(); // Return nothing while loading
          }
          final evidenceList = snapshot.data!;
          final requiredCount = widget.task.requiredEvidenceCount!;
          final evidenceComplete = evidenceList.length >= requiredCount;
          final taskIsCompleted = _assignmentStatus == 'completed';

          if (evidenceComplete && !taskIsCompleted) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton.icon(
                onPressed: _markTaskAsCompleted,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(AppLocalizations.of(context)!.markAsDone),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                ),
              ),
            );
          }
          return const SizedBox
              .shrink(); // Return an empty box if conditions aren't met
        },
      ),
      floatingActionButton: _assignmentStatus == 'completed' || _assignmentStatus == 'pending' || _assignmentStatus == 'not_assigned'
          ? null
          : FloatingActionButton.extended(
              onPressed: _showUploadDialog,
              label: Text(AppLocalizations.of(context)!.uploadEvidence),
              icon: const Icon(Icons.upload_file),
            ),
    );
  }
}
