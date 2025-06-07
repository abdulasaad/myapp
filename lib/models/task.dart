// lib/models/task.dart

class Task {
  final String id;
  final String campaignId;
  final String title;
  final String? description;
  final int points;
  final String status;

  Task({
    required this.id,
    required this.campaignId,
    required this.title,
    this.description,
    required this.points,
    required this.status,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      campaignId: json['campaign_id'],
      title: json['title'],
      description: json['description'],
      points: json['points'] ?? 0,
      status: json['status'],
    );
  }
}
