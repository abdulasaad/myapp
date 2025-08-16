// lib/screens/modern_home_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart';
import '../../l10n/app_localizations.dart';
import '../models/app_user.dart';
import '../services/smart_location_manager.dart';
import '../services/location_service.dart';
import '../services/session_service.dart';
import '../services/profile_service.dart';
import '../services/connectivity_service.dart';
import '../services/update_service.dart';
import '../services/user_status_service.dart';
import '../services/timezone_service.dart';
import '../services/simple_notification_service.dart';
import '../services/notification_manager.dart';
import '../services/notification_service.dart';
import '../services/background_notification_manager.dart';
import '../services/persistent_service_manager.dart';
import '../services/touring_task_movement_service.dart';
import 'package:provider/provider.dart';
import '../widgets/offline_widget.dart';
import '../widgets/language_selection_dialog.dart';
import '../widgets/service_control_widget.dart';
import 'agent/agent_route_dashboard_screen.dart';
import 'agent/app_health_screen.dart';
import '../widgets/update_dialog.dart';
import 'package:logger/logger.dart';
import 'campaigns/campaigns_list_screen.dart';
import 'tasks/standalone_tasks_screen.dart';
import 'admin/enhanced_manager_dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'client/client_dashboard_screen.dart';
import 'agent/agent_standalone_tasks_screen.dart';
import 'login_screen.dart';
import 'admin/settings_screen.dart';
import 'admin/group_management_screen.dart';
import 'agent/agent_geofence_map_screen.dart';
import 'agent/global_survey_dashboard_screen.dart';
import 'agent/notifications_screen.dart';
import 'manager/map_location_picker_screen.dart';
import 'manager/create_route_screen.dart';
import 'campaigns/campaign_wizard_step1_screen.dart';
import 'tasks/create_evidence_task_screen.dart';
import 'tasks/template_categories_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ModernHomeScreen extends StatefulWidget {
  final int? initialTabIndex;
  
  const ModernHomeScreen({super.key, this.initialTabIndex});

  @override
  State<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends State<ModernHomeScreen> with WidgetsBindingObserver {
  late int _selectedIndex;
  AppUser? _currentUser;
  bool _isLoading = true;
  final UpdateService _updateService = UpdateService();
  final SimpleNotificationService _notificationService = SimpleNotificationService();
  NotificationManager? _notificationManager;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex ?? 0;
    WidgetsBinding.instance.addObserver(this);
    _loadUserProfile();
    _setupSessionManagement();
    _loadNotificationCount();
    _setupNotificationManager();
    _initializeUserStatus();
    _restoreActiveTouringSessions();
    // Clean up APKs after installation and old APKs on app start
    _updateService.cleanupAfterInstallation();
    _updateService.cleanupAllApks();
  }

  void _initializeUserStatus() async {
    try {
      // Initialize status service for logged-in user
      await UserStatusService().onUserLogin();
      
      // Restore persistent notification if services are already running
      await PersistentServiceManager.restoreNotificationIfNeeded();
      
      // Auto-start location services for agents
      await _autoStartLocationService();
    } catch (e) {
      debugPrint('Failed to initialize user status: $e');
    }
  }

  Future<void> _autoStartLocationService() async {
    try {
      final isRunning = await PersistentServiceManager.areServicesRunning();
      if (!isRunning) {
        // Auto-start for agents only
        final user = ProfileService.instance.currentUser;
        if (user?.role == 'agent') {
          await PersistentServiceManager.startAllServices(context);
          debugPrint('✅ Auto-started location services for agent');
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to auto-start services: $e');
    }
  }

  void _restoreActiveTouringSessions() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Get the touring task movement service from Provider
      final touringService = Provider.of<TouringTaskMovementService>(context, listen: false);
      
      // Check and restore any active sessions for this user
      final restored = await touringService.checkAndRestoreActiveSession(currentUser.id);
      
      if (restored) {
        debugPrint('✅ Active touring session restored');
      } else {
        debugPrint('ℹ️ No active touring sessions to restore');
      }
    } catch (e) {
      debugPrint('❌ Failed to restore active touring sessions: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SessionService().stopPeriodicValidation();
    _notificationManager?.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // Clean up any APKs from installation when app resumes
        _updateService.cleanupAfterInstallation();
        // Check for updates when app comes back to foreground
        _checkForUpdate();
        // Resume status service but don't change status - background service handles this
        // Restore persistent notification if services are running
        PersistentServiceManager.restoreNotificationIfNeeded();
        break;
        
      case AppLifecycleState.paused:
        // App is going to background - status service will continue via background service
        debugPrint('App paused - status tracking continues in background');
        break;
        
      case AppLifecycleState.inactive:
        // App is becoming inactive (temporary)
        break;
        
      case AppLifecycleState.detached:
        // App is being detached (rare case)
        break;
        
      case AppLifecycleState.hidden:
        // App is hidden (Android 12+)
        break;
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
        context.showSnackBar('${AppLocalizations.of(context)!.errorLoadingProfile}: $e', isError: true);
      }
    }
  }

  void _setupNotificationManager() {
    debugPrint('🚀 Setting up NotificationManager for main screen');
    
    // Initialize NotificationManager lazily
    _notificationManager = NotificationManager();
    
    // Setup callback for notification count changes
    _notificationManager!.setOnNotificationCountChanged((count) {
      debugPrint('📊 Main screen: Notification count callback triggered: $count');
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
        debugPrint('✅ Main screen: Badge count updated to: $count');
      } else {
        debugPrint('❌ Main screen: Widget not mounted, skipping update');
      }
    });

    // Setup callback for received notifications (show in-app notification)
    _notificationManager!.setOnNotificationReceived((title, message, type) {
      debugPrint('🔔 Main screen: Notification received callback: $title - $message');
      if (mounted) {
        debugPrint('✅ Main screen: Showing in-app notification');
        _notificationManager!.showInAppNotification(
          context,
          title: title,
          message: message,
          type: type,
        );
        debugPrint('✅ Main screen: In-app notification displayed');
      } else {
        debugPrint('❌ Main screen: Widget not mounted, skipping notification');
      }
    });
    
    debugPrint('✅ Main screen: NotificationManager setup completed');
  }

  Future<void> _loadNotificationCount() async {
    try {
      debugPrint('Loading notification count for user: ${supabase.auth.currentUser?.id}');
      final count = await _notificationService.getUnreadCount();
      debugPrint('Notification count loaded: $count');
      debugPrint('Setting _unreadNotificationCount to: $count');
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
        debugPrint('State updated, _unreadNotificationCount is now: $_unreadNotificationCount');
        debugPrint('Badge should show: ${_unreadNotificationCount > 0}');
      }
    } catch (e) {
      // Silently handle notification count errors and set to 0
      debugPrint('Error loading notification count: $e');
      if (mounted) {
        setState(() {
          _unreadNotificationCount = 0;
        });
      }
    }
  }

  List<Widget> _getScreens() {
    if (_currentUser == null) return [_buildLoadingScreen()];

    if (_currentUser!.role == 'client') {
      // Client users only get Dashboard and Profile tabs
      return [
        _DashboardTab(user: _currentUser!),
        _ProfileTab(user: _currentUser!),
      ];
    } else if (_currentUser!.role == 'admin' || _currentUser!.role == 'manager') {
      return [
        _DashboardTab(user: _currentUser!),
        _CampaignsTab(),
        _TasksTab(),
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

    if (_currentUser!.role == 'client') {
      // Client users only get Dashboard and Profile navigation items
      return [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: AppLocalizations.of(context)!.dashboard,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: AppLocalizations.of(context)!.profile,
        ),
      ];
    } else if (_currentUser!.role == 'admin' || _currentUser!.role == 'manager') {
      return [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: AppLocalizations.of(context)!.dashboard,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.campaign),
          label: AppLocalizations.of(context)!.campaigns,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.task),
          label: AppLocalizations.of(context)!.tasks,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: AppLocalizations.of(context)!.profile,
        ),
      ];
    } else {
      return [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: AppLocalizations.of(context)!.home,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.campaign),
          label: AppLocalizations.of(context)!.campaigns,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment),
          label: AppLocalizations.of(context)!.myTasks,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: AppLocalizations.of(context)!.profile,
        ),
      ];
    }
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
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
              Text(AppLocalizations.of(context)!.errorLoadingProfile),
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
          _currentUser!.role == 'admin' || _currentUser!.role == 'manager' || _currentUser!.role == 'client'
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
            height: _currentUser!.role == 'admin' || _currentUser!.role == 'manager' || _currentUser!.role == 'client' ? 120 : 80, // Extended height for admin button
            child: _currentUser!.role == 'admin' || _currentUser!.role == 'manager' || _currentUser!.role == 'client'
                ? _buildFloatingAdminNav(safeIndex, navItems)
                : _buildAgentBottomNavWithButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingAdminNav(int currentIndex, List<BottomNavigationBarItem> navItems) {
    // Handle different layouts based on number of navigation items
    if (navItems.length == 2) {
      // Client layout - only Dashboard and Profile, centered
      return _buildClientNav(currentIndex, navItems);
    }
    
    // Admin/Manager layout - 4 tabs with central + button
    return Stack(
      children: [
        // Main navigation bar positioned at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
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
                // First two nav items
                Expanded(
                  child: _buildAdminNavItem(
                    (navItems[0].icon as Icon).icon ?? Icons.dashboard,
                    navItems[0].label ?? '',
                    0,
                    currentIndex == 0,
                  ),
                ),
                Expanded(
                  child: _buildAdminNavItem(
                    (navItems[1].icon as Icon).icon ?? Icons.campaign,
                    navItems[1].label ?? '',
                    1,
                    currentIndex == 1,
                  ),
                ),
                const SizedBox(width: 64), // Space for floating button
                // Last two nav items
                Expanded(
                  child: _buildAdminNavItem(
                    (navItems[2].icon as Icon).icon ?? Icons.task,
                    navItems[2].label ?? '',
                    2,
                    currentIndex == 2,
                  ),
                ),
                Expanded(
                  child: _buildAdminNavItem(
                    (navItems[3].icon as Icon).icon ?? Icons.person,
                    navItems[3].label ?? '',
                    3,
                    currentIndex == 3,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Floating Action Button positioned in the top area
        Positioned(
          top: 12, // Positioned in the available space above nav bar
          left: 0,
          right: 0,
          child: Center(
            child: _buildAdminAddButton(),
          ),
        ),
      ],
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
              Expanded(child: _buildEnhancedNavItem(Icons.home_filled, AppLocalizations.of(context)!.home, 0)),
              Expanded(child: _buildEnhancedNavItem(Icons.work_outline_rounded, AppLocalizations.of(context)!.campaigns, 1)),
              const SizedBox(width: 64), // Space for floating button
              Expanded(child: _buildEnhancedNavItem(Icons.assignment_outlined, AppLocalizations.of(context)!.tasks, 2)),
              Expanded(child: _buildEnhancedNavItem(Icons.person_outline_rounded, AppLocalizations.of(context)!.profile, 3)),
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

  Widget _buildClientNav(int currentIndex, List<BottomNavigationBarItem> navItems) {
    return Positioned(
      bottom: 16,
      left: 32,
      right: 32,
      child: Container(
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
            // Add spacing to center the 2 items
            const Spacer(),
            // Dashboard tab
            Expanded(
              flex: 2,
              child: _buildAdminNavItem(
                (navItems[0].icon as Icon).icon ?? Icons.dashboard,
                navItems[0].label ?? '',
                0,
                currentIndex == 0,
              ),
            ),
            const Spacer(),
            // Profile tab  
            Expanded(
              flex: 2,
              child: _buildAdminNavItem(
                (navItems[1].icon as Icon).icon ?? Icons.person,
                navItems[1].label ?? '',
                1,
                currentIndex == 1,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminAddButton() {
    // Hide the + button for client users (read-only access)
    if (_currentUser?.role == 'client') {
      return const SizedBox.shrink(); // Hide for clients
    }
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showAdminCreateOptions,
        borderRadius: BorderRadius.circular(40),
        splashColor: Colors.white.withValues(alpha: 0.3),
        highlightColor: Colors.white.withValues(alpha: 0.1),
        child: Container(
          width: 80, // Larger tap area
          height: 80, // Larger tap area
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF8B89F1), // Lighter indigo
                  Color(0xFF6366F1), // Selected tab color
                  Color(0xFF4F46E5), // Darker indigo
                ],
                stops: [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                // Main shadow
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                  spreadRadius: -5,
                ),
                // Inner glow effect
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(-3, -3),
                  spreadRadius: -8,
                ),
                // Colored glow
                BoxShadow(
                  color: const Color(0xFF8B89F1).withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 5),
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
                weight: 700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAdminCreateOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modern handle
              Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              
              // Header section with enhanced styling
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.08),
                      const Color(0xFF8B89F1).withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF8B89F1),
                            Color(0xFF6366F1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.createNew,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.chooseWhatToCreate,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Options with modern cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildModernCreateOption(
                      icon: Icons.campaign_rounded,
                      title: AppLocalizations.of(context)!.campaign,
                      subtitle: AppLocalizations.of(context)!.createCampaignDesc,
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.pop(context);
                        _createNewCampaign();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildModernCreateOption(
                      icon: Icons.task_alt_rounded,
                      title: AppLocalizations.of(context)!.task,
                      subtitle: AppLocalizations.of(context)!.createTaskDesc,
                      color: const Color(0xFF6366F1),
                      onTap: () {
                        Navigator.pop(context);
                        _createNewTask();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildModernCreateOption(
                      icon: Icons.route_rounded,
                      title: AppLocalizations.of(context)!.route,
                      subtitle: AppLocalizations.of(context)!.createRouteDesc,
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        Navigator.pop(context);
                        _createNewRoute();
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernCreateOption({
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container with gradient
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.1),
                      color.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createNewCampaign() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CampaignWizardStep1Screen(),
      ),
    );
    
    // If campaign was created successfully, refresh the current screen
    if (result == true && mounted) {
      setState(() {
        // This will trigger a rebuild which will refresh the campaigns tab
      });
    }
  }

  void _createNewTask() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppLocalizations.of(context)!.chooseTaskType,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
              
              // Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildTaskTypeOption(
                      icon: Icons.ballot_rounded,
                      title: AppLocalizations.of(context)!.templateTask,
                      subtitle: AppLocalizations.of(context)!.createTemplateDesc,
                      color: const Color(0xFF6366F1),
                      onTap: () async {
                        Navigator.pop(context);
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TemplateCategoriesScreen(),
                          ),
                        );
                        // Refresh if template task was created
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTaskTypeOption(
                      icon: Icons.edit_note_rounded,
                      title: AppLocalizations.of(context)!.customTask,
                      subtitle: AppLocalizations.of(context)!.createCustomDesc,
                      color: const Color(0xFF10B981),
                      onTap: () async {
                        Navigator.pop(context);
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CreateEvidenceTaskScreen(),
                          ),
                        );
                        // Refresh if needed
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskTypeOption({
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
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createNewRoute() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateRouteScreen(),
      ),
    );
    
    // If route was created successfully, refresh the current screen
    if (result == true && mounted) {
      setState(() {
        // This will trigger a rebuild
      });
    }
  }

}
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
    } else if (user.role == 'client') {
      return const ClientDashboardScreen();
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
  final SimpleNotificationService _notificationService = SimpleNotificationService();
  NotificationManager? _notificationManager;
  bool _isLocationEnabled = false;
  String? _currentLocationStatus;
  int _unreadNotificationCount = 0;

  // Check if background services are enabled, show warning if not
  Future<bool> _checkBackgroundServicesEnabled(BuildContext context) async {
    try {
      final isRunning = await PersistentServiceManager.areServicesRunning();
      if (!isRunning) {
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              icon: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 48,
              ),
              title: Text(
                'Background Services Required',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Text(
                'Background services must be enabled to perform this action. Please enable background services from the dashboard.',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }
        return false;
      }
      return true;
    } catch (e) {
      // If we can't check, allow the action to proceed
      return true;
    }
  }

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadAgentDashboardData();
    _startSmartLocationTracking();
    _loadNotificationCount();
    _setupAgentNotificationManager();
    // Initialize connectivity monitoring
    ConnectivityService().initialize();
    // Add lifecycle observer for app state changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _locationManager.stopTracking();
    _notificationManager?.dispose();
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
            _currentLocationStatus = AppLocalizations.of(context)!.permissionRequired;
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
            _currentLocationStatus = AppLocalizations.of(context)!.active;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLocationEnabled = false;
            _currentLocationStatus = AppLocalizations.of(context)!.disabled;
          });
        }
      }
    } catch (e) {
      _logger.e('Failed to start smart location tracking: $e');
      if (mounted) {
        setState(() {
          _isLocationEnabled = false;
          _currentLocationStatus = AppLocalizations.of(context)!.error;
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

      final visitAnalytics = await _getComprehensiveVisitAnalytics(userId).catchError((e) {
        debugPrint('Error loading visit analytics: $e');
        return AgentVisitAnalytics(
          totalVisitsToday: 0,
          totalVisitsThisWeek: 0,
          totalVisitsThisMonth: 0,
          placeVisitsToday: 0,
          taskVisitsToday: 0,
          evidenceSubmissionsToday: 0,
          averageVisitDuration: 0.0,
          visitCompletionRate: 0.0,
          uniqueLocationsVisited: 0,
          visitsVsYesterday: 0,
          peakVisitHour: 'N/A',
        );
      });

      return AgentDashboardData(
        taskStats: taskStats,
        earningsStats: earningsStats,
        recentActivity: recentActivity,
        activeTasks: activeTasks,
        routeStats: routeStats,
        campaignStats: campaignStats,
        visitAnalytics: visitAnalytics,
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
      List<dynamic> routeAssignmentsResponse = [];
      try {
        routeAssignmentsResponse = await supabase
            .from('route_assignments')
            .select('route_id, routes!inner(id, name, status)')
            .eq('agent_id', userId)
            .inFilter('status', ['assigned', 'in_progress'])
            .eq('routes.status', 'active');
      } catch (e) {
        debugPrint('Error loading route assignments: $e');
        // Continue with empty list
      }

      // Safely extract route names with better error handling
      final List<String> routeNames = [];
      for (final assignment in routeAssignmentsResponse) {
        try {
          final route = assignment['routes'] as Map<String, dynamic>?;
          if (route != null) {
            final name = route['name']?.toString() ?? 'Route ${route['id'] ?? 'Unknown'}';
            routeNames.add(name);
          }
        } catch (e) {
          debugPrint('Error processing route assignment: $e');
        }
      }
      final activeRoutesCount = routeNames.length;

      // Get places to visit today (unvisited places in active routes)
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      int todayPlacesCount = 0;
      if (activeRoutesCount > 0) {
        try {
          // Get route IDs safely
          final routeIds = <String>[];
          for (final assignment in routeAssignmentsResponse) {
            final routeId = assignment['route_id']?.toString();
            if (routeId != null) {
              routeIds.add(routeId);
            }
          }
          
          if (routeIds.isNotEmpty) {
            // Get all route places in assigned routes
            final allRoutePlaces = await supabase
                .from('route_places')
                .select('id, place_id, visit_frequency')
                .inFilter('route_id', routeIds);
            
            // Calculate remaining visits needed for each place
            int totalVisitsNeeded = 0;
            
            for (final routePlace in allRoutePlaces) {
              try {
                final placeId = routePlace['place_id']?.toString();
                if (placeId == null) continue;
                
                final visitFrequency = (routePlace['visit_frequency'] as num?)?.toInt() ?? 1;
                
                // Count completed visits for this place by this agent
                final completedVisits = await supabase
                    .from('place_visits')
                    .select('id')
                    .eq('agent_id', userId)
                    .eq('place_id', placeId)
                    .eq('status', 'completed')
                    .count(CountOption.exact);
                
                final completedCount = completedVisits.count;
                final remainingVisits = (visitFrequency - completedCount).clamp(0, visitFrequency).toInt();
                totalVisitsNeeded += remainingVisits;
              } catch (e) {
                debugPrint('Error processing route place: $e');
                // Continue with next place
              }
            }
            
            todayPlacesCount = totalVisitsNeeded;
          }
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
        weeklyVisitsCount = weeklyVisits.count;
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
      // If there are still issues, return safe default values
      debugPrint('Critical error in route stats: $e');
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

  Future<AgentVisitAnalytics> _getComprehensiveVisitAnalytics(String userId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      // 1. Get place visits from routes
      int placeVisitsToday = 0;
      int placeVisitsThisWeek = 0;
      int placeVisitsThisMonth = 0;
      double totalDuration = 0;
      int completedVisits = 0;
      int totalVisits = 0;
      Set<String> uniqueLocations = {};
      Map<int, int> hourlyVisits = {};

      try {
        final placeVisits = await supabase
            .from('place_visits')
            .select('*')
            .eq('agent_id', userId)
            .gte('created_at', monthStart.toIso8601String());

        for (final visit in placeVisits) {
          final visitDate = DateTime.parse(visit['created_at']);
          totalVisits++;
          
          if (visit['place_id'] != null) {
            uniqueLocations.add(visit['place_id'].toString());
          }
          
          if (visitDate.isAfter(todayStart)) {
            placeVisitsToday++;
            hourlyVisits[visitDate.hour] = (hourlyVisits[visitDate.hour] ?? 0) + 1;
          }
          
          if (visitDate.isAfter(weekStart)) {
            placeVisitsThisWeek++;
          }
          
          placeVisitsThisMonth++;
          
          if (visit['status'] == 'completed') {
            completedVisits++;
            if (visit['duration_minutes'] != null) {
              totalDuration += (visit['duration_minutes'] as num).toDouble();
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading place visits: $e');
      }

      // 2. Get task-based visits (task assignments with location check-ins)
      int taskVisitsToday = 0;
      int taskVisitsThisWeek = 0;
      int taskVisitsThisMonth = 0;
      try {
        final taskAssignments = await supabase
            .from('task_assignments')
            .select('*, tasks!inner(enforce_geofence)')
            .eq('agent_id', userId)
            .inFilter('status', ['in_progress', 'completed'])
            .gte('updated_at', monthStart.toIso8601String());

        for (final assignment in taskAssignments) {
          if (assignment['tasks']?['enforce_geofence'] == true) {
            final updateDate = DateTime.parse(assignment['updated_at']);
            
            if (updateDate.isAfter(todayStart)) {
              taskVisitsToday++;
              final visitHour = updateDate.hour;
              hourlyVisits[visitHour] = (hourlyVisits[visitHour] ?? 0) + 1;
            }
            
            if (updateDate.isAfter(weekStart)) {
              taskVisitsThisWeek++;
            }
            
            taskVisitsThisMonth++;
          }
        }
      } catch (e) {
        debugPrint('Error loading task visits: $e');
      }

      // 3. Get evidence submissions (which represent field visits)
      int evidenceSubmissionsToday = 0;
      int evidenceSubmissionsThisWeek = 0;
      int evidenceSubmissionsThisMonth = 0;
      try {
        final evidenceSubmissions = await supabase
            .from('evidence')
            .select('*')
            .eq('uploader_id', userId)
            .gte('created_at', monthStart.toIso8601String());

        for (final evidence in evidenceSubmissions) {
          final submissionDate = DateTime.parse(evidence['created_at']);
          
          if (submissionDate.isAfter(todayStart)) {
            evidenceSubmissionsToday++;
            final submissionHour = submissionDate.hour;
            hourlyVisits[submissionHour] = (hourlyVisits[submissionHour] ?? 0) + 1;
          }
          
          if (submissionDate.isAfter(weekStart)) {
            evidenceSubmissionsThisWeek++;
          }
          
          evidenceSubmissionsThisMonth++;
          
          // Track unique locations from evidence
          if (evidence['latitude'] != null && evidence['longitude'] != null) {
            uniqueLocations.add('${evidence['latitude']},${evidence['longitude']}');
          }
        }
      } catch (e) {
        debugPrint('Error loading evidence submissions: $e');
      }

      // Calculate totals
      final totalVisitsToday = placeVisitsToday + taskVisitsToday + evidenceSubmissionsToday;
      final totalVisitsThisWeek = placeVisitsThisWeek + taskVisitsThisWeek + evidenceSubmissionsThisWeek;
      final totalVisitsThisMonth = placeVisitsThisMonth + taskVisitsThisMonth + evidenceSubmissionsThisMonth;

      // Get yesterday's visits for comparison
      int yesterdayVisits = 0;
      try {
        final yesterdayPlaceVisits = await supabase
            .from('place_visits')
            .select('id')
            .eq('agent_id', userId)
            .gte('created_at', yesterdayStart.toIso8601String())
            .lt('created_at', todayStart.toIso8601String())
            .count(CountOption.exact);
        
        yesterdayVisits = yesterdayPlaceVisits.count ?? 0;
      } catch (e) {
        debugPrint('Error loading yesterday visits: $e');
      }

      // Calculate metrics
      final averageVisitDuration = completedVisits > 0 ? totalDuration / completedVisits : 0.0;
      final visitCompletionRate = totalVisits > 0 ? (completedVisits / totalVisits * 100) : 0.0;
      final visitsVsYesterday = totalVisitsToday - yesterdayVisits;

      // Find peak visit hour
      String peakVisitHour = 'N/A';
      if (hourlyVisits.isNotEmpty) {
        final peakHourEntry = hourlyVisits.entries
            .reduce((a, b) => a.value > b.value ? a : b);
        final hour = peakHourEntry.key;
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        peakVisitHour = '$displayHour:00 $period';
      }

      return AgentVisitAnalytics(
        totalVisitsToday: totalVisitsToday,
        totalVisitsThisWeek: totalVisitsThisWeek,
        totalVisitsThisMonth: totalVisitsThisMonth,
        placeVisitsToday: placeVisitsToday,
        taskVisitsToday: taskVisitsToday,
        evidenceSubmissionsToday: evidenceSubmissionsToday,
        averageVisitDuration: averageVisitDuration,
        visitCompletionRate: visitCompletionRate,
        uniqueLocationsVisited: uniqueLocations.length,
        visitsVsYesterday: visitsVsYesterday,
        peakVisitHour: peakVisitHour,
      );
    } catch (e) {
      debugPrint('Error in comprehensive visit analytics: $e');
      return AgentVisitAnalytics(
        totalVisitsToday: 0,
        totalVisitsThisWeek: 0,
        totalVisitsThisMonth: 0,
        placeVisitsToday: 0,
        taskVisitsToday: 0,
        evidenceSubmissionsToday: 0,
        averageVisitDuration: 0.0,
        visitCompletionRate: 0.0,
        uniqueLocationsVisited: 0,
        visitsVsYesterday: 0,
        peakVisitHour: 'N/A',
      );
    }
  }

  void _setupAgentNotificationManager() {
    debugPrint('🚀 Setting up NotificationManager for AGENT screen');
    
    // Initialize NotificationManager lazily for agent
    _notificationManager = NotificationManager();
    
    // Setup callback for notification count changes for agent
    _notificationManager!.setOnNotificationCountChanged((count) {
      debugPrint('📊 Agent screen: Notification count callback triggered: $count');
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
        debugPrint('✅ Agent screen: Badge count updated to: $count');
      } else {
        debugPrint('❌ Agent screen: Widget not mounted, skipping update');
      }
    });

    // Setup callback for received notifications (show in-app notification) for agent
    _notificationManager!.setOnNotificationReceived((title, message, type) {
      debugPrint('🔔 Agent screen: Notification received callback: $title - $message');
      if (mounted) {
        debugPrint('✅ Agent screen: Showing in-app notification');
        _notificationManager!.showInAppNotification(
          context,
          title: title,
          message: message,
          type: type,
        );
        debugPrint('✅ Agent screen: In-app notification displayed');
      } else {
        debugPrint('❌ Agent screen: Widget not mounted, skipping notification');
      }
    });
    
    debugPrint('✅ Agent screen: NotificationManager setup completed');
  }

  Future<void> _loadNotificationCount() async {
    try {
      debugPrint('Loading notification count for agent user: ${supabase.auth.currentUser?.id}');
      final count = await _notificationService.getUnreadCount();
      debugPrint('Agent notification count loaded: $count');
      debugPrint('Setting agent _unreadNotificationCount to: $count');
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
        debugPrint('Agent state updated, _unreadNotificationCount is now: $_unreadNotificationCount');
        debugPrint('Agent badge should show: ${_unreadNotificationCount > 0}');
      }
    } catch (e) {
      // Silently handle notification count errors and set to 0
      debugPrint('Error loading agent notification count: $e');
      if (mounted) {
        setState(() {
          _unreadNotificationCount = 0;
        });
      }
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
                        title: AppLocalizations.of(context)!.youreOffline,
                        subtitle: AppLocalizations.of(context)!.offlineMessage,
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
                            AppLocalizations.of(context)!.errorLoadingDashboard,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.pleaseTryAgainLater,
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
                            child: Text(AppLocalizations.of(context)!.retry),
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
                                  AppLocalizations.of(context)!.agentDashboard,
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
                                    primaryColor.withValues(alpha: 0.15),
                                    secondaryColor.withValues(alpha: 0.1),
                                    primaryColor.withValues(alpha: 0.05),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                              child: SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Profile Avatar
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  primaryColor,
                                                  primaryColor.withValues(alpha: 0.8),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: primaryColor.withValues(alpha: 0.3),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          
                                          // Agent Info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Greeting with time-based message
                                                Text(
                                                  _getTimeBasedGreeting(),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: textSecondaryColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 1),
                                                
                                                // Agent Name
                                                Text(
                                                  widget.user.fullName ?? AppLocalizations.of(context)!.agent,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: textPrimaryColor,
                                                    height: 1.1,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          // Action Buttons Row
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Notification Button
                                              _buildHeaderIconButton(
                                                icon: Icons.notifications_outlined,
                                                hasNotification: _unreadNotificationCount > 0,
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => const NotificationsScreen(),
                                                    ),
                                                  ).then((_) {
                                                    // Refresh notification count when returning
                                                    _loadNotificationCount();
                                                  });
                                                },
                                              ),
                                              const SizedBox(width: 6),
                                              
                                              // App Health Button
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.9),
                                                  borderRadius: BorderRadius.circular(18),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.1),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: IconButton(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => const AppHealthScreen(),
                                                      ),
                                                    );
                                                  },
                                                  icon: Icon(
                                                    Icons.health_and_safety_outlined,
                                                    color: primaryColor,
                                                    size: 18,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      // Time Row
                                      Row(
                                        children: [
                                          const Spacer(),
                                          
                                          // Time display
                                          Text(
                                            _getCurrentTime(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: textSecondaryColor,
                                            ),
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
                              // Background Services Control (Compact)
                              const ServiceControlWidget(isCompact: true),
                              const SizedBox(height: 20),
                              
                              // Performance Overview
                              _buildPerformanceOverview(data),
                              const SizedBox(height: 20),
                              
                              // Quick Stats Grid
                              _buildQuickStatsGrid(data),
                              const SizedBox(height: 24),
                              
                              // Quick Actions
                              _buildQuickActionsSection(context),
                              
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
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.offlineFeatureMessage,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
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
                AppLocalizations.of(context)!.todaysActivity,
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
                  title: AppLocalizations.of(context)!.routes,
                  value: data.routeStats.activeRoutes > 0 
                      ? '${data.routeStats.placesToVisitToday} ${AppLocalizations.of(context)!.places}'
                      : AppLocalizations.of(context)!.noneAssigned,
                  subtitle: data.routeStats.activeRoutes > 0 
                      ? AppLocalizations.of(context)!.toVisitToday
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
                  title: AppLocalizations.of(context)!.tasks,
                  value: data.taskStats.activeTasks > 0 
                      ? '${data.taskStats.activeTasks} ${AppLocalizations.of(context)!.active}'
                      : AppLocalizations.of(context)!.noneActive,
                  subtitle: data.taskStats.todayCompleted > 0 
                      ? '${data.taskStats.todayCompleted} ${AppLocalizations.of(context)!.completedToday}'
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
                        AppLocalizations.of(context)!.campaigns,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                      Text(
                        data.campaignStats.activeCampaigns > 0 
                            ? '${data.campaignStats.activeCampaigns} ${AppLocalizations.of(context)!.activeCampaign}${data.campaignStats.activeCampaigns != 1 ? 's' : ''}'
                            : AppLocalizations.of(context)!.noActiveCampaigns,
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
                      '${data.campaignStats.totalCampaignTasks} ${AppLocalizations.of(context)!.tasks}',
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

  // Get time-based greeting message
  String _getTimeBasedGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    
    if (hour >= 5 && hour < 12) {
      return AppLocalizations.of(context)!.goodMorning;
    } else if (hour >= 12 && hour < 17) {
      return AppLocalizations.of(context)!.goodAfternoon; 
    } else if (hour >= 17 && hour < 21) {
      return AppLocalizations.of(context)!.goodEvening;
    } else {
      return AppLocalizations.of(context)!.goodEvening; // Use good evening for night
    }
  }

  String _getCurrentTime() {
    // Baghdad timezone (UTC+3)
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final hour12 = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  // Get today's status based on activity
  String _getTodayStatus(AgentDashboardData data) {
    if (data.routeStats.activeRoutes > 0) {
      return AppLocalizations.of(context)!.onRoute;
    } else if (data.taskStats.activeTasks > 0) {
      return AppLocalizations.of(context)!.workingTasks;
    } else if (data.campaignStats.activeCampaigns > 0) {
      return AppLocalizations.of(context)!.inCampaign;
    } else {
      return AppLocalizations.of(context)!.available;
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
        'title': AppLocalizations.of(context)!.visitAnalytics,
        'value': data.visitAnalytics.primaryMetric,
        'subtitle': AppLocalizations.of(context)!.visitsToday,
        'icon': Icons.analytics,
        'color': Colors.green,
        'trend': data.visitAnalytics.trendIndicator,
      },
      {
        'title': AppLocalizations.of(context)!.activeTasks,
        'value': '${data.taskStats.activeTasks}',
        'subtitle': AppLocalizations.of(context)!.tasksInProgress,
        'icon': Icons.assignment,
        'color': primaryColor,
        'trend': '${data.taskStats.todayCompleted} completed today',
      },
      {
        'title': AppLocalizations.of(context)!.totalPoints,
        'value': '${data.taskStats.totalPoints}',
        'subtitle': AppLocalizations.of(context)!.pointsEarned,
        'icon': Icons.star,
        'color': Colors.amber,
        'trend': '${data.taskStats.weeklyCompleted} completed this week',
      },
      {
        'title': AppLocalizations.of(context)!.activeCampaigns,
        'value': '${data.campaignStats.activeCampaigns}',
        'subtitle': AppLocalizations.of(context)!.campaignsRunning,
        'icon': Icons.campaign,
        'color': secondaryColor,
        'trend': '${data.campaignStats.totalCampaignTasks} total tasks',
      },
      {
        'title': AppLocalizations.of(context)!.activeRoutes,
        'value': data.routeStats.routeNames.isNotEmpty 
            ? data.routeStats.routeNames.first 
            : '${data.routeStats.activeRoutes}',
        'subtitle': data.routeStats.routeNames.isNotEmpty 
            ? '${data.routeStats.activeRoutes} ${AppLocalizations.of(context)!.routesAssignedSuffix}${data.routeStats.activeRoutes != 1 ? 's' : ''} ${AppLocalizations.of(context)!.assigned}'
            : AppLocalizations.of(context)!.routesAssigned,
        'icon': Icons.route,
        'color': Colors.purple,
        'trend': data.routeStats.routeNames.length > 1 
            ? '+${data.routeStats.routeNames.length - 1} more routes'
            : '${data.routeStats.placesToVisitToday} places today',
      },
    ];

    return Column(
      children: [
        // Visit Analytics Card - Full width
        _buildDynamicStatCard(
          title: stats[0]['title'] as String,
          value: stats[0]['value'] as String,
          subtitle: stats[0]['subtitle'] as String,
          icon: stats[0]['icon'] as IconData,
          color: stats[0]['color'] as Color,
          trend: stats[0]['trend'] as String,
          isLarge: true,
          details: _buildVisitAnalyticsDetails(data.visitAnalytics),
        ),
        const SizedBox(height: 12),
        // First row
        Row(
          children: [
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
            const SizedBox(width: 12),
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
          ],
        ),
        const SizedBox(height: 12),
        // Second row
        Row(
          children: [
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
            const SizedBox(width: 12),
            Expanded(
              child: _buildDynamicStatCard(
                title: stats[4]['title'] as String,
                value: stats[4]['value'] as String,
                subtitle: stats[4]['subtitle'] as String,
                icon: stats[4]['icon'] as IconData,
                color: stats[4]['color'] as Color,
                trend: stats[4]['trend'] as String,
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
    bool isLarge = false,
    Widget? details,
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
          
          // Details section for large cards
          if (details != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            details,
          ],
        ],
      ),
    );
  }

  // Visit Analytics Details
  Widget _buildVisitAnalyticsDetails(AgentVisitAnalytics analytics) {
    return Column(
      children: [
        // Visit breakdown
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMiniStat(
              icon: Icons.location_on,
              value: analytics.placeVisitsToday.toString(),
              label: AppLocalizations.of(context)!.places,
              color: Colors.blue,
            ),
            _buildMiniStat(
              icon: Icons.task_alt,
              value: analytics.taskVisitsToday.toString(),
              label: AppLocalizations.of(context)!.tasks,
              color: Colors.orange,
            ),
            _buildMiniStat(
              icon: Icons.camera_alt,
              value: analytics.evidenceSubmissionsToday.toString(),
              label: AppLocalizations.of(context)!.evidence,
              color: Colors.purple,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Performance metrics
        Row(
          children: [
            Expanded(
              child: _buildMetricRow(
                label: AppLocalizations.of(context)!.completionRate,
                value: '${analytics.visitCompletionRate.toStringAsFixed(1)}%',
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricRow(
                label: AppLocalizations.of(context)!.peakHour,
                value: analytics.peakVisitHour,
                icon: Icons.schedule,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricRow(
                label: AppLocalizations.of(context)!.avgDuration,
                value: '${analytics.averageVisitDuration.toStringAsFixed(0)} min',
                icon: Icons.timer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricRow(
                label: AppLocalizations.of(context)!.weekTotal,
                value: analytics.totalVisitsThisWeek.toString(),
                icon: Icons.calendar_view_week,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricRow(
                label: AppLocalizations.of(context)!.monthTotal,
                value: analytics.totalVisitsThisMonth.toString(),
                icon: Icons.calendar_month,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricRow(
                label: AppLocalizations.of(context)!.uniqueLocations,
                value: analytics.uniqueLocationsVisited.toString(),
                icon: Icons.place,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: textSecondaryColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textSecondaryColor,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Quick Actions Section
  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.quickActions,
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
          childAspectRatio: 1.2,
          children: [
            _buildQuickActionItem(
              icon: Icons.add_location_alt,
              label: AppLocalizations.of(context)!.suggest,
              color: Colors.indigo,
              onTap: () async {
                if (await _checkBackgroundServicesEnabled(context)) {
                  _suggestNewPlace(context);
                }
              },
            ),
            _buildQuickActionItem(
              icon: Icons.map,
              label: AppLocalizations.of(context)!.map,
              color: Colors.teal,
              onTap: () async {
                if (await _checkBackgroundServicesEnabled(context)) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AgentGeofenceMapScreen(),
                    ),
                  );
                }
              },
            ),
            _buildQuickActionItem(
              icon: Icons.quiz,
              label: 'Surveys',
              color: Colors.purple,
              onTap: () async {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AgentGlobalSurveyDashboardScreen(),
                  ),
                );
              },
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
                  Text(AppLocalizations.of(context)!.suggestNewPlace),
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
                        decoration: InputDecoration(
                          labelText: '${AppLocalizations.of(context)!.placeName} *',
                          hintText: AppLocalizations.of(context)!.enterPlaceName,
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Description Field
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: '${AppLocalizations.of(context)!.description} (${AppLocalizations.of(context)!.optional})',
                          hintText: AppLocalizations.of(context)!.describePlaceHint,
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Address Field
                      TextField(
                        controller: addressController,
                        decoration: InputDecoration(
                          labelText: '${AppLocalizations.of(context)!.address} (${AppLocalizations.of(context)!.optional})',
                          hintText: AppLocalizations.of(context)!.enterAddress,
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
                                Text(
                                  AppLocalizations.of(context)!.location,
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
                                AppLocalizations.of(context)!.noLocationSelected,
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
                                label: Text(selectedLat != null ? AppLocalizations.of(context)!.changeLocation : AppLocalizations.of(context)!.selectLocationOnMap),
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
                                  Text(
                                    AppLocalizations.of(context)!.geofenceRadius,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${geofenceRadius.round()} ${AppLocalizations.of(context)!.meters}',
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
                  child: Text(AppLocalizations.of(context)!.cancel),
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
                  child: Text(AppLocalizations.of(context)!.submitSuggestion),
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
      context.showSnackBar(AppLocalizations.of(context)!.fillRequiredFields, isError: true);
      return;
    }

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        context.showSnackBar(AppLocalizations.of(context)!.authenticationRequired, isError: true);
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
        context.showSnackBar(AppLocalizations.of(context)!.placeSuggestionSubmitted);
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Show error message
        context.showSnackBar(
          '${AppLocalizations.of(context)!.failedToSubmitSuggestion}: $e',
          isError: true,
        );
      }
    }
  }
}

// Agent Campaigns Tab
class _AgentCampaignsTab extends StatefulWidget {
  @override
  State<_AgentCampaignsTab> createState() => _AgentCampaignsTabState();
}

class _AgentCampaignsTabState extends State<_AgentCampaignsTab> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkBackgroundServices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.data == false) {
          return _buildServiceRequiredView();
        }
        
        return CampaignsListScreen(locationService: LocationService());
      },
    );
  }
  
  Future<bool> _checkBackgroundServices() async {
    try {
      return await PersistentServiceManager.areServicesRunning();
    } catch (e) {
      return true; // Allow access if check fails
    }
  }
  
  Widget _buildServiceRequiredView() {
    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.settings_backup_restore,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.backgroundServicesRequired,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.backgroundServicesRequiredDescription,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Agent Tasks Tab
class _AgentTasksTab extends StatefulWidget {
  @override
  State<_AgentTasksTab> createState() => _AgentTasksTabState();
}

class _AgentTasksTabState extends State<_AgentTasksTab> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkBackgroundServices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.data == false) {
          return _buildServiceRequiredView();
        }
        
        return const AgentStandaloneTasksScreen();
      },
    );
  }
  
  Future<bool> _checkBackgroundServices() async {
    try {
      return await PersistentServiceManager.areServicesRunning();
    } catch (e) {
      return true; // Allow access if check fails
    }
  }
  
  Widget _buildServiceRequiredView() {
    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_late,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              Text(
                'Background Services Required',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Background services must be enabled to view and complete tasks. Please enable them from the Dashboard.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Profile Tab
class _ProfileTab extends StatelessWidget {
  final AppUser user;
  
  const _ProfileTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: SafeArea(
        bottom: false, // Don't apply safe area to bottom since we have bottom navigation
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Add bottom padding for navigation bar
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
            title: AppLocalizations.of(context)!.groupManagement,
            subtitle: AppLocalizations.of(context)!.manageGroupsDesc,
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
            title: AppLocalizations.of(context)!.settings,
            subtitle: AppLocalizations.of(context)!.settingsDesc,
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
        
        // App Health for agents only, nothing for managers
        if (user.role == 'agent') ...[
          _buildOptionCard(
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
        const SizedBox(height: 12),
        _buildOptionCard(
          icon: Icons.help_outline,
          title: AppLocalizations.of(context)!.helpSupport,
          subtitle: AppLocalizations.of(context)!.helpSupportDesc,
          onTap: () {
            // Feature coming soon - help and support page will be implemented here
            context.showSnackBar(AppLocalizations.of(context)!.helpSupportComingSoon);
          },
        ),
        const SizedBox(height: 12),
        _buildOptionCard(
          icon: Icons.language,
          title: AppLocalizations.of(context)!.language,
          subtitle: AppLocalizations.of(context)!.languageDesc,
          onTap: () {
            showLanguageSelectionDialog(context);
          },
        ),
        const SizedBox(height: 12),
        _buildOptionCard(
          icon: Icons.info_outline,
          title: AppLocalizations.of(context)!.about,
          subtitle: AppLocalizations.of(context)!.aboutDesc,
          onTap: () {
            // Feature coming soon - about dialog will be implemented here
            context.showSnackBar(AppLocalizations.of(context)!.aboutComingSoon);
          },
        ),
        const SizedBox(height: 12),
        _buildOptionCard(
          icon: Icons.logout,
          title: AppLocalizations.of(context)!.signOut,
          subtitle: AppLocalizations.of(context)!.signOutDesc,
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
    VoidCallback? onTap,
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
            title: Text(AppLocalizations.of(context)!.signOut),
            content: Text(AppLocalizations.of(context)!.signOutConfirmation),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: errorColor),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(AppLocalizations.of(context)!.signOut),
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
          
          // Stop background notification management
          BackgroundNotificationManager().stop();
          
          // Clear FCM token
          await NotificationService().clearFCMToken();
          
          // Clean up session in database
          await SessionService().forceLogout();
          
          // Update user status to offline
          await ProfileService.instance.updateUserStatus('offline');
          
          // Stop user status service
          await UserStatusService().onUserLogout();
          
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
              '${AppLocalizations.of(context)!.failedToSignOut}: $e',
              isError: true,
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar(
          '${AppLocalizations.of(context)!.anErrorOccurred}: $e',
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
  final AgentVisitAnalytics visitAnalytics;

  AgentDashboardData({
    required this.taskStats,
    required this.earningsStats,
    required this.recentActivity,
    required this.activeTasks,
    required this.routeStats,
    required this.campaignStats,
    required this.visitAnalytics,
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

// Comprehensive Visit Analytics
class AgentVisitAnalytics {
  // Overall visit counts
  final int totalVisitsToday;
  final int totalVisitsThisWeek;
  final int totalVisitsThisMonth;
  
  // Visit breakdown by type
  final int placeVisitsToday;
  final int taskVisitsToday;
  final int evidenceSubmissionsToday;
  
  // Performance metrics
  final double averageVisitDuration; // in minutes
  final double visitCompletionRate; // percentage
  final int uniqueLocationsVisited;
  
  // Trending data
  final int visitsVsYesterday; // positive or negative change
  final String peakVisitHour; // e.g., "2:00 PM"
  
  AgentVisitAnalytics({
    required this.totalVisitsToday,
    required this.totalVisitsThisWeek,
    required this.totalVisitsThisMonth,
    required this.placeVisitsToday,
    required this.taskVisitsToday,
    required this.evidenceSubmissionsToday,
    required this.averageVisitDuration,
    required this.visitCompletionRate,
    required this.uniqueLocationsVisited,
    required this.visitsVsYesterday,
    required this.peakVisitHour,
  });
  
  // Helper to get primary metric for display
  String get primaryMetric => totalVisitsToday.toString();
  
  // Helper to get trend indicator
  String get trendIndicator {
    if (visitsVsYesterday > 0) return '+$visitsVsYesterday vs yesterday';
    if (visitsVsYesterday < 0) return '$visitsVsYesterday vs yesterday';
    return 'Same as yesterday';
  }
}
