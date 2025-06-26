// lib/models/group.dart

class Group {
  final String id;
  final String name;
  final String? description;
  final String? createdBy; // User ID of the creator
  final DateTime createdAt;
  final DateTime updatedAt;
  // You might want to add a list of members here if you fetch them together,
  // or handle members separately. For now, keeping it simple.

  Group({
    required this.id,
    required this.name,
    this.description,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed Group',
      description: json['description'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
