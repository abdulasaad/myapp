// lib/screens/agent/earnings_screen.dart

import 'package:flutter/material.dart';
import '../../utils/constants.dart';

// A simple data class to hold the earnings info for one campaign
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

// Data class to hold the complete earnings summary
class EarningsSummary {
  final List<CampaignEarnings> campaignEarnings;
  // final int standaloneTasksTotal; // Will be replaced by standaloneTaskEarnings
  final List<StandaloneTaskEarning> standaloneTaskEarnings;

  EarningsSummary({
    required this.campaignEarnings,
    required this.standaloneTaskEarnings,
  });
}

// A simple data class to hold the earnings info for one standalone task
class StandaloneTaskEarning {
  final String taskName;
  final int balance;

  StandaloneTaskEarning({
    required this.taskName,
    required this.balance,
  });
}

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  // The future now returns our new summary object
  late Future<EarningsSummary> _earningsFuture;

  @override
  void initState() {
    super.initState();
    _earningsFuture = _fetchEarningsData();
  }

  /// Fetches earnings data for all campaigns AND standalone tasks.
  Future<EarningsSummary> _fetchEarningsData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      // Updated to reflect new EarningsSummary structure
      return EarningsSummary(campaignEarnings: [], standaloneTaskEarnings: []);
    }

    // --- Step 1: Fetch Campaign Earnings (existing logic) ---
    final agentCampaignsResponse = await supabase
        .from('campaign_agents')
        .select('campaign:campaigns(id, name)')
        .eq('agent_id', userId);

    final earningsList = <CampaignEarnings>[];
    for (final agentCampaign in agentCampaignsResponse) {
      final campaignData = agentCampaign['campaign'];
      if (campaignData == null) continue;

      final campaignId = campaignData['id'];
      final campaignName = campaignData['name'];

      final earningsResponse = await supabase.rpc(
          'get_agent_earnings_for_campaign',
          params: {'p_agent_id': userId, 'p_campaign_id': campaignId}).single();

      earningsList.add(CampaignEarnings(
        campaignName: campaignName,
        totalEarned: earningsResponse['total_earned'],
        totalPaid: earningsResponse['total_paid'],
        outstandingBalance: earningsResponse['outstanding_balance'],
      ));
    }

    // --- Step 2: Fetch details for completed standalone tasks ---
    final standaloneTasksResponse = await supabase
        .from('task_assignments')
        .select('tasks!inner(title, points)') // Fetch title and points
        .eq('agent_id', userId)
        .eq('status', 'completed')
        .isFilter(
            'tasks.campaign_id', null); // The key filter for standalone tasks

    final standaloneEarningsList = <StandaloneTaskEarning>[];
    for (final item in standaloneTasksResponse) {
      if (item['tasks'] != null &&
          item['tasks']['title'] != null &&
          item['tasks']['points'] != null) {
        standaloneEarningsList.add(StandaloneTaskEarning(
          taskName: item['tasks']['title'] as String,
          balance: item['tasks']['points'] as int,
        ));
      }
    }

    // --- Step 3: Return the complete summary object ---
    return EarningsSummary(
      campaignEarnings: earningsList,
      standaloneTaskEarnings: standaloneEarningsList, // Use the new list
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Earnings')),
      body: FutureBuilder<EarningsSummary>(
        future: _earningsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return preloader;
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error fetching earnings: ${snapshot.error}'));
          }
          if (!snapshot.hasData || (snapshot.data!.campaignEarnings.isEmpty && snapshot.data!.standaloneTaskEarnings.isEmpty)) {
            return const Center(child: Text('No earnings data found.'));
          }

          final summary = snapshot.data!;
          final campaignEarnings = summary.campaignEarnings;

          // Calculate overall totals including both campaigns and standalone tasks
          final campaignTotal = campaignEarnings.fold<int>(
              0, (sum, item) => sum + item.totalEarned);
          // Calculate total from standalone tasks
          final standaloneTasksTotal = summary.standaloneTaskEarnings.fold<int>(0, (sum, item) => sum + item.balance);
          final overallTotal = campaignTotal + standaloneTasksTotal;
          // Assuming standalone tasks also contribute to outstanding balance directly
          final campaignOutstanding = campaignEarnings.fold<int>(0, (sum, item) => sum + item.outstandingBalance);
          final overallOutstanding = campaignOutstanding + standaloneTasksTotal; // Add standalone task balances to outstanding

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _earningsFuture = _fetchEarningsData();
              });
            },
            child: Column(
              children: [
                // Summary Cards
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      _buildSummaryCard(context, 'Total Earned',
                          overallTotal.toString(), Colors.blue),
                      formSpacerHorizontal,
                      _buildSummaryCard(context, 'Outstanding Balance',
                          overallOutstanding.toString(), Colors.green),
                    ],
                  ),
                ),
                const Divider(),
                // List of earnings
                Expanded(
                  child: ListView(
                    children: [
                      // List of earnings per campaign
                      ...campaignEarnings.map((earning) => Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(earning.campaignName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall),
                                  const SizedBox(height: 12),
                                  _buildEarningRow('Total for Campaign:',
                                      earning.totalEarned.toString()),
                                  _buildEarningRow('Already Paid:',
                                      earning.totalPaid.toString()),
                                  const Divider(height: 20),
                                  _buildEarningRow('Balance for Campaign:',
                                      earning.outstandingBalance.toString(),
                                      isBold: true),
                                ],
                              ),
                            ),
                          )),
                      // Display each standalone task as a card
                      if (summary.standaloneTaskEarnings.isNotEmpty)
                        ...summary.standaloneTaskEarnings.map((taskEarning) => Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(taskEarning.taskName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge), // Using titleLarge for task name
                                    const SizedBox(height: 8),
                                    _buildEarningRow(
                                        'Balance for Task:',
                                        taskEarning.balance.toString(),
                                        isBold: true),
                                  ],
                                ),
                              ),
                            )),
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

  Widget _buildSummaryCard(
      BuildContext context, String title, String value, Color color) {
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
