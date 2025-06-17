// lib/models/app_user.dart

class AppUser {
  final String id;
  final String fullName;
  final String? username;
  final String role;
  final String status;
  final int agentCreationLimit;
  final String? defaultGroupId; 

  AppUser({
    required this.id,
    required this.fullName,
    this.username,
    required this.role,
    required this.status,
    required this.agentCreationLimit,
    this.defaultGroupId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'No Name',
      username: json['username'] as String?,
      role: json['role'] as String? ?? 'agent',
      status: json['status'] as String? ?? 'active',
      agentCreationLimit: json['agent_creation_limit'] as int? ?? 0,
      defaultGroupId: json['default_group_id'] as String?, // Added this line
    );
  }

  // toJson might be needed if you update AppUser instances, though often not for read-only models
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'username': username,
      'role': role,
      'status': status,
      'agent_creation_limit': agentCreationLimit,
      'default_group_id': defaultGroupId, // Added this line
    };
  }
}
