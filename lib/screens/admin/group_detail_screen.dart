// lib/screens/admin/group_detail_screen.dart

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/group_service.dart';
import '../../utils/constants.dart';
import 'create_edit_group_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final GroupService _groupService = GroupService();
  
  late Future<GroupWithMembers> _groupFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  void _loadGroup() {
    setState(() {
      _groupFuture = _groupService.getGroupWithMembers(widget.groupId);
    });
  }

  Future<void> _refreshGroup() async {
    setState(() => _isLoading = true);
    try {
      _loadGroup();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToEditGroup(GroupWithMembers groupWithMembers) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreateEditGroupScreen(group: groupWithMembers.group),
      ),
    );

    if (result == true) {
      _refreshGroup();
    }
  }

  Future<void> _removeMember(AppUser member, GroupWithMembers groupWithMembers) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove "${member.fullName}" from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _groupService.removeMembersFromGroup(groupWithMembers.group.id, [member.id]);
        _refreshGroup();
        if (mounted) {
          context.showSnackBar('${member.fullName} removed from group');
        }
      } catch (e) {
        if (mounted) {
          context.showSnackBar('Failed to remove member: $e', isError: true);
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteGroup(GroupWithMembers groupWithMembers) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Are you sure you want to delete "${groupWithMembers.group.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _groupService.deleteGroup(groupWithMembers.group.id);
        if (mounted) {
          context.showSnackBar('Group deleted successfully');
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          context.showSnackBar('Failed to delete group: $e', isError: true);
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: FutureBuilder<GroupWithMembers>(
        future: _groupFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Group Details'),
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Group Details'),
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.red[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading group',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshGroup,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final groupWithMembers = snapshot.data!;
          return Scaffold(
            appBar: AppBar(
              title: Text(groupWithMembers.group.name),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  onPressed: _isLoading ? null : _refreshGroup,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.refresh),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _navigateToEditGroup(groupWithMembers);
                        break;
                      case 'delete':
                        _deleteGroup(groupWithMembers);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Edit Group'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Delete Group', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: _refreshGroup,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Group Information Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
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
                                child: Icon(
                                  Icons.group,
                                  color: primaryColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      groupWithMembers.group.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimaryColor,
                                      ),
                                    ),
                                    Text(
                                      'Created ${_formatDate(groupWithMembers.group.createdAt)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (groupWithMembers.group.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 16),
                            Text(
                              groupWithMembers.group.description!,
                              style: const TextStyle(
                                fontSize: 16,
                                color: textSecondaryColor,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          // Group Statistics
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  'Members',
                                  groupWithMembers.memberCount.toString(),
                                  Icons.people,
                                ),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  'Manager',
                                  groupWithMembers.manager?.fullName ?? 'None',
                                  Icons.supervisor_account,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Members List
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Group Members',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimaryColor,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${groupWithMembers.memberCount} members',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (groupWithMembers.members.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No members in this group',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Edit the group to add members',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Column(
                              children: groupWithMembers.members.map((member) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[200]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _getRoleColor(member.role).withValues(alpha: 0.1),
                                      child: Text(
                                        member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          color: _getRoleColor(member.role),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      member.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(member.role.toUpperCase()),
                                        if (member.username?.isNotEmpty == true)
                                          Text('@${member.username}'),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(member.status ?? 'unknown').withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            (member.status ?? 'unknown').toUpperCase(),
                                            style: TextStyle(
                                              color: _getStatusColor(member.status ?? 'unknown'),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => _removeMember(member, groupWithMembers),
                                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                                          tooltip: 'Remove from group',
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _navigateToEditGroup(groupWithMembers),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              child: const Icon(Icons.edit),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: primaryColor, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'manager':
        return Colors.blue;
      case 'agent':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}