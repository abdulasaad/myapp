// lib/screens/admin/agent_earnings_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../models/campaign.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';

class AgentEarningsDetailScreen extends StatefulWidget {
  final AppUser agent;
  final Campaign? campaign;

  const AgentEarningsDetailScreen({
    super.key,
    required this.agent,
    this.campaign,
  });

  @override
  State<AgentEarningsDetailScreen> createState() => _AgentEarningsDetailScreenState();
}

class _AgentEarningsDetailScreenState extends State<AgentEarningsDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _earningsData;
  List<Map<String, dynamic>> _campaignTasks = [];
  List<Map<String, dynamic>> _standaloneTasks = [];
  List<Map<String, dynamic>> _dailyParticipation = [];

  @override
  void initState() {
    super.initState();
    _fetchEarningsData();
  }

  Future<void> _fetchEarningsData() async {
    setState(() => _isLoading = true);
    
    try {
      // Fetch overall earnings data using the new RPC function
      final overallEarnings = await supabase.rpc('get_agent_overall_earnings', params: {
        'p_agent_id': widget.agent.id,
      }).single();

      // Fetch completed campaign tasks
      final campaignTasksResponse = await supabase
          .from('task_assignments')
          .select('''
            *,
            tasks!inner (
              id,
              title,
              description,
              points,
              campaign_id,
              campaigns!inner (
                id,
                name
              )
            )
          ''')
          .eq('agent_id', widget.agent.id)
          .eq('status', 'completed')
          .not('tasks.campaign_id', 'is', null);

      // Fetch completed standalone tasks
      final standaloneTasksResponse = await supabase
          .from('task_assignments')
          .select('''
            *,
            tasks!inner (
              id,
              title,
              description,
              points,
              campaign_id
            )
          ''')
          .eq('agent_id', widget.agent.id)
          .eq('status', 'completed')
          .filter('tasks.campaign_id', 'is', null);

      // Fetch completed touring tasks
      final touringTasksResponse = await supabase
          .from('touring_task_assignments')
          .select('''
            *,
            touring_tasks!inner (
              id,
              title,
              description,
              points,
              campaign_id,
              campaigns!inner (
                id,
                name
              )
            )
          ''')
          .eq('agent_id', widget.agent.id)
          .eq('status', 'completed');

      // Fetch daily participation data
      final dailyParticipationResponse = await supabase
          .from('campaign_daily_participation')
          .select('''
            *,
            campaigns!inner (
              id,
              name
            )
          ''')
          .eq('agent_id', widget.agent.id)
          .gt('daily_points_earned', 0)
          .order('participation_date', ascending: false);

      // Combine campaign tasks and touring tasks
      final allCampaignTasks = <Map<String, dynamic>>[];
      allCampaignTasks.addAll(campaignTasksResponse);
      
      // Add touring tasks to campaign tasks list
      for (final touringTask in touringTasksResponse) {
        allCampaignTasks.add({
          'id': touringTask['id'],
          'agent_id': touringTask['agent_id'],
          'status': touringTask['status'],
          'completed_at': touringTask['completed_at'],
          'tasks': {
            'id': touringTask['touring_tasks']['id'],
            'title': touringTask['touring_tasks']['title'],
            'description': touringTask['touring_tasks']['description'],
            'points': touringTask['touring_tasks']['points'],
            'campaign_id': touringTask['touring_tasks']['campaign_id'],
            'campaigns': touringTask['touring_tasks']['campaigns'],
          }
        });
      }

      if (mounted) {
        setState(() {
          _earningsData = overallEarnings;
          _campaignTasks = allCampaignTasks;
          _standaloneTasks = standaloneTasksResponse;
          _dailyParticipation = dailyParticipationResponse;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching earnings data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('${widget.agent.fullName} - ${AppLocalizations.of(context)!.outstandingBalance}'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchEarningsData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEarningsSummaryCard(),
                    const SizedBox(height: 24),
                    _buildCampaignTasksSection(),
                    const SizedBox(height: 24),
                    _buildStandaloneTasksSection(),
                    const SizedBox(height: 24),
                    _buildDailyParticipationSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEarningsSummaryCard() {
    final totalEarned = _earningsData?['total_earned'] ?? 0;
    final totalPaid = _earningsData?['total_paid'] ?? 0;
    final remainingPoints = totalEarned - totalPaid;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    widget.agent.fullName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.agent.fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context)!.outstandingBalance,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildEarningsStatCard(
                    title: AppLocalizations.of(context)!.totalEarned,
                    value: totalEarned.toString(),
                    icon: Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildEarningsStatCard(
                    title: AppLocalizations.of(context)!.amountPaid,
                    value: totalPaid.toString(),
                    icon: Icons.payment,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildEarningsStatCard(
              title: AppLocalizations.of(context)!.remainingPoints,
              value: remainingPoints.toString(),
              icon: Icons.account_balance_wallet,
              isHighlight: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: remainingPoints > 0 ? () => _showPaymentDialog(remainingPoints) : null,
                icon: const Icon(Icons.payment, color: Colors.white),
                label: Text(
                  AppLocalizations.of(context)!.pay,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: remainingPoints > 0 ? Colors.green : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsStatCard({
    required String title,
    required String value,
    required IconData icon,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlight 
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: isHighlight 
            ? Border.all(color: Colors.white.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$value ${AppLocalizations.of(context)!.points}',
            style: TextStyle(
              fontSize: isHighlight ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.campaignTasks,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 16),
        if (_campaignTasks.isEmpty)
          _buildEmptyState(AppLocalizations.of(context)!.noCompletedCampaignTasks)
        else
          Column(
            children: _campaignTasks.map((task) => _buildTaskCard(task, true)).toList(),
          ),
      ],
    );
  }

  Widget _buildStandaloneTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.tasks,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 16),
        if (_standaloneTasks.isEmpty)
          _buildEmptyState(AppLocalizations.of(context)!.noCompletedStandaloneTasks)
        else
          Column(
            children: _standaloneTasks.map((task) => _buildTaskCard(task, false)).toList(),
          ),
      ],
    );
  }

  Widget _buildDailyParticipationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.dailyParticipation,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 16),
        if (_dailyParticipation.isEmpty)
          _buildEmptyState(AppLocalizations.of(context)!.noDailyParticipation)
        else
          Column(
            children: _dailyParticipation.map((participation) => _buildParticipationCard(participation)).toList(),
          ),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> taskData, bool isCampaignTask) {
    final task = taskData['tasks'];
    final assignment = taskData;
    final completedDate = assignment['completed_at'] != null 
        ? DateTime.parse(assignment['completed_at'])
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isCampaignTask ? Icons.campaign : Icons.assignment,
                    color: successColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isCampaignTask && task['campaigns'] != null)
                        Text(
                          task['campaigns']['name'],
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${task['points']} ${AppLocalizations.of(context)!.points}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: successColor,
                    ),
                  ),
                ),
              ],
            ),
            if (task['description'] != null && task['description'].isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                task['description'],
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondaryColor,
                  height: 1.4,
                ),
              ),
            ],
            if (completedDate != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: successColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${AppLocalizations.of(context)!.completedOn} ${DateFormat.yMMMd().format(completedDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: successColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParticipationCard(Map<String, dynamic> participationData) {
    final participation = participationData;
    final campaign = participation['campaigns'];
    final participationDate = DateTime.parse(participation['participation_date']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat.yMMMd().format(participationDate),
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${participation['daily_points_earned']} ${AppLocalizations.of(context)!.points}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildParticipationStat(
                  AppLocalizations.of(context)!.hoursWorked,
                  participation['hours_worked'].toString(),
                  Icons.access_time,
                ),
                _buildParticipationStat(
                  AppLocalizations.of(context)!.tasksCompleted,
                  participation['tasks_completed'].toString(),
                  Icons.assignment_turned_in,
                ),
                _buildParticipationStat(
                  AppLocalizations.of(context)!.touringTasks,
                  participation['touring_tasks_completed'].toString(),
                  Icons.location_on,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipationStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: textSecondaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(int maxPayableAmount) {
    final TextEditingController paymentController = TextEditingController();
    final TextEditingController bonusController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.pay,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppLocalizations.of(context)!.agent}: ${widget.agent.fullName}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  '${AppLocalizations.of(context)!.remainingPoints}: $maxPayableAmount',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: paymentController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.paymentAmount,
                    hintText: 'Enter amount (max: $maxPayableAmount)',
                    prefixIcon: const Icon(Icons.payment),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context)!.requiredField;
                    }
                    final amount = int.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Invalid amount';
                    }
                    if (amount > maxPayableAmount) {
                      return 'Max: $maxPayableAmount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: bonusController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Bonus Amount (Optional)',
                    hintText: 'Enter bonus amount',
                    prefixIcon: const Icon(Icons.card_giftcard),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final bonus = int.tryParse(value);
                      if (bonus == null || bonus < 0) {
                        return 'Invalid bonus';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Note: Payment amount will be deducted from agent balance. Bonus amount is additional payment.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final paymentAmount = int.parse(paymentController.text);
                  final bonusAmount = bonusController.text.isNotEmpty 
                      ? int.parse(bonusController.text) 
                      : 0;
                  Navigator.of(context).pop();
                  _processPayment(paymentAmount, bonusAmount);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.pay),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processPayment(int paymentAmount, int bonusAmount) async {
    try {
      debugPrint('Starting payment process: Payment=$paymentAmount, Bonus=$bonusAmount');
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final totalPayment = paymentAmount + bonusAmount;
      final currentUser = supabase.auth.currentUser;
      
      debugPrint('Current user: ${currentUser?.id}');
      debugPrint('Agent ID: ${widget.agent.id}');

      // First check if we have the required columns
      final paymentData = {
        'agent_id': widget.agent.id,
        'amount': totalPayment,
        'paid_by_manager_id': currentUser?.id,
        'paid_at': DateTime.now().toIso8601String(),
      };

      // Try to add new columns if they exist
      try {
        paymentData['payment_amount'] = paymentAmount;
        paymentData['bonus_amount'] = bonusAmount;
        paymentData['payment_method'] = 'manual';
        paymentData['notes'] = bonusAmount > 0 
            ? 'Payment: $paymentAmount points + Bonus: $bonusAmount points'
            : 'Payment: $paymentAmount points';
      } catch (columnError) {
        debugPrint('New columns not available, using basic structure: $columnError');
      }

      debugPrint('Payment data: $paymentData');

      // Insert payment record
      final result = await supabase.from('payments').insert(paymentData).select();
      debugPrint('Payment insert result: $result');

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              bonusAmount > 0
                  ? 'Payment: $paymentAmount + Bonus: $bonusAmount completed!'
                  : 'Payment: $paymentAmount points completed!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the earnings data
        _fetchEarningsData();
      }
    } catch (e) {
      debugPrint('Payment error: $e');
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}