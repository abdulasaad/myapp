// lib/screens/admin/enhanced_manager_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import 'evidence_list_screen.dart';
import '../tasks/standalone_tasks_screen.dart';
import '../calendar_screen.dart';
import 'pending_assignments_screen.dart';
import '../../services/group_service.dart';

class EnhancedManagerDashboardScreen extends StatefulWidget {
  const EnhancedManagerDashboardScreen({super.key});

  @override
  State<EnhancedManagerDashboardScreen> createState() => _EnhancedManagerDashboardScreenState();
}

class _EnhancedManagerDashboardScreenState extends State<EnhancedManagerDashboardScreen> {
  late Future<ManagerDashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadManagerDashboardData();
  }

  void _refreshDashboard() {
    setState(() {
      _dashboardFuture = _loadManagerDashboardData();
    });
  }

  Future<ManagerDashboardData> _loadManagerDashboardData() async {
    try {
      final results = await Future.wait([
        _getManagerTaskStats(),
        _getAgentManagementStats(),
        _getCampaignOverview(),
        _getEvidenceReviewQueue(),
        _getRecentManagerActivity(),
        _getUpcomingDeadlines(),
        _getGroupStats(),
      ]);

      return ManagerDashboardData(
        taskStats: results[0] as ManagerTaskStats,
        agentStats: results[1] as AgentManagementStats,
        campaignOverview: results[2] as CampaignOverview,
        evidenceQueue: results[3] as EvidenceReviewQueue,
        recentActivity: results[4] as List<ManagerActivityItem>,
        upcomingDeadlines: results[5] as List<UpcomingDeadline>,
        groupStats: results[6] as GroupStats,
      );
    } catch (e) {
      debugPrint('Error loading manager dashboard: $e');
      rethrow;
    }
  }

  Future<ManagerTaskStats> _getManagerTaskStats() async {
    // Get all tasks (both campaign and standalone)
    final tasksResponse = await supabase
        .from('tasks')
        .select('id, status, created_at');
    
    final assignmentsResponse = await supabase
        .from('task_assignments')
        .select('status');
    
    int totalTasks = tasksResponse.length;
    int activeTasks = 0, completedAssignments = 0, pendingAssignments = 0;
    int todayCompleted = 0; // Simplified for now
    
    for (final assignment in assignmentsResponse) {
      final status = assignment['status'] as String? ?? 'pending';
      
      switch (status) {
        case 'assigned':
        case 'in_progress':
          activeTasks++;
          break;
        case 'completed':
          completedAssignments++;
          todayCompleted++; // Simplified count
          break;
        case 'pending':
          pendingAssignments++;
          break;
      }
    }
    
    return ManagerTaskStats(
      totalTasks: totalTasks,
      activeTasks: activeTasks,
      completedAssignments: completedAssignments,
      pendingAssignments: pendingAssignments,
      todayCompleted: todayCompleted,
    );
  }

  Future<AgentManagementStats> _getAgentManagementStats() async {
    // Get agent statistics
    final agentsResponse = await supabase
        .from('profiles')
        .select('status, role')
        .eq('role', 'agent');
    
    int totalAgents = agentsResponse.length;
    int activeAgents = 0, onlineAgents = 0;
    
    for (final agent in agentsResponse) {
      final status = agent['status'] as String? ?? 'offline';
      
      if (status == 'active') {
        activeAgents++;
        onlineAgents++; // Consider active users as online
      }
    }
    
    // Get agent performance this week - simplified approach
    final weeklyPerformance = await supabase
        .from('task_assignments')
        .select('agent_id')
        .eq('status', 'completed');
    
    return AgentManagementStats(
      totalAgents: totalAgents,
      activeAgents: activeAgents,
      onlineAgents: onlineAgents,
      weeklyCompletions: weeklyPerformance.length,
    );
  }

  Future<CampaignOverview> _getCampaignOverview() async {
    final campaignsResponse = await supabase
        .from('campaigns')
        .select('id, name, start_date, end_date, status');
    
    final now = DateTime.now();
    int activeCampaigns = 0, upcomingCampaigns = 0, completedCampaigns = 0;
    
    for (final campaign in campaignsResponse) {
      final startDate = DateTime.parse(campaign['start_date']);
      final endDate = DateTime.parse(campaign['end_date']);
      
      if (now.isAfter(endDate)) {
        completedCampaigns++;
      } else if (now.isAfter(startDate)) {
        activeCampaigns++;
      } else {
        upcomingCampaigns++;
      }
    }
    
    return CampaignOverview(
      totalCampaigns: campaignsResponse.length,
      activeCampaigns: activeCampaigns,
      upcomingCampaigns: upcomingCampaigns,
      completedCampaigns: completedCampaigns,
    );
  }

  Future<EvidenceReviewQueue> _getEvidenceReviewQueue() async {
    try {
      final evidenceResponse = await supabase
          .from('evidence')
          .select('status, created_at, priority')
          .order('created_at', ascending: false);
      
      int pending = 0, approved = 0, rejected = 0, urgent = 0;
    
      for (final evidence in evidenceResponse) {
        final status = evidence['status'] as String? ?? 'pending';
        
        switch (status) {
          case 'pending':
            pending++;
            // Check priority field or use time-based urgency
            final priority = evidence['priority'] as String? ?? 'normal';
            if (priority == 'urgent') {
              urgent++;
            } else {
              // Consider recent pending items as urgent (last 24 hours)
              final createdAt = DateTime.parse(evidence['created_at']);
              final hoursSinceCreated = DateTime.now().difference(createdAt).inHours;
              if (hoursSinceCreated > 24) urgent++;
            }
            break;
          case 'approved':
            approved++;
            break;
          case 'rejected':
            rejected++;
            break;
        }
      }
      
      return EvidenceReviewQueue(
        pending: pending,
        approved: approved,
        rejected: rejected,
        urgent: urgent,
      );
    } catch (e) {
      debugPrint('Error loading evidence review queue: $e');
      // Return empty queue on error
      return EvidenceReviewQueue(
        pending: 0,
        approved: 0,
        rejected: 0,
        urgent: 0,
      );
    }
  }

  Future<List<ManagerActivityItem>> _getRecentManagerActivity() async {
    final activities = <ManagerActivityItem>[];
    
    // Get recent task creations
    final recentTasks = await supabase
        .from('tasks')
        .select('title, created_at')
        .order('created_at', ascending: false)
        .limit(5);
    
    for (final task in recentTasks) {
      activities.add(ManagerActivityItem(
        type: 'task_created',
        title: 'Created task: ${task['title']}',
        timestamp: DateTime.parse(task['created_at']),
        icon: Icons.add_task,
        color: primaryColor,
      ));
    }
    
    // Get recent evidence approvals - only if there are any reviewed evidence
    try {
      final recentEvidence = await supabase
          .from('evidence')
          .select('title, status, created_at')
          .not('status', 'eq', 'pending')
          .order('created_at', ascending: false)
          .limit(3);
      
      for (final evidence in recentEvidence) {
        final status = evidence['status'] as String;
        activities.add(ManagerActivityItem(
          type: 'evidence_reviewed',
          title: '${status == 'approved' ? 'Approved' : 'Rejected'}: ${evidence['title'] ?? 'Evidence'}',
          timestamp: DateTime.parse(evidence['created_at']),
          icon: status == 'approved' ? Icons.check_circle : Icons.cancel,
          color: status == 'approved' ? successColor : errorColor,
        ));
      }
    } catch (e) {
      debugPrint('No reviewed evidence found: $e');
      // Continue without adding evidence activities
    }
    
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return activities.take(6).toList();
  }
  
  Future<List<UpcomingDeadline>> _getUpcomingDeadlines() async {
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    
    final campaigns = await supabase
        .from('campaigns')
        .select('name, end_date')
        .gte('end_date', now.toIso8601String())
        .lte('end_date', weekFromNow.toIso8601String())
        .order('end_date');
    
    return campaigns.map((campaign) => UpcomingDeadline(
      title: campaign['name'],
      deadline: DateTime.parse(campaign['end_date']),
      type: 'campaign',
    )).toList();
  }

  Future<GroupStats> _getGroupStats() async {
    try {
      final groupService = GroupService();
      final statistics = await groupService.getGroupStatistics();
      
      // Get groups managed by current user if they're a manager
      int myGroups = 0;
      // This would need the current user's ID - for now using 0 as placeholder
      // TODO: Get actual current user ID and filter groups by manager_id
      
      return GroupStats(
        totalGroups: statistics['totalGroups'] ?? 0,
        totalMemberships: statistics['totalMemberships'] ?? 0,
        myGroups: myGroups,
      );
    } catch (e) {
      debugPrint('Error loading group statistics: $e');
      return GroupStats(
        totalGroups: 0,
        totalMemberships: 0,
        myGroups: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<ManagerDashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading dashboard',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _refreshDashboard,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          
          return RefreshIndicator(
            onRefresh: () async => _refreshDashboard(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildManagerWelcomeSection(),
                  const SizedBox(height: 20),
                  _buildManagementOverview(data),
                  const SizedBox(height: 20),
                  _buildQuickActionsSection(),
                  const SizedBox(height: 20),
                  _buildAgentManagementSection(data.agentStats),
                  const SizedBox(height: 20),
                  _buildEvidenceReviewSection(data.evidenceQueue),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildUpcomingDeadlines(data.upcomingDeadlines),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildRecentActivitySection(data.recentActivity),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildManagerWelcomeSection() {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;
    
    if (hour < 12) {
      greeting = 'Good Morning';
      greetingIcon = Icons.wb_sunny;
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      greetingIcon = Icons.wb_sunny_outlined;
    } else {
      greeting = 'Good Evening';
      greetingIcon = Icons.nightlight_round;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              greetingIcon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready to lead your team to success?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.manage_accounts,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildManagementOverview(ManagerDashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Management Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                title: 'Team Members',
                value: data.agentStats.totalAgents.toString(),
                subtitle: '${data.agentStats.onlineAgents} online',
                icon: Icons.group,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOverviewCard(
                title: 'Active Campaigns',
                value: data.campaignOverview.activeCampaigns.toString(),
                subtitle: '${data.campaignOverview.upcomingCampaigns} upcoming',
                icon: Icons.campaign,
                color: secondaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOverviewCard(
                title: 'Task Progress',
                value: data.taskStats.activeTasks.toString(),
                subtitle: '${data.taskStats.todayCompleted} completed today',
                icon: Icons.assignment,
                color: successColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildOverviewCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Pending Assignments',
                subtitle: 'Approval needed',
                icon: Icons.assignment_late,
                color: Colors.orange,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PendingAssignmentsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'Review Evidence',
                subtitle: 'Pending items',
                icon: Icons.rate_review,
                color: warningColor,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const EvidenceListScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'Manage Tasks',
                subtitle: 'All tasks',
                icon: Icons.list_alt,
                color: successColor,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const StandaloneTasksScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Calendar',
                subtitle: 'Schedule & deadlines',
                icon: Icons.calendar_today,
                color: secondaryColor,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CalendarScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Container()), // Empty space
            const SizedBox(width: 12),
            Expanded(child: Container()), // Empty space
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentManagementSection(AgentManagementStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Agent Management',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildAgentStatCard(
                  'Total Agents',
                  stats.totalAgents.toString(),
                  Icons.group,
                  primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAgentStatCard(
                  'Online Now',
                  stats.onlineAgents.toString(),
                  Icons.wifi,
                  successColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAgentStatCard(
                  'This Week',
                  stats.weeklyCompletions.toString(),
                  Icons.trending_up,
                  secondaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgentStatCard(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: textSecondaryColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEvidenceReviewSection(EvidenceReviewQueue queue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Evidence Review Queue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            const Spacer(),
            if (queue.urgent > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${queue.urgent} Urgent',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: errorColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const EvidenceListScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.pending_actions, color: warningColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${queue.pending} Pending Review',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimaryColor,
                        ),
                      ),
                      Text(
                        '${queue.approved} approved, ${queue.rejected} rejected',
                        style: const TextStyle(
                          fontSize: 12,
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
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingDeadlines(List<UpcomingDeadline> deadlines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming Deadlines',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: deadlines.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_available, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No upcoming deadlines',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: deadlines.map((deadline) {
                    final daysUntil = deadline.deadline.difference(DateTime.now()).inDays;
                    final isUrgent = daysUntil <= 2;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isUrgent ? errorColor : warningColor).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.schedule,
                              color: isUrgent ? errorColor : warningColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  deadline.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  daysUntil == 0 ? 'Today' : daysUntil == 1 ? 'Tomorrow' : '$daysUntil days',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isUrgent ? errorColor : textSecondaryColor,
                                    fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection(List<ManagerActivityItem> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: activities.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No recent activity',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: activities.map((activity) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: activity.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              activity.icon,
                              color: activity.color,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: textPrimaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _formatRelativeTime(activity.timestamp),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat.MMMd().format(dateTime);
    }
  }
}

// Data classes for Manager Dashboard
class ManagerDashboardData {
  final ManagerTaskStats taskStats;
  final AgentManagementStats agentStats;
  final CampaignOverview campaignOverview;
  final EvidenceReviewQueue evidenceQueue;
  final List<ManagerActivityItem> recentActivity;
  final List<UpcomingDeadline> upcomingDeadlines;
  final GroupStats groupStats;

  ManagerDashboardData({
    required this.taskStats,
    required this.agentStats,
    required this.campaignOverview,
    required this.evidenceQueue,
    required this.recentActivity,
    required this.upcomingDeadlines,
    required this.groupStats,
  });
}

class ManagerTaskStats {
  final int totalTasks;
  final int activeTasks;
  final int completedAssignments;
  final int pendingAssignments;
  final int todayCompleted;

  ManagerTaskStats({
    required this.totalTasks,
    required this.activeTasks,
    required this.completedAssignments,
    required this.pendingAssignments,
    required this.todayCompleted,
  });
}

class AgentManagementStats {
  final int totalAgents;
  final int activeAgents;
  final int onlineAgents;
  final int weeklyCompletions;

  AgentManagementStats({
    required this.totalAgents,
    required this.activeAgents,
    required this.onlineAgents,
    required this.weeklyCompletions,
  });
}

class CampaignOverview {
  final int totalCampaigns;
  final int activeCampaigns;
  final int upcomingCampaigns;
  final int completedCampaigns;

  CampaignOverview({
    required this.totalCampaigns,
    required this.activeCampaigns,
    required this.upcomingCampaigns,
    required this.completedCampaigns,
  });
}

class EvidenceReviewQueue {
  final int pending;
  final int approved;
  final int rejected;
  final int urgent;

  EvidenceReviewQueue({
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.urgent,
  });
}

class ManagerActivityItem {
  final String type;
  final String title;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  ManagerActivityItem({
    required this.type,
    required this.title,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}

class UpcomingDeadline {
  final String title;
  final DateTime deadline;
  final String type;

  UpcomingDeadline({
    required this.title,
    required this.deadline,
    required this.type,
  });
}

class GroupStats {
  final int totalGroups;
  final int totalMemberships;
  final int myGroups; // For managers - groups they manage

  GroupStats({
    required this.totalGroups,
    required this.totalMemberships,
    required this.myGroups,
  });
}