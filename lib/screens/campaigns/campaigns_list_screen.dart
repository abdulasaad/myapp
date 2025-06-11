// lib/screens/campaigns/campaigns_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/campaign.dart';
import '../../services/location_service.dart';
import '../../services/profile_service.dart';
import '../../utils/constants.dart';
import 'campaign_detail_screen.dart';
import '../agent/agent_task_list_screen.dart';

class CampaignsListScreen extends StatefulWidget {
  final LocationService locationService;
  const CampaignsListScreen({super.key, required this.locationService});

  @override
  CampaignsListScreenState createState() => CampaignsListScreenState();
}

class CampaignsListScreenState extends State<CampaignsListScreen> {
  late Future<List<Campaign>> _campaignsFuture;
  StreamSubscription<GeofenceStatus>? _geofenceStatusSubscription;
  final Map<String, bool> _geofenceStatuses = {};

  @override
  void initState() {
    super.initState();
    _campaignsFuture = _fetchCampaigns();
    if (!ProfileService.instance.canManageCampaigns) {
      _geofenceStatusSubscription = widget.locationService.geofenceStatusStream.listen((status) {
        if (mounted) {
          setState(() {
            _geofenceStatuses[status.campaignId] = status.isInside;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _geofenceStatusSubscription?.cancel();
    super.dispose();
  }

  void refreshCampaigns() {
    setState(() {
      _campaignsFuture = _fetchCampaigns();
    });
  }

  Future<List<Campaign>> _fetchCampaigns() async {
    if (!ProfileService.instance.canManageCampaigns) {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];
      
      final agentCampaignsResponse = await supabase.from('campaign_agents').select('campaign_id').eq('agent_id', userId);
      final campaignIds = agentCampaignsResponse.map((e) => e['campaign_id'] as String).toList();
      if (campaignIds.isEmpty) return [];

      // --- THE FIX: Replace the failing .in_() method ---
      // We now use the universal .filter() method, which is more robust.
      // The value needs to be in the format '(id1,id2,id3)'
      final idsFilter = '(${campaignIds.join(',')})';
      
      final response = await supabase
          .from('campaigns')
          .select()
          .filter('id', 'in', idsFilter) // <-- This is the robust solution
          .order('created_at', ascending: false);
      
      return response.map((json) => Campaign.fromJson(json)).toList();

    } else {
      // Manager's view remains the same
      final response = await supabase.from('campaigns').select().order('created_at', ascending: false);
      return response.map((json) => Campaign.fromJson(json)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Campaign>>(
      future: _campaignsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return preloader;
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No campaigns found.'));

        final campaigns = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => refreshCampaigns(),
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: campaigns.length,
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              return CampaignCard(
                campaign: campaign,
                isInsideGeofence: _geofenceStatuses[campaign.id],
                onTap: () {
                  if (ProfileService.instance.canManageCampaigns) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => CampaignDetailScreen(campaign: campaign)));
                  } else {
                    widget.locationService.setActiveCampaign(campaign.id);
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => AgentTaskListScreen(campaign: campaign)));
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

class CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final bool? isInsideGeofence;
  final VoidCallback onTap;

  const CampaignCard({
    super.key,
    required this.campaign,
    required this.isInsideGeofence,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget? statusWidget;
    if (isInsideGeofence != null) {
      final String message = isInsideGeofence! ? '✅ Inside Geofence' : '❌ Outside Geofence';
      final Color bgColor = isInsideGeofence! ? Colors.green.withAlpha(51) : Colors.red.withAlpha(51);
      statusWidget = Container(
        padding: const EdgeInsets.all(8),
        color: bgColor,
        child: Center(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
      );
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: primaryColor,
                child: Text(campaign.status.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              title: Text(campaign.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('${DateFormat.yMMMd().format(campaign.startDate)} - ${DateFormat.yMMMd().format(campaign.endDate)}'),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
            ),
            if (statusWidget != null) statusWidget,
          ],
        ),
      ),
    );
  }
}