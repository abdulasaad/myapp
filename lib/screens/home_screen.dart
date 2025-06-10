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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // We keep a single instance of the location service for the agent's session
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServicesBasedOnRole();
  }

  /// This is called when the app is minimized, resumed, etc.
  /// It helps us set the user's status correctly.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // This logic only applies to agents, not managers/admins.
    if (ProfileService.instance.canManageCampaigns) return;

    if (state == AppLifecycleState.resumed) {
      ProfileService.instance.updateUserStatus('active');
    } else if (state == AppLifecycleState.paused) {
      // "paused" covers both minimizing the app and locking the screen.
      ProfileService.instance.updateUserStatus('away');
    }
  }
  
  /// This function starts the necessary services depending on the user's role.
  Future<void> _initServicesBasedOnRole() async {
    // This logic only applies to agents.
    if (!ProfileService.instance.canManageCampaigns) {
      _locationService.start();

      // We automatically set the agent's most recent campaign as the one to track.
      try {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) return;

        final response = await supabase
            .from('campaign_agents')
            .select('campaign_id')
            .eq('agent_id', userId)
            .order('assigned_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (response != null && response['campaign_id'] != null) {
          // Tell the location service which campaign to check geofences for.
          _locationService.setActiveCampaign(response['campaign_id']);
        } else {
          logger.i("Agent is not assigned to any campaigns.");
        }
      } catch (e) {
        logger.e("Could not fetch agent's active campaign: $e");
      }
    }
  }

  /// Handles user sign-out, stopping services and updating status.
  Future<void> _signOut() async {
    // Stop the location service if it was running.
    _locationService.stop(); 
    // Set status to offline before logging out.
    await ProfileService.instance.updateUserStatus('offline');
    ProfileService.instance.clearProfile();

    try {
      await supabase.auth.signOut();
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

  /// Clean up resources when the screen is destroyed.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ProfileService.instance.canManageCampaigns ? 'Campaign Dashboard' : 'My Campaigns'),
        actions: [
          // For Managers: Show the Live Map button
          if (ProfileService.instance.canManageCampaigns)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: 'Live Map',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LiveMapScreen())),
            ),
          // For Agents: Show the GPS Calibration button
          if (!ProfileService.instance.canManageCampaigns)
            IconButton(
              icon: const Icon(Icons.satellite_alt_outlined),
              tooltip: 'GPS Calibration',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => CalibrationScreen(locationService: _locationService))),
            ),
        ],
      ),
      // The body of the scaffold now correctly passes the location service instance down.
      body: CampaignsListScreen(locationService: _locationService),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: primaryColor),
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
      // The Floating Action Button is only shown to managers/admins.
      floatingActionButton: ProfileService.instance.canManageCampaigns
          ? FloatingActionButton.extended(
              onPressed: () async {
                // We use a key to refresh the list, but it's not ideal.
                // A state management solution would be better in a larger app.
                await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreateCampaignScreen()));
              },
              label: const Text('New Campaign'),
              icon: const Icon(Icons.add),
              backgroundColor: primaryColor,
            )
          : null,
    );
  }
}