// lib/screens/campaigns/campaign_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../../models/app_user.dart';
import '../../models/campaign.dart';
import '../../models/task.dart';
import '../../utils/constants.dart';

class CampaignDetailScreen extends StatefulWidget {
  final Campaign campaign;
  const CampaignDetailScreen({super.key, required this.campaign});

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  late Future<List<AppUser>> _assignedAgentsFuture;
  late Future<List<Task>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _assignedAgentsFuture = _fetchAssignedAgents();
    _tasksFuture = _fetchTasks();
  }

  // --- DATA FETCHING ---

  Future<List<AppUser>> _fetchAssignedAgents() async {
    final agentIdsResponse = await supabase.from('campaign_agents').select('agent_id').eq('campaign_id', widget.campaign.id);
    final agentIds = agentIdsResponse.map((map) => map['agent_id'] as String).toList();
    if (agentIds.isEmpty) return [];
    
    final agents = <AppUser>[];
    for (final agentId in agentIds) {
      final agentResponse = await supabase.from('profiles').select('id, full_name').eq('id', agentId).single();
      agents.add(AppUser.fromJson(agentResponse));
    }
    return agents;
  }

  Future<List<Task>> _fetchTasks() async {
    final response = await supabase
        .from('tasks')
        .select()
        .eq('campaign_id', widget.campaign.id)
        .order('created_at', ascending: true);
    return response.map((json) => Task.fromJson(json)).toList();
  }

  // --- UI ACTIONS & DIALOGS ---

  Future<void> _addTask({required String title, String? description, required int points}) async {
    try {
      await supabase.from('tasks').insert({
        'campaign_id': widget.campaign.id,
        'title': title,
        'description': description,
        'points': points,
      });
      if (mounted) {
        context.showSnackBar('Task added successfully! It has been auto-assigned.');
        
        // --- THE FIX: Use a block body {} for setState ---
        // This ensures the callback is synchronous and does not return a Future.
        setState(() {
          _tasksFuture = _fetchTasks();
        });
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to add task: $e', isError: true);
    }
  }

  Future<void> _showAddTaskDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final pointsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Task'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: titleController, decoration: const InputDecoration(labelText: 'Task Title'), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
              formSpacer,
              TextFormField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description')),
              formSpacer,
              TextFormField(controller: pointsController, decoration: const InputDecoration(labelText: 'Points'), keyboardType: TextInputType.number, validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (int.tryParse(v) == null) return 'Must be a number';
                return null;
              }),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _addTask(title: titleController.text, description: descriptionController.text, points: int.parse(pointsController.text));
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add Task'),
          )
        ],
      ),
    );
  }
  
  Future<void> _assignAgent(String agentId) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;
      await supabase.from('campaign_agents').insert({'campaign_id': widget.campaign.id, 'agent_id': agentId, 'assigned_by': currentUserId});
      if (mounted) {
        context.showSnackBar('Agent assigned successfully! Existing tasks have been auto-assigned.');
        setState(() => _assignedAgentsFuture = _fetchAssignedAgents());
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to assign agent. They may already be assigned.', isError: true);
    }
  }
  
  Future<void> _showAssignAgentDialog() async {
    final allAgentsResponse = await supabase.from('profiles').select('id, full_name').eq('role', 'agent');
    final allAgents = allAgentsResponse.map((json) => AppUser.fromJson(json)).toList();
    if (!mounted) return;

    final selectedAgent = await showDialog<AppUser>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign an Agent'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allAgents.length,
            itemBuilder: (context, index) {
              final agent = allAgents[index];
              return ListTile(title: Text(agent.fullName), onTap: () => Navigator.of(context).pop(agent));
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
      ),
    );

    if (selectedAgent != null) {
      _assignAgent(selectedAgent.id);
    }
  }

  // --- BUILD METHOD ---
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
            _buildSectionHeader('Tasks', onPressed: _showAddTaskDialog, buttonLabel: 'Add Task'),
            _buildTasksList(),
            const SizedBox(height: 24),
            _buildSectionHeader('Assigned Agents & Payments', onPressed: _showAssignAgentDialog, buttonLabel: 'Assign Agent'),
            _buildAssignedAgentsList(),
          ],
        ),
      ),
    );
  }
  
  // --- WIDGET BUILDERS ---

  Widget _buildSectionHeader(String title, {required VoidCallback onPressed, required String buttonLabel}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        TextButton.icon(onPressed: onPressed, icon: const Icon(Icons.add), label: Text(buttonLabel)),
      ],
    );
  }

  Widget _buildTasksList() {
    return FutureBuilder<List<Task>>(
      future: _tasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return preloader;
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        final tasks = snapshot.data!;
        if (tasks.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No tasks created yet.')));
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.check_box_outline_blank),
                title: Text(task.title),
                subtitle: task.description != null && task.description!.isNotEmpty ? Text(task.description!) : null,
                trailing: Text('${task.points} pts'),
              ),
            );
          },
        );
      },
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
}

class AgentEarningTile extends StatefulWidget {
  final AppUser agent;
  final String campaignId;
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
    _fetchEarnings();
  }

  Future<void> _fetchEarnings() async {
    try {
      final data = await supabase.rpc('get_agent_earnings_for_campaign', params: {'p_agent_id': widget.agent.id, 'p_campaign_id': widget.campaignId}).single();
      if (mounted) setState(() => _earningsData = data);
    } catch (e) {
      logger.e("Error fetching earnings for agent ${widget.agent.id}: $e");
    }
  }

  Future<void> _showRecordPaymentDialog() async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final outstandingBalance = _earningsData?['outstanding_balance'] ?? 0;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pay ${widget.agent.fullName}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: amountController,
            decoration: const InputDecoration(labelText: 'Amount Paid', prefixText: 'Pts '),
            keyboardType: TextInputType.number,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              final enteredAmount = int.tryParse(value);
              if (enteredAmount == null || enteredAmount <= 0) return 'Must be a positive number';
              if (enteredAmount > outstandingBalance) return 'Cannot pay more than the balance of $outstandingBalance';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _recordPayment(amount: int.parse(amountController.text));
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Confirm Payment'),
          )
        ],
      ),
    );
    if (result == true) {
      _fetchEarnings();
    }
  }

  Future<void> _recordPayment({required int amount}) async {
    try {
      await supabase.from('payments').insert({
        'campaign_id': widget.campaignId,
        'agent_id': widget.agent.id,
        'paid_by_manager_id': supabase.auth.currentUser!.id,
        'amount': amount,
        'paid_at': DateTime.now().toIso8601String(),
      });
      if (mounted) context.showSnackBar('Payment recorded successfully!');
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to record payment: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _earningsData?['outstanding_balance'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Text(widget.agent.fullName.substring(0, 1).toUpperCase())),
        title: Text(widget.agent.fullName),
        subtitle: _earningsData == null 
            ? const Text('Loading earnings...')
            : Text('Outstanding Balance: $balance points'),
        trailing: TextButton(
          onPressed: balance > 0 ? _showRecordPaymentDialog : null,
          child: const Text('PAY'),
        ),
      ),
    );
  }
}