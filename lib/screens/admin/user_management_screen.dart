// lib/screens/admin/user_management_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../models/group.dart';
import '../../services/user_management_service.dart';
import '../../utils/constants.dart';
import 'create_edit_user_screen.dart';
import 'user_detail_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserManagementService _userService = UserManagementService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<AppUser> _users = [];
  List<Group> _groups = [];
  bool _isLoading = false;
  bool _hasMoreData = true;
  int _currentPage = 0;
  static const int _pageSize = 20;
  
  // Filters
  String? _roleFilter;
  String? _statusFilter;
  String? _groupFilter;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load groups for filtering
      _groups = await _userService.getAllGroups();
      
      // Load first page of users
      await _loadUsers(refresh: true);
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to load data: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUsers({bool refresh = false}) async {
    if (!refresh && !_hasMoreData) return;
    
    try {
      final page = refresh ? 0 : _currentPage;
      final users = await _userService.getUsers(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        roleFilter: _roleFilter,
        statusFilter: _statusFilter,
        groupFilter: _groupFilter,
        limit: _pageSize,
        offset: page * _pageSize,
      );

      setState(() {
        if (refresh) {
          _users = users;
          _currentPage = 0;
        } else {
          _users.addAll(users);
        }
        
        _hasMoreData = users.length == _pageSize;
        if (!refresh) _currentPage++;
      });
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to load users: $e', isError: true);
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadUsers();
    }
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _debounceSearch();
  }

  Timer? _searchTimer;
  void _debounceSearch() {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      _loadUsers(refresh: true);
    });
  }

  void _onFilterChanged() {
    _loadUsers(refresh: true);
  }

  Future<void> _createUser() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const CreateEditUserScreen(),
      ),
    );
    
    if (result == true) {
      _loadUsers(refresh: true);
    }
  }

  Future<void> _editUser(AppUser user) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreateEditUserScreen(user: user),
      ),
    );
    
    if (result == true) {
      _loadUsers(refresh: true);
    }
  }

  Future<void> _viewUserDetail(AppUser user) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => UserDetailScreen(user: user),
      ),
    );
    
    if (result == true) {
      _loadUsers(refresh: true);
    }
  }

  Future<void> _toggleUserStatus(AppUser user) async {
    final newStatus = user.status == 'active' ? 'offline' : 'active';
    final action = newStatus == 'active' ? 'activate' : 'deactivate';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action.toUpperCase()} User'),
        content: Text('Are you sure you want to $action ${user.fullName}?'),
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
      final success = await _userService.changeUserStatus(user.id, newStatus);
      if (mounted) {
        if (success) {
          context.showSnackBar('User ${action}d successfully');
          _loadUsers(refresh: true);
        } else {
          context.showSnackBar('Failed to $action user', isError: true);
        }
      }
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.fullName}? This action cannot be undone.'),
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
      final success = await _userService.deleteUser(user.id);
      if (mounted) {
        if (success) {
          context.showSnackBar('User deleted successfully');
          _loadUsers(refresh: true);
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
        title: const Text('User Management'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _loadUsers(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: _isLoading && _users.isEmpty
                ? preloader
                : _users.isEmpty
                    ? _buildEmptyState()
                    : _buildUsersList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createUser,
        label: const Text('Create User'),
        icon: const Icon(Icons.person_add),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, email, or username...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Role',
                  value: _roleFilter,
                  options: const ['admin', 'manager', 'agent'],
                  onChanged: (value) {
                    setState(() => _roleFilter = value);
                    _onFilterChanged();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Status',
                  value: _statusFilter,
                  options: const ['active', 'offline'],
                  onChanged: (value) {
                    setState(() => _statusFilter = value);
                    _onFilterChanged();
                  },
                ),
                const SizedBox(width: 8),
                if (_groups.isNotEmpty)
                  _buildFilterChip(
                    label: 'Group',
                    value: _groupFilter,
                    options: _groups.map((g) => g.id).toList(),
                    displayOptions: _groups.map((g) => g.name).toList(),
                    onChanged: (value) {
                      setState(() => _groupFilter = value);
                      _onFilterChanged();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String? value,
    required List<String> options,
    List<String>? displayOptions,
    required ValueChanged<String?> onChanged,
  }) {
    return PopupMenuButton<String?>(
      itemBuilder: (context) => [
        PopupMenuItem<String?>(
          value: null,
          child: Text('All ${label}s'),
        ),
        ...options.asMap().entries.map(
          (entry) => PopupMenuItem<String?>(
            value: entry.value,
            child: Text(displayOptions?[entry.key] ?? entry.value),
          ),
        ),
      ],
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value != null ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value != null ? '$label: ${_getDisplayValue(value, options, displayOptions)}' : label,
              style: TextStyle(
                color: value != null ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: value != null ? Colors.white : Colors.black87,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  String _getDisplayValue(String value, List<String> options, List<String>? displayOptions) {
    if (displayOptions == null) return value;
    final index = options.indexOf(value);
    return index >= 0 ? displayOptions[index] : value;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Users Found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _roleFilter != null || _statusFilter != null
                ? 'Try adjusting your search or filters'
                : 'Get started by creating your first user',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _createUser,
            icon: const Icon(Icons.person_add),
            label: const Text('Create User'),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _users.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _users.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = _users[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(AppUser user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _viewUserDetail(user),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getRoleColor(user.role),
                    radius: 20,
                    child: Text(
                      user.fullName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (user.email != null)
                          Text(
                            user.email!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        if (user.username != null)
                          Text(
                            '@${user.username}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility, size: 18),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
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
                              user.status == 'active' ? Icons.block : Icons.check_circle,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(user.status == 'active' ? 'Deactivate' : 'Activate'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
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
                        case 'view':
                          _viewUserDetail(user);
                          break;
                        case 'edit':
                          _editUser(user);
                          break;
                        case 'toggle_status':
                          _toggleUserStatus(user);
                          break;
                        case 'delete':
                          _deleteUser(user);
                          break;
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatusChip(user.role, _getRoleColor(user.role)),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    user.status ?? 'unknown',
                    (user.status ?? 'unknown') == 'active' ? Colors.green : Colors.grey,
                  ),
                  const Spacer(),
                  Text(
                    'Created ${DateFormat('MMM dd, yyyy').format(user.createdAt)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
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

