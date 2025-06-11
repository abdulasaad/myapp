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

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  late Future<List<CampaignEarnings>> _earningsFuture;

  @override
  void initState() {
    super.initState();
    _earningsFuture = _fetchEarningsData();
  }

  /// Fetches earnings data for all campaigns the agent is assigned to.
  Future<List<CampaignEarnings>> _fetchEarningsData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // 1. Get all campaign IDs the agent is assigned to
    final agentCampaignsResponse = await supabase
        .from('campaign_agents')
        .select('campaign:campaigns(id, name)') // Join to get campaign name
        .eq('agent_id', userId);

    final earningsList = <CampaignEarnings>[];

    // 2. For each campaign, call our RPC function to get the earnings
    for (final agentCampaign in agentCampaignsResponse) {
      final campaignData = agentCampaign['campaign'];
      if (campaignData == null) continue;

      final campaignId = campaignData['id'];
      final campaignName = campaignData['name'];

      final earningsResponse = await supabase.rpc(
        'get_agent_earnings_for_campaign',
        params: {'p_agent_id': userId, 'p_campaign_id': campaignId}
      ).single();

      earningsList.add(CampaignEarnings(
        campaignName: campaignName,
        totalEarned: earningsResponse['total_earned'],
        totalPaid: earningsResponse['total_paid'],
        outstandingBalance: earningsResponse['outstanding_balance'],
      ));
    }
    
    return earningsList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Earnings')),
      body: FutureBuilder<List<CampaignEarnings>>(
        future: _earningsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return preloader;
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error fetching earnings: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No earnings data found.'));
          }

          final allEarnings = snapshot.data!;
          // Calculate overall totals for the summary cards
          final overallTotal = allEarnings.fold<int>(0, (sum, item) => sum + item.totalEarned);
          final overallOutstanding = allEarnings.fold<int>(0, (sum, item) => sum + item.outstandingBalance);

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
                      _buildSummaryCard(context, 'Total Earned', overallTotal.toString(), Colors.blue),
                      formSpacerHorizontal,
                      _buildSummaryCard(context, 'Outstanding Balance', overallOutstanding.toString(), Colors.green),
                    ],
                  ),
                ),
                const Divider(),
                // List of earnings per campaign
                Expanded(
                  child: ListView.builder(
                    itemCount: allEarnings.length,
                    itemBuilder: (context, index) {
                      final earning = allEarnings[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(earning.campaignName, style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 12),
                              _buildEarningRow('Total for Campaign:', earning.totalEarned.toString()),
                              _buildEarningRow('Already Paid:', earning.totalPaid.toString()),
                              const Divider(height: 20),
                              _buildEarningRow('Balance for Campaign:', earning.outstandingBalance.toString(), isBold: true),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
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
              Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
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
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}