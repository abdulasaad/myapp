// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/location_service.dart';
import '../services/background_location_service.dart';
import '../services/profile_service.dart';
import '../services/session_service.dart';
import '../services/connectivity_service.dart';
import './campaigns/campaigns_list_screen.dart';
import './campaigns/create_campaign_screen.dart';
import './login_screen.dart';
import '../utils/constants.dart';
import './map/live_map_screen.dart';
import './agent/earnings_screen.dart';
import './agent/agent_standalone_tasks_screen.dart';
import './tasks/standalone_tasks_screen.dart';
import './calendar_screen.dart'; // Import the new calendar screen
import './reporting/location_history_screen.dart';
import './admin/settings_screen.dart';
import '../widgets/gps_status_indicator.dart';
import '../widgets/offline_widget.dart';

final logger = Logger();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ProfileService.instance.canManageCampaigns) {
      _tabController = TabController(length: 2, vsync: this);
      _tabController.addListener(() {
        if (mounted) setState(() => _currentTabIndex = _tabController.index);
      });
    }
    _initServicesBasedOnRole();
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    try {
      // Set initial state
      _isOnline = ConnectivityService().isOnline;
      
      // Listen to connectivity changes
      ConnectivityService().connectivityStream.listen((isOnline) {
        if (mounted) {
          setState(() {
            _isOnline = isOnline;
          });
          
          // Show snackbars for connectivity changes
          if (isOnline) {
            OnlineSnackBar.show(context);
          } else {
            OfflineSnackBar.show(context);
          }
        }
      });
    } catch (e) {
      logger.w('Failed to initialize connectivity listener: $e');
      // Default to offline if connectivity service is not available
      _isOnline = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Immediately validate session when app becomes active
      SessionService().validateSessionImmediately();
      
      if (!ProfileService.instance.canManageCampaigns) {
        ProfileService.instance.updateUserStatus('active');
      }
    } else if (state == AppLifecycleState.paused) {
      if (!ProfileService.instance.canManageCampaigns) {
        ProfileService.instance.updateUserStatus('away');
      }
    }
  }

  Future<void> _initServicesBasedOnRole() async {
    if (!ProfileService.instance.canManageCampaigns) {
      _locationService.start();
      await BackgroundLocationService.startLocationTracking();
    }
    
    // Set up session invalid callback to navigate to login
    SessionService().setSessionInvalidCallback(() {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    });
    
    // Start periodic session validation to prevent multiple logins
    SessionService().startPeriodicValidation();
  }

  Future<void> _signOut() async {
    _locationService.stop();
    // Stop background location service for agents
    if (!ProfileService.instance.canManageCampaigns) {
      await BackgroundLocationService.stopLocationTracking();
    }
    await ProfileService.instance.updateUserStatus('offline');
    ProfileService.instance.clearProfile();
    try {
      await SessionService().logout(); // This handles both database session invalidation and Supabase signOut
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error signing out. Please try again.',
            isError: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (ProfileService.instance.canManageCampaigns) {
      _tabController.dispose();
    }
    _locationService.stop();
    SessionService().stopPeriodicValidation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProfileService.instance.canManageCampaigns
        ? _buildManagerDashboard()
        : _buildAgentDashboard();
  }

  Widget _buildManagerDashboard() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard - ${ProfileService.instance.currentUser!.fullName}'),
        backgroundColor: _isOnline ? null : Colors.orange[700],
        actions: [
          if (!_isOnline)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 20),
                  SizedBox(width: 4),
                  Text('Offline', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          // ========== THE NEW CALENDAR BUTTON IS ADDED HERE ==========
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Events Calendar',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CalendarScreen()),
              );
            },
          ),
          // ==========================================================
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Location History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LocationHistoryScreen()),
              );
            },
          ),
          IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: 'Live Map',
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LiveMapScreen()))),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.campaign), text: 'Campaigns'),
            Tab(icon: Icon(Icons.assignment), text: 'Tasks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CampaignsListScreen(locationService: _locationService),
          const StandaloneTasksScreen(),
        ],
      ),
      drawer: _buildDrawer(),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const CreateCampaignScreen())),
              label: const Text('New Campaign'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildAgentDashboard() {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Work - ${ProfileService.instance.currentUser!.fullName}'),
        backgroundColor: _isOnline ? null : Colors.orange[700],
        actions: [
          if (!_isOnline)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 20),
                  SizedBox(width: 4),
                  Text('Offline', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          GpsStatusIndicator(locationService: _locationService),
        ],
      ),
      body: CampaignsListScreen(locationService: _locationService),
      drawer: _buildDrawer(),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: primaryColor),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ProfileService.instance.currentUser!.fullName,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
                Text(
                  ProfileService.instance.currentUser!.role,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          if (!ProfileService.instance.canManageCampaigns) ...[
            ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('Available Tasks'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AgentStandaloneTasksScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('My Earnings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const EarningsScreen()));
              },
            ),
          ],
          // The User/Group Management link that was previously here
          // is assumed to be handled by an admin-only web panel now.
          if (ProfileService.instance.role == 'admin')
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
          ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _signOut)
        ],
      ),
    );
  }
}
