// lib/screens/admin/enhanced_manager_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import 'evidence_list_screen.dart';
import '../tasks/standalone_tasks_screen.dart';
import '../calendar_screen.dart';
import 'pending_assignments_screen.dart';
import '../reporting/location_history_screen.dart';
import '../../services/group_service.dart';
import '../manager/team_members_screen.dart';
import '../manager/route_management_screen.dart';
import '../manager/place_management_screen.dart';
import '../manager/route_visit_analytics_screen.dart';

class EnhancedManagerDashboardScreen extends StatefulWidget {
  const EnhancedManagerDashboardScreen({super.key});

  @override
  State<EnhancedManagerDashboardScreen> createState() => _EnhancedManagerDashboardScreenState();
}

class _EnhancedManagerDashboardScreenState extends State<EnhancedManagerDashboardScreen> {
  late Future<ManagerDashboardData> _dashboardFuture;
  bool _isEditMode = false;
  List<ActionCardData> _actionCards = [];

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadManagerDashboardData();
    _initializeActionCards();
  }

  void _initializeActionCards() {
    _actionCards = [
      ActionCardData(
        id: 'pending_assignments',
        title: 'Pending Assignments',
        icon: Icons.assignment_late,
        color: Colors.orange,
        onTap: () => _navigateToPendingAssignments(),
      ),
      ActionCardData(
        id: 'review_evidence',
        title: 'Review Evidence',
        icon: Icons.rate_review,
        color: warningColor,
        onTap: () => _navigateToEvidenceList(),
      ),
      ActionCardData(
        id: 'manage_tasks',
        title: 'Manage Tasks',
        icon: Icons.list_alt,
        color: successColor,
        onTap: () => _navigateToManageTasks(),
      ),
      ActionCardData(
        id: 'calendar',
        title: 'Calendar',
        icon: Icons.calendar_today,
        color: secondaryColor,
        onTap: () => _navigateToCalendar(),
      ),
      ActionCardData(
        id: 'visit_analytics',
        title: 'Visit Analytics',
        icon: Icons.analytics,
        color: Colors.teal,
        onTap: () => _navigateToVisitAnalytics(),
      ),
      ActionCardData(
        id: 'location_history',
        title: 'Location History',
        icon: Icons.location_history,
        color: primaryColor,
        onTap: () => _navigateToLocationHistory(),
      ),
      ActionCardData(
        id: 'routes_places',
        title: 'Routes & Places',
        icon: Icons.route,
        color: Colors.purple,
        onTap: () => _navigateToRouteManagement(),
      ),
    ];
  }

  void _navigateToPendingAssignments() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PendingAssignmentsScreen(),
      ),
    );
  }

  void _navigateToEvidenceList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EvidenceListScreen(),
      ),
    );
  }

  void _navigateToManageTasks() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StandaloneTasksScreen(),
      ),
    );
  }

  void _navigateToCalendar() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CalendarScreen(),
      ),
    );
  }

  void _navigateToVisitAnalytics() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RouteVisitAnalyticsScreen(),
      ),
    );
  }

  void _navigateToLocationHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LocationHistoryScreen(),
      ),
    );
  }

  void _navigateToRouteManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RouteManagementScreen(),
      ),
    );
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
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
    // Get current user's role
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      return ManagerTaskStats(
        totalTasks: 0,
        activeTasks: 0,
        completedAssignments: 0,
        pendingAssignments: 0,
        todayCompleted: 0,
      );
    }

    final userProfile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', currentUser.id)
        .single();
    
    final isManager = userProfile['role'] == 'manager';
    
    // Get all tasks (both campaign and standalone)
    final tasksResponse = await supabase
        .from('tasks')
        .select('id, status, created_at');
    
    // For managers, get assignments only from agents in their groups
    List<Map<String, dynamic>> assignmentsResponse;
    
    if (isManager) {
      // Get manager's groups
      final managerGroups = await supabase
          .from('user_groups')
          .select('group_id')
          .eq('user_id', currentUser.id);
      
      if (managerGroups.isEmpty) {
        assignmentsResponse = [];
      } else {
        final groupIds = managerGroups.map((g) => g['group_id']).toList();
        
        // Get all agents in manager's groups
        final agentsInGroups = await supabase
            .from('user_groups')
            .select('user_id')
            .inFilter('group_id', groupIds);
        
        if (agentsInGroups.isEmpty) {
          assignmentsResponse = [];
        } else {
          final agentIds = agentsInGroups.map((a) => a['user_id'] as String).toList();
          
          // Get assignments from these agents only
          assignmentsResponse = await supabase
              .from('task_assignments')
              .select('status, agent_id')
              .inFilter('agent_id', agentIds);
        }
      }
    } else {
      // Admin sees all assignments
      assignmentsResponse = await supabase
          .from('task_assignments')
          .select('status');
    }
    
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
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      return AgentManagementStats(
        totalAgents: 0,
        activeAgents: 0,
        onlineAgents: 0,
        weeklyCompletions: 0,
      );
    }

    final userProfile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', currentUser.id)
        .single();
    
    final isManager = userProfile['role'] == 'manager';
    
    List<Map<String, dynamic>> agentsResponse;
    
    if (isManager) {
      // Get manager's groups
      final managerGroups = await supabase
          .from('user_groups')
          .select('group_id')
          .eq('user_id', currentUser.id);
      
      if (managerGroups.isEmpty) {
        agentsResponse = [];
      } else {
        final groupIds = managerGroups.map((g) => g['group_id']).toList();
        
        // Get all agents in manager's groups
        final agentsInGroups = await supabase
            .from('user_groups')
            .select('user_id')
            .inFilter('group_id', groupIds);
        
        if (agentsInGroups.isEmpty) {
          agentsResponse = [];
        } else {
          final agentIds = agentsInGroups.map((a) => a['user_id'] as String).toList();
          
          // Get agent profiles from these agents only
          agentsResponse = await supabase
              .from('profiles')
              .select('id, status, role')
              .eq('role', 'agent')
              .inFilter('id', agentIds);
        }
      }
    } else {
      // Admin sees all agents
      agentsResponse = await supabase
          .from('profiles')
          .select('id, status, role')
          .eq('role', 'agent');
    }
    
    int totalAgents = agentsResponse.length;
    int activeAgents = 0, onlineAgents = 0;
    
    for (final agent in agentsResponse) {
      final status = agent['status'] as String? ?? 'offline';
      
      if (status == 'active') {
        activeAgents++;
        onlineAgents++; // Consider active users as online
      }
    }
    
    // Get agent performance this week - same filtering applies
    List<Map<String, dynamic>> weeklyPerformanceResponse;
    
    if (isManager && agentsResponse.isNotEmpty) {
      final agentIds = agentsResponse.map((a) => a['id'] as String).toList();
      weeklyPerformanceResponse = await supabase
          .from('task_assignments')
          .select('agent_id')
          .eq('status', 'completed')
          .inFilter('agent_id', agentIds);
    } else if (!isManager) {
      weeklyPerformanceResponse = await supabase
          .from('task_assignments')
          .select('agent_id')
          .eq('status', 'completed');
    } else {
      weeklyPerformanceResponse = [];
    }
    
    return AgentManagementStats(
      totalAgents: totalAgents,
      activeAgents: activeAgents,
      onlineAgents: onlineAgents,
      weeklyCompletions: weeklyPerformanceResponse.length,
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
                  _buildQuickActionsSection(data),
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
          InkWell(
            onTap: _toggleEditMode,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: _isEditMode ? 0.3 : 0.2),
                borderRadius: BorderRadius.circular(8),
                border: _isEditMode ? Border.all(color: Colors.white, width: 1) : null,
              ),
              child: Icon(
                _isEditMode ? Icons.check : Icons.settings,
                color: Colors.white,
                size: 20,
              ),
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
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  title: 'Team Members',
                  value: data.agentStats.totalAgents.toString(),
                  subtitle: '${data.agentStats.onlineAgents} online',
                  icon: Icons.group,
                  color: primaryColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const TeamMembersScreen(),
                      ),
                    );
                  },
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
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  title: 'Route Management',
                  value: '🗺️',
                  subtitle: 'Create & manage routes',
                  icon: Icons.route,
                  color: Colors.purple,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RouteManagementScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewCard(
                  title: 'Place Management',
                  value: '📍',
                  subtitle: 'Approve agent suggestions',
                  icon: Icons.location_on,
                  color: Colors.green,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PlaceManagementScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Container()), // Empty space
            ],
          ),
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 150),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: lightShadowColor,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(
            color: color.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
              letterSpacing: 0.1,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: textSecondaryColor,
            ),
            softWrap: true,
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(ManagerDashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            if (_isEditMode) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Edit mode active',
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _buildCardsGrid(data),
      ],
    );
  }

  Widget _buildCardsGrid(ManagerDashboardData data) {
    return Column(
      children: [
        // Row 1: 3 cards
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  title: 'Pending Assignments',
                  subtitle: '',
                  icon: Icons.assignment_late,
                  color: Colors.orange,
                  badgeCount: data.taskStats.pendingAssignments,
                  onTap: _isEditMode ? null : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PendingAssignmentsScreen(),
                      ),
                    );
                  },
                  isDraggable: _isEditMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  title: 'Review Evidence',
                  subtitle: '',
                  icon: Icons.rate_review,
                  color: warningColor,
                  onTap: _isEditMode ? null : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const EvidenceListScreen(),
                      ),
                    );
                  },
                  isDraggable: _isEditMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  title: 'Manage Tasks',
                  subtitle: '',
                  icon: Icons.list_alt,
                  color: successColor,
                  onTap: _isEditMode ? null : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const StandaloneTasksScreen(),
                      ),
                    );
                  },
                  isDraggable: _isEditMode,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Row 2: 3 cards
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  title: 'Calendar',
                  subtitle: '',
                  icon: Icons.calendar_today,
                  color: secondaryColor,
                  onTap: _isEditMode ? null : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CalendarScreen(),
                      ),
                    );
                  },
                  isDraggable: _isEditMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  title: 'Visit Analytics',
                  subtitle: '',
                  icon: Icons.analytics,
                  color: Colors.teal,
                  onTap: _isEditMode ? null : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RouteVisitAnalyticsScreen(),
                      ),
                    );
                  },
                  isDraggable: _isEditMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  title: 'Location History',
                  subtitle: '',
                  icon: Icons.location_history,
                  color: primaryColor,
                  onTap: _isEditMode ? null : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LocationHistoryScreen(),
                      ),
                    );
                  },
                  isDraggable: _isEditMode,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Row 3: 1 card
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  title: 'Routes & Places',
                  subtitle: '',
                  icon: Icons.route,
                  color: Colors.purple,
                  onTap: _isEditMode ? null : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RouteManagementScreen(),
                      ),
                    );
                  },
                  isDraggable: _isEditMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Container()), // Empty space
              const SizedBox(width: 12),
              Expanded(child: Container()), // Empty space
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStaticGrid(ManagerDashboardData data) {
    // Ensure cards are initialized
    if (_actionCards.isEmpty) {
      _initializeActionCards();
    }
    
    // Split cards into rows of 3
    List<Widget> rows = [];
    for (int i = 0; i < _actionCards.length; i += 3) {
      List<ActionCardData> rowCards = _actionCards.skip(i).take(3).toList();
      rows.add(_buildCardRow(rowCards, data));
      if (i + 3 < _actionCards.length) {
        rows.add(const SizedBox(height: 12));
      }
    }
    
    return Column(children: rows);
  }

  Widget _buildCardRow(List<ActionCardData> cards, ManagerDashboardData data) {
    return IntrinsicHeight(
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: i < cards.length
                  ? _buildActionCardFromData(cards[i], data)
                  : Container(), // Empty space
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReorderableGrid(ManagerDashboardData data) {
    // For now, just show the static grid with edit mode styling
    // We can implement drag and drop later
    return _buildStaticGrid(data);
  }

  Widget _buildActionCardFromData(ActionCardData cardData, ManagerDashboardData data, {bool isDraggable = false}) {
    int? badgeCount;
    if (cardData.id == 'pending_assignments') {
      badgeCount = data.taskStats.pendingAssignments;
    }

    return _buildActionCard(
      title: cardData.title,
      subtitle: '',
      icon: cardData.icon,
      color: cardData.color,
      badgeCount: badgeCount,
      onTap: _isEditMode ? null : cardData.onTap,
      isDraggable: isDraggable,
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    int? badgeCount,
    bool isDraggable = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 130,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDraggable && _isEditMode 
                  ? color.withValues(alpha: 0.4)
                  : color.withValues(alpha: 0.15),
              width: isDraggable && _isEditMode ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: lightShadowColor,
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                surfaceColor,
                color.withValues(alpha: isDraggable && _isEditMode ? 0.05 : 0.02),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.15),
                          color.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 22,
                    ),
                  ),
                  if (isDraggable && _isEditMode)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: const Icon(
                          Icons.drag_indicator,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  if (badgeCount != null && badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textPrimaryColor,
                    letterSpacing: 0,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: textSecondaryColor,
                    fontSize: 11,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
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

class ActionCardData {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  ActionCardData({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}