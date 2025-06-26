// lib/models/task_template.dart

import 'template_category.dart';
import 'template_field.dart';

enum DifficultyLevel {
  easy,
  medium,
  hard,
}

enum EvidenceType {
  image,
  video,
  document,
  pdf,
  audio,
}

enum TaskType {
  simpleEvidence,    // Basic evidence upload
  geofenceStay,      // Stay in area for duration
  dataCollection,    // Form-based data collection
  inspection,        // Detailed checklist inspection
  survey,            // Survey with multiple questions
  monitoring,        // Continuous monitoring task
  delivery,          // Delivery confirmation
  maintenance,       // Maintenance report
}

class TaskTemplate {
  final String id;
  final String name;
  final String categoryId;
  final String description;
  final int defaultPoints;
  final bool requiresGeofence;
  final int defaultEvidenceCount;
  final Map<String, dynamic> templateConfig;
  final List<EvidenceType> evidenceTypes;
  final String? customInstructions;
  final int? estimatedDuration; // in minutes
  final DifficultyLevel difficultyLevel;
  final TaskType taskType;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Navigation properties
  final TemplateCategory? category;
  final List<TemplateField>? fields;

  TaskTemplate({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.description,
    required this.defaultPoints,
    required this.requiresGeofence,
    required this.defaultEvidenceCount,
    required this.templateConfig,
    required this.evidenceTypes,
    this.customInstructions,
    this.estimatedDuration,
    required this.difficultyLevel,
    required this.taskType,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.category,
    this.fields,
  });

  factory TaskTemplate.fromJson(Map<String, dynamic> json) {
    return TaskTemplate(
      id: json['id'],
      name: json['name'],
      categoryId: json['category_id'],
      description: json['description'] ?? '',
      defaultPoints: json['default_points'] ?? 10,
      requiresGeofence: json['requires_geofence'] ?? false,
      defaultEvidenceCount: json['default_evidence_count'] ?? 1,
      templateConfig: json['template_config'] != null 
          ? Map<String, dynamic>.from(json['template_config'])
          : {},
      evidenceTypes: json['evidence_types'] != null 
          ? (json['evidence_types'] as List)
              .map((e) => _parseEvidenceType(e.toString()))
              .toList()
          : [EvidenceType.image],
      customInstructions: json['custom_instructions'],
      estimatedDuration: json['estimated_duration'],
      difficultyLevel: _parseDifficultyLevel(json['difficulty_level']),
      taskType: _parseTaskType(json['task_type']),
      isActive: json['is_active'] ?? true,
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      category: json['template_categories'] != null 
          ? TemplateCategory.fromJson(json['template_categories'])
          : null,
      fields: json['template_fields'] != null
          ? (json['template_fields'] as List)
              .map((field) => TemplateField.fromJson(field))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      'task_type': taskType.name,
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static DifficultyLevel _parseDifficultyLevel(String? level) {
    switch (level?.toLowerCase()) {
      case 'easy':
        return DifficultyLevel.easy;
      case 'hard':
        return DifficultyLevel.hard;
      case 'medium':
      default:
        return DifficultyLevel.medium;
    }
  }

  static EvidenceType _parseEvidenceType(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return EvidenceType.image;
      case 'video':
        return EvidenceType.video;
      case 'document':
        return EvidenceType.document;
      case 'pdf':
        return EvidenceType.pdf;
      case 'audio':
        return EvidenceType.audio;
      default:
        return EvidenceType.image;
    }
  }

  static TaskType _parseTaskType(String? type) {
    switch (type?.toLowerCase()) {
      case 'simpleevidence':
        return TaskType.simpleEvidence;
      case 'geofencestay':
        return TaskType.geofenceStay;
      case 'datacollection':
        return TaskType.dataCollection;
      case 'inspection':
        return TaskType.inspection;
      case 'survey':
        return TaskType.survey;
      case 'monitoring':
        return TaskType.monitoring;
      case 'delivery':
        return TaskType.delivery;
      case 'maintenance':
        return TaskType.maintenance;
      default:
        return TaskType.simpleEvidence;
    }
  }

  String get difficultyDisplayName {
    switch (difficultyLevel) {
      case DifficultyLevel.easy:
        return 'Easy';
      case DifficultyLevel.medium:
        return 'Medium';
      case DifficultyLevel.hard:
        return 'Hard';
    }
  }

  String get estimatedDurationDisplay {
    if (estimatedDuration == null) return 'No estimate';
    if (estimatedDuration! < 60) return '${estimatedDuration}min';
    final hours = (estimatedDuration! / 60).floor();
    final minutes = estimatedDuration! % 60;
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}min';
  }

  List<String> get evidenceTypeDisplayNames {
    return evidenceTypes.map((type) {
      switch (type) {
        case EvidenceType.image:
          return 'Photo';
        case EvidenceType.video:
          return 'Video';
        case EvidenceType.document:
          return 'Document';
        case EvidenceType.pdf:
          return 'PDF';
        case EvidenceType.audio:
          return 'Audio';
      }
    }).toList();
  }

  String get taskTypeDisplayName {
    switch (taskType) {
      case TaskType.simpleEvidence:
        return 'Evidence Upload';
      case TaskType.geofenceStay:
        return 'Location Stay';
      case TaskType.dataCollection:
        return 'Data Collection';
      case TaskType.inspection:
        return 'Inspection';
      case TaskType.survey:
        return 'Survey';
      case TaskType.monitoring:
        return 'Monitoring';
      case TaskType.delivery:
        return 'Delivery';
      case TaskType.maintenance:
        return 'Maintenance';
    }
  }

  String get taskTypeDescription {
    switch (taskType) {
      case TaskType.simpleEvidence:
        return 'Upload photos or documents as evidence';
      case TaskType.geofenceStay:
        return 'Stay in designated area for required duration';
      case TaskType.dataCollection:
        return 'Fill out forms and collect specific data';
      case TaskType.inspection:
        return 'Complete detailed inspection checklist';
      case TaskType.survey:
        return 'Answer survey questions and submit responses';
      case TaskType.monitoring:
        return 'Monitor and report on ongoing conditions';
      case TaskType.delivery:
        return 'Confirm delivery and obtain signatures';
      case TaskType.maintenance:
        return 'Perform maintenance and report status';
    }
  }

  bool get hasCustomFields => fields != null && fields!.isNotEmpty;
  
  bool get requiresGeofenceStay => taskType == TaskType.geofenceStay;
  
  bool get requiresFormData => [
    TaskType.dataCollection,
    TaskType.inspection,
    TaskType.survey,
    TaskType.maintenance
  ].contains(taskType);
  
  bool get requiresSignature => taskType == TaskType.delivery;
  
  int? get requiredStayDuration {
    if (taskType != TaskType.geofenceStay) return null;
    return templateConfig['required_stay_minutes'] as int?;
  }
  
  bool get allowsEarlyCompletion {
    return templateConfig['allow_early_completion'] == true;
  }

  TaskTemplate copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? description,
    int? defaultPoints,
    bool? requiresGeofence,
    int? defaultEvidenceCount,
    Map<String, dynamic>? templateConfig,
    List<EvidenceType>? evidenceTypes,
    String? customInstructions,
    int? estimatedDuration,
    DifficultyLevel? difficultyLevel,
    TaskType? taskType,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    TemplateCategory? category,
    List<TemplateField>? fields,
  }) {
    return TaskTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      defaultPoints: defaultPoints ?? this.defaultPoints,
      requiresGeofence: requiresGeofence ?? this.requiresGeofence,
      defaultEvidenceCount: defaultEvidenceCount ?? this.defaultEvidenceCount,
      templateConfig: templateConfig ?? this.templateConfig,
      evidenceTypes: evidenceTypes ?? this.evidenceTypes,
      customInstructions: customInstructions ?? this.customInstructions,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      taskType: taskType ?? this.taskType,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
      fields: fields ?? this.fields,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskTemplate && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TaskTemplate(id: $id, name: $name, category: ${category?.name})';
  }
}