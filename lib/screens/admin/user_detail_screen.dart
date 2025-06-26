// lib/screens/admin/user_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../models/group.dart';
import '../../services/user_management_service.dart';
import '../../utils/constants.dart';
import 'create_edit_user_screen.dart';

class UserDetailScreen extends StatefulWidget {
  final AppUser user;

  const UserDetailScreen({super.key, required this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final UserManagementService _userService = UserManagementService();
  List<Group> _userGroups = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  late AppUser _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final groups = await _userService.getUserGroups(_currentUser.id);
      setState(() {
        _userGroups = groups;
      });
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to load user data: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshUserData() async {
    try {
      final updatedUser = await _userService.getUserById(_currentUser.id);
      if (updatedUser != null) {
        setState(() => _currentUser = updatedUser);
      }
      await _loadUserData();
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to refresh user data: $e', isError: true);
      }
    }
  }

  Future<void> _editUser() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreateEditUserScreen(user: _currentUser),
      ),
    );
    
    if (result == true) {
      await _refreshUserData();
    }
  }

  Future<void> _toggleUserStatus() async {
    final newStatus = _currentUser.status == 'active' ? 'offline' : 'active';
    final action = newStatus == 'active' ? 'activate' : 'deactivate';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action.toUpperCase()} User'),
        content: Text('Are you sure you want to $action ${_currentUser.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'active' ? Colors.green : Colors.orange,
            ),
            child: Text(action.toUpperCase()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isUpdating = true);
      final success = await _userService.changeUserStatus(_currentUser.id, newStatus);
      
      if (mounted) {
        setState(() => _isUpdating = false);
        if (success) {
          context.showSnackBar('User ${action}d successfully');
          await _refreshUserData();
        } else {
          context.showSnackBar('Failed to $action user', isError: true);
        }
      }
    }
  }

  Future<void> _deleteUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${_currentUser.fullName}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isUpdating = true);
      final success = await _userService.deleteUser(_currentUser.id);
      
      if (mounted) {
        setState(() => _isUpdating = false);
        if (success) {
          context.showSnackBar('User deleted successfully');
          Navigator.of(context).pop(true);
        } else {
          context.showSnackBar('Failed to delete user', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentUser.fullName),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isUpdating)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_status',
                  child: Row(
                    children: [
                      Icon(
                        _currentUser.status == 'active' ? Icons.block : Icons.check_circle,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(_currentUser.status == 'active' ? 'Deactivate' : 'Activate'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (action) {
                switch (action) {
                  case 'edit':
                    _editUser();
                    break;
                  case 'toggle_status':
                    _toggleUserStatus();
                    break;
                  case 'delete':
                    _deleteUser();
                    break;
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshUserData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserHeader(),
                    const SizedBox(height: 24),
                    _buildUserDetails(),
                    const SizedBox(height: 24),
                    _buildGroupsSection(),
                    const SizedBox(height: 24),
                    _buildActivitySection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getRoleColor(_currentUser.role),
            _getRoleColor(_currentUser.role).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getRoleColor(_currentUser.role).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            radius: 30,
            child: Text(
              _currentUser.fullName[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUser.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentUser.role.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatusChip(_currentUser.status ?? 'unknown'),
                    const SizedBox(width: 8),
                    Text(
                      'Since ${DateFormat('MMM yyyy').format(_currentUser.createdAt)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUserDetails() {
    return _buildSection(
      title: 'User Details',
      children: [
        _buildDetailItem('Email', _currentUser.email ?? 'Not provided', Icons.email),
        if (_currentUser.username != null)
          _buildDetailItem('Username', '@${_currentUser.username}', Icons.person_outline),
        _buildDetailItem('Role', _currentUser.role, Icons.admin_panel_settings),
        _buildDetailItem('Status', _currentUser.status ?? 'Unknown', Icons.toggle_on),
        if (_currentUser.agentCreationLimit != null)
          _buildDetailItem('Agent Creation Limit', _currentUser.agentCreationLimit.toString(), Icons.group_add),
        _buildDetailItem('Created', DateFormat('MMM dd, yyyy at HH:mm').format(_currentUser.createdAt), Icons.access_time),
        if (_currentUser.updatedAt != null)
          _buildDetailItem('Last Updated', DateFormat('MMM dd, yyyy at HH:mm').format(_currentUser.updatedAt!), Icons.update),
      ],
    );
  }

  Widget _buildGroupsSection() {
    return _buildSection(
      title: 'Group Memberships',
      children: [
        if (_userGroups.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.grey[600]),
                const SizedBox(width: 8),
                const Text('User is not assigned to any groups'),
              ],
            ),
          )
        else
          ..._userGroups.map((group) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.group,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (group.description != null)
                            Text(
                              group.description!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildActivitySection() {
    return _buildSection(
      title: 'Recent Activity',
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.grey[600]),
              const SizedBox(width: 8),
              const Text('Activity tracking coming soon...'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey[600]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.blue;
      case 'agent':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}