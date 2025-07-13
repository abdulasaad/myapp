// lib/screens/manager/route_visit_analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/constants.dart';
import '../../models/place_visit.dart';
import '../../models/route_assignment.dart';
import '../../models/app_user.dart';

class RouteVisitAnalyticsScreen extends StatefulWidget {
  const RouteVisitAnalyticsScreen({super.key});

  @override
  State<RouteVisitAnalyticsScreen> createState() => _RouteVisitAnalyticsScreenState();
}

class _RouteVisitAnalyticsScreenState extends State<RouteVisitAnalyticsScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<PlaceVisit> _recentVisits = [];
  List<RouteAssignment> _activeAssignments = [];
  Map<String, dynamic> _analytics = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Load recent place visits with agent and place details
      final visitsResponse = await supabase
          .from('place_visits')
          .select('''
            *,
            places(*),
            route_assignments(
              *,
              routes(*),
              profiles:agent_id(*)
            )
          ''')
          .order('created_at', ascending: false)
          .limit(50);

      print('Recent visits response: $visitsResponse');

      List<PlaceVisit> recentVisits = [];
      for (var json in visitsResponse) {
        try {
          final visit = PlaceVisit.fromJson(json);
          recentVisits.add(visit);
        } catch (e) {
          print('Error parsing visit: $e');
        }
      }

      // Load active route assignments
      final assignmentsResponse = await supabase
          .from('route_assignments')
          .select('''
            *,
            routes(*),
            profiles:agent_id(*)
          ''')
          .inFilter('status', ['assigned', 'in_progress']);

      print('Active assignments response: $assignmentsResponse');

      List<RouteAssignment> activeAssignments = [];
      for (var json in assignmentsResponse) {
        try {
          final assignment = RouteAssignment.fromJson(json);
          activeAssignments.add(assignment);
        } catch (e) {
          print('Error parsing assignment: $e');
        }
      }

      // Calculate analytics
      final completedVisits = recentVisits.where((v) => v.status == 'completed').length;
      final activeVisits = recentVisits.where((v) => v.status == 'checked_in').length;
      final totalDuration = recentVisits
          .where((v) => v.durationMinutes != null)
          .fold(0, (sum, v) => sum + v.durationMinutes!);
      
      final analytics = {
        'totalVisits': recentVisits.length,
        'completedVisits': completedVisits,
        'activeVisits': activeVisits,
        'pendingVisits': recentVisits.where((v) => v.status == 'pending').length,
        'totalDurationHours': (totalDuration / 60).round(),
        'avgVisitDuration': recentVisits.isNotEmpty 
            ? (totalDuration / recentVisits.length).round() 
            : 0,
      };

      setState(() {
        _recentVisits = recentVisits;
        _activeAssignments = activeAssignments;
        _analytics = analytics;
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showSnackBar('Error loading analytics: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('${AppLocalizations.of(context)!.routes} ${AppLocalizations.of(context)!.visitAnalytics}'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.overview),
            Tab(text: AppLocalizations.of(context)!.recentVisits),
            Tab(text: AppLocalizations.of(context)!.activeRoutes),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildRecentVisitsTab(),
                _buildActiveRoutesTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppLocalizations.of(context)!.visitAnalytics} ${AppLocalizations.of(context)!.overview}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            const SizedBox(height: 20),
            
            // Analytics Cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _buildAnalyticsCard(
                  AppLocalizations.of(context)!.totalVisits,
                  _analytics['totalVisits']?.toString() ?? '0',
                  Icons.location_on,
                  Colors.blue,
                ),
                _buildAnalyticsCard(
                  AppLocalizations.of(context)!.completed,
                  _analytics['completedVisits']?.toString() ?? '0',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildAnalyticsCard(
                  AppLocalizations.of(context)!.activeNow,
                  _analytics['activeVisits']?.toString() ?? '0',
                  Icons.access_time,
                  Colors.orange,
                ),
                _buildAnalyticsCard(
                  AppLocalizations.of(context)!.totalHours,
                  _analytics['totalDurationHours']?.toString() ?? '0',
                  Icons.schedule,
                  Colors.purple,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Recent Activity Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.quickStats,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.timeline, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.averageVisitDuration(_analytics['avgVisitDuration']),
                        style: const TextStyle(color: textSecondaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.route, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.activeRouteAssignments(_activeAssignments.length),
                        style: const TextStyle(color: textSecondaryColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: textSecondaryColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentVisitsTab() {
    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      child: _recentVisits.isEmpty
          ? Center(
              child: Text(
                AppLocalizations.of(context)!.noRecentVisitsFound,
                style: const TextStyle(color: textSecondaryColor),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _recentVisits.length,
              itemBuilder: (context, index) {
                final visit = _recentVisits[index];
                return _buildVisitCard(visit);
              },
            ),
    );
  }

  Widget _buildVisitCard(PlaceVisit visit) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (visit.status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = AppLocalizations.of(context)!.completed;
        statusIcon = Icons.check_circle;
        break;
      case 'checked_in':
        statusColor = Colors.blue;
        statusText = AppLocalizations.of(context)!.checkedIn;
        statusIcon = Icons.access_time;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusText = AppLocalizations.of(context)!.pending;
        statusIcon = Icons.schedule;
        break;
      default:
        statusColor = Colors.grey;
        statusText = visit.status.toUpperCase();
        statusIcon = Icons.help_outline;
    }

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
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visit.place?.name ?? AppLocalizations.of(context)!.unknownPlace,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (visit.durationMinutes != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      visit.formattedDuration,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            if (visit.place?.address != null) ...[
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: textSecondaryColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      visit.place!.address!,
                      style: const TextStyle(
                        color: textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            Row(
              children: [
                Icon(Icons.person, size: 16, color: textSecondaryColor),
                const SizedBox(width: 4),
                Text(
                  '${AppLocalizations.of(context)!.agent}: ${visit.routeAssignment?.agent?.fullName ?? AppLocalizations.of(context)!.unknown}',
                  style: const TextStyle(
                    color: textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat.MMMd().add_jm().format(visit.createdAt),
                  style: const TextStyle(
                    color: textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            
            if (visit.visitNotes != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        visit.visitNotes!,
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRoutesTab() {
    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      child: _activeAssignments.isEmpty
          ? Center(
              child: Text(
                AppLocalizations.of(context)!.noActiveRouteAssignments,
                style: const TextStyle(color: textSecondaryColor),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _activeAssignments.length,
              itemBuilder: (context, index) {
                final assignment = _activeAssignments[index];
                return _buildAssignmentCard(assignment);
              },
            ),
    );
  }

  Widget _buildAssignmentCard(RouteAssignment assignment) {
    Color statusColor = assignment.status == 'in_progress' 
        ? Colors.blue 
        : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.route,
            color: statusColor,
            size: 24,
          ),
        ),
        title: Text(
          assignment.route?.name ?? 'Route ${assignment.routeId}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${AppLocalizations.of(context)!.agent}: ${assignment.agent?.fullName ?? AppLocalizations.of(context)!.unknown}',
              style: const TextStyle(color: textSecondaryColor),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    assignment.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Assigned: ${DateFormat.MMMd().format(assignment.assignedAt)}',
                  style: const TextStyle(
                    color: textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: textSecondaryColor,
          size: 16,
        ),
        onTap: () => _viewAssignmentDetails(assignment),
      ),
    );
  }

  void _viewAssignmentDetails(RouteAssignment assignment) {
    // TODO: Navigate to detailed assignment view
    context.showSnackBar(AppLocalizations.of(context)!.assignmentDetails);
  }
}