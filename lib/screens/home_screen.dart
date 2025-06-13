// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/profile_service.dart';
import './campaigns/campaigns_list_screen.dart';
import './campaigns/create_campaign_screen.dart';
import './login_screen.dart';
import '../utils/constants.dart';
import './map/live_map_screen.dart';
import './agent/calibration_screen.dart';
import './agent/earnings_screen.dart';
import './tasks/standalone_tasks_screen.dart';

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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (ProfileService.instance.canManageCampaigns) return;
    if (state == AppLifecycleState.resumed) {
      ProfileService.instance.updateUserStatus('active');
    } else if (state == AppLifecycleState.paused) {
      ProfileService.instance.updateUserStatus('away');
    }
  }

  Future<void> _initServicesBasedOnRole() async {
    if (!ProfileService.instance.canManageCampaigns) {
      _locationService.start();
    }
  }

  Future<void> _signOut() async {
    _locationService.stop();
    await ProfileService.instance.updateUserStatus('offline');
    ProfileService.instance.clearProfile();
    try {
      await supabase.auth.signOut();
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
        title: const Text('Main Dashboard'),
        actions: [
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

  /// This is the corrected Agent Dashboard view.
  Widget _buildAgentDashboard() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Work'),
        actions: [
          IconButton(
            icon: const Icon(Icons.satellite_alt_outlined),
            tooltip: 'GPS Calibration',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    CalibrationScreen(locationService: _locationService),
              ),
            ),
          ),
        ],
      ),
      // --- THE FIX ---
      // The body is now simply the CampaignsListScreen.
      // It handles its own tabs and data fetching internally.
      // The redundant Column and FutureBuilder have been removed.
      body: CampaignsListScreen(locationService: _locationService),
      drawer: _buildDrawer(),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
              decoration: BoxDecoration(color: primaryColor),
              child: Text('Al-Tijwal App',
                  style: TextStyle(color: Colors.white, fontSize: 24))),
          if (!ProfileService.instance.canManageCampaigns)
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('My Earnings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const EarningsScreen()));
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
