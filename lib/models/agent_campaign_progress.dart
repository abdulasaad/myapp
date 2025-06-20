// lib/models/agent_campaign_progress.dart

// Re-using the EvidenceFile model which is still perfect
class EvidenceFile {
  final String id;
  final String title;
  final String fileUrl;
  final DateTime createdAt;
  final String taskTitle;

  EvidenceFile({
    required this.id,
    required this.title,
    required this.fileUrl,
    required this.createdAt,
    required this.taskTitle,
  });

  factory EvidenceFile.fromJson(Map<String, dynamic> json) {
    return EvidenceFile(
      id: json['id'] as String,
      title: json['title'] as String,
      fileUrl: json['file_url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      taskTitle: json['task_title'] as String,
    );
  }
}

// New model for the individual tasks in the progress list
class ProgressTaskItem {
  final String id;
  final String title;
  final String? description;
  final int points;
  final String status;
  final int evidenceRequired;
  final int evidenceUploaded;

  ProgressTaskItem({
    required this.id,
    required this.title,
    this.description,
    required this.points,
    required this.status,
    required this.evidenceRequired,
    required this.evidenceUploaded,
  });

  factory ProgressTaskItem.fromJson(Map<String, dynamic> json) {
    return ProgressTaskItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      points: json['points'] as int? ?? 0,
      status: json['status'] as String,
      evidenceRequired: json['evidence_required'] as int? ?? 0,
      evidenceUploaded: json['evidence_uploaded'] as int? ?? 0,
    );
  }
}

// The main data model for the entire screen
class AgentCampaignDetails {
  final int totalPoints;
  final int pointsPaid;
  final int outstandingBalance;
  final List<ProgressTaskItem> tasks;
  final List<EvidenceFile> files;

  AgentCampaignDetails({
    required this.totalPoints,
    required this.pointsPaid,
    required this.outstandingBalance,
    required this.tasks,
    required this.files,
  });

  factory AgentCampaignDetails.fromJson(Map<String, dynamic> json) {
    final earnings = json['earnings'] as Map<String, dynamic>;
    final total = earnings['total_points'] as int? ?? 0;
    final paid = earnings['paid_points'] as int? ?? 0;

    return AgentCampaignDetails(
      totalPoints: total,
      pointsPaid: paid,
      outstandingBalance: total - paid,
      tasks: (json['tasks'] as List)
          .map((t) => ProgressTaskItem.fromJson(t as Map<String, dynamic>))
          .toList(),
      files: (json['files'] as List)
          .map((f) => EvidenceFile.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
}