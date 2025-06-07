// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
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
  // A GlobalKey to access the state of CampaignsListScreen and call its refresh method.
  final GlobalKey<CampaignsListScreenState> _campaignsListKey = GlobalKey<CampaignsListScreenState>();

  Future<void> _signOut() async {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaigns'),
        automaticallyImplyLeading: true,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to the create screen
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CreateCampaignScreen()),
          );
          // When we come back, refresh the list of campaigns
          _campaignsListKey.currentState?.refreshCampaigns();
        },
        label: const Text('New Campaign'),
        icon: const Icon(Icons.add),
        backgroundColor: primaryColor,
      ),
    );
  }
}
