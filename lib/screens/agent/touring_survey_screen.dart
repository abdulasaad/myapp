// lib/screens/agent/touring_survey_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/touring_survey.dart';
import '../../models/survey_field.dart';
import '../../models/survey_submission.dart';
import '../../services/survey_service.dart';
import '../../services/location_service.dart';
import '../../utils/constants.dart';
import '../../widgets/modern_notification.dart';

class TouringSurveyScreen extends StatefulWidget {
  final TouringSurvey survey;
  final String touringTaskId;
  final String? sessionId;
  final SurveySubmission? existingSubmission;

  const TouringSurveyScreen({
    super.key,
    required this.survey,
    required this.touringTaskId,
    this.sessionId,
    this.existingSubmission,
  });

  @override
  State<TouringSurveyScreen> createState() => _TouringSurveyScreenState();
}

class _TouringSurveyScreenState extends State<TouringSurveyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _surveyService = SurveyService();
  final _locationService = LocationService();
  final _imagePicker = ImagePicker();
  
  Map<String, dynamic> _submissionData = {};
  Map<String, String?> _fieldErrors = {};
  final bool _isLoading = false;
  bool _isSubmitting = false;
  Position? _currentLocation;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _getCurrentLocation();
  }

  void _initializeForm() {
    if (widget.existingSubmission != null) {
      _submissionData = Map.from(widget.existingSubmission!.submissionData);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentLocation = await _locationService.getCurrentLocation();
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.survey.title),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!widget.survey.isRequired)
            TextButton(
              onPressed: _skipSurvey,
              child: const Text('Skip', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSurveyHeader(),
                    const SizedBox(height: 24),
                    _buildSurveyFields(),
                    const SizedBox(height: 32),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSurveyHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.quiz, color: primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.survey.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            if (widget.survey.description != null && widget.survey.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                widget.survey.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.survey.isRequired ? Colors.red[100] : Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.survey.isRequired ? 'Required' : 'Optional',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.survey.isRequired ? Colors.red[700] : Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${widget.survey.fieldCount} questions',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurveyFields() {
    if (!widget.survey.hasFields) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('No survey questions available'),
          ),
        ),
      );
    }

    return Column(
      children: widget.survey.orderedFields.asMap().entries.map((entry) {
        final index = entry.key;
        final field = entry.value;
        return Column(
          children: [
            _buildFieldWidget(field, index),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildFieldWidget(SurveyField field, int index) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel(field, index),
            const SizedBox(height: 12),
            _buildFieldInput(field),
            if (_fieldErrors[field.fieldName] != null) ...[
              const SizedBox(height: 8),
              Text(
                _fieldErrors[field.fieldName]!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(SurveyField field, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                field.fieldLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (field.isRequired)
                Text(
                  'Required',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldInput(SurveyField field) {
    switch (field.fieldType) {
      case SurveyFieldType.text:
        return _buildTextInput(field);
      case SurveyFieldType.textarea:
        return _buildTextAreaInput(field);
      case SurveyFieldType.number:
        return _buildNumberInput(field);
      case SurveyFieldType.rating:
        return _buildRatingInput(field);
      case SurveyFieldType.select:
        return _buildSelectInput(field);
      case SurveyFieldType.multiselect:
        return _buildMultiSelectInput(field);
      case SurveyFieldType.boolean:
        return _buildBooleanInput(field);
      case SurveyFieldType.date:
        return _buildDateInput(field);
      case SurveyFieldType.photo:
        return _buildPhotoInput(field);
    }
  }

  Widget _buildTextInput(SurveyField field) {
    return TextFormField(
      initialValue: _submissionData[field.fieldName]?.toString() ?? '',
      decoration: InputDecoration(
        hintText: field.fieldPlaceholder,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        setState(() {
          _submissionData[field.fieldName] = value;
          _fieldErrors[field.fieldName] = null;
        });
      },
      validator: (value) => field.validateValue(value),
    );
  }

  Widget _buildTextAreaInput(SurveyField field) {
    return TextFormField(
      initialValue: _submissionData[field.fieldName]?.toString() ?? '',
      decoration: InputDecoration(
        hintText: field.fieldPlaceholder,
        border: const OutlineInputBorder(),
      ),
      maxLines: 4,
      onChanged: (value) {
        setState(() {
          _submissionData[field.fieldName] = value;
          _fieldErrors[field.fieldName] = null;
        });
      },
      validator: (value) => field.validateValue(value),
    );
  }

  Widget _buildNumberInput(SurveyField field) {
    return TextFormField(
      initialValue: _submissionData[field.fieldName]?.toString() ?? '',
      decoration: InputDecoration(
        hintText: field.fieldPlaceholder,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        setState(() {
          _submissionData[field.fieldName] = value;
          _fieldErrors[field.fieldName] = null;
        });
      },
      validator: (value) => field.validateValue(value),
    );
  }

  Widget _buildRatingInput(SurveyField field) {
    final currentValue = _submissionData[field.fieldName] as int? ?? 0;
    final maxRating = field.validationRules?.maxValue?.toInt() ?? 5;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(maxRating, (index) {
            final rating = index + 1;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _submissionData[field.fieldName] = rating;
                  _fieldErrors[field.fieldName] = null;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                child: Icon(
                  rating <= currentValue ? Icons.star : Icons.star_border,
                  color: rating <= currentValue ? Colors.amber : Colors.grey,
                  size: 32,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          currentValue > 0 ? 'Rating: $currentValue/$maxRating' : 'Tap to rate',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectInput(SurveyField field) {
    if (!field.hasOptions) return const Text('No options available');
    
    final currentValue = _submissionData[field.fieldName]?.toString();
    
    return Column(
      children: field.fieldOptions!.map((option) {
        return RadioListTile<String>(
          title: Text(option),
          value: option,
          groupValue: currentValue,
          onChanged: (value) {
            setState(() {
              _submissionData[field.fieldName] = value;
              _fieldErrors[field.fieldName] = null;
            });
          },
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }

  Widget _buildMultiSelectInput(SurveyField field) {
    if (!field.hasOptions) return const Text('No options available');
    
    final currentValues = _submissionData[field.fieldName] as List<String>? ?? [];
    
    return Column(
      children: field.fieldOptions!.map((option) {
        final isSelected = currentValues.contains(option);
        return CheckboxListTile(
          title: Text(option),
          value: isSelected,
          onChanged: (value) {
            setState(() {
              final values = List<String>.from(currentValues);
              if (value == true) {
                values.add(option);
              } else {
                values.remove(option);
              }
              _submissionData[field.fieldName] = values;
              _fieldErrors[field.fieldName] = null;
            });
          },
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }

  Widget _buildBooleanInput(SurveyField field) {
    final currentValue = _submissionData[field.fieldName] as bool?;
    
    return Column(
      children: [
        RadioListTile<bool>(
          title: const Text('Yes'),
          value: true,
          groupValue: currentValue,
          onChanged: (value) {
            setState(() {
              _submissionData[field.fieldName] = value;
              _fieldErrors[field.fieldName] = null;
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<bool>(
          title: const Text('No'),
          value: false,
          groupValue: currentValue,
          onChanged: (value) {
            setState(() {
              _submissionData[field.fieldName] = value;
              _fieldErrors[field.fieldName] = null;
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildDateInput(SurveyField field) {
    final currentValue = _submissionData[field.fieldName]?.toString();
    final displayDate = currentValue != null ? DateTime.tryParse(currentValue) : null;
    
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: displayDate ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        
        if (date != null) {
          setState(() {
            _submissionData[field.fieldName] = date.toIso8601String().split('T')[0];
            _fieldErrors[field.fieldName] = null;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today),
            const SizedBox(width: 12),
            Text(
              displayDate != null 
                  ? '${displayDate.day}/${displayDate.month}/${displayDate.year}'
                  : field.fieldPlaceholder ?? 'Select date',
              style: TextStyle(
                color: displayDate != null ? Colors.black : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoInput(SurveyField field) {
    final currentPhoto = _submissionData[field.fieldName]?.toString();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentPhoto != null) ...[
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(currentPhoto),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.error, size: 50, color: Colors.red),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _pickPhoto(field),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Change Photo'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _submissionData[field.fieldName] = null;
                    _fieldErrors[field.fieldName] = null;
                  });
                },
                icon: const Icon(Icons.delete),
                label: const Text('Remove'),
              ),
            ],
          ),
        ] else ...[
          OutlinedButton.icon(
            onPressed: () => _pickPhoto(field),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Photo'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickPhoto(SurveyField field) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _submissionData[field.fieldName] = image.path;
          _fieldErrors[field.fieldName] = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ModernNotification.error(
          context,
          message: 'Error taking photo',
          subtitle: e.toString(),
        );
      }
    }
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitSurvey,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.send),
        label: Text(_isSubmitting ? 'Submitting...' : 'Submit Survey'),
      ),
    );
  }

  Future<void> _submitSurvey() async {
    setState(() => _isSubmitting = true);
    
    try {
      // Validate all fields
      bool isValid = true;
      final errors = <String, String>{};
      
      for (final field in widget.survey.orderedFields) {
        final error = field.validateValue(_submissionData[field.fieldName]);
        if (error != null) {
          errors[field.fieldName] = error;
          isValid = false;
        }
      }
      
      if (!isValid) {
        setState(() {
          _fieldErrors = errors;
        });
        ModernNotification.warning(
          context,
          message: 'Please fix errors',
          subtitle: 'Some fields require your attention',
        );
        return;
      }

      // Submit the survey
      final submission = await _surveyService.submitSurveyResponse(
        surveyId: widget.survey.id,
        touringTaskId: widget.touringTaskId,
        sessionId: widget.sessionId,
        submissionData: _submissionData,
        latitude: _currentLocation?.latitude,
        longitude: _currentLocation?.longitude,
      );

      if (submission == null) {
        throw Exception('Failed to submit survey');
      }

      if (mounted) {
        ModernNotification.success(
          context,
          message: 'Survey Submitted',
          subtitle: 'Thank you for your feedback!',
        );
        Navigator.pop(context, submission);
      }

    } catch (e) {
      if (mounted) {
        ModernNotification.error(
          context,
          message: 'Submission Failed',
          subtitle: e.toString(),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _skipSurvey() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Survey'),
        content: const Text('Are you sure you want to skip this survey? You can complete it later if needed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close survey screen
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }
}