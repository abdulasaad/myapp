// lib/screens/manager/team_members_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../services/user_management_service.dart';
import '../../utils/constants.dart';

class TeamMembersScreen extends StatefulWidget {
  const TeamMembersScreen({super.key});

  @override
  State<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends State<TeamMembersScreen> {
  late Future<List<TeamMemberInfo>> _teamMembersFuture;
  String _filterStatus = 'all'; // all, active, offline
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _teamMembersFuture = _fetchTeamMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<TeamMemberInfo>> _fetchTeamMembers() async {
    try {
      // Use UserManagementService to get agents filtered by manager's groups
      final agents = await UserManagementService().getUsers(
        roleFilter: 'agent',
        statusFilter: null, // We'll filter by status in UI
      );

      // Get additional info for each agent
      final teamMembers = <TeamMemberInfo>[];
      
      for (final agent in agents) {
        // Get agent's active tasks count
        final activeTasksResponse = await supabase
            .from('task_assignments')
            .select('id')
            .eq('agent_id', agent.id)
            .inFilter('status', ['assigned', 'in_progress']);

        // Get agent's groups
        final userGroupsResponse = await supabase
            .from('user_groups')
            .select('''
              groups!inner(name)
            ''')
            .eq('user_id', agent.id);

        final groupNames = userGroupsResponse
            .map((item) => item['groups']['name'] as String)
            .toList();

        teamMembers.add(TeamMemberInfo(
          user: agent,
          activeTasks: activeTasksResponse.length,
          groupNames: groupNames,
        ));
      }

      return teamMembers;
    } catch (e) {
      debugPrint('Error fetching team members: $e');
      return [];
    }
  }

  List<TeamMemberInfo> _filterTeamMembers(List<TeamMemberInfo> members) {
    var filteredMembers = members;

    // Apply status filter
    switch (_filterStatus) {
      case 'active':
        filteredMembers = filteredMembers.where((m) => m.user.status == 'active').toList();
        break;
      case 'offline':
        filteredMembers = filteredMembers.where((m) => m.user.status != 'active').toList();
        break;
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredMembers = filteredMembers.where((m) {
        final name = m.user.fullName.toLowerCase();
        final email = (m.user.email ?? '').toLowerCase();
        final username = (m.user.username ?? '').toLowerCase();
        
        return name.contains(query) || 
               email.contains(query) || 
               username.contains(query);
      }).toList();
    }

    return filteredMembers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: _showSearchBar 
            ? TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search team members...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text('Team Members'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_showSearchBar ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _filterStatus = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Members')),
              const PopupMenuItem(value: 'active', child: Text('Active')),
              const PopupMenuItem(value: 'offline', child: Text('Offline')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filterStatus != 'all' || _searchQuery.isNotEmpty)
            _buildFilterIndicator(),
          Expanded(
            child: FutureBuilder<List<TeamMemberInfo>>(
              future: _teamMembersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'Unable to load team members',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please check your connection and try again',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _teamMembersFuture = _fetchTeamMembers();
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final allMembers = snapshot.data ?? [];
                final filteredMembers = _filterTeamMembers(allMembers);

                if (filteredMembers.isEmpty) {
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
                            Icons.group_off,
                            size: 60,
                            color: primaryColor.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _getEmptyMessage(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textPrimaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getEmptySubtitle(),
                          style: TextStyle(
                            fontSize: 16,
                            color: textSecondaryColor,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _teamMembersFuture = _fetchTeamMembers();
                    });
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = filteredMembers[index];
                      return _buildTeamMemberCard(member);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterIndicator() {
    final chips = <Widget>[];
    
    if (_filterStatus != 'all') {
      String filterText;
      switch (_filterStatus) {
        case 'active':
          filterText = 'Active';
          break;
        case 'offline':
          filterText = 'Offline';
          break;
        default:
          filterText = _filterStatus;
      }
      
      chips.add(
        Chip(
          label: Text(filterText),
          onDeleted: () {
            setState(() {
              _filterStatus = 'all';
            });
          },
          deleteIcon: const Icon(Icons.close, size: 18),
        ),
      );
    }
    
    if (_searchQuery.isNotEmpty) {
      chips.add(
        Chip(
          label: Text('Search: "$_searchQuery"'),
          onDeleted: () {
            setState(() {
              _searchQuery = '';
              _searchController.clear();
            });
          },
          deleteIcon: const Icon(Icons.close, size: 18),
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
      ),
      child: Wrap(
        spacing: 8,
        children: [
          ...chips,
          if (chips.length > 1)
            ActionChip(
              label: const Text('Clear All'),
              onPressed: () {
                setState(() {
                  _filterStatus = 'all';
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
        ],
      ),
    );
  }

  String _getEmptyMessage() {
    if (_searchQuery.isNotEmpty) {
      return 'No members found';
    }
    
    switch (_filterStatus) {
      case 'active':
        return 'No active members';
      case 'offline':
        return 'No offline members';
      default:
        return 'No team members found';
    }
  }

  String _getEmptySubtitle() {
    if (_searchQuery.isNotEmpty) {
      return 'No members match "$_searchQuery".\nTry adjusting your search terms.';
    }
    
    switch (_filterStatus) {
      case 'active':
        return 'All team members are currently offline.\nCheck back later for active members.';
      case 'offline':
        return 'All team members are currently active.\nGreat job keeping the team engaged!';
      default:
        return 'You don\'t have any team members assigned to your groups yet.\nContact your administrator to add agents to your groups.';
    }
  }

  Widget _buildTeamMemberCard(TeamMemberInfo member) {
    final user = member.user;
    final isOnline = user.status == 'active';
    final statusColor = isOnline ? successColor : Colors.grey;
    
    // Get last seen text (for demo purposes, showing created date)
    final lastSeenText = isOnline 
        ? 'Active now' 
        : 'Last seen ${DateFormat.MMMd().add_jm().format(user.createdAt)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: statusColor,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  _getInitials(user.fullName),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Member info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimaryColor,
                          ),
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (user.username != null)
                    Text(
                      '@${user.username}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: textSecondaryColor,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    lastSeenText,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOnline ? successColor : textSecondaryColor,
                      fontWeight: isOnline ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Stats row
                  Row(
                    children: [
                      Icon(Icons.assignment, size: 16, color: Colors.blue[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${member.activeTasks} active tasks',
                        style: const TextStyle(
                          fontSize: 12,
                          color: textSecondaryColor,
                        ),
                      ),
                      if (member.groupNames.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.group, size: 16, color: Colors.green[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            member.groupNames.join(', '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: textSecondaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Action menu button
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'details':
                    _showMemberDetails(member);
                    break;
                  case 'edit_name':
                    await _showEditNameDialog(member);
                    break;
                  case 'reset_password':
                    await _showPasswordResetDialog(member);
                    break;
                }
              },
              icon: const Icon(Icons.more_vert, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.withValues(alpha: 0.1),
                foregroundColor: textSecondaryColor,
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18),
                      SizedBox(width: 8),
                      Text('View Details'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit_name',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Edit Name', style: TextStyle(color: Colors.blue)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset_password',
                  child: Row(
                    children: [
                      Icon(Icons.lock_reset, size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Reset Password', style: TextStyle(color: Colors.orange)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  Future<void> _showEditNameDialog(TeamMemberInfo member) async {
    final TextEditingController nameController = TextEditingController(text: member.user.fullName);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text('Edit Agent Name'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit name for @${member.user.username ?? 'agent'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              
              // Name Requirements
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Name Requirements',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...[ 
                      'At least 2 characters long',
                      'Contains at least one letter',
                      'Only letters, spaces, hyphens, periods, and commas',
                      'Maximum 100 characters',
                    ].map((requirement) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, 
                            size: 12, color: Colors.blue[600]),
                          const SizedBox(width: 6),
                          Text(
                            requirement,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Name Input Field
              TextFormField(
                controller: nameController,
                validator: (value) {
                  return UserManagementService().validateFullName(value ?? '');
                },
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter agent full name',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              
              const SizedBox(height: 16),
              
              // Warning
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_rounded, color: Colors.blue[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will update the agent\'s display name throughout the system.',
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Name'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != member.user.fullName && mounted) {
      await _performNameUpdate(member, newName);
    }
  }

  Future<void> _showPasswordResetDialog(TeamMemberInfo member) async {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool showPassword = false;
    bool showConfirmPassword = false;

    final newPassword = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black54,
        resizeToAvoidBottomInset: false,
        body: Center(
          child: StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.lock_reset, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  const Text('Reset Password'),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enter new password for ${member.user.fullName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Password Requirements
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Password Requirements',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue[800],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...[ 
                                'At least 8 characters long',
                                'Contains uppercase letters (A-Z)',
                                'Contains lowercase letters (a-z)',
                                'Contains at least one number (0-9)',
                              ].map((requirement) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_outline, 
                                      size: 12, color: Colors.blue[600]),
                                    const SizedBox(width: 6),
                                    Text(
                                      requirement,
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // New Password Field
                        TextFormField(
                          controller: passwordController,
                          obscureText: !showPassword,
                          validator: (value) {
                            return UserManagementService().validatePassword(value ?? '');
                          },
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            hintText: 'Enter new password',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showPassword ? Icons.visibility_off : Icons.visibility,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  showPassword = !showPassword;
                                });
                              },
                            ),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Confirm Password Field
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: !showConfirmPassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm the password';
                            }
                            if (value != passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            hintText: 'Re-enter the password',
                            prefixIcon: const Icon(Icons.lock, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  showConfirmPassword = !showConfirmPassword;
                                });
                              },
                            ),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Warning
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_rounded, color: Colors.orange[700], size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'The agent\'s current password will be immediately replaced.',
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
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(context).pop(passwordController.text.trim());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reset Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (newPassword != null && newPassword.isNotEmpty && mounted) {
      await _performPasswordReset(member, newPassword);
    }
  }

  Future<void> _performPasswordReset(TeamMemberInfo member, String newPassword) async {
    // Show loading dialog
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Resetting password...'),
          ],
        ),
      ),
    );

    try {
      final success = await UserManagementService().resetPasswordDirect(member.user.id, newPassword);
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (success) {
        // Show success dialog with new password
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: successColor),
                const SizedBox(width: 8),
                const Text('Password Reset Successfully'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Password reset successfully for ${member.user.fullName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Agent can use this password to login immediately',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New Password:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              newPassword,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: newPassword));
                              if (context.mounted) {
                                context.showSnackBar('Password copied to clipboard');
                              }
                            },
                            icon: const Icon(Icons.copy, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: primaryColor.withValues(alpha: 0.1),
                              foregroundColor: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Share this password securely with the agent',
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
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.error, color: errorColor),
              const SizedBox(width: 8),
              const Text('Reset Failed'),
            ],
          ),
          content: Text(
            'Failed to reset password: ${e.toString()}',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _performNameUpdate(TeamMemberInfo member, String newName) async {
    // Show loading dialog
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Updating name...'),
          ],
        ),
      ),
    );

    try {
      final success = await UserManagementService().updateAgentName(member.user.id, newName);
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (success) {
        // Show success message
        context.showSnackBar('Agent name updated successfully');
        
        // Refresh the team members list to show the updated name
        setState(() {
          _teamMembersFuture = _fetchTeamMembers();
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      
      // Show error message
      context.showSnackBar('Failed to update name: ${e.toString()}', isError: true);
    }
  }

  void _showMemberDetails(TeamMemberInfo member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member.user.fullName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${member.user.email ?? 'Not provided'}'),
            const SizedBox(height: 8),
            Text('Username: ${member.user.username ?? 'Not set'}'),
            const SizedBox(height: 8),
            Text('Status: ${member.user.status}'),
            const SizedBox(height: 8),
            Text('Active Tasks: ${member.activeTasks}'),
            const SizedBox(height: 8),
            Text('Groups: ${member.groupNames.join(', ')}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class TeamMemberInfo {
  final AppUser user;
  final int activeTasks;
  final List<String> groupNames;

  TeamMemberInfo({
    required this.user,
    required this.activeTasks,
    required this.groupNames,
  });
}