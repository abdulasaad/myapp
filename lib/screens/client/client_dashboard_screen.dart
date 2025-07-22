// lib/screens/client/client_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/constants.dart';
import '../../models/campaign.dart';
import '../map/live_map_screen.dart';
import '../campaigns/campaign_detail_screen.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  ClientDashboardData? _dashboardData;
  bool _hasError = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    
    try {
      setState(() {
        _hasError = false;
        _isLoading = true;
      });

      final data = await _loadClientDashboardData();
      
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
      debugPrint('Error loading client dashboard data: $e');
    }
  }

  Future<ClientDashboardData> _loadClientDashboardData() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Debug: Test client access
      debugPrint('🔍 CLIENT DEBUG: Testing client access...');
      debugPrint('🔍 CLIENT DEBUG: Current user ID: ${currentUser.id}');
      try {
        final testResult = await supabase.rpc('test_client_access');
        debugPrint('🔍 CLIENT DEBUG: Access test results:');
        for (final row in testResult) {
          debugPrint('  ${row['test_name']}: ${row['result']}');
        }
      } catch (e) {
        debugPrint('❌ CLIENT DEBUG: Error running test_client_access: $e');
      }

      // Load client's campaigns
      debugPrint('🔍 CLIENT DEBUG: Loading campaigns for client ID: ${currentUser.id}');
      final campaignsResponse = await supabase
          .from('campaigns')
          .select('*')
          .eq('client_id', currentUser.id)
          .order('created_at', ascending: false);

      debugPrint('🔍 CLIENT DEBUG: Campaigns response: ${campaignsResponse.length} campaigns found');
      
      final campaigns = (campaignsResponse as List)
          .map((json) => Campaign.fromJson(json))
          .toList();
      
      debugPrint('🔍 CLIENT DEBUG: Parsed ${campaigns.length} campaigns');

      // Get campaign stats
      final stats = await _getCampaignStats(campaigns);
      
      // Get recent activity
      final recentActivity = await _getRecentActivity(campaigns);

      return ClientDashboardData(
        campaigns: campaigns,
        totalCampaigns: campaigns.length,
        activeCampaigns: campaigns.where((c) => c.status == 'active').length,
        completedCampaigns: campaigns.where((c) => c.status == 'completed').length,
        totalTasks: stats['totalTasks'] ?? 0,
        completedTasks: stats['completedTasks'] ?? 0,
        activeAgents: stats['activeAgents'] ?? 0,
        recentActivity: recentActivity,
      );
    } catch (e) {
      debugPrint('Error loading client dashboard: $e');
      rethrow;
    }
  }

  Future<Map<String, int>> _getCampaignStats(List<Campaign> campaigns) async {
    try {
      if (campaigns.isEmpty) {
        return {'totalTasks': 0, 'completedTasks': 0, 'activeAgents': 0};
      }

      final campaignIds = campaigns.map((c) => c.id).toList();
      
      // Get tasks for these campaigns
      final tasksResponse = await supabase
          .from('tasks')
          .select('id, status')
          .inFilter('campaign_id', campaignIds);

      final totalTasks = tasksResponse.length;
      final completedTasks = tasksResponse
          .where((task) => task['status'] == 'completed')
          .length;

      // Get active agents for these campaigns
      final agentsResponse = await supabase
          .from('task_assignments')
          .select('agent_id')
          .inFilter('task_id', tasksResponse.map((t) => t['id']).toList());

      final uniqueAgents = agentsResponse
          .map((assignment) => assignment['agent_id'])
          .toSet()
          .length;

      return {
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
        'activeAgents': uniqueAgents,
      };
    } catch (e) {
      debugPrint('Error getting campaign stats: $e');
      return {'totalTasks': 0, 'completedTasks': 0, 'activeAgents': 0};
    }
  }

  Future<List<ClientActivityItem>> _getRecentActivity(List<Campaign> campaigns) async {
    try {
      if (campaigns.isEmpty) return [];

      final campaignIds = campaigns.map((c) => c.id).toList();
      
      // Get recent task completions
      final tasksResponse = await supabase
          .from('tasks')
          .select('id, title, status, created_at, campaign_id')
          .inFilter('campaign_id', campaignIds)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(10);

      return tasksResponse.map((task) {
        final campaign = campaigns.firstWhere((c) => c.id == task['campaign_id']);
        return ClientActivityItem(
          type: 'task_completed',
          description: 'Task "${task['title']}" completed in ${campaign.name}',
          timestamp: DateTime.parse(task['created_at']),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting recent activity: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Client Dashboard'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildErrorWidget()
              : _dashboardData == null
                  ? const Center(child: Text('No data available'))
                  : _buildDashboardContent(context, l10n),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Error loading dashboard'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDashboardData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, AppLocalizations l10n) {
    final data = _dashboardData!;

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Cards
            _buildStatsSection(context, data),
            const SizedBox(height: 24),
            
            // Quick Actions
            _buildQuickActionsSection(context, l10n),
            const SizedBox(height: 24),
            
            // Campaigns List
            _buildCampaignsSection(context, data, l10n),
            const SizedBox(height: 24),
            
            // Recent Activity
            _buildRecentActivitySection(context, data, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, ClientDashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Campaigns',
                data.totalCampaigns.toString(),
                Icons.campaign,
                primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Active Campaigns',
                data.activeCampaigns.toString(),
                Icons.play_circle_filled,
                successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Tasks',
                data.totalTasks.toString(),
                Icons.task_alt,
                warningColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Active Agents',
                data.activeAgents.toString(),
                Icons.people,
                Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Live Map',
                'Track agent locations',
                Icons.map,
                primaryColor,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LiveMapScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Campaigns',
                'View all campaigns',
                Icons.campaign,
                successColor,
                () {
                  // Navigate to campaigns list (filtered for client)
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              radius: 24,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignsSection(BuildContext context, ClientDashboardData data, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Campaigns',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (data.campaigns.length > 3)
              TextButton(
                onPressed: () {
                  // Navigate to full campaigns list
                },
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (data.campaigns.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No campaigns assigned yet',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          )
        else
          ...data.campaigns.take(3).map((campaign) => _buildCampaignCard(context, campaign)),
      ],
    );
  }

  Widget _buildCampaignCard(BuildContext context, Campaign campaign) {
    final statusColor = campaign.status == 'active' 
        ? successColor 
        : campaign.status == 'completed' 
            ? Colors.blue 
            : warningColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CampaignDetailScreen(campaign: campaign),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    campaign.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    campaign.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (campaign.description != null) ...[
              const SizedBox(height: 8),
              Text(
                campaign.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${DateFormat('MMM dd').format(campaign.startDate)} - ${DateFormat('MMM dd').format(campaign.endDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(BuildContext context, ClientDashboardData data, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (data.recentActivity.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No recent activity',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.recentActivity.length > 5 ? 5 : data.recentActivity.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final activity = data.recentActivity[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: successColor.withValues(alpha: 0.1),
                    child: Icon(Icons.check, color: successColor, size: 16),
                  ),
                  title: Text(
                    activity.description,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    DateFormat('MMM dd, HH:mm').format(activity.timestamp),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// Data models for client dashboard
class ClientDashboardData {
  final List<Campaign> campaigns;
  final int totalCampaigns;
  final int activeCampaigns;
  final int completedCampaigns;
  final int totalTasks;
  final int completedTasks;
  final int activeAgents;
  final List<ClientActivityItem> recentActivity;

  ClientDashboardData({
    required this.campaigns,
    required this.totalCampaigns,
    required this.activeCampaigns,
    required this.completedCampaigns,
    required this.totalTasks,
    required this.completedTasks,
    required this.activeAgents,
    required this.recentActivity,
  });
}

class ClientActivityItem {
  final String type;
  final String description;
  final DateTime timestamp;

  ClientActivityItem({
    required this.type,
    required this.description,
    required this.timestamp,
  });
}