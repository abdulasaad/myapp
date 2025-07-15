// lib/screens/admin/agents_earnings_management_screen.dart

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';
import 'agent_earnings_detail_screen.dart';

class AgentsEarningsManagementScreen extends StatefulWidget {
  const AgentsEarningsManagementScreen({super.key});

  @override
  State<AgentsEarningsManagementScreen> createState() => _AgentsEarningsManagementScreenState();
}

class _AgentsEarningsManagementScreenState extends State<AgentsEarningsManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _agentsData = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAgentsData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAgentsData() async {
    setState(() => _isLoading = true);
    
    try {
      // Fetch all agents (users with role agent)
      final agentsResponse = await supabase
          .from('profiles')
          .select('id, full_name, email, role')
          .eq('role', 'agent')
          .order('full_name');

      List<Map<String, dynamic>> agentsWithEarnings = [];

      for (final agent in agentsResponse) {
        // Calculate earnings for each agent
        final earnings = await _calculateAgentEarnings(agent['id']);
        agentsWithEarnings.add({
          'agent': AppUser.fromJson(agent),
          'earnings': earnings,
        });
      }

      if (mounted) {
        setState(() {
          _agentsData = agentsWithEarnings;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching agents data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _calculateAgentEarnings(String agentId) async {
    try {
      // Fetch completed tasks for this agent
      final tasksResponse = await supabase
          .from('task_assignments')
          .select('''
            tasks!inner (
              points
            )
          ''')
          .eq('agent_id', agentId)
          .eq('status', 'completed');

      // Fetch payments for this agent
      final paymentsResponse = await supabase
          .from('payments')
          .select('amount')
          .eq('agent_id', agentId);

      // Calculate totals
      int totalEarned = 0;
      int totalPaid = 0;
      int taskCount = 0;

      // Sum up earnings from tasks
      for (final task in tasksResponse) {
        totalEarned += (task['tasks']['points'] as int? ?? 0);
        taskCount++;
      }

      // Sum up payments
      for (final payment in paymentsResponse) {
        totalPaid += (payment['amount'] as int? ?? 0);
      }

      return {
        'total_earned': totalEarned,
        'total_paid': totalPaid,
        'remaining_points': totalEarned - totalPaid,
        'completed_tasks': taskCount,
      };
    } catch (e) {
      debugPrint('Error calculating earnings for agent $agentId: $e');
      return {
        'total_earned': 0,
        'total_paid': 0,
        'remaining_points': 0,
        'completed_tasks': 0,
      };
    }
  }

  List<Map<String, dynamic>> get _filteredAgents {
    if (_searchQuery.isEmpty) return _agentsData;
    
    return _agentsData.where((agentData) {
      final agent = agentData['agent'] as AppUser;
      return agent.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (agent.email?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.agentsEarningsManagement),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAgentsData,
            tooltip: AppLocalizations.of(context)!.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: primaryColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (query) {
                setState(() => _searchQuery = query);
              },
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchAgents,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAgents.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchAgentsData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredAgents.length,
                          itemBuilder: (context, index) {
                            return _buildAgentCard(_filteredAgents[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(Map<String, dynamic> agentData) {
    final AppUser agent = agentData['agent'];
    final Map<String, dynamic> earnings = agentData['earnings'];

    final totalEarned = earnings['total_earned'] as int;
    final totalPaid = earnings['total_paid'] as int;
    final remainingPoints = earnings['remaining_points'] as int;
    final completedTasks = earnings['completed_tasks'] as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => AgentEarningsDetailScreen(
              agent: agent,
            ),
          ));
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Agent info row
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      agent.fullName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          agent.fullName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          agent.email ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: textSecondaryColor,
                    size: 16,
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Earnings summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildEarningsStat(
                            label: AppLocalizations.of(context)!.totalEarned,
                            value: totalEarned.toString(),
                            icon: Icons.trending_up,
                            color: successColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildEarningsStat(
                            label: AppLocalizations.of(context)!.amountPaid,
                            value: totalPaid.toString(),
                            icon: Icons.payment,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEarningsStat(
                            label: AppLocalizations.of(context)!.remainingPoints,
                            value: remainingPoints.toString(),
                            icon: Icons.account_balance_wallet,
                            color: remainingPoints > 0 ? warningColor : successColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildEarningsStat(
                            label: AppLocalizations.of(context)!.completedTasks,
                            value: completedTasks.toString(),
                            icon: Icons.assignment_turned_in,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label.contains('Tasks')
              ? value
              : '$value ${AppLocalizations.of(context)!.points}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? AppLocalizations.of(context)!.noAgentsFound
                  : AppLocalizations.of(context)!.noAgentsMatchSearch,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? AppLocalizations.of(context)!.noAgentsFoundDesc
                  : AppLocalizations.of(context)!.tryDifferentSearch,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}