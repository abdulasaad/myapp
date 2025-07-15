// lib/screens/agent/agent_touring_task_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/campaign.dart';
import '../../models/touring_task.dart';
import '../../models/campaign_geofence.dart';
import '../../services/touring_task_service.dart';
import '../../services/persistent_service_manager.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';
import 'touring_task_execution_screen.dart';

class AgentTouringTaskListScreen extends StatefulWidget {
  final Campaign campaign;
  final String agentId;

  const AgentTouringTaskListScreen({
    super.key,
    required this.campaign,
    required this.agentId,
  });

  @override
  State<AgentTouringTaskListScreen> createState() => _AgentTouringTaskListScreenState();
}

class _AgentTouringTaskListScreenState extends State<AgentTouringTaskListScreen> {
  final TouringTaskService _touringTaskService = TouringTaskService();
  late Future<List<Map<String, dynamic>>> _assignmentsFuture;
  bool _backgroundServicesRunning = false;
  Map<String, bool> _dailyCompletionStatus = {}; // Track completion status for each task
  Set<DateTime> _expandedDays = {}; // Track which day cards are expanded

  @override
  void initState() {
    super.initState();
    _loadAssignments();
    _checkBackgroundServices();
  }
  
  Future<void> _checkBackgroundServices() async {
    final isRunning = await PersistentServiceManager.areServicesRunning();
    if (mounted) {
      setState(() {
        _backgroundServicesRunning = isRunning;
      });
    }
  }
  
  bool _isTaskAvailable(String taskId) {
    final today = DateTime.now();
    final campaignStartDate = DateTime(widget.campaign.startDate.year, widget.campaign.startDate.month, widget.campaign.startDate.day);
    final campaignEndDate = DateTime(widget.campaign.endDate.year, widget.campaign.endDate.month, widget.campaign.endDate.day, 23, 59, 59);
    final currentDate = DateTime(today.year, today.month, today.day);
    
    // Check campaign date range
    final isInDateRange = !currentDate.isBefore(campaignStartDate) && !today.isAfter(campaignEndDate);
    
    // Check if task was completed today
    final isCompletedToday = _dailyCompletionStatus[taskId] ?? false;
    
    return isInDateRange && !isCompletedToday;
  }
  
  String? _getTaskUnavailableReason(String taskId) {
    final today = DateTime.now();
    final campaignStartDate = DateTime(widget.campaign.startDate.year, widget.campaign.startDate.month, widget.campaign.startDate.day);
    final campaignEndDate = DateTime(widget.campaign.endDate.year, widget.campaign.endDate.month, widget.campaign.endDate.day, 23, 59, 59);
    final currentDate = DateTime(today.year, today.month, today.day);
    
    if (currentDate.isBefore(campaignStartDate)) {
      return AppLocalizations.of(context)!.taskStartsOn(widget.campaign.startDate);
    }
    
    if (today.isAfter(campaignEndDate)) {
      return AppLocalizations.of(context)!.taskEndedOn(widget.campaign.endDate);
    }
    
    // CRITICAL: Check if task was completed today
    final isCompletedToday = _dailyCompletionStatus[taskId] ?? false;
    if (isCompletedToday) {
      return AppLocalizations.of(context)!.taskCompletedToday;
    }
    
    if (!_backgroundServicesRunning) {
      return AppLocalizations.of(context)!.enableBackgroundServicesMessage;
    }
    
    return null;
  }

  void _loadAssignments() {
    print('🔍 Loading assignments for agent: ${widget.agentId}');
    setState(() {
      _assignmentsFuture = _loadAssignmentsWithCompletionStatus();
    });
  }
  
  Future<List<Map<String, dynamic>>> _loadAssignmentsWithCompletionStatus() async {
    // Load task assignments
    print('🔍 Loading assignments for agent: ${widget.agentId} and campaign: ${widget.campaign.id}');
    final assignments = await _touringTaskService.getTouringTaskAssignmentsForAgentAndCampaign(widget.agentId, widget.campaign.id);
    
    print('📊 Found ${assignments.length} assignments for this campaign');
    for (int i = 0; i < assignments.length; i++) {
      final assignment = assignments[i];
      final task = assignment['task'] as TouringTask;
      print('📋 Assignment $i: Task ${task.title} (ID: ${task.id}) for campaign ${task.campaignId}');
    }
    
    // Check daily completion status for each task
    for (final assignment in assignments) {
      final task = assignment['task'] as TouringTask;
      final isCompletedToday = await _touringTaskService.isTaskCompletedToday(task.id, widget.agentId);
      _dailyCompletionStatus[task.id] = isCompletedToday;
    }
    
    return assignments;
  }

  Future<void> _startTouringTask(TouringTask task, CampaignGeofence geofence) async {
    // Check if it's the correct day to start the task
    final today = DateTime.now();
    final campaignStartDate = DateTime(widget.campaign.startDate.year, widget.campaign.startDate.month, widget.campaign.startDate.day);
    final campaignEndDate = DateTime(widget.campaign.endDate.year, widget.campaign.endDate.month, widget.campaign.endDate.day, 23, 59, 59);
    final currentDate = DateTime(today.year, today.month, today.day);
    
    if (currentDate.isBefore(campaignStartDate)) {
      _showValidationError(
        AppLocalizations.of(context)!.taskNotAvailableYet,
        AppLocalizations.of(context)!.taskStartsOn(widget.campaign.startDate),
      );
      return;
    }
    
    if (today.isAfter(campaignEndDate)) {
      _showValidationError(
        AppLocalizations.of(context)!.taskExpired,
        AppLocalizations.of(context)!.taskEndedOn(widget.campaign.endDate),
      );
      return;
    }
    
    // CRITICAL: Check if task was completed today
    final isCompletedToday = _dailyCompletionStatus[task.id] ?? false;
    if (isCompletedToday) {
      _showValidationError(
        AppLocalizations.of(context)!.taskCompletedToday,
        AppLocalizations.of(context)!.taskCompletedToday,
      );
      return;
    }
    
    // Check if background services are running
    final areServicesRunning = await PersistentServiceManager.areServicesRunning();
    if (!areServicesRunning) {
      _showValidationError(
        AppLocalizations.of(context)!.backgroundServicesRequired,
        AppLocalizations.of(context)!.enableBackgroundServicesMessage,
        showSettingsAction: true,
      );
      return;
    }
    
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TouringTaskExecutionScreen(
          task: task,
          geofence: geofence,
          agentId: widget.agentId,
        ),
      ),
    );

    if (result != null) {
      _loadAssignments();
    }
  }
  
  void _showValidationError(String title, String message, {bool showSettingsAction = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (showSettingsAction)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToSettings();
              },
              child: Text(AppLocalizations.of(context)!.settings),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }
  
  void _navigateToSettings() {
    // Navigate to app settings or show instructions
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.enableBackgroundServices),
        content: Text(AppLocalizations.of(context)!.backgroundServicesInstructions),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('${AppLocalizations.of(context)!.touringTasks} - ${widget.campaign.name}'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadAssignments(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _assignmentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading tasks',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: const TextStyle(color: textSecondaryColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadAssignments,
                      child: Text(AppLocalizations.of(context)!.retry),
                    ),
                  ],
                ),
              );
            }

            final assignments = snapshot.data ?? [];

            // Always show day cards, even if no assignments
            return _buildDayCardsList(assignments);
          },
        ),
      ),
    );
  }

  // Generate list of campaign days
  List<DateTime> _getCampaignDays() {
    final List<DateTime> days = [];
    final startDate = DateTime(widget.campaign.startDate.year, widget.campaign.startDate.month, widget.campaign.startDate.day);
    final endDate = DateTime(widget.campaign.endDate.year, widget.campaign.endDate.month, widget.campaign.endDate.day);
    
    DateTime currentDay = startDate;
    while (currentDay.isBefore(endDate) || currentDay.isAtSameMomentAs(endDate)) {
      days.add(currentDay);
      currentDay = currentDay.add(const Duration(days: 1));
    }
    
    return days;
  }
  
  // Check if a day is available (not in the past and within campaign dates)
  bool _isDayAvailable(DateTime day) {
    final today = DateTime.now();
    final currentDate = DateTime(today.year, today.month, today.day);
    
    return !day.isBefore(currentDate);
  }
  
  // Check if a day is today
  bool _isToday(DateTime day) {
    final today = DateTime.now();
    final currentDate = DateTime(today.year, today.month, today.day);
    
    return day.isAtSameMomentAs(currentDate);
  }
  
  // Build the list of day cards
  Widget _buildDayCardsList(List<Map<String, dynamic>> assignments) {
    final campaignDays = _getCampaignDays();
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: campaignDays.length,
      itemBuilder: (context, index) {
        final day = campaignDays[index];
        return _buildDayCard(day, assignments);
      },
    );
  }
  
  // Build a single day card
  Widget _buildDayCard(DateTime day, List<Map<String, dynamic>> assignments) {
    final isExpanded = _expandedDays.contains(day);
    final isAvailable = _isDayAvailable(day);
    final isToday = _isToday(day);
    
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: isToday ? 6 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isToday ? BorderSide(color: primaryColor, width: 2) : BorderSide.none,
        ),
        child: Column(
          children: [
            InkWell(
              onTap: isAvailable ? () {
                setState(() {
                  if (isExpanded) {
                    _expandedDays.remove(day);
                  } else {
                    _expandedDays.add(day);
                  }
                });
              } : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Day indicator
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isToday 
                            ? primaryColor 
                            : isAvailable 
                                ? primaryColor.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: isToday 
                            ? null 
                            : Border.all(
                                color: isAvailable ? primaryColor.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
                              ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isToday 
                                  ? Colors.white 
                                  : isAvailable 
                                      ? primaryColor 
                                      : Colors.grey,
                            ),
                          ),
                          Text(
                            _getShortDayName(day),
                            style: TextStyle(
                              fontSize: 10,
                              color: isToday 
                                  ? Colors.white 
                                  : isAvailable 
                                      ? primaryColor 
                                      : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Day info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _getFullDayName(day),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isAvailable ? textPrimaryColor : Colors.grey,
                                ),
                              ),
                              if (isToday) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    AppLocalizations.of(context)!.today,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.assignment,
                                size: 16,
                                color: isAvailable ? textSecondaryColor : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppLocalizations.of(context)!.tasksAvailable(assignments.length.toString()),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isAvailable ? textSecondaryColor : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Expand/collapse indicator
                    if (isAvailable)
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: textSecondaryColor,
                      )
                    else
                      Icon(
                        Icons.lock,
                        color: Colors.grey,
                      ),
                  ],
                ),
              ),
            ),
            
            // Expanded content
            if (isExpanded && isAvailable)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: assignments.isEmpty
                    ? _buildNoTasksMessage(day)
                    : Column(
                        children: assignments.map((assignment) {
                          final task = assignment['task'] as TouringTask;
                          final geofence = assignment['geofence'] as CampaignGeofence;
                          return _buildTaskCardInDay(task, geofence, day);
                        }).toList(),
                      ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Helper methods for day names
  String _getShortDayName(DateTime day) {
    const shortDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return shortDays[day.weekday - 1];
  }
  
  String _getFullDayName(DateTime day) {
    final formatter = DateFormat('EEEE, MMM d');
    return formatter.format(day);
  }
  
  // Build task card within a day (simplified version for inside day cards)
  Widget _buildTaskCardInDay(TouringTask task, CampaignGeofence geofence, DateTime day) {
    final isToday = _isToday(day);
    final isTaskAvailable = isToday ? _isTaskAvailable(task.id) : false;
    final canStart = isTaskAvailable && _backgroundServicesRunning;
    final isCompletedToday = _dailyCompletionStatus[task.id] ?? false;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.tour, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimaryColor,
                        ),
                      ),
                      if (task.description != null && task.description!.isNotEmpty)
                        Text(
                          task.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: textSecondaryColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${task.points} pts',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Task details in compact form
            Row(
              children: [
                Expanded(
                  child: _buildCompactInfoItem(
                    Icons.schedule,
                    task.formattedDuration,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactInfoItem(
                    Icons.directions_walk,
                    task.movementTimeoutText,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Start button (only available for today)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canStart ? () => _startTouringTask(task, geofence) : null,
                icon: Icon(
                  isToday && isCompletedToday 
                      ? Icons.check_circle 
                      : canStart 
                          ? Icons.play_arrow 
                          : Icons.block
                ),
                label: Text(
                  isToday && isCompletedToday 
                      ? AppLocalizations.of(context)!.taskCompleted
                      : canStart 
                          ? AppLocalizations.of(context)!.startTask 
                          : isToday 
                              ? AppLocalizations.of(context)!.taskUnavailable
                              : AppLocalizations.of(context)!.availableOnDay,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isToday && isCompletedToday 
                      ? Colors.green 
                      : canStart 
                          ? primaryColor 
                          : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Compact info item for task details
  Widget _buildCompactInfoItem(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  // Message when no tasks are assigned for a day
  Widget _buildNoTasksMessage(DateTime day) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.tour_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.noTouringTasksForDay,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.noTouringTasksDescription,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tour,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.noTouringTasksAssigned,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.noTouringTasksDescription,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAssignments,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.refresh),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(TouringTask task, CampaignGeofence geofence) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.tour, color: primaryColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimaryColor,
                          ),
                        ),
                        if (task.description != null && task.description!.isNotEmpty)
                          Text(
                            task.description!,
                            style: const TextStyle(
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
                      color: task.status == 'active' ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: task.status == 'active' ? Colors.green.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      task.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: task.status == 'active' ? Colors.green[700] : Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTaskDetails(task, geofence),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.location_on,
                      AppLocalizations.of(context)!.workZone,
                      geofence.name,
                      geofence.color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.schedule,
                      AppLocalizations.of(context)!.duration,
                      task.formattedDuration,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.directions_walk,
                      AppLocalizations.of(context)!.movementTimeout,
                      task.movementTimeoutText,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.stars,
                      AppLocalizations.of(context)!.points,
                      '${task.points}',
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildStartButton(task, geofence),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskDetails(TouringTask task, CampaignGeofence geofence) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.taskRequirements,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRequirement(
            Icons.schedule,
            AppLocalizations.of(context)!.spendTimeInWorkZone(task.formattedDuration),
          ),
          const SizedBox(height: 8),
          _buildRequirement(
            Icons.directions_walk,
            AppLocalizations.of(context)!.keepMovingTimer(task.movementTimeoutText),
          ),
          const SizedBox(height: 8),
          _buildRequirement(
            Icons.straighten,
            AppLocalizations.of(context)!.movementThreshold(task.minMovementThreshold.toStringAsFixed(1)),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStartButton(TouringTask task, CampaignGeofence geofence) {
    final isAvailable = _isTaskAvailable(task.id);
    final canStart = isAvailable && _backgroundServicesRunning;
    final reason = _getTaskUnavailableReason(task.id);
    
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canStart ? () => _startTouringTask(task, geofence) : null,
            icon: Icon(canStart ? Icons.play_arrow : Icons.block),
            label: Text(canStart ? AppLocalizations.of(context)!.startTask : AppLocalizations.of(context)!.taskUnavailable),
            style: ElevatedButton.styleFrom(
              backgroundColor: canStart ? primaryColor : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (!canStart && reason != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reason,
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}