// lib/models/app_user.dart

class AppUser {
  final String id;
  final String fullName;
  final String? username;
  final String? email;
  final String role;
  final String? status;
  final int? agentCreationLimit;
  final String? defaultGroupId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AppUser({
    required this.id,
    required this.fullName,
    this.username,
    this.email,
    required this.role,
    this.status,
    this.agentCreationLimit,
    this.defaultGroupId,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'No Name',
      username: json['username'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'agent',
      status: json['status'] as String? ?? 'active',
      agentCreationLimit: json['agent_creation_limit'] as int?,
      defaultGroupId: json['default_group_id'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'username': username,
      'email': email,
      'role': role,
      'status': status,
      'agent_creation_limit': agentCreationLimit,
      'default_group_id': defaultGroupId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
