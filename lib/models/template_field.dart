// lib/models/template_field.dart

enum TemplateFieldType {
  text,
  number,
  date,
  boolean,
  select,
  multiselect,
  textarea,
  email,
  phone,
}

class TemplateField {
  final String id;
  final String templateId;
  final String fieldName;
  final TemplateFieldType fieldType;
  final String fieldLabel;
  final String? placeholderText;
  final bool isRequired;
  final List<String>? fieldOptions; // For select/multiselect types
  final Map<String, dynamic> validationRules;
  final int sortOrder;
  final String? helpText;
  final DateTime createdAt;

  TemplateField({
    required this.id,
    required this.templateId,
    required this.fieldName,
    required this.fieldType,
    required this.fieldLabel,
    this.placeholderText,
    required this.isRequired,
    this.fieldOptions,
    required this.validationRules,
    required this.sortOrder,
    this.helpText,
    required this.createdAt,
  });

  factory TemplateField.fromJson(Map<String, dynamic> json) {
    return TemplateField(
      id: json['id'],
      templateId: json['template_id'],
      fieldName: json['field_name'],
      fieldType: _parseFieldType(json['field_type']),
      fieldLabel: json['field_label'],
      placeholderText: json['placeholder_text'],
      isRequired: json['is_required'] ?? false,
      fieldOptions: json['field_options'] != null 
          ? List<String>.from(json['field_options'])
          : null,
      validationRules: json['validation_rules'] != null 
          ? Map<String, dynamic>.from(json['validation_rules'])
          : {},
      sortOrder: json['sort_order'] ?? 0,
      helpText: json['help_text'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      'created_at': createdAt.toIso8601String(),
    };
  }

  static TemplateFieldType _parseFieldType(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return TemplateFieldType.text;
      case 'number':
        return TemplateFieldType.number;
      case 'date':
        return TemplateFieldType.date;
      case 'boolean':
        return TemplateFieldType.boolean;
      case 'select':
        return TemplateFieldType.select;
      case 'multiselect':
        return TemplateFieldType.multiselect;
      case 'textarea':
        return TemplateFieldType.textarea;
      case 'email':
        return TemplateFieldType.email;
      case 'phone':
        return TemplateFieldType.phone;
      default:
        return TemplateFieldType.text;
    }
  }

  bool get isSelectType => fieldType == TemplateFieldType.select || fieldType == TemplateFieldType.multiselect;
  bool get isTextType => fieldType == TemplateFieldType.text || fieldType == TemplateFieldType.textarea;
  bool get isNumericType => fieldType == TemplateFieldType.number;
  bool get isDateType => fieldType == TemplateFieldType.date;
  bool get isBooleanType => fieldType == TemplateFieldType.boolean;

  String get fieldTypeDisplayName {
    switch (fieldType) {
      case TemplateFieldType.text:
        return 'Text';
      case TemplateFieldType.number:
        return 'Number';
      case TemplateFieldType.date:
        return 'Date';
      case TemplateFieldType.boolean:
        return 'Yes/No';
      case TemplateFieldType.select:
        return 'Single Choice';
      case TemplateFieldType.multiselect:
        return 'Multiple Choice';
      case TemplateFieldType.textarea:
        return 'Long Text';
      case TemplateFieldType.email:
        return 'Email';
      case TemplateFieldType.phone:
        return 'Phone';
    }
  }

  TemplateField copyWith({
    String? id,
    String? templateId,
    String? fieldName,
    TemplateFieldType? fieldType,
    String? fieldLabel,
    String? placeholderText,
    bool? isRequired,
    List<String>? fieldOptions,
    Map<String, dynamic>? validationRules,
    int? sortOrder,
    String? helpText,
    DateTime? createdAt,
  }) {
    return TemplateField(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      fieldName: fieldName ?? this.fieldName,
      fieldType: fieldType ?? this.fieldType,
      fieldLabel: fieldLabel ?? this.fieldLabel,
      placeholderText: placeholderText ?? this.placeholderText,
      isRequired: isRequired ?? this.isRequired,
      fieldOptions: fieldOptions ?? this.fieldOptions,
      validationRules: validationRules ?? this.validationRules,
      sortOrder: sortOrder ?? this.sortOrder,
      helpText: helpText ?? this.helpText,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TemplateField && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TemplateField(id: $id, fieldName: $fieldName, fieldType: $fieldType)';
  }
}