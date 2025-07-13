// lib/screens/reporting/campaign_report_screen.dart

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/constants.dart';

class CampaignReport {
  final int totalTasks;
  final int completedTasks;
  final int totalPointsEarned;
  final int assignedAgents;
  double get completionPercentage => totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

  CampaignReport({
    required this.totalTasks,
    required this.completedTasks,
    required this.totalPointsEarned,
    required this.assignedAgents,
  });

  factory CampaignReport.fromJson(Map<String, dynamic> json) {
    return CampaignReport(
      totalTasks: json['total_tasks'] ?? 0,
      completedTasks: json['completed_tasks'] ?? 0,
      totalPointsEarned: json['total_points_earned'] ?? 0,
      assignedAgents: json['assigned_agents'] ?? 0,
    );
  }
}

class CampaignReportScreen extends StatefulWidget {
  final String campaignId;
  const CampaignReportScreen({super.key, required this.campaignId});

  @override
  State<CampaignReportScreen> createState() => _CampaignReportScreenState();
}

class _CampaignReportScreenState extends State<CampaignReportScreen> {
  late Future<CampaignReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _fetchReportData();
  }

  Future<CampaignReport> _fetchReportData() async {
    try {
      final response = await supabase.rpc('get_campaign_report_data', params: {'p_campaign_id': widget.campaignId}).single();
      return CampaignReport.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load report data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.campaignReport)),
      body: FutureBuilder<CampaignReport>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return preloader;
          }
          if (snapshot.hasError) {
            return Center(child: Text('${AppLocalizations.of(context)!.error}: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return Center(child: Text(AppLocalizations.of(context)!.noReportDataAvailable));
          }

          final report = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(AppLocalizations.of(context)!.campaignProgress, style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 20),
                        LinearProgressIndicator(
                          value: report.completionPercentage,
                          minHeight: 12,
                          borderRadius: BorderRadius.circular(6),
                          backgroundColor: Colors.grey[700],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                        const SizedBox(height: 12),
                        Text('${report.completedTasks} / ${report.totalTasks} ${AppLocalizations.of(context)!.tasksCompleted}', style: Theme.of(context).textTheme.titleLarge),
                        Text('(${(report.completionPercentage * 100).toStringAsFixed(0)}%)', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[400])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _buildMetricCard(icon: Icons.assignment_turned_in_outlined, label: AppLocalizations.of(context)!.totalPointsEarned, value: report.totalPointsEarned.toString(), color: Colors.blue),
                    _buildMetricCard(icon: Icons.people_alt_outlined, label: AppLocalizations.of(context)!.assignedAgents, value: report.assignedAgents.toString(), color: Colors.teal),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({required IconData icon, required String label, required String value, required Color color}) {
    return Card(
      color: color.withAlpha(40),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}