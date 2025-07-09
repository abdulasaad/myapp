// lib/screens/admin/enhanced_manager_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import 'evidence_list_screen.dart';
import '../tasks/standalone_tasks_screen.dart';
import '../calendar_screen.dart';
import '../reporting/location_history_screen.dart';
import '../../services/group_service.dart';
import '../manager/team_members_screen.dart';
import '../manager/route_management_screen.dart';
import '../manager/place_management_screen.dart';
import '../manager/route_visit_analytics_screen.dart';
import '../map/live_map_screen.dart';
import 'send_notification_screen.dart';

class EnhancedManagerDashboardScreen extends StatefulWidget {
  const EnhancedManagerDashboardScreen({super.key});

  @override
  State<EnhancedManagerDashboardScreen> createState() => _EnhancedManagerDashboardScreenState();
}

class _EnhancedManagerDashboardScreenState extends State<EnhancedManagerDashboardScreen> {
  ManagerDashboardData? _dashboardData;
  bool _hasError = false;

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
      });

      final data = await _loadManagerDashboardData();
      
      if (mounted) {
        setState(() {
          _dashboardData = data;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
      debugPrint('Error loading dashboard data: $e');
    }
  }

  void _refreshDashboard() {
    _loadDashboardData();
  }

  Future<ManagerDashboardData> _loadManagerDashboardData() async {
    try {
      final results = await Future.wait([
        _getManagerTaskStats(),
        _getAgentManagementStats(),
        _getCampaignOverview(),
        _getGroupStats(),
      ]);

      final data = ManagerDashboardData(
        taskStats: results[0] as ManagerTaskStats,
        agentStats: results[1] as AgentManagementStats,
        campaignOverview: results[2] as CampaignOverview,
        evidenceQueue: EvidenceReviewQueue(pending: 0, approved: 0, rejected: 0, urgent: 0),
        recentActivity: <ManagerActivityItem>[],
        upcomingDeadlines: <UpcomingDeadline>[],
        groupStats: results[3] as GroupStats,
      );
      
      return data;
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
      // Get groups where manager is a member (via user_groups)
      final memberGroups = await supabase
          .from('user_groups')
          .select('group_id')
          .eq('user_id', currentUser.id);
      
      if (memberGroups.isEmpty) {
        assignmentsResponse = [];
      } else {
        final groupIds = memberGroups.map((g) => g['group_id'] as String).toList();
        
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
      // Get groups where manager is a member (via user_groups)
      final memberGroups = await supabase
          .from('user_groups')
          .select('group_id')
          .eq('user_id', currentUser.id);
      
      if (memberGroups.isEmpty) {
        agentsResponse = [];
      } else {
        final groupIds = memberGroups.map((g) => g['group_id'] as String).toList();
        
        // Get all agents in manager's groups
        final agentsInGroups = await supabase
            .from('user_groups')
            .select('user_id')
            .inFilter('group_id', groupIds);
        
        if (agentsInGroups.isEmpty) {
          agentsResponse = [];
        } else {
          final agentIds = agentsInGroups.map((a) => a['user_id'] as String).toList();
          
          // Use the same database function as live map for consistent online status
          agentsResponse = await supabase
              .rpc('get_agents_with_last_location')
              .then((data) => (data as List<dynamic>)
                  .cast<Map<String, dynamic>>()
                  .where((agent) => agentIds.contains(agent['id']))
                  .toList());
        }
      }
    } else {
      // Admin sees all agents - use same function as live map
      agentsResponse = await supabase
          .rpc('get_agents_with_last_location')
          .then((data) => (data as List<dynamic>).cast<Map<String, dynamic>>());
    }
    
    int totalAgents = agentsResponse.length;
    int activeAgents = 0, onlineAgents = 0;
    
    for (final agent in agentsResponse) {
      final status = agent['status'] as String? ?? 'offline';
      
      if (status == 'active') {
        activeAgents++;
      }
      
      // Use same online logic as live map
      if (_isAgentOnline(agent)) {
        onlineAgents++;
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

  // Same online status logic as live map
  bool _isAgentOnline(Map<String, dynamic> agent) {
    final lastSeenStr = agent['last_seen'] as String?;
    if (lastSeenStr == null) return false;
    
    try {
      final lastSeen = DateTime.parse(lastSeenStr);
      final calculatedStatus = _getCalculatedStatus(lastSeen);
      // Consider online if Active or Away (not Offline)
      return calculatedStatus != 'Offline';
    } catch (e) {
      // If parsing fails, consider offline
      return false;
    }
  }

  // Same calculated status logic as live map
  String _getCalculatedStatus(DateTime? lastSeen) {
    if (lastSeen == null) return 'Offline';
    final difference = DateTime.now().difference(lastSeen);
    if (difference.inSeconds <= 45) return 'Active';
    if (difference.inMinutes < 15) return 'Away';
    return 'Offline';
  }

  Future<CampaignOverview> _getCampaignOverview() async {
    final campaignsResponse = await supabase
        .from('campaigns')
        .select('id, name, start_date, end_date, status');
    
    final now = DateTime.now();
    int activeCampaigns = 0, completedCampaigns = 0;
    
    for (final campaign in campaignsResponse) {
      final startDate = DateTime.parse(campaign['start_date']);
      final endDate = DateTime.parse(campaign['end_date']);
      
      if (now.isAfter(endDate)) {
        completedCampaigns++;
      } else if (now.isAfter(startDate)) {
        activeCampaigns++;
      } else {
        // upcomingCampaigns not needed
      }
    }
    
    return CampaignOverview(
      totalCampaigns: campaignsResponse.length,
      activeCampaigns: activeCampaigns,
      completedCampaigns: completedCampaigns,
      totalTasks: 0, // Placeholder since we removed task functionality
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
      body: _hasError
          ? Center(
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
            )
          : _dashboardData != null
              ? _buildDashboardContent(_dashboardData!)
              : const Center(child: Text('Loading dashboard...')),
      ),
    );
  }

  Widget _buildDashboardContent(ManagerDashboardData data) {
    return Column(
      children: [
        // Fixed Dashboard Title Header
        Container(
          width: double.infinity,
          color: backgroundColor,
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
          child: const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
        ),
        
        // Scrollable content below the fixed title
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadDashboardData();
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildManagerWelcomeSection(),
                  const SizedBox(height: 20),
                  _buildManagementOverview(data),
                  const SizedBox(height: 20),
                  _buildQuickActionsSection(data),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildManagerWelcomeSection() {
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
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _getManagerProfile(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final profile = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Welcome ',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            profile['full_name'] ?? 'Manager',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        profile['role'] ?? 'Manager',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profile['group_name'] ?? 'No group assigned',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  );
                } else {
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Manager Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }
              },
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
        _buildOverviewLine(
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
        const SizedBox(height: 12),
        _buildOverviewLine(
          title: 'Route Management',
          value: '',
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
        const SizedBox(height: 12),
        _buildOverviewLine(
          title: 'Place Management',
          value: '',
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
        const SizedBox(height: 12),
        _buildOverviewLine(
          title: 'Live Map',
          value: '${data.agentStats.onlineAgents}',
          subtitle: 'Track agents in real-time',
          icon: Icons.map,
          color: Colors.orange,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const LiveMapScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildOverviewLine({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: color.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
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
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
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
        // Row 1: 3 cards - Core Management
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  title: 'Manage Tasks',
                  subtitle: '',
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
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  title: 'Review Evidence',
                  subtitle: '',
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
                  title: 'Routes & Places',
                  subtitle: '',
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Row 2: 3 cards - Analytics & Planning
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  title: 'Calendar',
                  subtitle: '',
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
              Expanded(
                child: _buildActionCard(
                  title: 'Visit Analytics',
                  subtitle: '',
                  icon: Icons.analytics,
                  color: Colors.teal,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RouteVisitAnalyticsScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  title: 'Location History',
                  subtitle: '',
                  icon: Icons.location_history,
                  color: primaryColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LocationHistoryScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Row 3: Admin Features (only show for admin role)
        FutureBuilder<String?>(
          future: _getCurrentUserRole(),
          builder: (context, snapshot) {
            debugPrint('User role check: ${snapshot.data}');
            final userRole = snapshot.data;
            if (userRole != 'admin') {
              debugPrint('User role is not admin, hiding admin features');
              return const SizedBox.shrink();
            }
            
            return IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      title: 'Send Notification',
                      subtitle: 'Message users',
                      icon: Icons.notification_add,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SendNotificationScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(), // Placeholder for future admin feature
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(), // Placeholder for future admin feature
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    int? badgeCount,
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
              color: color.withValues(alpha: 0.15),
              width: 1,
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
                color.withValues(alpha: 0.02),
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

  Future<Map<String, dynamic>> _getManagerProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return {};
    
    try {
      // Get user profile
      final profile = await supabase
          .from('profiles')
          .select('full_name, role')
          .eq('id', user.id)
          .single();
      
      // Get user's group
      final userGroups = await supabase
          .from('user_groups')
          .select('group_id, groups(name)')
          .eq('user_id', user.id)
          .limit(1);
      
      String? groupName;
      if (userGroups.isNotEmpty) {
        groupName = userGroups.first['groups']['name'];
      }
      
      return {
        'full_name': profile['full_name'],
        'role': profile['role'],
        'group_name': groupName,
      };
    } catch (e) {
      return {};
    }
  }

  // Helper method to get current user role
  Future<String?> _getCurrentUserRole() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;
      
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      
      return response['role'] as String?;
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return null;
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

  ManagerDashboardData copyWith({
    ManagerTaskStats? taskStats,
    AgentManagementStats? agentStats,
    CampaignOverview? campaignOverview,
    EvidenceReviewQueue? evidenceQueue,
    List<ManagerActivityItem>? recentActivity,
    List<UpcomingDeadline>? upcomingDeadlines,
    GroupStats? groupStats,
  }) {
    return ManagerDashboardData(
      taskStats: taskStats ?? this.taskStats,
      agentStats: agentStats ?? this.agentStats,
      campaignOverview: campaignOverview ?? this.campaignOverview,
      evidenceQueue: evidenceQueue ?? this.evidenceQueue,
      recentActivity: recentActivity ?? this.recentActivity,
      upcomingDeadlines: upcomingDeadlines ?? this.upcomingDeadlines,
      groupStats: groupStats ?? this.groupStats,
    );
  }
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
  final int completedCampaigns;
  final int totalTasks;

  CampaignOverview({
    required this.totalCampaigns,
    required this.activeCampaigns,
    required this.completedCampaigns,
    required this.totalTasks,
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
