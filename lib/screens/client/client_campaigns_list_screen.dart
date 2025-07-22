// lib/screens/client/client_campaigns_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/constants.dart';
import '../../models/campaign.dart';
import '../campaigns/campaign_detail_screen.dart';

class ClientCampaignsListScreen extends StatefulWidget {
  final List<Campaign> campaigns;

  const ClientCampaignsListScreen({
    super.key,
    required this.campaigns,
  });

  @override
  State<ClientCampaignsListScreen> createState() => _ClientCampaignsListScreenState();
}

class _ClientCampaignsListScreenState extends State<ClientCampaignsListScreen> {
  String _selectedFilter = 'all';
  List<Campaign> _filteredCampaigns = [];

  @override
  void initState() {
    super.initState();
    _applyFilter();
  }

  void _applyFilter() {
    setState(() {
      switch (_selectedFilter) {
        case 'active':
          _filteredCampaigns = widget.campaigns.where((c) => c.status == 'active').toList();
          break;
        case 'completed':
          _filteredCampaigns = widget.campaigns.where((c) => c.status == 'completed').toList();
          break;
        case 'pending':
          _filteredCampaigns = widget.campaigns.where((c) => c.status == 'pending').toList();
          break;
        default:
          _filteredCampaigns = List.from(widget.campaigns);
      }
      
      // Sort by creation date (newest first)
      _filteredCampaigns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return successColor;
      case 'completed':
        return Colors.blue;
      case 'pending':
        return warningColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('${l10n.campaigns} (${widget.campaigns.length})'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter tabs
          Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All ${l10n.campaigns}', widget.campaigns.length),
                  const SizedBox(width: 8),
                  _buildFilterChip('active', l10n.activeCampaigns, widget.campaigns.where((c) => c.status == 'active').length),
                  const SizedBox(width: 8),
                  _buildFilterChip('completed', 'Completed', widget.campaigns.where((c) => c.status == 'completed').length),
                  const SizedBox(width: 8),
                  _buildFilterChip('pending', 'Pending', widget.campaigns.where((c) => c.status == 'pending').length),
                ],
              ),
            ),
          ),
          
          // Campaigns list
          Expanded(
            child: _filteredCampaigns.isEmpty 
                ? _buildEmptyState(l10n)
                : RefreshIndicator(
                    onRefresh: () async {
                      // Refresh would typically reload data from parent
                      _applyFilter();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredCampaigns.length,
                      itemBuilder: (context, index) {
                        final campaign = _filteredCampaigns[index];
                        return _buildCampaignCard(campaign);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, int count) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
          _applyFilter();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.campaign_outlined,
              size: 60,
              color: primaryColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _getEmptyStateText(l10n),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getEmptyStateSubtitle(l10n),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: textSecondaryColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _getEmptyStateText(AppLocalizations l10n) {
    switch (_selectedFilter) {
      case 'active':
        return 'No ${l10n.activeCampaigns}';
      case 'completed':
        return 'No Completed ${l10n.campaigns}';
      case 'pending':
        return 'No Pending ${l10n.campaigns}';
      default:
        return 'No ${l10n.campaigns} Yet';
    }
  }

  String _getEmptyStateSubtitle(AppLocalizations l10n) {
    switch (_selectedFilter) {
      case 'active':
        return 'You don\'t have any active campaigns at the moment.';
      case 'completed':
        return 'You haven\'t completed any campaigns yet.';
      case 'pending':
        return 'You don\'t have any pending campaigns.';
      default:
        return 'You don\'t have any campaigns assigned yet.';
    }
  }

  Widget _buildCampaignCard(Campaign campaign) {
    final statusColor = _getStatusColor(campaign.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CampaignDetailScreen(campaign: campaign),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      campaign.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimaryColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      campaign.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Description
              if (campaign.description != null && campaign.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  campaign.description!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: textSecondaryColor,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Campaign details row
              Row(
                children: [
                  // Date range
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${DateFormat('MMM dd').format(campaign.startDate)} - ${DateFormat('MMM dd, yyyy').format(campaign.endDate)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Package type indicator
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Icon(Icons.business_center, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        campaign.packageType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}