// lib/screens/admin/user_management_screen.dart

import 'package:flutter/material.dart';
import 'package:myapp/models/app_user.dart';
import 'package:myapp/models/group.dart'; // Import the Group model
import 'package:myapp/services/profile_service.dart';
import 'package:myapp/utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> with SingleTickerProviderStateMixin {
  late Future<List<AppUser>> _usersFuture;
  late Future<List<Group>> _groupsFuture; 
  late Future<Map<String, int>>? _quotaInfoFuture;
  TabController? _tabController;

  bool _canCreateAgent = true;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    final bool isAdmin = ProfileService.instance.role == 'admin';
    if (isAdmin) {
      _tabController = TabController(length: 2, vsync: this);
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          setState(() {
            _currentTabIndex = _tabController!.index;
          });
          // No need to refresh all data on tab change if data is loaded initially
          // and refreshed after specific actions.
        }
      });
    }
    _refreshAllData(); 
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _refreshAllData() {
    setState(() {
      _usersFuture = _fetchUsers();
      _groupsFuture = _fetchGroups(); 
      if (ProfileService.instance.role != 'admin') {
        _quotaInfoFuture = _fetchManagerQuota();
      } else {
        _quotaInfoFuture = null;
      }
    });
  }

  Future<List<AppUser>> _fetchUsers() async {
    print("_fetchUsers called");
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false);
      print("_fetchUsers successful, count: ${response.length}");
      return response.map((json) => AppUser.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching users in _fetchUsers: $e');
      if(mounted) context.showSnackBar('Error fetching users: ${e.toString()}', isError: true);
      return []; // Return empty list on error to prevent FutureBuilder from breaking hard
    }
  }

  Future<List<Group>> _fetchGroups() async {
    print("_fetchGroups called");
    try {
      final response = await supabase
          .from('groups')
          .select()
          .order('created_at', ascending: false);
      print("_fetchGroups successful, count: ${response.length}");
      return response.map((json) => Group.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching groups in _fetchGroups: $e');
      if(mounted) context.showSnackBar('Error fetching groups: ${e.toString()}', isError: true);
      return [];
    }
  }

  Future<Map<String, int>> _fetchManagerQuota() async {
    print("_fetchManagerQuota called");
    final managerId = supabase.auth.currentUser!.id;
    try {
      final profileData = await supabase
          .from('profiles')
          .select('agent_creation_limit')
          .eq('id', managerId)
          .single(); // This could throw if manager profile not found by RLS
      print('_fetchManagerQuota: raw profileData from Supabase: $profileData'); // Log the raw data
      final createdCount = await supabase.rpc('get_my_creation_count');
      final limit = profileData['agent_creation_limit'] as int? ?? 0;
      final created = createdCount as int? ?? 0;
      if(mounted) setState(() => _canCreateAgent = created < limit);
      print("_fetchManagerQuota successful: limit $limit, created $created");
      return {'limit': limit, 'created': created};
    } catch (e) {
      print('Error in _fetchManagerQuota: $e');
      if(mounted) {
        context.showSnackBar('Error fetching manager quota: ${e.toString()}', isError: true);
        setState(() => _canCreateAgent = false);
      }
      return {'limit': 0, 'created': 0}; // Return default/empty on error
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    final currentContext = context;
    final confirm = await _showConfirmationDialog(
      context: currentContext,
      title: 'Delete ${user.role}?',
      content: 'Are you sure you want to delete ${user.fullName}? This action cannot be undone.'
    );
    if (confirm != true || !mounted) return;
    try {
      await supabase.auth.admin.deleteUser(user.id);
      if (mounted) {
        context.showSnackBar('User deleted successfully.');
        _refreshAllData(); 
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to delete user: $e', isError: true);
    }
  }

  Future<void> _deleteGroup(Group group) async {
    final currentContext = context;
     final confirm = await _showConfirmationDialog(
      context: currentContext,
      title: 'Delete Group?',
      content: 'Are you sure you want to delete the group "${group.name}"? This will remove all members from this group and cannot be undone.'
    );
    if (confirm != true || !mounted) return;

    try {
      await supabase.from('groups').delete().eq('id', group.id);
      if(mounted) {
        context.showSnackBar('Group "${group.name}" deleted successfully.');
        _refreshAllData();
      }
    } catch (e) {
      if(mounted) context.showSnackBar('Failed to delete group: ${e.toString()}', isError: true);
    }
  }


  Future<void> _toggleSuspendUser(AppUser user) async {
     final newStatus = user.status == 'active' ? 'suspended' : 'active';
     try {
        await supabase.from('profiles').update({'status': newStatus}).eq('id', user.id);
        if(mounted) context.showSnackBar('User status updated.');
        _refreshAllData(); 
     } catch(e) {
       if(mounted) context.showSnackBar('Failed to update status: $e', isError: true);
     }
  }

  Future<void> _resetPassword(AppUser user) async {
    final currentContext = context;
    final newPassword = await _showPasswordResetDialog(currentContext);
    if (newPassword == null || !mounted) return;
    try {
      await supabase.auth.admin.updateUserById(user.id, attributes: AdminUserAttributes(password: newPassword));
      if(mounted) context.showSnackBar('Password for ${user.fullName} has been reset.');
    } catch(e) {
      if(mounted) context.showSnackBar('Failed to reset password: $e', isError: true);
    }
  }

  Future<void> _updateManagerQuota(AppUser manager, int newQuota) async {
    if (!mounted) return;
    try {
      await supabase
          .from('profiles')
          .update({'agent_creation_limit': newQuota})
          .eq('id', manager.id);
      if (!mounted) return;
      context.showSnackBar('Quota for ${manager.fullName} updated to $newQuota.');
      _refreshAllData(); 
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar('Failed to update quota: $e', isError: true);
    }
  }
  
  Future<int?> _showEditQuotaDialog(BuildContext context, AppUser manager) async {
    final quotaController = TextEditingController(
      text: manager.agentCreationLimit.toString(), 
    );
    final formKey = GlobalKey<FormState>();
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Quota for ${manager.fullName}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: quotaController,
            decoration: const InputDecoration(labelText: 'New Agent Creation Limit'),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              final n = int.tryParse(v);
              if (n == null) return 'Invalid number';
              if (n < 0) return 'Cannot be negative';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(int.parse(quotaController.text));
              }
            },
            child: const Text('Save Quota'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddUserDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _AddUserDialogContent(),
    );
    if (result == true) _refreshAllData(); 
  }

  Future<void> _showAddGroupDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _AddGroupDialogContent(),
    );
    if (result == true) {
      _refreshAllData(); 
    }
  }
  
  Future<void> _showEditGroupDialog(Group group) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _EditGroupDialogContent(group: group),
    );
    if (result == true) {
      _refreshAllData();
    }
  }


  Future<bool?> _showConfirmationDialog({required BuildContext context, required String title, required String content}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Confirm', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );
  }

  Future<String?> _showPasswordResetDialog(BuildContext context) {
     final passController = TextEditingController();
     final formKey = GlobalKey<FormState>();
     return showDialog<String>(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('Reset Password'),
         content: Form(
           key: formKey,
           child: TextFormField(
             controller: passController,
             decoration: const InputDecoration(labelText: 'New Password'),
             validator: (v) => (v == null || v.length < 6) ? 'Must be at least 6 characters' : null,
           ),
         ),
         actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(passController.text);
              }
            }, child: const Text('Set Password')),
         ],
       ),
     );
  }

  Widget _buildFloatingActionButton() {
    final bool isAdmin = ProfileService.instance.role == 'admin';
    if (isAdmin) {
      if (_currentTabIndex == 0) {
        return FloatingActionButton.extended(
          heroTag: 'adminAddUserFab',
          onPressed: _showAddUserDialog,
          label: const Text('Add New User'),
          icon: const Icon(Icons.person_add),
          backgroundColor: Theme.of(context).primaryColor,
        );
      } else {
        return FloatingActionButton.extended(
          heroTag: 'adminAddGroupFab',
          onPressed: _showAddGroupDialog,
          label: const Text('Add New Group'),
          icon: const Icon(Icons.group_add),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        );
      }
    } else {
      if (_currentTabIndex == 0) {
         return FloatingActionButton.extended(
            heroTag: 'managerAddUserFab',
            onPressed: _canCreateAgent ? _showAddUserDialog : null,
            label: const Text('Add New User'),
            icon: const Icon(Icons.person_add),
            backgroundColor: _canCreateAgent ? Theme.of(context).primaryColor : Colors.grey,
          );
      }
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = ProfileService.instance.role == 'admin';
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshAllData), 
        ],
        bottom: isAdmin 
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.person), text: 'Users'),
                  Tab(icon: Icon(Icons.group), text: 'Groups'),
                ],
              )
            : null, // No TabBar for non-admins
      ),
      body: Column(
        children: [
          if (!isAdmin) _buildManagerQuotaHeader(), // This is for managers, always on "users" view effectively
          Expanded(
            child: isAdmin && _tabController != null
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUsersListWidget(),
                    _buildGroupsListWidget(), 
                  ],
                )
              : _buildUsersListWidget(), // Non-admins only see the user list
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildUsersListWidget() {
    final bool isAdmin = ProfileService.instance.role == 'admin';
    return FutureBuilder<List<AppUser>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return preloader;
        if (snapshot.hasError) return Center(child: Text('Error loading users: ${snapshot.error}'));
        final users = snapshot.data ?? [];
        if (users.isEmpty && !isAdmin) return const Center(child: Text('You have not created any agents yet.'));
        if (users.isEmpty && isAdmin) return const Center(child: Text('No other users found.'));
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildUserTile(user);
          },
        );
      },
    );
  }

  Widget _buildGroupsListWidget() {
    final bool isAdmin = ProfileService.instance.role == 'admin';
    return FutureBuilder<List<Group>>(
      future: _groupsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return preloader;
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading groups: ${snapshot.error}'));
        }
        final groups = snapshot.data ?? [];
        if (groups.isEmpty) {
          return const Center(child: Text('No groups found.'));
        }
        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.group_work),
                title: Text(group.name),
                trailing: isAdmin 
                  ? PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditGroupDialog(group);
                        } else if (value == 'delete') {
                          _deleteGroup(group);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    )
                  : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildManagerQuotaHeader() {
    return FutureBuilder<Map<String, int>>(
      future: _quotaInfoFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
        final quotaInfo = snapshot.data!;
        final limit = quotaInfo['limit']!;
        final created = quotaInfo['created']!;
        return Container(
          width: double.infinity,
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Agent Quota: $created / $limit',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  Widget _buildUserTile(AppUser user) {
    final statusColor = user.status == 'active' ? Colors.green : Colors.orange;
    final isAdmin = ProfileService.instance.role == 'admin';
    if (user.id == supabase.auth.currentUser!.id) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Text(user.role.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white)),
        ),
        title: Text(user.fullName),
        subtitle: Text(user.username ?? user.role),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async { 
            if (value == 'suspend') _toggleSuspendUser(user);
            else if (value == 'delete') _deleteUser(user);
            else if (value == 'reset_password') _resetPassword(user);
            else if (value == 'edit_manager') {
              final newQuota = await _showEditQuotaDialog(context, user);
              if (newQuota != null) _updateManagerQuota(user, newQuota);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'suspend', child: Text(user.status == 'active' ? 'Suspend User' : 'Unsuspend User')),
            PopupMenuItem(value: 'reset_password', child: Text('Reset Password')),
            if (isAdmin && user.role == 'manager') const PopupMenuItem(value: 'edit_manager', child: Text('Edit Quota')),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'delete', child: Text('Delete User', style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        ),
      ),
    );
  }
}

class _AddUserDialogContent extends StatefulWidget {
  const _AddUserDialogContent();
  @override
  State<_AddUserDialogContent> createState() => _AddUserDialogContentState();
}

class _AddUserDialogContentState extends State<_AddUserDialogContent> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _quotaController = TextEditingController(text: '10');
  String _selectedRole = 'agent';

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _quotaController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    print('_createUser: Method called.');
    if (!_formKey.currentState!.validate()) {
      print('_createUser: Form validation failed.');
      // Optionally, show a snackbar if form is invalid, though Flutter usually shows field errors.
      // if(mounted) context.showSnackBar('Please correct the form errors.', isError: true);
      return;
    }
    print('_createUser: Form validation passed.');

    setState(() => _isLoading = true);
    print('_createUser: _isLoading set to true.');

    final String currentUserRole = ProfileService.instance.role ?? 'unknown';
    final String currentUserId = supabase.auth.currentUser!.id;
    print('_createUser: currentUserRole: $currentUserRole, currentUserId: $currentUserId');
    print('_createUser: _selectedRole for new user: $_selectedRole');
    final String emailForAuth = _selectedRole == 'agent' ? '${_usernameController.text.trim()}@agent.local' : _emailController.text.trim();
    final String password = _passwordController.text;
    final String fullName = _fullNameController.text.trim();
    final String? username = _selectedRole == 'agent' ? _usernameController.text.trim() : null;
    final int? agentCreationLimit = (_selectedRole == 'manager' && currentUserRole == 'admin') ? (int.tryParse(_quotaController.text) ?? 0) : null;

    try {
      final AuthResponse authResponse = await supabase.auth.signUp(
        email: emailForAuth, password: password,
        data: {'full_name': fullName, 'role': _selectedRole, 'creator_id': currentUserId},
      );
      if (authResponse.user == null) throw Exception('User creation failed: No user returned from signUp.');
      final String newUserId = authResponse.user!.id;
      Map<String, dynamic> updateProfileData = {
        'full_name': fullName, 'role': _selectedRole, 'created_by': currentUserId,
        'status': 'active', 'email': emailForAuth,
      };
      if (_selectedRole == 'agent') {
        if (username == null || username.isEmpty) throw Exception('Username is required for agent role.');
        updateProfileData['username'] = username;
      } else if (_selectedRole == 'manager') {
        if (currentUserRole != 'admin') throw Exception('Only admins can create manager users.');
        if (agentCreationLimit != null) updateProfileData['agent_creation_limit'] = agentCreationLimit;
      }
      if (updateProfileData.isNotEmpty) await supabase.from('profiles').update(updateProfileData).eq('id', newUserId);
      
      // If a manager created this new agent, check if the manager has a default_group_id
      if (currentUserRole == 'manager' && _selectedRole == 'agent') {
        final managerProfileResponse = await supabase
            .from('profiles')
            .select('default_group_id')
            .eq('id', currentUserId)
            .maybeSingle(); // Use maybeSingle() to gracefully handle 0 rows
        
        final String? managerDefaultGroupId = managerProfileResponse?['default_group_id'] as String?; // Add null-check for managerProfileResponse

        if (managerDefaultGroupId != null) {
          // Add the new agent to the manager's default group
          await supabase.from('group_members').insert({
            'group_id': managerDefaultGroupId,
            'user_id': newUserId, // The ID of the newly created agent
            'added_by': currentUserId, // The manager who created the agent
          });
          print('New agent $newUserId auto-assigned to group $managerDefaultGroupId by manager $currentUserId');
        }
      }

      if (!mounted) return;
      context.showSnackBar('User "$fullName" created successfully!');
      Navigator.of(context).pop(true);
      print('_createUser: User creation process successful for $fullName.');
    } catch (e) {
      print('_createUser: Error caught: ${e.toString()}');
      if (!mounted) return;
      if (e is AuthException && e.message.contains("User already registered")) { 
        context.showSnackBar('Failed to create user: This email or username might already be registered.', isError: true);
      } else if (e.toString().contains('profiles') && supabase.auth.currentUser?.id != null && currentUserRole == 'admin') {
        context.showSnackBar('Failed to create profile: $e. Auth user might exist without profile.', isError: true);
      } else {
        context.showSnackBar('Failed to create user: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        print('_createUser: _isLoading set to false in finally block.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = ProfileService.instance.role == 'admin';
    return AlertDialog(
      title: const Text('Add New User'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _fullNameController, decoration: const InputDecoration(labelText: 'Full Name'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              formSpacer,
              if (isAdmin) DropdownButtonFormField<String>(
                value: _selectedRole, decoration: const InputDecoration(labelText: 'Role'),
                items: ['agent', 'manager'].map((role) => DropdownMenuItem(value: role, child: Text(role.toUpperCase()))).toList(),
                onChanged: (value) => setState(() => _selectedRole = value ?? 'agent'),
              ) else InputDecorator(decoration: const InputDecoration(labelText: 'Role'), child: Text('AGENT', style: Theme.of(context).textTheme.titleMedium)),
              formSpacer,
              if (_selectedRole == 'manager') TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email Address'), keyboardType: TextInputType.emailAddress, validator: (v) => v == null || !v.contains('@') ? 'Invalid email' : null)
              else TextFormField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              formSpacer,
              TextFormField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password'), validator: (v) => (v == null || v.length < 6) ? 'Must be at least 6 characters' : null),
              if (isAdmin && _selectedRole == 'manager') ...[
                formSpacer,
                TextFormField(controller: _quotaController, decoration: const InputDecoration(labelText: 'Agent Creation Limit'), keyboardType: TextInputType.number, validator: (v) => int.tryParse(v!) == null ? 'Invalid number' : null),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _isLoading ? null : _createUser, child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Create User')),
      ],
    );
  }
}

class _AddGroupDialogContent extends StatefulWidget {
  const _AddGroupDialogContent();
  @override
  State<_AddGroupDialogContent> createState() => _AddGroupDialogContentState();
}

class _AddGroupDialogContentState extends State<_AddGroupDialogContent> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  List<AppUser> _selectedUsers = []; 
  bool _isLoading = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _selectUsers() async {
    final List<AppUser>? result = await showDialog<List<AppUser>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _UserSelectionDialog(initialSelectedUsers: List<AppUser>.from(_selectedUsers));
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedUsers = result;
      });
    }
  }

  void _removeUserFromSelected(AppUser userToRemove) {
    setState(() {
      _selectedUsers.removeWhere((user) => user.id == userToRemove.id);
    });
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUsers.isEmpty) {
      context.showSnackBar('Please select at least one user for the group.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final groupName = _groupNameController.text.trim();
    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) {
      if (mounted) context.showSnackBar('Error: Could not identify current user.', isError: true);
      setState(() => _isLoading = false);
      return;
    }

    try {
      final groupResponse = await supabase
          .from('groups')
          .insert({
            'name': groupName,
            'created_by': currentUserId,
          })
          .select()
          .single(); 

      final newGroupId = groupResponse['id'] as String?;

      if (newGroupId == null) {
        throw Exception('Failed to create group or retrieve group ID.');
      }

      if (_selectedUsers.isNotEmpty) {
        final List<Map<String, dynamic>> membersToInsert = _selectedUsers.map((user) {
          return {
            'group_id': newGroupId,
            'user_id': user.id,
            'added_by': currentUserId,
          };
        }).toList();
        await supabase.from('group_members').insert(membersToInsert);
      }

      if (!mounted) return;
      context.showSnackBar('Group "$groupName" created successfully!');
      Navigator.of(context).pop(true); 
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar('Failed to create group: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Group'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(controller: _groupNameController, decoration: const InputDecoration(labelText: 'Group Name'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              formSpacer, 
              Text('Group Users:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _selectedUsers.isEmpty
                  ? const Text('No users selected yet.')
                  : Wrap(
                      spacing: 6.0,
                      runSpacing: 0.0,
                      children: _selectedUsers.map((user) => Chip(
                        label: Text(user.fullName),
                        onDeleted: () => _removeUserFromSelected(user),
                        deleteIcon: const Icon(Icons.close, size: 18),
                      )).toList(),
                    ),
              formSpacer,
              ElevatedButton.icon(
                onPressed: _selectUsers,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add/Remove Users'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        ElevatedButton(onPressed: _isLoading ? null : _createGroup, child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create Group')),
      ],
    );
  }
}

class _UserSelectionDialog extends StatefulWidget {
  final List<AppUser> initialSelectedUsers;
  const _UserSelectionDialog({required this.initialSelectedUsers});
  @override
  State<_UserSelectionDialog> createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<_UserSelectionDialog> {
  late Future<List<AppUser>> _allUsersFuture;
  List<AppUser> _selectedUsersInDialog = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _allUsersFuture = _fetchAllUsers();
    _selectedUsersInDialog = List<AppUser>.from(widget.initialSelectedUsers);
  }

  Future<List<AppUser>> _fetchAllUsers() async {
    final currentUserId = supabase.auth.currentUser?.id;
    try {
      var query = supabase.from('profiles').select();
      if (currentUserId != null) {
        query = query.neq('id', currentUserId); 
      }
      final response = await query.order('full_name', ascending: true);
      return response.map((json) => AppUser.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching users for selection: $e');
      return [];
    }
  }

  void _toggleUserSelection(AppUser user) {
    setState(() {
      final isSelected = _selectedUsersInDialog.any((selectedUser) => selectedUser.id == user.id);
      if (isSelected) {
        _selectedUsersInDialog.removeWhere((selectedUser) => selectedUser.id == user.id);
      } else {
        _selectedUsersInDialog.add(user);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Users'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search Users',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<AppUser>>(
                future: _allUsersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No users found or error loading users.'));
                  }
                  List<AppUser> filteredUsers = snapshot.data!
                      .where((user) => user.fullName.toLowerCase().contains(_searchQuery) || (user.username?.toLowerCase().contains(_searchQuery) ?? false))
                      .toList();
                  if (filteredUsers.isEmpty && _searchQuery.isNotEmpty) {
                    return const Center(child: Text('No users match your search.'));
                  }
                   if (filteredUsers.isEmpty && _searchQuery.isEmpty) {
                    return const Center(child: Text('No other users available to add.'));
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final isSelected = _selectedUsersInDialog.any((selectedUser) => selectedUser.id == user.id);
                      return CheckboxListTile(
                        title: Text(user.fullName),
                        subtitle: Text(user.username ?? user.role),
                        value: isSelected,
                        onChanged: (bool? value) {
                          _toggleUserSelection(user);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(_selectedUsersInDialog);
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

// Dialog for editing a group
class _EditGroupDialogContent extends StatefulWidget {
  final Group group;
  const _EditGroupDialogContent({required this.group});

  @override
  State<_EditGroupDialogContent> createState() => _EditGroupDialogContentState();
}

class _EditGroupDialogContentState extends State<_EditGroupDialogContent> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _groupNameController;
  List<AppUser> _initialMembers = [];
  List<AppUser> _currentMembers = [];
  bool _isLoading = false;
  bool _isFetchingMembers = true;

  @override
  void initState() {
    super.initState();
    _groupNameController = TextEditingController(text: widget.group.name);
    _fetchInitialMembers();
  }

  Future<void> _fetchInitialMembers() async {
    setState(() => _isFetchingMembers = true);
    try {
      final response = await supabase
          .from('group_members')
          .select('user_id, member_profile:profiles!group_members_user_id_fkey ( id, full_name, username, role, status, agent_creation_limit )') // Specify FK for join
          .eq('group_id', widget.group.id);

      final List<AppUser> members = response.map((item) {
        // The data for profiles is now nested under 'member_profile' key
        final profileData = item['member_profile'] as Map<String, dynamic>?;
        if (profileData == null) {
          print('Warning: Profile data missing for user_id ${item['user_id']} in group ${widget.group.id}');
          return AppUser(id: item['user_id'], fullName: 'Unknown User', role: 'unknown', status: 'unknown', agentCreationLimit: 0);
        }
        return AppUser.fromJson(profileData);
      }).toList();
      
      if (mounted) {
        setState(() {
          _initialMembers = List<AppUser>.from(members);
          _currentMembers = List<AppUser>.from(members);
          _isFetchingMembers = false;
        });
      }
    } catch (e) {
      print('Error fetching group members: $e');
      if (mounted) {
        context.showSnackBar('Error fetching group members: ${e.toString()}', isError: true);
        setState(() => _isFetchingMembers = false);
      }
    }
  }


  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _selectUsersForEdit() async {
    final List<AppUser>? result = await showDialog<List<AppUser>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _UserSelectionDialog(initialSelectedUsers: List<AppUser>.from(_currentMembers));
      },
    );

    if (result != null && mounted) {
      setState(() {
        _currentMembers = result;
      });
    }
  }

  void _removeUserFromCurrent(AppUser userToRemove) {
    setState(() {
      _currentMembers.removeWhere((user) => user.id == userToRemove.id);
    });
  }

  Future<void> _updateGroup() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    final newGroupName = _groupNameController.text.trim();
    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) {
      if (mounted) context.showSnackBar('Error: Could not identify current user.', isError: true);
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Update group name if changed
      if (newGroupName != widget.group.name) {
        await supabase
            .from('groups')
            .update({'name': newGroupName})
            .eq('id', widget.group.id);
      }

      // Reconcile members
      final initialMemberIds = _initialMembers.map((u) => u.id).toSet();
      final currentMemberIds = _currentMembers.map((u) => u.id).toSet();

      final membersToAdd = currentMemberIds.difference(initialMemberIds);
      final membersToRemove = initialMemberIds.difference(currentMemberIds);

      if (membersToRemove.isNotEmpty) {
        await supabase
            .from('group_members')
            .delete()
            .eq('group_id', widget.group.id)
            .inFilter('user_id', membersToRemove.toList());
      }

      if (membersToAdd.isNotEmpty) {
        final List<Map<String, dynamic>> newMemberRecords = membersToAdd.map((userId) {
          return {
            'group_id': widget.group.id,
            'user_id': userId,
            'added_by': currentUserId, 
          };
        }).toList();
        await supabase.from('group_members').insert(newMemberRecords);
      }

      if (!mounted) return;
      context.showSnackBar('Group "${newGroupName}" updated successfully.');
      Navigator.of(context).pop(true); 
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar('Failed to update group: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Group: ${widget.group.name}'),
      content: _isFetchingMembers 
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _groupNameController,
                      decoration: const InputDecoration(labelText: 'Group Name'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    formSpacer,
                    Text('Group Members:', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _currentMembers.isEmpty
                        ? const Text('No users in this group.')
                        : Wrap(
                            spacing: 6.0,
                            runSpacing: 0.0,
                            children: _currentMembers.map((user) => Chip(
                              label: Text(user.fullName),
                              onDeleted: () => _removeUserFromCurrent(user),
                              deleteIcon: const Icon(Icons.close, size: 18),
                            )).toList(),
                          ),
                    formSpacer,
                    ElevatedButton.icon(
                      onPressed: _selectUsersForEdit,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Add/Remove Users'),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading || _isFetchingMembers ? null : _updateGroup,
          child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}
