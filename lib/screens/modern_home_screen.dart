// lib/screens/modern_home_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'agent/agent_route_dashboard_screen.dart';
import '../widgets/update_dialog.dart';
import 'package:logger/logger.dart';
import 'campaigns/campaigns_list_screen.dart';
import 'tasks/standalone_tasks_screen.dart';
import 'map/live_map_screen.dart';
import 'admin/enhanced_manager_dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'agent/agent_standalone_tasks_screen.dart';
import 'login_screen.dart';
import 'admin/settings_screen.dart';
import 'admin/group_management_screen.dart';
import 'agent/agent_geofence_map_screen.dart';
import 'manager/map_location_picker_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
          Text('Loading...'),
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
              const Text('Error loading user profile'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserProfile,
                child: const Text('Retry'),
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
          // Floating navigation bar
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _currentUser!.role == 'admin' || _currentUser!.role == 'manager'
                ? _buildFloatingAdminNav(safeIndex, navItems)
                : _buildAgentBottomNavWithButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingAdminNav(int currentIndex, List<BottomNavigationBarItem> navItems) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: List.generate(navItems.length, (index) {
          final item = navItems[index];
          final isSelected = currentIndex == index;
          // Extract IconData from the BottomNavigationBarItem
          IconData iconData = Icons.help; // fallback
          if (item.icon is Icon) {
            iconData = (item.icon as Icon).icon ?? Icons.help;
          }
          return Expanded(
            child: _buildAdminNavItem(
              iconData,
              item.label ?? '',
              index,
              isSelected,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAdminNavItem(IconData icon, String label, int index, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected 
                  ? const Color(0xFF6366F1).withValues(alpha: 0.1) 
                  : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF9CA3AF),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentBottomNavWithButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main navigation bar
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(child: _buildEnhancedNavItem(Icons.home_filled, 'Home', 0)),
              Expanded(child: _buildEnhancedNavItem(Icons.work_outline_rounded, 'Campaigns', 1)),
              const SizedBox(width: 64), // Space for floating button
              Expanded(child: _buildEnhancedNavItem(Icons.assignment_outlined, 'Tasks', 2)),
              Expanded(child: _buildEnhancedNavItem(Icons.person_outline_rounded, 'Profile', 3)),
            ],
          ),
        ),
        // Floating Action Button positioned above the nav
        Positioned(
          top: -28,
          left: 0,
          right: 0,
          child: Center(
            child: _buildEnhancedUploadButton(),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected 
                  ? const Color(0xFF6366F1).withValues(alpha: 0.1) 
                  : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF9CA3AF),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedUploadButton() {
    return GestureDetector(
      onTap: _showRoutesDashboard,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667EEA).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: -5,
            ),
          ],
        ),
        child: const Icon(
          Icons.route_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Future<void> _showRoutesDashboard() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AgentRouteDashboardScreen(),
      ),
    );
  }

}

// Dashboard Tab for Admins/Managers
class _DashboardTab extends StatelessWidget {
  final AppUser user;
  
  const _DashboardTab({required this.user});

  @override
  Widget build(BuildContext context) {
    // Use different dashboards based on specific role
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
  @override
  Widget build(BuildContext context) {
    return CampaignsListScreen(locationService: LocationService());
  }
}

// Tasks Tab
class _TasksTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const StandaloneTasksScreen();
  }
}

// Map Tab
class _MapTab extends StatelessWidget {
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
  bool _isLocationEnabled = false;
  String? _currentLocationStatus;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadAgentDashboardData();
    _startSmartLocationTracking();
    // Initialize connectivity monitoring
    ConnectivityService().initialize();
    // Add lifecycle observer for app state changes
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
      
      // First check location permission status
      final locationService = LocationService();
      final hasPermission = await locationService.hasLocationPermission();
      
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _isLocationEnabled = false;
            _currentLocationStatus = 'Permission required';
          });
        }
        return;
      }
      
      final success = await _locationManager.initialize();
      if (success) {
        await _locationManager.startTracking();
        _logger.i('✅ Smart location tracking started successfully');
        if (mounted) {
          setState(() {
            _isLocationEnabled = true;
            _currentLocationStatus = 'Active';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLocationEnabled = false;
            _currentLocationStatus = 'Disabled';
          });
        }
      }
    } catch (e) {
      _logger.e('Failed to start smart location tracking: $e');
      if (mounted) {
        setState(() {
          _isLocationEnabled = false;
          _currentLocationStatus = 'Error';
        });
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

      // Load data with individual error handling
      final taskStats = await _getAgentTaskStats(userId).catchError((e) {
        debugPrint('Error loading task stats: $e');
        return AgentTaskStats(
          activeTasks: 0,
          completedTasks: 0,
          totalPoints: 0,
          todayCompleted: 0,
          weeklyCompleted: 0,
        );
      });

      final earningsStats = await _getAgentEarningsStats(userId).catchError((e) {
        debugPrint('Error loading earnings stats: $e');
        return AgentEarningsStats(
          totalEarned: 0,
          totalPaid: 0,
          pendingPayment: 0,
          monthlyEarnings: 0,
          weeklyEarnings: 0,
        );
      });

      final recentActivity = await _getRecentAgentActivity(userId).catchError((e) {
        debugPrint('Error loading recent activity: $e');
        return <AgentActivityItem>[];
      });

      final activeTasks = await _getActiveTasksPreview(userId).catchError((e) {
        debugPrint('Error loading active tasks: $e');
        return <ActiveTaskPreview>[];
      });

      final routeStats = await _getAgentRouteStats(userId).catchError((e) {
        debugPrint('Error loading route stats: $e');
        return AgentRouteStats(
          activeRoutes: 0,
          placesToVisitToday: 0,
          completedVisitsThisWeek: 0,
          routeNames: [],
        );
      });

      final campaignStats = await _getAgentCampaignStats(userId).catchError((e) {
        debugPrint('Error loading campaign stats: $e');
        return AgentCampaignStats(
          activeCampaigns: 0,
          completedCampaigns: 0,
          totalCampaignTasks: 0,
        );
      });

      return AgentDashboardData(
        taskStats: taskStats,
        earningsStats: earningsStats,
        recentActivity: recentActivity,
        activeTasks: activeTasks,
        routeStats: routeStats,
        campaignStats: campaignStats,
      );
    } catch (e) {
      debugPrint('Error loading agent dashboard: $e');
      rethrow;
    }
  }

  Future<AgentTaskStats> _getAgentTaskStats(String userId) async {
    final taskAssignments = await supabase
        .from('task_assignments')
        .select('status, completed_at, tasks!inner(points)')
        .eq('agent_id', userId);

    int activeTasks = 0, completedTasks = 0, totalPoints = 0;
    int todayCompleted = 0, weeklyCompleted = 0;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final weekStart = todayStart.subtract(Duration(days: today.weekday - 1));

    for (final assignment in taskAssignments) {
      final status = assignment['status'] as String;
      final points = assignment['tasks']['points'] as int? ?? 0;
      
      switch (status) {
        case 'assigned':
        case 'in_progress':
          activeTasks++;
          break;
        case 'completed':
          completedTasks++;
          totalPoints += points;
          
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
    try {
      // Get total earned points
      final completedAssignments = await supabase
          .from('task_assignments')
          .select('tasks!inner(points)')
          .eq('agent_id', userId)
          .eq('status', 'completed');

      final totalEarned = completedAssignments.fold<int>(
        0, (sum, assignment) => sum + (assignment['tasks']['points'] as int? ?? 0)
      );

      // Get total paid - handle case where payments table might not exist
      int totalPaid = 0;
      try {
        final payments = await supabase
            .from('payments')
            .select('amount')
            .eq('agent_id', userId);

        totalPaid = payments.fold<int>(
          0, (sum, payment) => sum + (payment['amount'] as int? ?? 0)
        );
      } catch (e) {
        debugPrint('Payments table not accessible: $e');
        // Keep totalPaid as 0
      }

      final pendingPayment = totalEarned - totalPaid;

      // Get this month's earnings
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      
      final monthlyAssignments = await supabase
          .from('task_assignments')
          .select('tasks!inner(points), completed_at')
          .eq('agent_id', userId)
          .eq('status', 'completed')
          .gte('completed_at', monthStart.toIso8601String());

      final monthlyEarnings = monthlyAssignments.fold<int>(
        0, (sum, assignment) => sum + (assignment['tasks']['points'] as int? ?? 0)
      );

      // Get weekly earnings
      final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      
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
    } catch (e) {
      debugPrint('Error in _getAgentEarningsStats: $e');
      rethrow;
    }
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
        .limit(5);

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
        .limit(3);

    for (final evidence in recentEvidence) {
      activities.add(AgentActivityItem(
        type: 'evidence_submitted',
        title: 'Uploaded: ${evidence['title']}',
        timestamp: DateTime.parse(evidence['created_at']),
        icon: Icons.camera_alt,
        color: primaryColor,
      ));
    }

    // Get recent place visits
    final recentVisits = await supabase
        .from('place_visits')
        .select('created_at, places!inner(name)')
        .eq('agent_id', userId)
        .order('created_at', ascending: false)
        .limit(3);

    for (final visit in recentVisits) {
      activities.add(AgentActivityItem(
        type: 'place_visited',
        title: 'Visited: ${visit['places']['name']}',
        timestamp: DateTime.parse(visit['created_at']),
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
    try {
      // Get active routes assigned to this agent via route_assignments table
      final routeAssignmentsResponse = await supabase
          .from('route_assignments')
          .select('route_id, routes!inner(id, name, status)')
          .eq('agent_id', userId)
          .inFilter('status', ['assigned', 'in_progress'])
          .eq('routes.status', 'active');

      final routeNames = routeAssignmentsResponse.map((assignment) {
        final route = assignment['routes'] as Map<String, dynamic>?;
        return route?['name'] as String? ?? 'Route ${route?['id'] ?? ''}';
      }).toList();
      final activeRoutesCount = routeAssignmentsResponse.length;

      // Get places to visit today (unvisited places in active routes)
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      int todayPlacesCount = 0;
      if (activeRoutesCount > 0) {
        try {
          // Get route assignment IDs for this agent
          final routeAssignmentIds = routeAssignmentsResponse.map((assignment) => assignment['route_id'] as String).toList();
          
          // Get all route places in assigned routes
          final allRoutePlaces = await supabase
              .from('route_places')
              .select('id, place_id, visit_frequency')
              .filter('route_id', 'in', '(${routeAssignmentIds.join(',')})');
          
          // Calculate remaining visits needed for each place
          int totalVisitsNeeded = 0;
          
          for (final routePlace in allRoutePlaces) {
            final placeId = routePlace['place_id'];
            final int visitFrequency = (routePlace['visit_frequency'] as int?) ?? 1;
            
            // Count completed visits for this place by this agent
            final completedVisits = await supabase
                .from('place_visits')
                .select('id')
                .eq('agent_id', userId)
                .eq('place_id', placeId)
                .eq('status', 'completed')
                .count(CountOption.exact);
            
            final int completedCount = completedVisits.count;
            final int remainingVisits = (visitFrequency - completedCount).clamp(0, visitFrequency);
            totalVisitsNeeded += remainingVisits;
          }
          
          todayPlacesCount = totalVisitsNeeded;
        } catch (e) {
          debugPrint('Error loading today places: $e');
          // Keep default 0
        }
      }

      // Get completed visits this week
      final weekStart = todayStart.subtract(Duration(days: today.weekday - 1));
      
      int weeklyVisitsCount = 0;
      try {
        final weeklyVisits = await supabase
            .from('place_visits')
            .select('id')
            .eq('agent_id', userId)
            .gte('created_at', weekStart.toIso8601String())
            .count(CountOption.exact);
        weeklyVisitsCount = weeklyVisits.count ?? 0;
      } catch (e) {
        debugPrint('Error loading weekly visits: $e');
        // Keep default 0
      }

      return AgentRouteStats(
        activeRoutes: activeRoutesCount,
        placesToVisitToday: todayPlacesCount,
        completedVisitsThisWeek: weeklyVisitsCount,
        routeNames: routeNames,
      );
    } catch (e) {
      // If there are still relationship issues, return default values
      debugPrint('Error loading route stats: $e');
      return AgentRouteStats(
        activeRoutes: 0,
        placesToVisitToday: 0,
        completedVisitsThisWeek: 0,
        routeNames: [],
      );
    }
  }

  Future<AgentCampaignStats> _getAgentCampaignStats(String userId) async {
    try {
      // Get campaigns assigned to this agent via campaign_agents table
      final agentCampaigns = await supabase
          .from('campaign_agents')
          .select('campaign_id, campaigns!inner(id, start_date, end_date, status)')
          .eq('agent_id', userId);

      if (agentCampaigns.isEmpty) {
        return AgentCampaignStats(
          activeCampaigns: 0,
          completedCampaigns: 0,
          totalCampaignTasks: 0,
        );
      }

      final now = DateTime.now();
      int activeCampaigns = 0;
      int completedCampaigns = 0;

      // Count active and completed campaigns
      for (final assignment in agentCampaigns) {
        final campaign = assignment['campaigns'];
        if (campaign != null) {
          final startDate = DateTime.tryParse(campaign['start_date'] ?? '');
          final endDate = DateTime.tryParse(campaign['end_date'] ?? '');
          
          if (startDate != null && endDate != null) {
            if (now.isAfter(startDate) && now.isBefore(endDate)) {
              activeCampaigns++;
            } else if (now.isAfter(endDate)) {
              completedCampaigns++;
            }
          }
        }
      }

      // Total campaign tasks assigned to this agent
      final campaignTasks = await supabase
          .from('task_assignments')
          .select('id, tasks!inner(campaign_id)')
          .eq('agent_id', userId)
          .not('tasks.campaign_id', 'is', null)
          .count(CountOption.exact);

      return AgentCampaignStats(
        activeCampaigns: activeCampaigns,
        completedCampaigns: completedCampaigns,
        totalCampaignTasks: campaignTasks.count ?? 0,
      );
    } catch (e) {
      debugPrint('Error loading agent campaign stats: $e');
      return AgentCampaignStats(
        activeCampaigns: 0,
        completedCampaigns: 0,
        totalCampaignTasks: 0,
      );
    }
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
                    return const Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                      ),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    // Check if it's a network error
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
                          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading dashboard',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please try again later',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshDashboard,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final data = snapshot.data!;
                  
                  return RefreshIndicator(
                    onRefresh: () async => _refreshDashboard(),
                    color: primaryColor,
                    child: CustomScrollView(
                      slivers: [
                        // Modern App Bar
                        SliverAppBar(
                          expandedHeight: 120.0,
                          floating: false,
                          pinned: true,
                          elevation: 0,
                          backgroundColor: surfaceColor,
                          flexibleSpace: FlexibleSpaceBar(
                            titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                            title: Row(
                              children: [
                                Text(
                                  'Agent Dashboard',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimaryColor,
                                  ),
                                ),
                              ],
                            ),
                            background: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    primaryColor.withValues(alpha: 0.1),
                                    secondaryColor.withValues(alpha: 0.05),
                                  ],
                                ),
                              ),
                              child: SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Welcome back,',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: textSecondaryColor,
                                            ),
                                          ),
                                          Text(
                                            widget.user.fullName ?? 'Agent',
                                            style: GoogleFonts.poppins(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Notification & Settings
                                      Row(
                                        children: [
                                          _buildHeaderIconButton(
                                            icon: Icons.notifications_outlined,
                                            hasNotification: true,
                                            onTap: () {
                                              // Handle notifications
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          _buildHeaderIconButton(
                                            icon: Icons.settings_outlined,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => const SettingsScreen(),
                                                ),
                                              );
                                            },
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
                        
                        // Dashboard Content
                        SliverPadding(
                          padding: const EdgeInsets.all(20),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              // Location Status Card
                              _buildLocationStatusCard(),
                              const SizedBox(height: 20),
                              
                              // Performance Overview
                              _buildPerformanceOverview(data),
                              const SizedBox(height: 20),
                              
                              // Quick Stats Grid
                              _buildQuickStatsGrid(data),
                              const SizedBox(height: 24),
                              
                              // Quick Actions
                              _buildQuickActionsSection(context),
                              const SizedBox(height: 24),
                              
                              // Active Tasks & Routes
                              _buildActiveWorkSection(data),
                              const SizedBox(height: 24),
                              
                              // Recent Activity
                              _buildRecentActivitySection(data.recentActivity),
                              const SizedBox(height: 120), // Space for floating nav
                            ]),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              // Offline banner at the top
              if (!isOnline)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange[700],
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_off, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'You\'re offline - Some features may not be available',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
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

  // Header Icon Button
  Widget _buildHeaderIconButton({
    required IconData icon,
    bool hasNotification = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Icon(icon, color: textSecondaryColor, size: 24),
            if (hasNotification)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: errorColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: surfaceColor, width: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Location Status Card
  Widget _buildLocationStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isLocationEnabled
              ? [primaryColor, primaryColor.withValues(alpha: 0.8)]
              : [Colors.orange, Colors.orange.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_isLocationEnabled ? primaryColor : Colors.orange)
                .withValues(alpha: 0.3),
            blurRadius: 12,
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
              _isLocationEnabled ? Icons.location_on : Icons.location_off,
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
                  'Location Service',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                Text(
                  _currentLocationStatus ?? 'Checking...',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (!_isLocationEnabled)
            TextButton(
              onPressed: () async {
                try {
                  setState(() {
                    _currentLocationStatus = 'Requesting permission...';
                  });
                  
                  final locationService = LocationService();
                  final permissionGranted = await locationService.requestLocationPermission();
                  
                  if (permissionGranted) {
                    if (mounted) {
                      setState(() {
                        _isLocationEnabled = true;
                        _currentLocationStatus = 'Starting...';
                      });
                      context.showSnackBar('Location service enabled successfully!');
                      // Restart location tracking with new permissions
                      _startSmartLocationTracking();
                      _refreshDashboard(); // Refresh the dashboard data
                    }
                  } else {
                    if (mounted) {
                      setState(() {
                        _currentLocationStatus = 'Permission denied';
                      });
                      context.showSnackBar(
                        'Location permission denied. Please enable it in device settings.',
                        isError: true,
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      _currentLocationStatus = 'Error occurred';
                    });
                    context.showSnackBar(
                      'Failed to enable location service: $e',
                      isError: true,
                    );
                  }
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Enable'),
            ),
        ],
      ),
    );
  }

  // Today's Activity Overview
  Widget _buildPerformanceOverview(AgentDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
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
                'Today\'s Activity',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getTodayStatus(data),
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Main Activity Summary
          Row(
            children: [
              // Routes Activity
              Expanded(
                child: _buildActivityItem(
                  icon: Icons.route,
                  title: 'Routes',
                  value: data.routeStats.activeRoutes > 0 
                      ? '${data.routeStats.placesToVisitToday} places'
                      : 'None assigned',
                  subtitle: data.routeStats.activeRoutes > 0 
                      ? 'to visit today'
                      : '',
                  color: secondaryColor,
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              // Tasks Activity
              Expanded(
                child: _buildActivityItem(
                  icon: Icons.assignment,
                  title: 'Tasks',
                  value: data.taskStats.activeTasks > 0 
                      ? '${data.taskStats.activeTasks} active'
                      : 'None active',
                  subtitle: data.taskStats.todayCompleted > 0 
                      ? '${data.taskStats.todayCompleted} completed today'
                      : '',
                  color: primaryColor,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Campaigns Activity
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.campaign, color: Colors.purple, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Campaigns',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                      Text(
                        data.campaignStats.activeCampaigns > 0 
                            ? '${data.campaignStats.activeCampaigns} active campaign${data.campaignStats.activeCampaigns != 1 ? 's' : ''}'
                            : 'No active campaigns',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (data.campaignStats.totalCampaignTasks > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${data.campaignStats.totalCampaignTasks} tasks',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.purple,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Get today's status based on activity
  String _getTodayStatus(AgentDashboardData data) {
    if (data.routeStats.activeRoutes > 0) {
      return 'On Route';
    } else if (data.taskStats.activeTasks > 0) {
      return 'Working Tasks';
    } else if (data.campaignStats.activeCampaigns > 0) {
      return 'In Campaign';
    } else {
      return 'Available';
    }
  }

  // Build activity item
  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textPrimaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: textSecondaryColor,
            ),
          ),
      ],
    );
  }


  // Quick Stats Grid - Extended Layout
  Widget _buildQuickStatsGrid(AgentDashboardData data) {
    final stats = [
      {
        'title': 'Active Tasks',
        'value': '${data.taskStats.activeTasks}',
        'subtitle': 'Tasks in progress',
        'icon': Icons.assignment,
        'color': primaryColor,
        'trend': '${data.taskStats.todayCompleted} completed today',
      },
      {
        'title': 'Total Points',
        'value': '${data.taskStats.totalPoints}',
        'subtitle': 'Points earned',
        'icon': Icons.star,
        'color': Colors.amber,
        'trend': '${data.taskStats.weeklyCompleted} completed this week',
      },
      {
        'title': 'Active Campaigns',
        'value': '${data.campaignStats.activeCampaigns}',
        'subtitle': 'Campaigns running',
        'icon': Icons.campaign,
        'color': secondaryColor,
        'trend': '${data.campaignStats.totalCampaignTasks} total tasks',
      },
      {
        'title': 'Active Routes',
        'value': data.routeStats.routeNames.isNotEmpty 
            ? data.routeStats.routeNames.first 
            : '${data.routeStats.activeRoutes}',
        'subtitle': data.routeStats.routeNames.isNotEmpty 
            ? '${data.routeStats.activeRoutes} route${data.routeStats.activeRoutes != 1 ? 's' : ''} assigned'
            : 'Routes assigned',
        'icon': Icons.route,
        'color': Colors.purple,
        'trend': data.routeStats.routeNames.length > 1 
            ? '+${data.routeStats.routeNames.length - 1} more routes'
            : '${data.routeStats.placesToVisitToday} places today',
      },
    ];

    return Column(
      children: [
        // First row
        Row(
          children: [
            Expanded(
              child: _buildDynamicStatCard(
                title: stats[0]['title'] as String,
                value: stats[0]['value'] as String,
                subtitle: stats[0]['subtitle'] as String,
                icon: stats[0]['icon'] as IconData,
                color: stats[0]['color'] as Color,
                trend: stats[0]['trend'] as String,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDynamicStatCard(
                title: stats[1]['title'] as String,
                value: stats[1]['value'] as String,
                subtitle: stats[1]['subtitle'] as String,
                icon: stats[1]['icon'] as IconData,
                color: stats[1]['color'] as Color,
                trend: stats[1]['trend'] as String,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row
        Row(
          children: [
            Expanded(
              child: _buildDynamicStatCard(
                title: stats[2]['title'] as String,
                value: stats[2]['value'] as String,
                subtitle: stats[2]['subtitle'] as String,
                icon: stats[2]['icon'] as IconData,
                color: stats[2]['color'] as Color,
                trend: stats[2]['trend'] as String,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDynamicStatCard(
                title: stats[3]['title'] as String,
                value: stats[3]['value'] as String,
                subtitle: stats[3]['subtitle'] as String,
                icon: stats[3]['icon'] as IconData,
                color: stats[3]['color'] as Color,
                trend: stats[3]['trend'] as String,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Dynamic Stat Card - Adapts to content size
  Widget _buildDynamicStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String trend,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with icon and title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textSecondaryColor,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Value
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textPrimaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          
          // Subtitle
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: textSecondaryColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          // Trend (if exists)
          if (trend.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              trend,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // Quick Actions Section
  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildQuickActionItem(
              icon: Icons.add_location_alt,
              label: 'Suggest',
              color: Colors.indigo,
              onTap: () => _suggestNewPlace(context),
            ),
            _buildQuickActionItem(
              icon: Icons.map,
              label: 'Map',
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AgentGeofenceMapScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Quick Action Item
  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
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
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Active Work Section
  Widget _buildActiveWorkSection(AgentDashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Work',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AgentStandaloneTasksScreen(),
                ),
              ),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (data.activeTasks.isEmpty && data.routeStats.activeRoutes == 0)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.assignment_turned_in,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No active work',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check back later for new assignments',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              // Active Tasks
              ...data.activeTasks.map((task) => _buildActiveTaskCard(task)),
              
              // Active Routes (if any)
              if (data.routeStats.activeRoutes > 0)
                _buildActiveRouteCard(data.routeStats),
            ],
          ),
      ],
    );
  }

  // Active Task Card
  Widget _buildActiveTaskCard(ActiveTaskPreview task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getTaskStatusColor(task.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              task.status == 'in_progress' ? Icons.play_circle : Icons.assignment,
              color: _getTaskStatusColor(task.status),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${task.points} points',
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecondaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getTaskStatusColor(task.status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getTaskStatusColor(task.status),
                        ),
                      ),
                    ),
                  ],
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
    );
  }

  // Active Route Card
  Widget _buildActiveRouteCard(AgentRouteStats routeStats) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            secondaryColor.withValues(alpha: 0.1),
            primaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: secondaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: secondaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.route,
              color: secondaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Routes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${routeStats.placesToVisitToday} places to visit today',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${routeStats.activeRoutes}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Recent Activity Section
  Widget _buildRecentActivitySection(List<AgentActivityItem> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 16),
        
        if (activities.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                'No recent activity',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: activities
                  .map((activity) => _buildRecentActivityItem(activity))
                  .toList(),
            ),
          ),
      ],
    );
  }

  // Recent Activity Item
  Widget _buildRecentActivityItem(AgentActivityItem activity) {
    final timeAgo = _getTimeAgo(activity.timestamp);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: activity.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              activity.icon,
              color: activity.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: TextStyle(
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
  }

  // Helper method to get time ago string
  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  // Helper method to get task status color
  Color _getTaskStatusColor(String status) {
    switch (status) {
      case 'assigned':
        return primaryColor;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return successColor;
      default:
        return textSecondaryColor;
    }
  }

  // Suggest new place functionality
  Future<void> _suggestNewPlace(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    
    double? selectedLat;
    double? selectedLng;
    double geofenceRadius = 50.0; // Default radius

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.add_location, color: primaryColor),
                  const SizedBox(width: 8),
                  const Text('Suggest New Place'),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Place Name Field
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Place Name *',
                          hintText: 'Enter the name of the place',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Description Field
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'Describe this place...',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Address Field
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address (Optional)',
                          hintText: 'Enter the address',
                          prefixIcon: Icon(Icons.location_city),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Location Selection
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.map, color: primaryColor),
                                const SizedBox(width: 8),
                                const Text(
                                  'Location',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (selectedLat != null && selectedLng != null)
                              Text(
                                'Lat: ${selectedLat!.toStringAsFixed(6)}, Lng: ${selectedLng!.toStringAsFixed(6)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              )
                            else
                              Text(
                                'No location selected',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MapLocationPickerScreen(
                                        initialLocation: selectedLat != null && selectedLng != null 
                                            ? LatLng(selectedLat!, selectedLng!)
                                            : null,
                                        initialRadius: geofenceRadius,
                                      ),
                                    ),
                                  );
                                  
                                  if (result != null) {
                                    setState(() {
                                      selectedLat = result['location'].latitude;
                                      selectedLng = result['location'].longitude;
                                      geofenceRadius = result['radius'] ?? 50.0;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.map),
                                label: Text(selectedLat != null ? 'Change Location' : 'Select Location on Map'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Geofence Radius
                      if (selectedLat != null && selectedLng != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.radio_button_unchecked, color: primaryColor),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Geofence Radius',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${geofenceRadius.round()} meters',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              Slider(
                                value: geofenceRadius,
                                min: 10.0,
                                max: 500.0,
                                divisions: 49,
                                label: '${geofenceRadius.round()}m',
                                onChanged: (value) {
                                  setState(() {
                                    geofenceRadius = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: nameController.text.trim().isEmpty || 
                           selectedLat == null || 
                           selectedLng == null
                      ? null
                      : () async {
                          await _submitPlaceSuggestion(
                            dialogContext,
                            nameController.text.trim(),
                            descriptionController.text.trim(),
                            addressController.text.trim(),
                            selectedLat!,
                            selectedLng!,
                            geofenceRadius,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit Suggestion'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Submit place suggestion to database
  Future<void> _submitPlaceSuggestion(
    BuildContext context,
    String name,
    String description,
    String address,
    double latitude,
    double longitude,
    double geofenceRadius,
  ) async {
    // Validation (matching route screen)
    if (name.trim().isEmpty) {
      context.showSnackBar('Please fill required fields (Name)', isError: true);
      return;
    }

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        context.showSnackBar('Authentication required', isError: true);
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Prepare place data (matching route screen exactly)
      final placeData = {
        'name': name,
        'description': description.isEmpty ? null : description,
        'address': address.isEmpty ? null : address,
        'latitude': latitude,
        'longitude': longitude,
        'created_by': userId,
        'approval_status': 'pending', // Requires manager approval
        'status': 'pending_approval',
        'metadata': {
          'created_by_role': 'agent',
          'geofence_radius': geofenceRadius,
        },
      };

      // Insert into database
      await supabase.from('places').insert(placeData);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Show success message (matching route screen)
        context.showSnackBar('Place suggestion submitted! Waiting for manager approval.');
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Show error message
        context.showSnackBar(
          'Failed to submit place suggestion: $e',
          isError: true,
        );
      }
    }
  }
}

// Agent Campaigns Tab
class _AgentCampaignsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CampaignsListScreen(locationService: LocationService());
  }
}

// Agent Tasks Tab
class _AgentTasksTab extends StatelessWidget {
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            child: Text(
              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.fullName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textPrimaryColor,
            ),
          ),
          Text(
            '${user.role.toUpperCase()} • ${(user.status ?? 'unknown').toUpperCase()}',
            style: const TextStyle(
              fontSize: 14,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
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
        // Group Management - Admin only (for client separation)
        if (user.role == 'admin')
          _buildOptionCard(
            icon: Icons.group,
            title: 'Group Management',
            subtitle: 'Manage client groups and team members',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const GroupManagementScreen(),
                ),
              );
            },
          ),
        if (user.role == 'admin')
          const SizedBox(height: 12),
        if (user.role == 'admin' || user.role == 'manager')
          _buildOptionCard(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'App preferences and configuration',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        if (user.role == 'admin' || user.role == 'manager')
          const SizedBox(height: 12),
        const SizedBox(height: 12),
        _buildOptionCard(
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'Get help and contact support',
          onTap: () {
            // Feature coming soon - help and support page will be implemented here
            context.showSnackBar('Help & Support coming soon');
          },
        ),
        const SizedBox(height: 12),
        _buildOptionCard(
          icon: Icons.info_outline,
          title: 'About',
          subtitle: 'App version and information',
          onTap: () {
            // Feature coming soon - about dialog will be implemented here
            context.showSnackBar('About information coming soon');
          },
        ),
        const SizedBox(height: 12),
        _buildOptionCard(
          icon: Icons.logout,
          title: 'Sign Out',
          subtitle: 'Sign out of your account',
          color: errorColor,
          onTap: () async {
            await _handleSignOut(context);
          },
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    final optionColor = color ?? textPrimaryColor;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: optionColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: optionColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: optionColor,
                    ),
                  ),
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
            Icon(
              Icons.chevron_right,
              color: textSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      // Show confirmation dialog
      final shouldSignOut = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out of your account?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: errorColor),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sign Out'),
              ),
            ],
          );
        },
      );

      if (shouldSignOut == true && context.mounted) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        try {
          // Stop all location tracking services first
          try {
            await SmartLocationManager().stopTracking();
          } catch (e) {
            // Continue with logout even if location cleanup fails
          }
          
          // Clean up session in database
          await SessionService().forceLogout();
          
          // Update user status to offline
          await ProfileService.instance.updateUserStatus('offline');
          
          // Sign out from Supabase Auth
          await supabase.auth.signOut();
          
          if (context.mounted) {
            // Close loading dialog
            Navigator.of(context).pop();
            
            // Navigate to login screen
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        } catch (e) {
          if (context.mounted) {
            // Close loading dialog
            Navigator.of(context).pop();
            
            // Show error message
            context.showSnackBar(
              'Failed to sign out properly: $e',
              isError: true,
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar(
          'An error occurred: $e',
          isError: true,
        );
      }
    }
  }
}

// Data classes for Agent Dashboard
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

class AgentRouteStats {
  final int activeRoutes;
  final int placesToVisitToday;
  final int completedVisitsThisWeek;
  final List<String> routeNames;

  AgentRouteStats({
    required this.activeRoutes,
    required this.placesToVisitToday,
    required this.completedVisitsThisWeek,
    required this.routeNames,
  });
}

class AgentCampaignStats {
  final int activeCampaigns;
  final int completedCampaigns;
  final int totalCampaignTasks;

  AgentCampaignStats({
    required this.activeCampaigns,
    required this.completedCampaigns,
    required this.totalCampaignTasks,
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
