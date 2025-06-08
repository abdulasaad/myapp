// lib/screens/campaigns/campaigns_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/screens/agent/agent_campaign_view_screen.dart'; // <-- NEW IMPORT
import 'package:myapp/screens/campaigns/campaign_detail_screen.dart';
import 'package:myapp/services/user_service.dart'; // <-- NEW IMPORT
import '../../models/campaign.dart';
import '../../utils/constants.dart';

class CampaignsListScreen extends StatefulWidget {
  const CampaignsListScreen({super.key});

  @override
  CampaignsListScreenState createState() => CampaignsListScreenState();
}

class CampaignsListScreenState extends State<CampaignsListScreen> {
  late Future<List<Campaign>> _campaignsFuture;

  @override
  void initState() {
    super.initState();
    _campaignsFuture = _fetchCampaigns();
  }

  void refreshCampaigns() {
    setState(() {
      _campaignsFuture = _fetchCampaigns();
    });
  }

  Future<List<Campaign>> _fetchCampaigns() async {
    final response = await supabase
        .from('campaigns')
        .select()
        .order('created_at', ascending: false);

    return response.map((json) => Campaign.fromJson(json)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Campaign>>(
      future: _campaignsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return preloader;
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No campaigns found.'));
        }

        final campaigns = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            refreshCampaigns();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: campaigns.length,
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: primaryColor,
                    child: Text(
                      campaign.status.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    campaign.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${DateFormat.yMMMd().format(campaign.startDate)} - ${DateFormat.yMMMd().format(campaign.endDate)}',
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  // ===============================================
                  //  UPDATED: Role-based navigation logic
                  // ===============================================
                  onTap: () {
                    // If the user is a manager, go to the detail/management screen.
                    if (UserService.canManageCampaigns) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  CampaignDetailScreen(campaign: campaign),
                        ),
                      );
                    } else {
                      // If the user is an agent, go to their specialized task view.
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  AgentCampaignViewScreen(campaign: campaign),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
