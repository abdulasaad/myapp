// lib/screens/campaigns/campaign_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../../models/app_user.dart';
import '../../models/campaign.dart';
import '../../services/profile_service.dart';
import '../../utils/constants.dart';
import './geofence_editor_screen.dart';

class CampaignDetailScreen extends StatefulWidget {
  final Campaign campaign;
  // --- FIX: Use modern super.key constructor ---
  const CampaignDetailScreen({super.key, required this.campaign});

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  // --- FIX: Removed all unused variables and functions ---
  late Future<List<AppUser>> _assignedAgentsFuture;

  @override
  void initState() {
    super.initState();
    _assignedAgentsFuture = _fetchAssignedAgents();
  }

  Future<List<AppUser>> _fetchAssignedAgents() async {
    final agentIdsResponse = await supabase.from('campaign_agents').select('agent_id').eq('campaign_id', widget.campaign.id);
    final agentIds = agentIdsResponse.map((map) => map['agent_id'] as String).toList();
    if (agentIds.isEmpty) return [];
    
    final List<AppUser> agents = [];
    for (final agentId in agentIds) {
      final agentResponse = await supabase.from('profiles').select('id, full_name').eq('id', agentId).single();
      agents.add(AppUser.fromJson(agentResponse));
    }
    return agents;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.campaign.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildSectionHeader('Geofence', buttonLabel: 'Manage', onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => GeofenceEditorScreen(campaign: widget.campaign)));
            }),
            const SizedBox(height: 24),
            _buildSectionHeader('Assigned Agents'),
            _buildAssignedAgentsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onPressed, String? buttonLabel}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (ProfileService.instance.canManageCampaigns && onPressed != null && buttonLabel != null)
          TextButton.icon(onPressed: onPressed, icon: const Icon(Icons.add), label: Text(buttonLabel)),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.campaign.name, style: Theme.of(context).textTheme.headlineMedium),
          if (widget.campaign.description != null && widget.campaign.description!.isNotEmpty) ...[
            formSpacer,
            Text(widget.campaign.description!),
          ],
          formSpacer,
          Row(children: [
            const Icon(Icons.calendar_today, size: 16),
            const SizedBox(width: 8),
            Text('${DateFormat.yMMMd().format(widget.campaign.startDate)} - ${DateFormat.yMMMd().format(widget.campaign.endDate)}'),
          ]),
          formSpacer,
          Row(children: [
            const Icon(Icons.info_outline, size: 16),
            const SizedBox(width: 8),
            Text('Status: ${widget.campaign.status}'),
          ]),
        ]),
      ),
    );
  }
  
  Widget _buildAssignedAgentsList() {
    return FutureBuilder<List<AppUser>>(
      future: _assignedAgentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return preloader;
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        final agents = snapshot.data!;
        if (agents.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No agents assigned yet.')));
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: agents.length,
          itemBuilder: (context, index) {
            final agent = agents[index];
            return AgentEarningTile(agent: agent, campaignId: widget.campaign.id);
          },
        );
      },
    );
  }
}

class AgentEarningTile extends StatefulWidget {
  final AppUser agent;
  final String campaignId;
  // --- FIX: Use modern super.key constructor ---
  const AgentEarningTile({super.key, required this.agent, required this.campaignId});

  @override
  State<AgentEarningTile> createState() => _AgentEarningTileState();
}

class _AgentEarningTileState extends State<AgentEarningTile> {
  final logger = Logger();
  Map<String, dynamic>? _earningsData;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await supabase.rpc('get_agent_earnings_for_campaign', params: {'p_agent_id': widget.agent.id, 'p_campaign_id': widget.campaignId}).single();
      if (mounted) setState(() => _earningsData = data);
    } catch (e) {
      logger.e("Error fetching earnings for agent ${widget.agent.id}: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Text(widget.agent.fullName.substring(0, 1).toUpperCase())),
        title: Text(widget.agent.fullName),
        subtitle: _earningsData == null ? const Text('Loading earnings...') : Text('Outstanding Balance: ${_earningsData!['outstanding_balance']}'),
      )
    );
  }
}