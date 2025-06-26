// lib/services/template_service.dart

import 'package:flutter/foundation.dart';
import '../models/template_category.dart';
import '../models/task_template.dart';
import '../models/template_field.dart';
import '../models/task.dart';
import '../utils/constants.dart';

class TemplateService {
  // Singleton pattern
  static final TemplateService _instance = TemplateService._internal();
  factory TemplateService() => _instance;
  TemplateService._internal();

  // ================================
  // TEMPLATE CATEGORIES
  // ================================

  /// Get all active template categories
  Future<List<TemplateCategory>> getCategories() async {
    final response = await supabase
        .from('template_categories')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    
    return response.map((json) => TemplateCategory.fromJson(json)).toList();
  }

  /// Get a specific category by ID
  Future<TemplateCategory?> getCategoryById(String categoryId) async {
    final response = await supabase
        .from('template_categories')
        .select()
        .eq('id', categoryId)
        .eq('is_active', true)
        .maybeSingle();
    
    return response != null ? TemplateCategory.fromJson(response) : null;
  }

  // ================================
  // TASK TEMPLATES
  // ================================

  /// Get all active templates
  Future<List<TaskTemplate>> getTemplates() async {
    final response = await supabase
        .from('task_templates')
        .select('''
          *,
          template_categories!inner(*)
        ''')
        .eq('is_active', true)
        .eq('template_categories.is_active', true)
        .order('name');
    
    return response.map((json) => TaskTemplate.fromJson(json)).toList();
  }

  /// Get templates by category
  Future<List<TaskTemplate>> getTemplatesByCategory(String categoryId) async {
    final response = await supabase
        .from('task_templates')
        .select('''
          *,
          template_categories!inner(*)
        ''')
        .eq('category_id', categoryId)
        .eq('is_active', true)
        .eq('template_categories.is_active', true)
        .order('name');
    
    return response.map((json) => TaskTemplate.fromJson(json)).toList();
  }

  /// Get templates by category name (using RPC function)
  Future<List<TaskTemplate>> getTemplatesByCategoryName(String categoryName) async {
    final response = await supabase.rpc('get_templates_by_category', 
        params: {'category_name': categoryName});
    
    return response.map((json) => TaskTemplate.fromJson({
      'id': json['template_id'],
      'name': json['template_name'],
      'description': json['description'],
      'default_points': json['default_points'],
      'requires_geofence': json['requires_geofence'],
      'difficulty_level': json['difficulty_level'],
      'estimated_duration': json['estimated_duration'],
      'category_id': '', // We don't have this from the RPC
      'template_config': {},
      'evidence_types': ['image'],
      'default_evidence_count': 1,
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    })).toList();
  }

  /// Get a specific template with its fields
  Future<TaskTemplate?> getTemplateWithFields(String templateId) async {
    final response = await supabase.rpc('get_template_with_fields', 
        params: {'template_id': templateId});
    
    if (response == null) return null;
    
    final templateData = response['template'];
    final fieldsData = response['fields'] as List?;
    
    // Parse the template
    final template = TaskTemplate.fromJson(templateData);
    
    // Parse the fields
    final fields = fieldsData?.map((field) => TemplateField.fromJson(field)).toList();
    
    return template.copyWith(fields: fields);
  }

  /// Get template by ID (without fields)
  Future<TaskTemplate?> getTemplateById(String templateId) async {
    final response = await supabase
        .from('task_templates')
        .select('''
          *,
          template_categories(*)
        ''')
        .eq('id', templateId)
        .eq('is_active', true)
        .maybeSingle();
    
    return response != null ? TaskTemplate.fromJson(response) : null;
  }

  // ================================
  // TEMPLATE FIELDS
  // ================================

  /// Get fields for a specific template
  Future<List<TemplateField>> getTemplateFields(String templateId) async {
    final response = await supabase
        .from('template_fields')
        .select()
        .eq('template_id', templateId)
        .order('sort_order');
    
    return response.map((json) => TemplateField.fromJson(json)).toList();
  }

  // ================================
  // TASK CREATION FROM TEMPLATES
  // ================================

  /// Create a task from a template
  Future<Task> createTaskFromTemplate({
    required String templateId,
    required String title,
    String? description,
    String? locationName,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? customFieldValues,
    int? overridePoints,
    bool? overrideGeofence,
    int? overrideEvidenceCount,
  }) async {
    // Get the template
    final template = await getTemplateById(templateId);
    if (template == null) {
      throw Exception('Template not found');
    }

    // Prepare task data
    final taskData = {
      'title': title,
      'description': description ?? template.description,
      'points': overridePoints ?? template.defaultPoints,
      'status': 'active',
      'location_name': locationName,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'required_evidence_count': overrideEvidenceCount ?? template.defaultEvidenceCount,
      'enforce_geofence': overrideGeofence ?? template.requiresGeofence,
      'template_id': templateId,
      'custom_fields': customFieldValues ?? {},
      'template_version': 1,
      'campaign_id': null, // Standalone task
    };

    // Insert the task
    final response = await supabase
        .from('tasks')
        .insert(taskData)
        .select()
        .single();

    // Track template usage for analytics
    await _trackTemplateUsage(templateId, response['id']);

    return Task.fromJson(response);
  }

  /// Update custom field values for an existing task
  Future<void> updateTaskCustomFields(String taskId, Map<String, dynamic> customFields) async {
    await supabase
        .from('tasks')
        .update({'custom_fields': customFields})
        .eq('id', taskId);
  }

  // ================================
  // ANALYTICS & TRACKING
  // ================================

  /// Track template usage for analytics
  Future<void> _trackTemplateUsage(String templateId, String taskId) async {
    try {
      await supabase.from('template_usage_analytics').insert({
        'template_id': templateId,
        'task_id': taskId,
        'created_by': supabase.auth.currentUser?.id,
      });
    } catch (e) {
      // Don't fail task creation if analytics tracking fails
      debugPrint('Failed to track template usage: $e');
    }
  }

  /// Update template usage when task is completed
  Future<void> updateTemplateUsageCompletion({
    required String taskId,
    required int completionTimeMinutes,
    required double successRate,
  }) async {
    try {
      await supabase
          .from('template_usage_analytics')
          .update({
            'completion_time': completionTimeMinutes,
            'success_rate': successRate,
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('task_id', taskId);
    } catch (e) {
      debugPrint('Failed to update template usage completion: $e');
    }
  }

  /// Get template usage statistics (admin only)
  Future<Map<String, dynamic>> getTemplateAnalytics(String templateId) async {
    final response = await supabase
        .from('template_usage_analytics')
        .select()
        .eq('template_id', templateId);

    if (response.isEmpty) {
      return {
        'total_usage': 0,
        'completion_rate': 0.0,
        'avg_completion_time': 0,
        'avg_success_rate': 0.0,
      };
    }

    final totalUsage = response.length;
    final completedTasks = response.where((item) => item['completed_at'] != null).toList();
    final completionRate = completedTasks.length / totalUsage;
    
    final avgCompletionTime = completedTasks.isNotEmpty
        ? completedTasks
            .where((item) => item['completion_time'] != null)
            .map((item) => item['completion_time'] as int)
            .fold(0, (a, b) => a + b) / completedTasks.length
        : 0;

    final avgSuccessRate = completedTasks.isNotEmpty
        ? completedTasks
            .where((item) => item['success_rate'] != null)
            .map((item) => item['success_rate'] as double)
            .fold(0.0, (a, b) => a + b) / completedTasks.length
        : 0.0;

    return {
      'total_usage': totalUsage,
      'completion_rate': completionRate,
      'avg_completion_time': avgCompletionTime.round(),
      'avg_success_rate': avgSuccessRate,
    };
  }

  // ================================
  // ADMIN FUNCTIONS
  // ================================

  /// Create a new template category (admin only)
  Future<TemplateCategory> createCategory({
    required String name,
    required String description,
    required String iconName,
    int sortOrder = 0,
  }) async {
    final response = await supabase
        .from('template_categories')
        .insert({
          'name': name,
          'description': description,
          'icon_name': iconName,
          'sort_order': sortOrder,
        })
        .select()
        .single();

    return TemplateCategory.fromJson(response);
  }

  /// Create a new task template (admin only)
  Future<TaskTemplate> createTemplate({
    required String name,
    required String categoryId,
    required String description,
    int defaultPoints = 10,
    bool requiresGeofence = false,
    int defaultEvidenceCount = 1,
    Map<String, dynamic> templateConfig = const {},
    List<EvidenceType> evidenceTypes = const [EvidenceType.image],
    String? customInstructions,
    int? estimatedDuration,
    DifficultyLevel difficultyLevel = DifficultyLevel.medium,
  }) async {
    final response = await supabase
        .from('task_templates')
        .insert({
          'name': name,
          'category_id': categoryId,
          'description': description,
          'default_points': defaultPoints,
          'requires_geofence': requiresGeofence,
          'default_evidence_count': defaultEvidenceCount,
          'template_config': templateConfig,
          'evidence_types': evidenceTypes.map((e) => e.name).toList(),
          'custom_instructions': customInstructions,
          'estimated_duration': estimatedDuration,
          'difficulty_level': difficultyLevel.name,
          'created_by': supabase.auth.currentUser?.id,
        })
        .select()
        .single();

    return TaskTemplate.fromJson(response);
  }

  /// Add a custom field to a template (admin only)
  Future<TemplateField> addTemplateField({
    required String templateId,
    required String fieldName,
    required TemplateFieldType fieldType,
    required String fieldLabel,
    String? placeholderText,
    bool isRequired = false,
    List<String>? fieldOptions,
    Map<String, dynamic> validationRules = const {},
    int sortOrder = 0,
    String? helpText,
  }) async {
    final response = await supabase
        .from('template_fields')
        .insert({
          'template_id': templateId,
          'field_name': fieldName,
          'field_type': fieldType.name,
          'field_label': fieldLabel,
          'placeholder_text': placeholderText,
          'is_required': isRequired,
          'field_options': fieldOptions,
          'validation_rules': validationRules,
          'sort_order': sortOrder,
          'help_text': helpText,
        })
        .select()
        .single();

    return TemplateField.fromJson(response);
  }

  // ================================
  // UTILITY FUNCTIONS
  // ================================

  /// Validate custom field values against template field requirements
  Map<String, String> validateCustomFields(
    List<TemplateField> fields,
    Map<String, dynamic> values,
  ) {
    final errors = <String, String>{};

    for (final field in fields) {
      final value = values[field.fieldName];

      // Check required fields
      if (field.isRequired && (value == null || value.toString().trim().isEmpty)) {
        errors[field.fieldName] = '${field.fieldLabel} is required';
        continue;
      }

      if (value == null) continue;

      // Type-specific validation
      switch (field.fieldType) {
        case TemplateFieldType.number:
          if (double.tryParse(value.toString()) == null) {
            errors[field.fieldName] = '${field.fieldLabel} must be a valid number';
          }
          break;
        case TemplateFieldType.email:
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.toString())) {
            errors[field.fieldName] = '${field.fieldLabel} must be a valid email address';
          }
          break;
        case TemplateFieldType.phone:
          if (!RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(value.toString())) {
            errors[field.fieldName] = '${field.fieldLabel} must be a valid phone number';
          }
          break;
        case TemplateFieldType.select:
          if (field.fieldOptions != null && !field.fieldOptions!.contains(value.toString())) {
            errors[field.fieldName] = '${field.fieldLabel} must be one of the available options';
          }
          break;
        case TemplateFieldType.multiselect:
          if (field.fieldOptions != null && value is List) {
            for (final item in value) {
              if (!field.fieldOptions!.contains(item.toString())) {
                errors[field.fieldName] = '${field.fieldLabel} contains invalid options';
                break;
              }
            }
          }
          break;
        default:
          break;
      }

      // Custom validation rules
      if (field.validationRules.isNotEmpty) {
        // Add more validation rules as needed
        if (field.validationRules['minLength'] != null) {
          final minLength = field.validationRules['minLength'] as int;
          if (value.toString().length < minLength) {
            errors[field.fieldName] = '${field.fieldLabel} must be at least $minLength characters';
          }
        }
        
        if (field.validationRules['maxLength'] != null) {
          final maxLength = field.validationRules['maxLength'] as int;
          if (value.toString().length > maxLength) {
            errors[field.fieldName] = '${field.fieldLabel} must be no more than $maxLength characters';
          }
        }
      }
    }

    return errors;
  }
}