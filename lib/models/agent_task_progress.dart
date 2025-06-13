// lib/models/agent_task_progress.dart

class AgentTaskProgress {
  final String agentId;
  final String agentName;
  final String assignmentStatus;
  final int evidenceRequired;
  final int evidenceUploaded;
  final int pointsTotal;
  final int pointsPaid;
  final int outstandingBalance;

  AgentTaskProgress({
    required this.agentId,
    required this.agentName,
    required this.assignmentStatus,
    required this.evidenceRequired,
    required this.evidenceUploaded,
    required this.pointsTotal,
    required this.pointsPaid,
    required this.outstandingBalance,
  });

  factory AgentTaskProgress.fromJson(Map<String, dynamic> json, String agentId) {
    return AgentTaskProgress(
      agentId: agentId, // Pass agentId separately as it's not in the RPC direct output but needed
      agentName: json['agent_name'] as String? ?? 'Unknown Agent',
      assignmentStatus: json['assignment_status'] as String? ?? 'unknown',
      evidenceRequired: json['evidence_required'] as int? ?? 0,
      evidenceUploaded: json['evidence_uploaded'] as int? ?? 0,
      pointsTotal: json['points_total'] as int? ?? 0,
      pointsPaid: json['points_paid'] as int? ?? 0,
      outstandingBalance: json['outstanding_balance'] as int? ?? 0,
    );
  }

  // Helper to calculate progress, ensuring no division by zero
  double get progressPercentage {
    if (evidenceRequired <= 0) {
      return 0.0; // Or 1.0 if 0 required means complete
    }
    return evidenceUploaded / evidenceRequired;
  }
}
