// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:myapp/services/profile_service.dart';
import 'campaigns/campaigns_list_screen.dart';
import 'campaigns/create_campaign_screen.dart';
import 'login_screen.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<CampaignsListScreenState> _campaignsListKey = GlobalKey<CampaignsListScreenState>();

  Future<void> _signOut() async {
    // ===============================================
    //  NEW: Clear profile data on sign out
    // ===============================================
    ProfileService.instance.clearProfile();
    // ===============================================
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

  @override
  Widget build(BuildContext context) {
    // Check the user's role from our service
    final isManager = ProfileService.instance.role == 'manager' || ProfileService.instance.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaigns'),
      ),
      body: CampaignsListScreen(key: _campaignsListKey),
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
      // ===============================================
      //  NEW: Only show the button if user is a manager/admin
      // ===============================================
      floatingActionButton: isManager ? FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CreateCampaignScreen()),
          );
          _campaignsListKey.currentState?.refreshCampaigns();
        },
        label: const Text('New Campaign'),
        icon: const Icon(Icons.add),
        backgroundColor: primaryColor,
      ) : null, // If not a manager, show nothing
    );
  }
}
