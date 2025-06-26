// lib/models/task_with_template.dart

import 'task.dart';
import 'task_template.dart';

class TaskWithTemplate {
  final Task task;
  final TaskTemplate? template;
  final Map<String, dynamic> customFieldValues;

  TaskWithTemplate({
    required this.task,
    this.template,
    Map<String, dynamic>? customFieldValues,
  }) : customFieldValues = customFieldValues ?? {};

  factory TaskWithTemplate.fromTask(Task task) {
    return TaskWithTemplate(
      task: task,
      customFieldValues: task.customFields ?? {},
    );
  }

  factory TaskWithTemplate.fromJson(Map<String, dynamic> json) {
    return TaskWithTemplate(
      task: Task.fromJson(json),
      template: json['task_templates'] != null 
          ? TaskTemplate.fromJson(json['task_templates'])
          : null,
      customFieldValues: json['custom_fields'] != null 
          ? Map<String, dynamic>.from(json['custom_fields'])
          : {},
    );
  }

  bool get isFromTemplate => task.templateId != null;
  bool get hasTemplate => template != null;
  bool get hasCustomFields => customFieldValues.isNotEmpty;

  String get templateName => template?.name ?? 'Custom Task';
  String get categoryName => template?.category?.name ?? 'General';

  T? getCustomFieldValue<T>(String fieldName) {
    final value = customFieldValues[fieldName];
    if (value is T) return value;
    return null;
  }

  void setCustomFieldValue(String fieldName, dynamic value) {
    customFieldValues[fieldName] = value;
  }

  TaskWithTemplate copyWith({
    Task? task,
    TaskTemplate? template,
    Map<String, dynamic>? customFieldValues,
  }) {
    return TaskWithTemplate(
      task: task ?? this.task,
      template: template ?? this.template,
      customFieldValues: customFieldValues ?? this.customFieldValues,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskWithTemplate && other.task.id == task.id;
  }

  @override
  int get hashCode => task.id.hashCode;

  @override
  String toString() {
    return 'TaskWithTemplate(task: ${task.title}, template: ${template?.name})';
  }
}