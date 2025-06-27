// lib/screens/modern_home_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';
import '../models/app_user.dart';
import '../services/location_service.dart';
import '../services/background_location_service.dart';
import '../services/session_service.dart';
import '../services/profile_service.dart';
import '../services/connectivity_service.dart';
import '../widgets/gps_status_indicator.dart';
import '../widgets/offline_widget.dart';
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

class _ModernHomeScreenState extends State<ModernHomeScreen> {
  int _selectedIndex = 0;
  AppUser? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _setupSessionManagement();
  }

  @override
  void dispose() {
    SessionService().stopPeriodicValidation();
    super.dispose();
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
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: safeIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondaryColor,
        backgroundColor: surfaceColor,
        elevation: 8,
        items: navItems,
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

class _AgentDashboardTabState extends State<_AgentDashboardTab> {
  late Future<AgentDashboardData> _dashboardFuture;
  final LocationService _locationService = LocationService();
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadAgentDashboardData();
    _startLocationTracking();
    // Initialize connectivity monitoring
    ConnectivityService().initialize();
  }

  @override
  void dispose() {
    _locationService.stop();
    BackgroundLocationService.stopLocationTracking();
    super.dispose();
  }

  void _startLocationTracking() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          context.showSnackBar(
            'Location services are disabled. Please enable them in device settings.',
            isError: true,
          );
        }
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            context.showSnackBar(
              'Location permission denied. Please grant permission to track your location.',
              isError: true,
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          context.showSnackBar(
            'Location permission permanently denied. Please enable it in app settings.',
            isError: true,
          );
        }
        return;
      }

      // Initialize background service if not already initialized
      await BackgroundLocationService.initialize();
      
      // Start foreground location tracking
      await _locationService.start();
      _logger.i('Foreground location tracking started for agent: ${widget.user.fullName}');
      
      // Start background location tracking
      await BackgroundLocationService.startLocationTracking();
      _logger.i('Background location tracking started for agent: ${widget.user.fullName}');
      
      // Location tracking started successfully - no notification needed
    } catch (e) {
      _logger.e('Failed to start location tracking: $e');
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
      ]);

      return AgentDashboardData(
        taskStats: results[0] as AgentTaskStats,
        earningsStats: results[1] as AgentEarningsStats,
        recentActivity: results[2] as List<AgentActivityItem>,
        activeTasks: results[3] as List<ActiveTaskPreview>,
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
    int todayCompleted = 0;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

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
          }
          break;
      }
    }

    return AgentTaskStats(
      activeTasks: activeTasks,
      completedTasks: completedTasks,
      totalPoints: totalPoints,
      todayCompleted: todayCompleted,
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
    
    final monthlyAssignments = await supabase
        .from('task_assignments')
        .select('tasks!inner(points), completed_at')
        .eq('agent_id', userId)
        .eq('status', 'completed')
        .gte('completed_at', monthStart.toIso8601String());

    final monthlyEarnings = monthlyAssignments.fold<int>(
      0, (sum, assignment) => sum + (assignment['tasks']['points'] as int? ?? 0)
    );

    return AgentEarningsStats(
      totalEarned: totalEarned,
      totalPaid: totalPaid,
      pendingPayment: pendingPayment,
      monthlyEarnings: monthlyEarnings,
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
        icon: Icons.upload,
        color: primaryColor,
      ));
    }

    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return activities.take(5).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dashboard Title with background label
                          SafeArea(
                            bottom: false,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      primaryColor.withValues(alpha: 0.15),
                                      primaryColor.withValues(alpha: 0.08),
                                      primaryColor.withValues(alpha: 0.12),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: primaryColor.withValues(alpha: 0.25),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                  child: Center(
                                    child: Text(
                                      'Agent Dashboard',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: textPrimaryColor,
                                        letterSpacing: 0.5,
                                        fontSize: 26,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildWelcomeCard(data.taskStats),
                                const SizedBox(height: 20),
                                _buildPerformanceStats(data.taskStats, data.earningsStats),
                                const SizedBox(height: 20),
                                _buildQuickActions(context),
                                const SizedBox(height: 20),
                                _buildActiveTasksPreview(data.activeTasks),
                                const SizedBox(height: 20),
                                _buildRecentActivity(data.recentActivity),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                      color: Colors.orange[700],
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

  Widget _buildWelcomeCard(AgentTaskStats stats) {
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
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      widget.user.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // GPS Signal Indicator with Label
              Column(
                children: [
                  _buildGPSIndicator(),
                  const SizedBox(height: 4),
                  const Text(
                    'GPS Signal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        stats.todayCompleted.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Today\'s Tasks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        stats.activeTasks.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Active Tasks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGPSIndicator() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: GpsStatusIndicator(locationService: _locationService),
    );
  }

  Widget _buildPerformanceStats(AgentTaskStats taskStats, AgentEarningsStats earningsStats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Overview',
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
                child: _buildStatCard(
                  icon: Icons.check_circle,
                  title: 'Completed',
                  value: taskStats.completedTasks.toString(),
                  color: successColor,
                  subtitle: 'Total tasks',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.stars,
                  title: 'Points Earned',
                  value: taskStats.totalPoints.toString(),
                  color: secondaryColor,
                  subtitle: 'Total points',
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
                child: _buildStatCard(
                  icon: Icons.account_balance_wallet,
                  title: 'Pending',
                  value: earningsStats.pendingPayment.toString(),
                  color: warningColor,
                  subtitle: 'Payment due',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.trending_up,
                  title: 'This Month',
                  value: earningsStats.monthlyEarnings.toString(),
                  color: primaryColor,
                  subtitle: 'Points earned',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
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
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
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
          if (subtitle != null) ...
            [const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: textSecondaryColor,
              ),
              softWrap: true,
            )],
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
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
        // First row with 2 items for better spacing
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.assignment,
                  title: 'View Tasks',
                  subtitle: 'See all tasks',
                  color: primaryColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AgentStandaloneTasksScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.account_balance_wallet,
                  title: 'Earnings',
                  subtitle: 'Check payments',
                  color: successColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const EarningsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Second row with 2 items
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.campaign,
                  title: 'Campaigns',
                  subtitle: 'Active campaigns',
                  color: secondaryColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CampaignsListScreen(locationService: LocationService()),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.map,
                  title: 'MAP',
                  subtitle: 'Campaign zones',
                  color: warningColor,
                  onTap: () {
                    // Navigate to agent geofence map
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AgentGeofenceMapScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15)),
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
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: textPrimaryColor,
                    letterSpacing: 0.1,
                  ),
                  textAlign: TextAlign.center,
                  softWrap: true,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: textSecondaryColor,
                ),
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTasksPreview(List<ActiveTaskPreview> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Tasks',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.assignment_turned_in, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No active tasks',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check back later for new assignments',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          ...tasks.map((task) => Container(
            margin: const EdgeInsets.only(bottom: 8),
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
                    color: _getTaskStatusColor(task.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    task.status == 'in_progress' ? Icons.play_arrow : Icons.assignment,
                    color: _getTaskStatusColor(task.status),
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(Icons.stars, size: 12, color: secondaryColor),
                          const SizedBox(width: 4),
                          Text(
                            '${task.points} pts',
                            style: const TextStyle(
                              fontSize: 12,
                              color: textSecondaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getTaskStatusColor(task.status).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              task.status.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
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
          )),
      ],
    );
  }

  Color _getTaskStatusColor(String status) {
    switch (status) {
      case 'in_progress':
        return primaryColor;
      case 'assigned':
        return warningColor;
      default:
        return textSecondaryColor;
    }
  }

  Widget _buildRecentActivity(List<AgentActivityItem> activities) {
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
                            width: 32,
                            height: 32,
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

  AgentDashboardData({
    required this.taskStats,
    required this.earningsStats,
    required this.recentActivity,
    required this.activeTasks,
  });
}

class AgentTaskStats {
  final int activeTasks;
  final int completedTasks;
  final int totalPoints;
  final int todayCompleted;

  AgentTaskStats({
    required this.activeTasks,
    required this.completedTasks,
    required this.totalPoints,
    required this.todayCompleted,
  });
}

class AgentEarningsStats {
  final int totalEarned;
  final int totalPaid;
  final int pendingPayment;
  final int monthlyEarnings;

  AgentEarningsStats({
    required this.totalEarned,
    required this.totalPaid,
    required this.pendingPayment,
    required this.monthlyEarnings,
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
