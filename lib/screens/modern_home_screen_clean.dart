// lib/screens/modern_home_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';
import '../models/app_user.dart';
import '../services/smart_location_manager.dart';
import '../services/location_service.dart';
import '../services/session_service.dart';
import '../services/profile_service.dart';
import '../services/connectivity_service.dart';
import '../services/update_service.dart';
import '../services/timezone_service.dart';
import '../widgets/offline_widget.dart';
import '../l10n/app_localizations.dart';
import 'agent/agent_route_dashboard_screen.dart';
import 'agent/app_health_screen.dart';
import '../widgets/update_dialog.dart';
import 'package:logger/logger.dart';
import 'campaigns/campaigns_list_screen.dart';
import 'tasks/standalone_tasks_screen.dart';
import 'map/live_map_screen.dart';
import 'admin/enhanced_manager_dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'agent/agent_standalone_tasks_screen.dart';
import 'agent/earnings_screen.dart';
import 'login_screen.dart';
import 'admin/settings_screen.dart';
import 'admin/group_management_screen.dart';
import 'agent/agent_geofence_map_screen.dart';

class ModernHomeScreen extends StatefulWidget {
  const ModernHomeScreen({super.key});

  @override
  State<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends State<ModernHomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  AppUser? _currentUser;
  bool _isLoading = true;
  final UpdateService _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserProfile();
    _setupSessionManagement();
    // Clean up APKs after installation and old APKs on app start
    _updateService.cleanupAfterInstallation();
    _updateService.cleanupAllApks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SessionService().stopPeriodicValidation();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Clean up any APKs from installation when app resumes
      _updateService.cleanupAfterInstallation();
      // Check for updates when app comes back to foreground
      _checkForUpdate();
    }
  }
  
  Future<void> _checkForUpdate() async {
    try {
      final appVersion = await _updateService.checkForUpdate();
      
      if (appVersion != null && mounted) {
        // Show mandatory update dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => UpdateDialog(appVersion: appVersion),
        );
      }
    } catch (e) {
      // Silently ignore update check errors when app resumes
    }
  }

  void _setupSessionManagement() {
    // Set callback for when session becomes invalid
    SessionService().setSessionInvalidCallback(() {
      if (mounted) {
        // Navigate back to login screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        context.showSnackBar(
          'You have been logged out because this account was accessed from another device.',
          isError: true,
        );
      }
    });
    
    // Start periodic session validation
    SessionService().startPeriodicValidation();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No authenticated user');
      }
      
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      final user = AppUser.fromJson(response);
      
      // Fetch and set the user's timezone
      try {
        await TimezoneService.instance.fetchUserTimezone();
      } catch (e) {
        // Continue with default timezone if fetch fails
      }
      
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showSnackBar('Error loading profile: $e', isError: true);
      }
    }
  }

  List<Widget> _getScreens() {
    if (_currentUser == null) return [_buildLoadingScreen()];

    final isAdmin = _currentUser!.role == 'admin' || _currentUser!.role == 'manager';
    
    if (isAdmin) {
      return [
        _DashboardTab(user: _currentUser!),
        _CampaignsTab(),
        _TasksTab(),
        _MapTab(),
        _ProfileTab(user: _currentUser!),
      ];
    } else {
      return [
        _AgentDashboardTab(user: _currentUser!),
        _AgentCampaignsTab(),
        _AgentTasksTab(),
        _ProfileTab(user: _currentUser!),
      ];
    }
  }

  List<BottomNavigationBarItem> _getNavItems() {
    if (_currentUser == null) return [];

    final isAdmin = _currentUser!.role == 'admin' || _currentUser!.role == 'manager';
    
    if (isAdmin) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.campaign),
          label: 'Campaigns',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.task),
          label: 'Tasks',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: 'Map',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    } else {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.campaign),
          label: 'Campaigns',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment),
          label: 'My Tasks',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    }
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.loading),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: _buildLoadingScreen(),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.errorLoadingUserProfile),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserProfile,
                child: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        ),
      );
    }

    final screens = _getScreens();
    final navItems = _getNavItems();
    
    // Ensure selectedIndex is within bounds
    final safeIndex = _selectedIndex.clamp(0, screens.length - 1);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Main content
          _currentUser!.role == 'admin' || _currentUser!.role == 'manager'
              ? IndexedStack(
                  index: safeIndex,
                  children: screens,
                )
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF6366F1), // Blue at top
                        Color(0xFFDDD6FE), // Very light purple/lavender
                        Color(0xFFF8FAFC), // Almost white with slight blue tint
                        Colors.white,      // Pure white at bottom
                      ],
                      stops: [0.0, 0.2, 0.5, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Status bar spacer
                      SizedBox(height: MediaQuery.of(context).padding.top),
                      Expanded(
                        child: IndexedStack(
                          index: safeIndex,
                          children: screens,
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: navItems,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    );
  }
}

// Dashboard Tab for Admin/Manager
class _DashboardTab extends StatelessWidget {
  final AppUser user;
  
  const _DashboardTab({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.role == 'admin') {
      return const AdminDashboardScreen();
    } else if (user.role == 'manager') {
      return const EnhancedManagerDashboardScreen();
    } else {
      // This shouldn't happen as agents use _AgentDashboardTab, but fallback to manager dashboard
      return const EnhancedManagerDashboardScreen();
    }
  }
}

// Campaigns Tab
class _CampaignsTab extends StatelessWidget {
  const _CampaignsTab();

  @override
  Widget build(BuildContext context) {
    return CampaignsListScreen(locationService: LocationService());
  }
}

// Tasks Tab
class _TasksTab extends StatelessWidget {
  const _TasksTab();

  @override
  Widget build(BuildContext context) {
    return const StandaloneTasksScreen();
  }
}

// Map Tab
class _MapTab extends StatelessWidget {
  const _MapTab();

  @override
  Widget build(BuildContext context) {
    return const LiveMapScreen();
  }
}

// Agent Dashboard Tab
class _AgentDashboardTab extends StatefulWidget {
  final AppUser user;
  
  const _AgentDashboardTab({required this.user});

  @override
  State<_AgentDashboardTab> createState() => _AgentDashboardTabState();
}

class _AgentDashboardTabState extends State<_AgentDashboardTab> with WidgetsBindingObserver {
  late Future<AgentDashboardData> _dashboardFuture;
  final SmartLocationManager _locationManager = SmartLocationManager();
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadAgentDashboardData();
    _startSmartLocationTracking();
    ConnectivityService().initialize();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _locationManager.stopTracking();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _locationManager.onAppLifecycleStateChanged(state);
  }

  void _startSmartLocationTracking() async {
    try {
      _logger.i('Starting smart location tracking for agent: ${widget.user.fullName}');
      
      final success = await _locationManager.initialize();
      if (success) {
        await _locationManager.startTracking();
        _logger.i('✅ Smart location tracking started successfully');
      } else {
        if (mounted) {
          context.showSnackBar(
            'Failed to initialize location tracking. Please check permissions.',
            isError: true,
          );
        }
      }
    } catch (e) {
      _logger.e('Failed to start smart location tracking: $e');
      if (mounted) {
        context.showSnackBar(
          'Failed to start location tracking: $e',
          isError: true,
        );
      }
    }
  }

  void _refreshDashboard() {
    setState(() {
      _dashboardFuture = _loadAgentDashboardData();
    });
  }

  Future<AgentDashboardData> _loadAgentDashboardData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('No authenticated user');

      final results = await Future.wait([
        _getAgentTaskStats(userId),
        _getAgentEarningsStats(userId),
        _getRecentAgentActivity(userId),
        _getActiveTasksPreview(userId),
        _getAgentRouteStats(userId),
        _getAgentCampaignStats(userId),
      ]);

      return AgentDashboardData(
        taskStats: results[0] as AgentTaskStats,
        earningsStats: results[1] as AgentEarningsStats,
        recentActivity: results[2] as List<AgentActivityItem>,
        activeTasks: results[3] as List<ActiveTaskPreview>,
        routeStats: results[4] as AgentRouteStats,
        campaignStats: results[5] as AgentCampaignStats,
      );
    } catch (e) {
      debugPrint('Error loading agent dashboard: $e');
      rethrow;
    }
  }

  Future<AgentTaskStats> _getAgentTaskStats(String userId) async {
    // Get comprehensive earnings using the RPC function
    final earningsResult = await supabase.rpc('get_agent_overall_earnings', params: {
      'p_agent_id': userId,
    }).single();

    final totalPoints = earningsResult['total_earned'] as int? ?? 0;

    // Get task assignments for active/completed counts
    final taskAssignments = await supabase
        .from('task_assignments')
        .select('status, completed_at, tasks!inner(points)')
        .eq('agent_id', userId);

    // Get touring task assignments for additional counts
    final touringTaskAssignments = await supabase
        .from('touring_task_assignments')
        .select('status, completed_at, touring_tasks!inner(points)')
        .eq('agent_id', userId);

    int activeTasks = 0, completedTasks = 0;
    int todayCompleted = 0, weeklyCompleted = 0;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    // Process regular task assignments
    for (final assignment in taskAssignments) {
      final status = assignment['status'] as String;
      
      switch (status) {
        case 'assigned':
        case 'in_progress':
          activeTasks++;
          break;
        case 'completed':
          completedTasks++;
          
          final completedAt = assignment['completed_at'];
          if (completedAt != null) {
            final completedDate = DateTime.parse(completedAt);
            if (completedDate.isAfter(todayStart)) {
              todayCompleted++;
            }
            if (completedDate.isAfter(weekStart)) {
              weeklyCompleted++;
            }
          }
          break;
      }
    }

    // Process touring task assignments
    for (final assignment in touringTaskAssignments) {
      final status = assignment['status'] as String;
      
      switch (status) {
        case 'assigned':
        case 'in_progress':
          activeTasks++;
          break;
        case 'completed':
          completedTasks++;
          
          final completedAt = assignment['completed_at'];
          if (completedAt != null) {
            final completedDate = DateTime.parse(completedAt);
            if (completedDate.isAfter(todayStart)) {
              todayCompleted++;
            }
            if (completedDate.isAfter(weekStart)) {
              weeklyCompleted++;
            }
          }
          break;
      }
    }

    return AgentTaskStats(
      activeTasks: activeTasks,
      completedTasks: completedTasks,
      totalPoints: totalPoints,
      todayCompleted: todayCompleted,
      weeklyCompleted: weeklyCompleted,
    );
  }

  Future<AgentEarningsStats> _getAgentEarningsStats(String userId) async {
    // Get total earned points
    final completedAssignments = await supabase
        .from('task_assignments')
        .select('tasks!inner(points)')
        .eq('agent_id', userId)
        .eq('status', 'completed');

    final totalEarned = completedAssignments.fold<int>(
      0, (sum, assignment) => sum + (assignment['tasks']['points'] as int? ?? 0)
    );

    // Get total paid
    final payments = await supabase
        .from('payments')
        .select('amount')
        .eq('agent_id', userId);

    final totalPaid = payments.fold<int>(
      0, (sum, payment) => sum + (payment['amount'] as int? ?? 0)
    );

    final pendingPayment = totalEarned - totalPaid;

    // Get this month's earnings
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    final monthlyAssignments = await supabase
        .from('task_assignments')
        .select('tasks!inner(points), completed_at')
        .eq('agent_id', userId)
        .eq('status', 'completed')
        .gte('completed_at', monthStart.toIso8601String());

    final monthlyEarnings = monthlyAssignments.fold<int>(
      0, (sum, assignment) => sum + (assignment['tasks']['points'] as int? ?? 0)
    );

    final weeklyAssignments = await supabase
        .from('task_assignments')
        .select('tasks!inner(points), completed_at')
        .eq('agent_id', userId)
        .eq('status', 'completed')
        .gte('completed_at', weekStart.toIso8601String());

    final weeklyEarnings = weeklyAssignments.fold<int>(
      0, (sum, assignment) => sum + (assignment['tasks']['points'] as int? ?? 0)
    );

    return AgentEarningsStats(
      totalEarned: totalEarned,
      totalPaid: totalPaid,
      pendingPayment: pendingPayment,
      monthlyEarnings: monthlyEarnings,
      weeklyEarnings: weeklyEarnings,
    );
  }

  Future<List<AgentActivityItem>> _getRecentAgentActivity(String userId) async {
    final activities = <AgentActivityItem>[];

    // Get recent task completions
    final recentTasks = await supabase
        .from('task_assignments')
        .select('completed_at, tasks!inner(title)')
        .eq('agent_id', userId)
        .eq('status', 'completed')
        .order('completed_at', ascending: false)
        .limit(3);

    for (final task in recentTasks) {
      if (task['completed_at'] != null) {
        activities.add(AgentActivityItem(
          type: 'task_completed',
          title: 'Completed: ${task['tasks']['title']}',
          timestamp: DateTime.parse(task['completed_at']),
          icon: Icons.check_circle,
          color: successColor,
        ));
      }
    }

    // Get recent evidence submissions
    final recentEvidence = await supabase
        .from('evidence')
        .select('created_at, title')
        .eq('uploader_id', userId)
        .order('created_at', ascending: false)
        .limit(2);

    for (final evidence in recentEvidence) {
      activities.add(AgentActivityItem(
        type: 'evidence_submitted',
        title: 'Uploaded: ${evidence['title']}',
        timestamp: DateTime.parse(evidence['created_at']),
        icon: Icons.upload,
        color: primaryColor,
      ));
    }

    // Get recent place visits
    final recentVisits = await supabase
        .from('place_visits')
        .select('visited_at, places!inner(name)')
        .eq('agent_id', userId)
        .order('visited_at', ascending: false)
        .limit(2);

    for (final visit in recentVisits) {
      activities.add(AgentActivityItem(
        type: 'place_visited',
        title: 'Visited: ${visit['places']['name']}',
        timestamp: DateTime.parse(visit['visited_at']),
        icon: Icons.location_on,
        color: secondaryColor,
      ));
    }

    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return activities.take(7).toList();
  }

  Future<List<ActiveTaskPreview>> _getActiveTasksPreview(String userId) async {
    final activeTasks = await supabase
        .from('task_assignments')
        .select('''
          task_id,
          status,
          tasks!inner(title, points, description)
        ''')
        .eq('agent_id', userId)
        .inFilter('status', ['assigned', 'in_progress'])
        .limit(3);

    return activeTasks.map((task) => ActiveTaskPreview(
      taskId: task['task_id'],
      title: task['tasks']['title'],
      points: task['tasks']['points'] ?? 0,
      status: task['status'],
      description: task['tasks']['description'],
    )).toList();
  }

  Future<AgentRouteStats> _getAgentRouteStats(String userId) async {
    final routeAssignments = await supabase
        .from('route_assignments')
        .select('''
          status,
          routes!inner(
            route_places(
              place_id,
              places!inner(name)
            )
          )
        ''')
        .eq('agent_id', userId)
        .inFilter('status', ['assigned', 'in_progress']);

    int activeRoutes = routeAssignments.length;
    int totalPlaces = 0;
    
    for (final assignment in routeAssignments) {
      final routePlaces = assignment['routes']['route_places'] as List? ?? [];
      totalPlaces += routePlaces.length;
    }

    // Get today's place visits
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    
    final todayVisits = await supabase
        .from('place_visits')
        .select('id')
        .eq('agent_id', userId)
        .gte('visited_at', todayStart.toIso8601String());

    return AgentRouteStats(
      activeRoutes: activeRoutes,
      totalPlaces: totalPlaces,
      visitedToday: todayVisits.length,
      pendingVisits: totalPlaces - todayVisits.length,
    );
  }

  Future<AgentCampaignStats> _getAgentCampaignStats(String userId) async {
    // Get campaigns this agent is assigned to
    final campaignAssignments = await supabase
        .from('campaign_agents')
        .select('campaign_id')
        .eq('agent_id', userId);

    final campaignIds = campaignAssignments
        .map((assignment) => assignment['campaign_id'] as String)
        .toList();

    if (campaignIds.isEmpty) {
      return AgentCampaignStats(
        activeCampaigns: 0,
        totalTasks: 0,
        completedTasks: 0,
      );
    }

    final activeCampaigns = await supabase
        .from('campaigns')
        .select('id')
        .inFilter('id', campaignIds)
        .eq('status', 'active');

    // Get tasks for these campaigns
    final campaignTasks = await supabase
        .from('tasks')
        .select('id, campaign_id')
        .inFilter('campaign_id', campaignIds);

    final taskIds = campaignTasks
        .map((task) => task['id'] as String)
        .toList();

    int completedTasks = 0;
    if (taskIds.isNotEmpty) {
      final completedAssignments = await supabase
          .from('task_assignments')
          .select('id')
          .eq('agent_id', userId)
          .eq('status', 'completed')
          .inFilter('task_id', taskIds);
      
      completedTasks = completedAssignments.length;
    }

    return AgentCampaignStats(
      activeCampaigns: activeCampaigns.length,
      totalTasks: campaignTasks.length,
      completedTasks: completedTasks,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<bool>(
        stream: ConnectivityService().connectivityStream,
        initialData: ConnectivityService().isOnline,
        builder: (context, connectivitySnapshot) {
          final isOnline = connectivitySnapshot.data ?? true;
          
          return Stack(
            children: [
              FutureBuilder<AgentDashboardData>(
                future: _dashboardFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    if (!isOnline || ConnectivityService.isNetworkError(snapshot.error)) {
                      return OfflineWidget(
                        title: 'You\'re Offline',
                        subtitle: 'Please check your internet connection to load the dashboard.',
                        onRetry: isOnline ? _refreshDashboard : null,
                      );
                    }
                    
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
                            child: Text(AppLocalizations.of(context)!.retry),
                          ),
                        ],
                      ),
                    );
                  }

                  final data = snapshot.data!;
                  
                  return RefreshIndicator(
                    onRefresh: () async => _refreshDashboard(),
                    child: CustomScrollView(
                      slivers: [
                        // Modern App Bar
                        SliverAppBar(
                          expandedHeight: 120,
                          floating: false,
                          pinned: true,
                          backgroundColor: Colors.transparent,
                          flexibleSpace: FlexibleSpaceBar(
                            background: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF6366F1).withValues(alpha: 0.9),
                                    const Color(0xFF8B5CF6).withValues(alpha: 0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Welcome back,',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  color: Colors.white.withValues(alpha: 0.9),
                                                ),
                                              ),
                                              Text(
                                                widget.user.fullName?.split(' ').first ?? 'Agent',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              // Only show app health for agents, nothing for managers
                                              if (widget.user.role == 'agent') ...[
                                                GestureDetector(
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => const AppHealthScreen(),
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: const Icon(
                                                      Icons.health_and_safety_outlined,
                                                      color: Colors.white,
                                                      size: 24,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                  Icons.settings_outlined,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Location Status Card
                        SliverToBoxAdapter(
                          child: _buildLocationStatusCard(data),
                        ),

                        // Performance Overview
                        SliverToBoxAdapter(
                          child: _buildPerformanceOverview(data),
                        ),

                        // Quick Stats Grid
                        SliverToBoxAdapter(
                          child: _buildQuickStatsGrid(data),
                        ),

                        // Quick Actions
                        SliverToBoxAdapter(
                          child: _buildQuickActions(),
                        ),

                        // Active Work Section
                        SliverToBoxAdapter(
                          child: _buildActiveWorkSection(data),
                        ),

                        // Recent Activity
                        SliverToBoxAdapter(
                          child: _buildRecentActivity(data.recentActivity),
                        ),

                        // Bottom padding for navigation bar
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 100),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              // Offline banner
              if (!isOnline)
                Positioned(
                  top: MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.orange,
                    child: Text(
                      'You\'re offline. Some features may not work.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLocationStatusCard(AgentDashboardData data) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withValues(alpha: 0.1),
            Colors.green.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.gps_fixed,
              color: Colors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Services',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'GPS tracking is active',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceOverview(AgentDashboardData data) {
    final completionRate = data.taskStats.activeTasks > 0 
        ? (data.taskStats.todayCompleted / (data.taskStats.activeTasks + data.taskStats.todayCompleted))
        : 1.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Performance',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(completionRate * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: completionRate,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[400]!, Colors.green[600]!],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Mini stats
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  '${data.taskStats.activeTasks}',
                  'Active Tasks',
                  Icons.assignment,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildMiniStat(
                  '${data.taskStats.weeklyCompleted}',
                  'Week Completed',
                  Icons.date_range,
                  Colors.purple,
                ),
              ),
              Expanded(
                child: _buildMiniStat(
                  '${data.taskStats.totalPoints}',
                  'Total Points',
                  Icons.star,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, IconData icon, Color color) {
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
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQuickStatsGrid(AgentDashboardData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Stats',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Earnings',
                  value: '\$${data.earningsStats.pendingPayment}',
                  subtitle: 'Pending payment',
                  icon: Icons.account_balance_wallet,
                  color: Colors.green,
                  trend: data.earningsStats.weeklyEarnings > 0 ? '+\$${data.earningsStats.weeklyEarnings} this week' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Routes',
                  value: '${data.routeStats.activeRoutes}',
                  subtitle: 'Active routes',
                  icon: Icons.route,
                  color: Colors.blue,
                  trend: '${data.routeStats.visitedToday} places today',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Campaigns',
                  value: '${data.campaignStats.activeCampaigns}',
                  subtitle: 'Active campaigns',
                  icon: Icons.campaign,
                  color: Colors.purple,
                  trend: '${data.campaignStats.totalTasks} total tasks',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Monthly',
                  value: '${data.earningsStats.monthlyEarnings}',
                  subtitle: 'Points earned',
                  icon: Icons.trending_up,
                  color: Colors.orange,
                  trend: 'This month',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          if (trend != null) ...[
            const SizedBox(height: 8),
            Text(
              trend,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'title': 'Tasks', 'icon': Icons.assignment, 'color': Colors.blue, 'route': '/agent-tasks'},
      {'title': 'Routes', 'icon': Icons.route, 'color': Colors.green, 'route': '/agent-routes'},
      {'title': 'Campaigns', 'icon': Icons.campaign, 'color': Colors.purple, 'route': '/agent-campaigns'},
      {'title': 'Evidence', 'icon': Icons.camera_alt, 'color': Colors.orange, 'route': '/evidence'},
      {'title': 'Earnings', 'icon': Icons.attach_money, 'color': Colors.teal, 'route': '/earnings'},
      {'title': 'Suggest Place', 'icon': Icons.add_location, 'color': Colors.indigo, 'route': '/suggest-place'},
      {'title': 'My Areas', 'icon': Icons.map, 'color': Colors.red, 'route': '/map'},
      {'title': 'GPS Calibration', 'icon': Icons.gps_fixed, 'color': Colors.cyan, 'route': '/calibration'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return _buildActionCard(
                title: action['title'] as String,
                icon: action['icon'] as IconData,
                color: action['color'] as Color,
                onTap: () => _handleActionTap(action['route'] as String),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _handleActionTap(String route) {
    switch (route) {
      case '/agent-tasks':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AgentStandaloneTasksScreen()),
        );
        break;
      case '/agent-routes':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AgentRouteDashboardScreen()),
        );
        break;
      case '/agent-campaigns':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CampaignsListScreen(locationService: LocationService())),
        );
        break;
      case '/earnings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EarningsScreen()),
        );
        break;
      case '/map':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AgentGeofenceMapScreen()),
        );
        break;
      case '/calibration':
        Navigator.pushNamed(context, '/calibration');
        break;
      default:
        context.showSnackBar('Feature coming soon!');
    }
  }

  Widget _buildActiveWorkSection(AgentDashboardData data) {
    final hasActiveTasks = data.activeTasks.isNotEmpty;
    final hasActiveRoutes = data.routeStats.activeRoutes > 0;

    if (!hasActiveTasks && !hasActiveRoutes) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Colors.green[400],
            ),
            const SizedBox(height: 12),
            Text(
              'All caught up!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No active tasks or routes assigned',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Work',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          
          // Active Tasks
          if (hasActiveTasks) ...[
            ...data.activeTasks.map((task) => _buildActiveTaskCard(task)),
          ],
          
          // Active Routes
          if (hasActiveRoutes) ...[
            _buildActiveRouteCard(data.routeStats),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveTaskCard(ActiveTaskPreview task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.assignment,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: task.status == 'in_progress' 
                            ? Colors.orange.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        task.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: task.status == 'in_progress' ? Colors.orange[700] : Colors.blue[700],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${task.points} pts',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRouteCard(AgentRouteStats routeStats) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withValues(alpha: 0.1),
            Colors.blue.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.2),
          width: 1,
        ),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.route,
              color: Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Routes',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${routeStats.pendingVisits} places to visit today',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${routeStats.activeRoutes}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(List<AgentActivityItem> activities) {
    if (activities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
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
              children: activities.asMap().entries.map((entry) {
                final index = entry.key;
                final activity = entry.value;
                final isLast = index == activities.length - 1;
                
                return _buildActivityItem(activity, isLast);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(AgentActivityItem activity, bool isLast) {
    final timeAgo = _getTimeAgo(activity.timestamp);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

// Data Models
class AgentDashboardData {
  final AgentTaskStats taskStats;
  final AgentEarningsStats earningsStats;
  final List<AgentActivityItem> recentActivity;
  final List<ActiveTaskPreview> activeTasks;
  final AgentRouteStats routeStats;
  final AgentCampaignStats campaignStats;

  AgentDashboardData({
    required this.taskStats,
    required this.earningsStats,
    required this.recentActivity,
    required this.activeTasks,
    required this.routeStats,
    required this.campaignStats,
  });
}

class AgentTaskStats {
  final int activeTasks;
  final int completedTasks;
  final int totalPoints;
  final int todayCompleted;
  final int weeklyCompleted;

  AgentTaskStats({
    required this.activeTasks,
    required this.completedTasks,
    required this.totalPoints,
    required this.todayCompleted,
    required this.weeklyCompleted,
  });
}

class AgentEarningsStats {
  final int totalEarned;
  final int totalPaid;
  final int pendingPayment;
  final int monthlyEarnings;
  final int weeklyEarnings;

  AgentEarningsStats({
    required this.totalEarned,
    required this.totalPaid,
    required this.pendingPayment,
    required this.monthlyEarnings,
    required this.weeklyEarnings,
  });
}

class AgentActivityItem {
  final String type;
  final String title;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  AgentActivityItem({
    required this.type,
    required this.title,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}

class ActiveTaskPreview {
  final String taskId;
  final String title;
  final int points;
  final String status;
  final String? description;

  ActiveTaskPreview({
    required this.taskId,
    required this.title,
    required this.points,
    required this.status,
    this.description,
  });
}

class AgentRouteStats {
  final int activeRoutes;
  final int totalPlaces;
  final int visitedToday;
  final int pendingVisits;

  AgentRouteStats({
    required this.activeRoutes,
    required this.totalPlaces,
    required this.visitedToday,
    required this.pendingVisits,
  });
}

class AgentCampaignStats {
  final int activeCampaigns;
  final int totalTasks;
  final int completedTasks;

  AgentCampaignStats({
    required this.activeCampaigns,
    required this.totalTasks,
    required this.completedTasks,
  });
}

// Agent Campaigns Tab
class _AgentCampaignsTab extends StatelessWidget {
  const _AgentCampaignsTab();

  @override
  Widget build(BuildContext context) {
    return CampaignsListScreen(locationService: LocationService());
  }
}

// Agent Tasks Tab
class _AgentTasksTab extends StatelessWidget {
  const _AgentTasksTab();

  @override
  Widget build(BuildContext context) {
    return const AgentStandaloneTasksScreen();
  }
}

// Profile Tab
class _ProfileTab extends StatelessWidget {
  final AppUser user;
  
  const _ProfileTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 24),
              _buildProfileOptions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: Icon(
              Icons.person,
              size: 50,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.fullName ?? 'Agent',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email ?? '',
            style: TextStyle(
              fontSize: 16,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user.role?.toUpperCase() ?? 'AGENT',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOptions(BuildContext context) {
    return Column(
      children: [
        _buildOptionCard(
          context,
          icon: Icons.account_circle,
          title: 'Account Settings',
          subtitle: 'Manage your profile and preferences',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
        ),
        // Add App Health option for agents only
        if (user.role == 'agent') ...[
          _buildOptionCard(
            context,
            icon: Icons.health_and_safety,
            title: 'App Health Check',
            subtitle: 'Check GPS, notifications, and system status',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AppHealthScreen(),
                ),
              );
            },
          ),
        ],
        _buildOptionCard(
          context,
          icon: Icons.location_on,
          title: 'Work Areas',
          subtitle: 'View all assigned geofences from campaigns, tasks, and touring routes',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AgentGeofenceMapScreen(),
              ),
            );
          },
        ),
        _buildOptionCard(
          context,
          icon: Icons.attach_money,
          title: 'Earnings & Payments',
          subtitle: 'Track your earnings and payment history',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EarningsScreen(),
              ),
            );
          },
        ),
        _buildOptionCard(
          context,
          icon: Icons.gps_fixed,
          title: 'GPS Calibration',
          subtitle: 'Improve location accuracy',
          onTap: () {
            Navigator.pushNamed(context, '/calibration');
          },
        ),
        _buildOptionCard(
          context,
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'Get help and contact support',
          onTap: () {
            // TODO: Navigate to help screen
          },
        ),
        const SizedBox(height: 16),
        _buildOptionCard(
          context,
          icon: Icons.logout,
          title: 'Sign Out',
          subtitle: 'Log out of your account',
          onTap: () => _handleSignOut(context),
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDestructive 
                ? Colors.red.withValues(alpha: 0.1) 
                : primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.red : primaryColor,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDestructive ? Colors.red : textPrimaryColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: textSecondaryColor,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: textSecondaryColor,
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      await ProfileService.instance.updateUserStatus('offline');
      await supabase.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar('Error signing out: $e', isError: true);
      }
    }
  }
}