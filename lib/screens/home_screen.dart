// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/profile_service.dart';
// --- FIX: Corrected all import paths ---
import './campaigns/campaigns_list_screen.dart';
import './campaigns/create_campaign_screen.dart';
import './login_screen.dart';
import '../utils/constants.dart' as constants;
import './map/live_map_screen.dart';
import './agent/calibration_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final GlobalKey<CampaignsListScreenState> _campaignsListKey = GlobalKey<CampaignsListScreenState>();
  
  // Create an instance of the service to be used by the agent
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServicesBasedOnRole();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (ProfileService.instance.canManageCampaigns) return;

    if (state == AppLifecycleState.resumed) {
      ProfileService.instance.updateUserStatus('active');
    } else if (state == AppLifecycleState.paused) {
      ProfileService.instance.updateUserStatus('away');
    }
  }
  
  void _initServicesBasedOnRole() {
    // Start the location service only for agents
    if (!ProfileService.instance.canManageCampaigns) {
      _locationService.start();
    }
  }

  Future<void> _signOut() async {
    // Use the instance variable to stop the service
    _locationService.stop(); 
    await ProfileService.instance.updateUserStatus('offline');
    ProfileService.instance.clearProfile();

    try {
      await constants.supabase.auth.signOut();
    } catch (e) {
      if (mounted) context.showSnackBar('Error signing out. Please try again.', isError: true);
    }

    if (mounted) {
       Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Use the instance variable to stop the service
    _locationService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaigns'),
        actions: [
          // For Managers: Live Map Button
          if (ProfileService.instance.canManageCampaigns)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: 'Live Map',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LiveMapScreen()),
                );
              },
            ),
          // For Agents: Calibration Button
          if (!ProfileService.instance.canManageCampaigns)
            IconButton(
              icon: const Icon(Icons.satellite_alt_outlined),
              tooltip: 'GPS Calibration',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CalibrationScreen(locationService: _locationService),
                  ),
                );
              },
            ),
        ],
      ),
      // --- FIX: Included the body to resolve the "unused import" warning ---
      body: CampaignsListScreen(key: _campaignsListKey),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: constants.primaryColor),
              child: Text('Al-Tijwal App', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _signOut,
            )
          ],
        ),
      ),
      floatingActionButton: ProfileService.instance.canManageCampaigns
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const CreateCampaignScreen()),
                );
                _campaignsListKey.currentState?.refreshCampaigns();
              },
              label: const Text('New Campaign'),
              icon: const Icon(Icons.add),
              backgroundColor: constants.primaryColor,
            )
          : null,
    );
  }
}