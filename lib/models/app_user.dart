// lib/models/app_user.dart

class AppUser {
  final String id;
  final String fullName;
  final String? username;
  final String role;
  final String status;
  final int agentCreationLimit;

  AppUser({
    required this.id,
    required this.fullName,
    this.username,
    required this.role,
    required this.status,
    required this.agentCreationLimit,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      fullName: json['full_name'] ?? 'No Name',
      username: json['username'],
      role: json['role'] ?? 'agent',
      status: json['status'] ?? 'active',
      agentCreationLimit: json['agent_creation_limit'] ?? 0,
    );
  }
}
