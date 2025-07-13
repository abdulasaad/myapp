// lib/screens/agent/earnings_screen.dart

import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';

// --- DATA MODELS ---

// Model for campaign-specific earnings, remains unchanged.
class CampaignEarnings {
  final String campaignName;
  final int totalEarned;
  final int totalPaid;
  final int outstandingBalance;

  CampaignEarnings({
    required this.campaignName,
    required this.totalEarned,
    required this.totalPaid,
    required this.outstandingBalance,
  });
}

// ===================================================================
// NEW: A model to hold the detailed earnings for a single standalone task.
// ===================================================================
class StandaloneTaskEarning {
  final String taskName;
  final int pointsEarned;
  final int pointsPaid;
  final int outstandingBalance;

  StandaloneTaskEarning({
    required this.taskName,
    required this.pointsEarned,
    required this.pointsPaid,
    required this.outstandingBalance,
  });
}


// The summary now holds two lists: one for campaigns and one for tasks.
class EarningsSummary {
  final List<CampaignEarnings> campaignEarnings;
  final List<StandaloneTaskEarning> standaloneTaskEarnings;

  EarningsSummary({
    required this.campaignEarnings,
    required this.standaloneTaskEarnings,
  });
}

// --- MAIN WIDGET ---

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  late Future<EarningsSummary> _earningsFuture;

  @override
  void initState() {
    super.initState();
    _earningsFuture = _fetchEarningsData();
  }

  // ===================================================================
  // THE FIX: This function is overhauled to fetch and calculate balances
  // for each standalone task individually.
  // ===================================================================
  Future<EarningsSummary> _fetchEarningsData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return EarningsSummary(campaignEarnings: [], standaloneTaskEarnings: []);
    }

    // --- Step 1: Fetch Campaign Earnings (logic is unchanged) ---
    final agentCampaignsResponse = await supabase
        .from('campaign_agents')
        .select('campaign:campaigns(id, name)')
        .eq('agent_id', userId);

    final campaignEarningsList = <CampaignEarnings>[];
    for (final agentCampaign in agentCampaignsResponse) {
      final campaignData = agentCampaign['campaign'];
      if (campaignData == null) continue;

      final campaignId = campaignData['id'];
      final campaignName = campaignData['name'];

      final earningsResponse = await supabase.rpc('get_agent_earnings_for_campaign',
          params: {'p_agent_id': userId, 'p_campaign_id': campaignId}).single();

      campaignEarningsList.add(CampaignEarnings(
        campaignName: campaignName,
        totalEarned: earningsResponse['total_earned'],
        totalPaid: earningsResponse['total_paid'],
        outstandingBalance: earningsResponse['outstanding_balance'],
      ));
    }

    // --- Step 2: Fetch Completed Standalone Tasks ---
    final standaloneTasksResponse = await supabase
        .from('task_assignments')
        .select('tasks!inner(id, title, points)')
        .eq('agent_id', userId)
        .eq('status', 'completed')
        .isFilter('tasks.campaign_id', null);

    final standaloneEarningsList = <StandaloneTaskEarning>[];
    for (final item in standaloneTasksResponse) {
      final taskData = item['tasks'];
      if (taskData == null) continue;

      final taskId = taskData['id'] as String;
      final taskName = taskData['title'] as String;
      final pointsEarned = taskData['points'] as int;

      // --- Step 3: For each task, find its specific payments ---
      final paymentsResponse = await supabase
          .from('payments')
          .select('amount')
          .eq('agent_id', userId)
          .eq('task_id', taskId);
      
      final pointsPaid = paymentsResponse.fold<int>(0, (sum, payment) => sum + (payment['amount'] as int));
      final outstandingBalance = pointsEarned - pointsPaid;
      
      standaloneEarningsList.add(StandaloneTaskEarning(
        taskName: taskName,
        pointsEarned: pointsEarned,
        pointsPaid: pointsPaid,
        outstandingBalance: outstandingBalance,
      ));
    }

    // --- Step 4: Return the complete summary ---
    return EarningsSummary(
      campaignEarnings: campaignEarningsList,
      standaloneTaskEarnings: standaloneEarningsList,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.myEarnings)),
      body: FutureBuilder<EarningsSummary>(
        future: _earningsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return preloader;
          }
          if (snapshot.hasError) {
            return Center(child: Text(AppLocalizations.of(context)!.errorFetchingEarnings(snapshot.error.toString())));
          }
          
          final summary = snapshot.data;
          if (summary == null || (summary.campaignEarnings.isEmpty && summary.standaloneTaskEarnings.isEmpty)) {
            return Center(child: Text(AppLocalizations.of(context)!.noEarningsDataFound));
          }

          // Calculate overall totals from both lists
          final totalCampaignEarned = summary.campaignEarnings.fold<int>(0, (sum, e) => sum + e.totalEarned);
          final totalTaskEarned = summary.standaloneTaskEarnings.fold<int>(0, (sum, e) => sum + e.pointsEarned);
          final overallTotal = totalCampaignEarned + totalTaskEarned;
          
          final totalCampaignOutstanding = summary.campaignEarnings.fold<int>(0, (sum, e) => sum + e.outstandingBalance);
          final totalTaskOutstanding = summary.standaloneTaskEarnings.fold<int>(0, (sum, e) => sum + e.outstandingBalance);
          final overallOutstanding = totalCampaignOutstanding + totalTaskOutstanding;


          return RefreshIndicator(
            onRefresh: () async => setState(() => _earningsFuture = _fetchEarningsData()),
            child: Column(
              children: [
                // Summary Cards
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      _buildSummaryCard(context, AppLocalizations.of(context)!.totalEarned, overallTotal.toString(), Colors.blue),
                      formSpacerHorizontal,
                      _buildSummaryCard(context, AppLocalizations.of(context)!.outstandingBalance, overallOutstanding.toString(), Colors.green),
                    ],
                  ),
                ),
                const Divider(),
                // ===================================================================
                // THE FIX: Use a single unified ListView for all earnings.
                // ===================================================================
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      // List of earnings per campaign
                      ...summary.campaignEarnings.map((earning) =>
                        _buildCampaignEarningCard(context, earning)
                      ),
                      // List of earnings per standalone task
                      ...summary.standaloneTaskEarnings.map((earning) =>
                        _buildTaskEarningCard(context, earning)
                      )
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildCampaignEarningCard(BuildContext context, CampaignEarnings earning) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(earning.campaignName, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _buildEarningRow(AppLocalizations.of(context)!.totalForCampaign, earning.totalEarned.toString()),
            _buildEarningRow(AppLocalizations.of(context)!.alreadyPaid, earning.totalPaid.toString()),
            const Divider(height: 20),
            _buildEarningRow(AppLocalizations.of(context)!.balanceForCampaign, earning.outstandingBalance.toString(), isBold: true),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // NEW: A dedicated card widget for displaying individual task earnings.
  // ===================================================================
  Widget _buildTaskEarningCard(BuildContext context, StandaloneTaskEarning earning) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(earning.taskName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildEarningRow(AppLocalizations.of(context)!.pointsEarned, earning.pointsEarned.toString()),
            _buildEarningRow(AppLocalizations.of(context)!.pointsPaid, earning.pointsPaid.toString()),
             const Divider(height: 20),
            _buildEarningRow(AppLocalizations.of(context)!.outstandingBalance, earning.outstandingBalance.toString(), isBold: true),
          ],
        ),
      ),
    );
  }


  Widget _buildSummaryCard(BuildContext context, String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: color.withAlpha(50),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarningRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
