// lib/widgets/standalone_upload_dialog.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart';
import '../services/location_service.dart';

class StandaloneUploadDialog extends StatefulWidget {
  const StandaloneUploadDialog({super.key});

  @override
  State<StandaloneUploadDialog> createState() => _StandaloneUploadDialogState();
}

class _StandaloneUploadDialogState extends State<StandaloneUploadDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  dynamic _selectedFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
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
                  const Icon(Icons.upload_file, color: primaryColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Upload Evidence',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textPrimaryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Title Input
              TextFormField(
                controller: _titleController,
                enabled: !_isUploading,
                decoration: const InputDecoration(
                  labelText: 'Title *',
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
                  hintText: 'Optional description or notes',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                maxLength: 500,
              ),
              const SizedBox(height: 16),
              
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
                          'Select File',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (_selectedFile == null)
                      _buildFileSelectionButton(
                        icon: Icons.attach_file,
                        label: 'Select File',
                        onTap: _isUploading ? null : _pickFile,
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
                      'Uploading... ${(_uploadProgress * 100).toInt()}%',
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
                      child: _isUploading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Upload'),
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
            context.showSnackBar('File too large. Maximum size is 50MB.', isError: true);
          }
          return;
        }
        
        setState(() => _selectedFile = file);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error selecting file: $e', isError: true);
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
      final fileName = 'standalone/${supabase.auth.currentUser!.id}/$timestamp-$sanitizedName';
      final fileSize = file.size;

      // Check file size (limit to 50MB)
      if (fileSize > 50 * 1024 * 1024) {
        if (mounted) {
          context.showSnackBar('File too large. Maximum size is 50MB.', isError: true);
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

      // Create evidence record
      final evidenceData = {
        'task_assignment_id': null, // null for standalone uploads
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
        'status': 'pending', // All uploads start as pending for review
      };

      await supabase.from('evidence').insert(evidenceData);

      setState(() => _uploadProgress = 1.0);

      if (mounted) {
        context.showSnackBar('Evidence uploaded successfully! Your manager will review it soon.');
        Navigator.of(context).pop(true); // Return true to indicate successful upload
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Upload failed: $e', isError: true);
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

