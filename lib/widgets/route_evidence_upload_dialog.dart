// lib/widgets/route_evidence_upload_dialog.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart';
import '../services/location_service.dart';
import '../models/place_visit.dart';
import '../models/route_place.dart';
import '../widgets/modern_notification.dart';

class RouteEvidenceUploadDialog extends StatefulWidget {
  final PlaceVisit placeVisit;
  final RoutePlace routePlace;
  final int requiredEvidenceCount;
  final int currentEvidenceCount;

  const RouteEvidenceUploadDialog({
    super.key,
    required this.placeVisit,
    required this.routePlace,
    required this.requiredEvidenceCount,
    required this.currentEvidenceCount,
  });

  @override
  State<RouteEvidenceUploadDialog> createState() => _RouteEvidenceUploadDialogState();
}

class _RouteEvidenceUploadDialogState extends State<RouteEvidenceUploadDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  dynamic _selectedFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  
  @override
  void initState() {
    super.initState();
    // Auto-populate title with place name and evidence number
    final evidenceNumber = widget.currentEvidenceCount + 1;
    _titleController.text = '${widget.routePlace.place?.name ?? 'Place'} - Evidence $evidenceNumber';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainingEvidence = widget.requiredEvidenceCount - widget.currentEvidenceCount;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.camera_alt, color: primaryColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload Evidence',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textPrimaryColor,
                          ),
                        ),
                        Text(
                          '${widget.routePlace.place?.name ?? 'Unknown Place'}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Evidence Progress Indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: remainingEvidence > 0 ? Colors.orange[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: remainingEvidence > 0 ? Colors.orange[200]! : Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      remainingEvidence > 0 ? Icons.info_outline : Icons.check_circle,
                      color: remainingEvidence > 0 ? Colors.orange[700] : Colors.green[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        remainingEvidence > 0 
                            ? 'Evidence Required: $remainingEvidence more needed (${widget.currentEvidenceCount}/${widget.requiredEvidenceCount})'
                            : 'Evidence Complete: ${widget.currentEvidenceCount}/${widget.requiredEvidenceCount} submitted',
                        style: TextStyle(
                          fontSize: 12,
                          color: remainingEvidence > 0 ? Colors.orange[700] : Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Title Input
              TextFormField(
                controller: _titleController,
                enabled: !_isUploading,
                decoration: const InputDecoration(
                  labelText: 'Evidence Title *',
                  hintText: 'Enter a title for this evidence',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  if (value.trim().length < 3) {
                    return 'Title must be at least 3 characters';
                  }
                  return null;
                },
                maxLength: 100,
              ),
              const SizedBox(height: 16),
              
              // Description Input
              TextFormField(
                controller: _descriptionController,
                enabled: !_isUploading,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional notes about this evidence',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
                maxLength: 300,
              ),
              const SizedBox(height: 16),
              
              // Instructions (if available)
              if (widget.routePlace.instructions?.isNotEmpty == true) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instructions:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.routePlace.instructions!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // File Selection
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.attach_file, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Select Evidence File',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (_selectedFile == null)
                      Column(
                        children: [
                          _buildFileSelectionButton(
                            icon: Icons.camera_alt,
                            label: 'Take Photo/Video',
                            onTap: _isUploading ? null : _pickFile,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey[300])),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey[300])),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildFileSelectionButton(
                            icon: Icons.file_upload,
                            label: 'Upload File',
                            onTap: _isUploading ? null : _pickFile,
                          ),
                        ],
                      )
                    else
                      _buildSelectedFileInfo(),
                  ],
                ),
              ),
              
              if (_isUploading) ...[
                const SizedBox(height: 16),
                Column(
                  children: [
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 8),
                    Text(
                      'Uploading evidence... ${(_uploadProgress * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUploading || _selectedFile == null 
                          ? null 
                          : _uploadEvidence,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: _isUploading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Upload Evidence'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileSelectionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade100 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: onTap == null ? Colors.grey : primaryColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? Colors.grey : textPrimaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFileInfo() {
    final file = _selectedFile as PlatformFile;
    final fileName = file.name;
    final fileSize = file.size > 0 ? ' (${_formatFileSize(file.size)})' : '';
    final icon = _getFileIcon(file.extension);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (fileSize.isNotEmpty)
                  Text(
                    fileSize.trim(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isUploading ? null : () {
              setState(() {
                _selectedFile = null;
              });
            },
            icon: Icon(Icons.close, color: Colors.green.shade700),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.videocam;
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
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  Future<void> _pickFile() async {
    try {
      // Use FilePicker with FileType.any to show Android's built-in picker
      // This will show options for camera, gallery, file manager, etc.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        allowCompression: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Check file size (limit to 50MB)
        if (file.size > 50 * 1024 * 1024) {
          if (mounted) {
            ModernNotification.error(context, message: 'File too large. Maximum size is 50MB.');
          }
          return;
        }
        
        setState(() => _selectedFile = file);
      }
    } catch (e) {
      if (mounted) {
        ModernNotification.error(context, message: 'Error selecting file: $e');
      }
    }
  }

  Future<void> _uploadEvidence() async {
    if (!_formKey.currentState!.validate() || _selectedFile == null) {
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Get current location for metadata
      Position? currentLocation;
      try {
        currentLocation = await LocationService().getCurrentLocation();
      } catch (e) {
        // Continue without location if GPS fails
      }

      setState(() => _uploadProgress = 0.2);

      // Prepare file data
      final file = _selectedFile as PlatformFile;
      
      Uint8List fileBytes;
      if (file.bytes != null) {
        fileBytes = file.bytes!;
      } else if (file.path != null) {
        final bytes = await File(file.path!).readAsBytes();
        fileBytes = Uint8List.fromList(bytes);
      } else {
        throw Exception('File has no data');
      }
      
      final mimeType = lookupMimeType(file.name, headerBytes: fileBytes) ?? 'application/octet-stream';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final fileName = 'route_evidence/${supabase.auth.currentUser!.id}/$timestamp-$sanitizedName';
      final fileSize = file.size;

      // Check file size (limit to 50MB)
      if (fileSize > 50 * 1024 * 1024) {
        if (mounted) {
          ModernNotification.error(context, message: 'File too large. Maximum size is 50MB.');
        }
        return;
      }

      setState(() => _uploadProgress = 0.4);

      // Upload file to storage
      await supabase.storage.from('task-evidence').uploadBinary(
        fileName,
        fileBytes,
        fileOptions: FileOptions(contentType: mimeType, upsert: false),
      );

      setState(() => _uploadProgress = 0.7);

      // Get file URL - try signed URL first, fallback to public URL
      String fileUrl;
      try {
        // Try to create a signed URL (valid for 1 year)
        fileUrl = await supabase.storage
            .from('task-evidence')
            .createSignedUrl(fileName, 60 * 60 * 24 * 365); // 1 year
        debugPrint('✅ Generated signed URL: $fileUrl');
      } catch (e) {
        // Fallback to public URL if signed URL fails
        fileUrl = supabase.storage.from('task-evidence').getPublicUrl(fileName);
        debugPrint('⚠️ Signed URL failed, using public URL: $fileUrl');
        debugPrint('Signed URL error: $e');
      }

      // Create evidence record linked to place visit
      final evidenceData = {
        'place_visit_id': widget.placeVisit.id, // Link to place visit instead of task_assignment_id
        'route_assignment_id': widget.placeVisit.routeAssignmentId, // Also link to route assignment
        'uploader_id': supabase.auth.currentUser!.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'file_url': fileUrl,
        'mime_type': mimeType,
        'file_size': fileSize,
        'captured_at': DateTime.now().toIso8601String(),
        'latitude': currentLocation?.latitude,
        'longitude': currentLocation?.longitude,
        'accuracy': currentLocation?.accuracy,
        'status': 'approved', // Evidence is automatically available to managers
      };

      await supabase.from('evidence').insert(evidenceData);

      setState(() => _uploadProgress = 1.0);

      if (mounted) {
        ModernNotification.success(context, message: 'Evidence uploaded successfully!');
        Navigator.of(context).pop(true); // Return true to indicate successful upload
      }
    } catch (e) {
      if (mounted) {
        ModernNotification.error(context, message: 'Upload failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }
}