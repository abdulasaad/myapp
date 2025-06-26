// lib/screens/admin/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import '../tasks/template_categories_screen.dart';
import 'simple_evidence_review_screen.dart';
import '../tasks/standalone_tasks_screen.dart';
import 'user_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<AdminDashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadAdminDashboardData();
  }

  void _refreshDashboard() {
    setState(() {
      _dashboardFuture = _loadAdminDashboardData();
    });
  }

  Future<AdminDashboardData> _loadAdminDashboardData() async {
    try {
      final results = await Future.wait([
        _getSystemOverview(),
        _getManagerStats(),
        _getSystemPerformance(),
        _getRecentSystemActivity(),
      ]);

      return AdminDashboardData(
        systemOverview: results[0] as SystemOverview,
        managerStats: results[1] as ManagerStats,
        systemPerformance: results[2] as SystemPerformance,
        recentActivity: results[3] as List<AdminActivityItem>,
      );
    } catch (e) {
      debugPrint('Error loading admin dashboard: $e');
      rethrow;
    }
  }

  Future<SystemOverview> _getSystemOverview() async {
    // Get total users by role
    final usersResponse = await supabase
        .from('profiles')
        .select('role, status, created_at');
    
    int totalManagers = 0, totalAgents = 0, activeUsers = 0;
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    int newUsersThisMonth = 0;
    
    for (final user in usersResponse) {
      final role = user['role'] as String;
      final status = user['status'] as String? ?? 'offline';
      final createdAt = DateTime.parse(user['created_at']);
      
      if (role == 'manager') totalManagers++;
      if (role == 'agent') totalAgents++;
      if (status == 'active') activeUsers++;
      if (createdAt.isAfter(thisMonth)) newUsersThisMonth++;
    }
    
    // Get campaign stats
    final campaignsResponse = await supabase
        .from('campaigns')
        .select('status, created_at');
    
    int totalCampaigns = campaignsResponse.length;
    int activeCampaigns = 0;
    
    for (final _ in campaignsResponse) {
      // For now, we'll consider all as active (you can add logic based on dates)
      activeCampaigns++;
    }
    
    // Get task stats
    final tasksResponse = await supabase
        .from('tasks')
        .select('id');
    
    int totalTasks = tasksResponse.length;
    
    return SystemOverview(
      totalManagers: totalManagers,
      totalAgents: totalAgents,
      activeUsers: activeUsers,
      newUsersThisMonth: newUsersThisMonth,
      totalCampaigns: totalCampaigns,
      activeCampaigns: activeCampaigns,
      totalTasks: totalTasks,
    );
  }

  Future<ManagerStats> _getManagerStats() async {
    // Get managers and their performance
    final managersResponse = await supabase
        .from('profiles')
        .select('id, full_name, status')
        .eq('role', 'manager');
    
    int onlineManagers = 0;
    final List<ManagerPerformance> topManagers = [];
    
    for (final manager in managersResponse) {
      final name = manager['full_name'] as String;
      final status = manager['status'] as String? ?? 'offline';
      
      if (status == 'active') {
        onlineManagers++;
      }
      
      // Get campaigns created by this manager (simplified - get all campaigns and distribute)
      final campaignsResponse = await supabase
          .from('campaigns')
          .select('id');
      
      final campaignsCount = campaignsResponse.length;
      
      topManagers.add(ManagerPerformance(
        name: name,
        campaignsManaged: campaignsCount ~/ (managersResponse.length > 0 ? managersResponse.length : 1), // Simplified distribution
        isOnline: status == 'active',
      ));
    }
    
    // Sort by campaigns managed
    topManagers.sort((a, b) => b.campaignsManaged.compareTo(a.campaignsManaged));
    
    return ManagerStats(
      totalManagers: managersResponse.length,
      onlineManagers: onlineManagers,
      topPerformers: topManagers.take(5).toList(),
    );
  }

  Future<SystemPerformance> _getSystemPerformance() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    
    // Get task completion stats
    final weeklyCompletions = await supabase
        .from('task_assignments')
        .select('id')
        .eq('status', 'completed')
        .gte('completed_at', weekStart.toIso8601String());
    
    final monthlyCompletions = await supabase
        .from('task_assignments')
        .select('id')
        .eq('status', 'completed')
        .gte('completed_at', monthStart.toIso8601String());
    
    // Get evidence approval stats
    final evidenceResponse = await supabase
        .from('evidence')
        .select('status');
    
    double approvalRate = 0.0;
    if (evidenceResponse.isNotEmpty) {
      final approved = evidenceResponse.where((e) => e['status'] == 'approved').length;
      approvalRate = (approved / evidenceResponse.length) * 100;
    }
    
    // Calculate system health score (simplified)
    final activeUsers = await supabase
        .from('profiles')
        .select('id')
        .eq('status', 'active');
    
    final totalUsers = await supabase
        .from('profiles')
        .select('id');
    
    double systemHealth = 85.0; // Base score
    if (totalUsers.isNotEmpty) {
      final activePercentage = (activeUsers.length / totalUsers.length) * 100;
      systemHealth = (systemHealth + activePercentage) / 2;
    }
    
    return SystemPerformance(
      weeklyTaskCompletions: weeklyCompletions.length,
      monthlyTaskCompletions: monthlyCompletions.length,
      evidenceApprovalRate: approvalRate,
      systemHealthScore: systemHealth,
    );
  }

  Future<List<AdminActivityItem>> _getRecentSystemActivity() async {
    final activities = <AdminActivityItem>[];
    
    // Get recent user registrations
    final recentUsers = await supabase
        .from('profiles')
        .select('full_name, role, created_at')
        .order('created_at', ascending: false)
        .limit(3);
    
    for (final user in recentUsers) {
      final role = user['role'] as String;
      activities.add(AdminActivityItem(
        type: 'user_registered',
        title: 'New ${role}: ${user['full_name']}',
        timestamp: DateTime.parse(user['created_at']),
        icon: role == 'manager' ? Icons.admin_panel_settings : Icons.person_add,
        color: role == 'manager' ? primaryColor : successColor,
      ));
    }
    
    // Get recent campaign creations
    final recentCampaigns = await supabase
        .from('campaigns')
        .select('name, created_at')
        .order('created_at', ascending: false)
        .limit(3);
    
    for (final campaign in recentCampaigns) {
      activities.add(AdminActivityItem(
        type: 'campaign_created',
        title: 'Campaign created: ${campaign['name']}',
        timestamp: DateTime.parse(campaign['created_at']),
        icon: Icons.campaign,
        color: secondaryColor,
      ));
    }
    
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return activities.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<AdminDashboardData>(
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
                  _buildAdminWelcomeSection(),
                  const SizedBox(height: 20),
                  _buildSystemOverview(data.systemOverview),
                  const SizedBox(height: 20),
                  _buildAdminQuickActions(),
                  const SizedBox(height: 20),
                  _buildManagerManagementSection(data.managerStats),
                  const SizedBox(height: 20),
                  _buildSystemPerformanceSection(data.systemPerformance),
                  const SizedBox(height: 20),
                  _buildRecentActivitySection(data.recentActivity),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdminWelcomeSection() {
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
      padding: const EdgeInsets.all(24),
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
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              greetingIcon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'System Administrator',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your platform is running smoothly',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemOverview(SystemOverview overview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Overview',
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
              child: _buildSystemCard(
                title: 'Total Managers',
                value: overview.totalManagers.toString(),
                subtitle: 'Platform leaders',
                icon: Icons.admin_panel_settings,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSystemCard(
                title: 'Total Agents',
                value: overview.totalAgents.toString(),
                subtitle: 'Field workers',
                icon: Icons.group,
                color: secondaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSystemCard(
                title: 'Active Users',
                value: overview.activeUsers.toString(),
                subtitle: 'Currently online',
                icon: Icons.wifi,
                color: successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSystemCard(
                title: 'Total Campaigns',
                value: overview.totalCampaigns.toString(),
                subtitle: 'All campaigns',
                icon: Icons.campaign,
                color: warningColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSystemCard(
                title: 'Total Tasks',
                value: overview.totalTasks.toString(),
                subtitle: 'All tasks created',
                icon: Icons.assignment,
                color: errorColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSystemCard(
                title: 'New This Month',
                value: overview.newUsersThisMonth.toString(),
                subtitle: 'User growth',
                icon: Icons.trending_up,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSystemCard({
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
                  fontSize: 18,
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
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Admin Actions',
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
              child: _buildAdminActionCard(
                title: 'User Management',
                subtitle: 'Manage roles & permissions',
                icon: Icons.manage_accounts,
                color: primaryColor,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const UserManagementScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAdminActionCard(
                title: 'System Tasks',
                subtitle: 'Global task overview',
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
              child: _buildAdminActionCard(
                title: 'Evidence Review',
                subtitle: 'Monitor quality',
                icon: Icons.rate_review,
                color: warningColor,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SimpleEvidenceReviewScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAdminActionCard(
                title: 'Templates',
                subtitle: 'Global templates',
                icon: Icons.category,
                color: secondaryColor,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TemplateCategoriesScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminActionCard({
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
        padding: const EdgeInsets.all(14),
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
                size: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagerManagementSection(ManagerStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manager Performance',
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
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildManagerStatCard(
                      'Total Managers',
                      stats.totalManagers.toString(),
                      Icons.admin_panel_settings,
                      primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildManagerStatCard(
                      'Online Now',
                      stats.onlineManagers.toString(),
                      Icons.online_prediction,
                      successColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildManagerStatCard(
                      'Top Performers',
                      stats.topPerformers.length.toString(),
                      Icons.star,
                      warningColor,
                    ),
                  ),
                ],
              ),
              if (stats.topPerformers.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Top Performing Managers',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                ...stats.topPerformers.take(3).map((manager) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: manager.isOnline ? successColor : Colors.grey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          manager.name,
                          style: const TextStyle(
                            fontSize: 13,
                            color: textPrimaryColor,
                          ),
                        ),
                      ),
                      Text(
                        '${manager.campaignsManaged} campaigns',
                        style: const TextStyle(
                          fontSize: 12,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManagerStatCard(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: textSecondaryColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSystemPerformanceSection(SystemPerformance performance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Performance',
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
              child: _buildPerformanceCard(
                'Weekly Tasks',
                performance.weeklyTaskCompletions.toString(),
                'Completed this week',
                Icons.assignment_turned_in,
                primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPerformanceCard(
                'Monthly Tasks',
                performance.monthlyTaskCompletions.toString(),
                'Completed this month',
                Icons.trending_up,
                successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPerformanceCard(
                'Approval Rate',
                '${performance.evidenceApprovalRate.toStringAsFixed(1)}%',
                'Evidence quality',
                Icons.verified,
                warningColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPerformanceCard(
                'System Health',
                '${performance.systemHealthScore.toStringAsFixed(0)}%',
                'Overall status',
                Icons.health_and_safety,
                performance.systemHealthScore > 80 ? successColor : errorColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
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
                  fontSize: 18,
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

  Widget _buildRecentActivitySection(List<AdminActivityItem> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent System Activity',
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

// Data classes for Admin Dashboard
class AdminDashboardData {
  final SystemOverview systemOverview;
  final ManagerStats managerStats;
  final SystemPerformance systemPerformance;
  final List<AdminActivityItem> recentActivity;

  AdminDashboardData({
    required this.systemOverview,
    required this.managerStats,
    required this.systemPerformance,
    required this.recentActivity,
  });
}

class SystemOverview {
  final int totalManagers;
  final int totalAgents;
  final int activeUsers;
  final int newUsersThisMonth;
  final int totalCampaigns;
  final int activeCampaigns;
  final int totalTasks;

  SystemOverview({
    required this.totalManagers,
    required this.totalAgents,
    required this.activeUsers,
    required this.newUsersThisMonth,
    required this.totalCampaigns,
    required this.activeCampaigns,
    required this.totalTasks,
  });
}

class ManagerStats {
  final int totalManagers;
  final int onlineManagers;
  final List<ManagerPerformance> topPerformers;

  ManagerStats({
    required this.totalManagers,
    required this.onlineManagers,
    required this.topPerformers,
  });
}

class ManagerPerformance {
  final String name;
  final int campaignsManaged;
  final bool isOnline;

  ManagerPerformance({
    required this.name,
    required this.campaignsManaged,
    required this.isOnline,
  });
}

class SystemPerformance {
  final int weeklyTaskCompletions;
  final int monthlyTaskCompletions;
  final double evidenceApprovalRate;
  final double systemHealthScore;

  SystemPerformance({
    required this.weeklyTaskCompletions,
    required this.monthlyTaskCompletions,
    required this.evidenceApprovalRate,
    required this.systemHealthScore,
  });
}

class AdminActivityItem {
  final String type;
  final String title;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  AdminActivityItem({
    required this.type,
    required this.title,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}