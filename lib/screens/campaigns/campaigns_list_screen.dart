// lib/screens/campaigns/campaigns_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// ====================================================================
//  FIX: Add this import statement for the detail screen
// ====================================================================
import 'campaign_detail_screen.dart';
// ====================================================================
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
          return const Center(child: Text('No campaigns found. Create one!'));
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
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        // This line will no longer have an error
                        builder:
                            (context) =>
                                CampaignDetailScreen(campaign: campaign),
                      ),
                    );
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
