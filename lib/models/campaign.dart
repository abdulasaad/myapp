// lib/models/campaign.dart

class Campaign {
  final String id;
  final DateTime createdAt;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String packageType;
  final String? clientId;
  final String? assignedManagerId;

  Campaign({
    required this.id,
    required this.createdAt,
    required this.name,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.packageType,
    this.clientId,
    this.assignedManagerId,
  });

  // Factory constructor to create a Campaign from a JSON object (Map)
  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      name: json['name'],
      description: json['description'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      status: json['status'],
      packageType: json['package_type'],
      clientId: json['client_id'],
      assignedManagerId: json['assigned_manager_id'],
    );
  }
}
