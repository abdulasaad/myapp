// lib/screens/admin/user_management_screen.dart

import 'package:flutter/material.dart';
import 'package:myapp/models/app_user.dart';
import 'package:myapp/services/profile_service.dart';
import 'package:myapp/utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late Future<List<AppUser>> _usersFuture;
  late Future<Map<String, int>>? _quotaInfoFuture;

  bool _canCreateAgent = true;

  @override
  void initState() {
    super.initState();
    _refreshUsers();
  }

  void _refreshUsers() {
    setState(() {
      _usersFuture = _fetchUsers();
      if (ProfileService.instance.role != 'admin') {
        _quotaInfoFuture = _fetchManagerQuota();
      } else {
        _quotaInfoFuture = null;
      }
    });
  }

  Future<List<AppUser>> _fetchUsers() async {
    // RLS policies on the 'profiles' table handle the filtering automatically.
    // Admins see all users. Managers only see users they created.
    final response = await supabase
        .from('profiles')
        .select()
        .order('created_at', ascending: false);
    return response.map((json) => AppUser.fromJson(json)).toList();
  }

  Future<Map<String, int>> _fetchManagerQuota() async {
    final managerId = supabase.auth.currentUser!.id;
    try {
      final profileData = await supabase
          .from('profiles')
          .select('agent_creation_limit')
          .eq('id', managerId)
          .single();
      
      final createdCount = await supabase.rpc('get_my_creation_count');
      
      final limit = profileData['agent_creation_limit'] as int? ?? 0;
      final created = createdCount as int? ?? 0;

      if(mounted) {
        setState(() => _canCreateAgent = created < limit);
      }
      return {'limit': limit, 'created': created};
    } catch (e) {
      if(mounted) {
        setState(() => _canCreateAgent = false);
      }
      return {'limit': 0, 'created': 0};
    }
  }

  // --- ACTIONS ---

  Future<void> _deleteUser(AppUser user) async {
    final currentContext = context;
    final confirm = await _showConfirmationDialog(
      context: currentContext,
      title: 'Delete ${user.role}?',
      content: 'Are you sure you want to delete ${user.fullName}? This action cannot be undone.'
    );

    if (confirm != true || !mounted) return;

    try {
      // Use the Admin API to delete the user from auth, which cascades to 'profiles'
      await supabase.auth.admin.deleteUser(user.id);
      if (mounted) {
        context.showSnackBar('User deleted successfully.');
        _refreshUsers();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to delete user: $e', isError: true);
      }
    }
  }

  Future<void> _toggleSuspendUser(AppUser user) async {
     final newStatus = user.status == 'active' ? 'suspended' : 'active';
     try {
        await supabase.from('profiles').update({'status': newStatus}).eq('id', user.id);
        if(mounted) context.showSnackBar('User status updated.');
        _refreshUsers();
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
      if (!mounted) return; // Re-check mounted before using context
      context.showSnackBar('Quota for ${manager.fullName} updated to $newQuota.');
      _refreshUsers();
    } catch (e) {
      if (!mounted) return; // Re-check mounted before using context
      context.showSnackBar('Failed to update quota: $e', isError: true);
    }
  }
  
  // --- DIALOGS ---

  Future<int?> _showEditQuotaDialog(BuildContext context, AppUser manager) async {
    // Assuming AppUser.agentCreationLimit is nullable (int?).
    // If it's non-nullable (int), then manager.agentCreationLimit.toString() is fine.
    // The current form is robust for nullability.
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
    // Using a separate widget for the dialog allows for better state management
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _AddUserDialogContent(),
    );
    // If the dialog returns true, it means a user was created, so refresh the list.
    if (result == true) {
      _refreshUsers();
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

  // --- BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = ProfileService.instance.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshUsers),
        ],
      ),
      body: Column(
        children: [
          if (!isAdmin) _buildManagerQuotaHeader(),
          Expanded(
            child: FutureBuilder<List<AppUser>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return preloader;
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final users = snapshot.data ?? [];
                if (users.isEmpty && !isAdmin) {
                  return const Center(child: Text('You have not created any agents yet.'));
                }
                if (users.isEmpty && isAdmin) {
                  return const Center(child: Text('No other users found.'));
                }
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _buildUserTile(user);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isAdmin || _canCreateAgent ? _showAddUserDialog : null,
        label: const Text('Add New User'),
        icon: const Icon(Icons.add),
        backgroundColor: isAdmin || _canCreateAgent ? Theme.of(context).primaryColor : Colors.grey,
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildManagerQuotaHeader() {
    return FutureBuilder<Map<String, int>>(
      future: _quotaInfoFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
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
    
    if (user.id == supabase.auth.currentUser!.id) {
      return const SizedBox.shrink();
    }
    
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
          onSelected: (value) async { // Marked as async
            if (value == 'suspend') {
              _toggleSuspendUser(user);
            } else if (value == 'delete') {
              _deleteUser(user);
            } else if (value == 'reset_password') {
              _resetPassword(user);
            } else if (value == 'edit_manager') {
              final newQuota = await _showEditQuotaDialog(context, user);
              if (newQuota != null) {
                _updateManagerQuota(user, newQuota);
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'suspend',
              child: Text(user.status == 'active' ? 'Suspend User' : 'Unsuspend User'),
            ),
            PopupMenuItem(
              value: 'reset_password',
              child: Text('Reset Password'),
            ),
            if (isAdmin && user.role == 'manager')
              const PopupMenuItem(
                value: 'edit_manager',
                child: Text('Edit Quota'),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete User', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ),
      ),
    );
  }
}

// A separate stateful widget for the dialog's content to manage its state.
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final String currentUserRole = ProfileService.instance.role ?? 'unknown';
    final String currentUserId = supabase.auth.currentUser!.id;

    final String emailForAuth = _selectedRole == 'agent'
        ? '${_usernameController.text.trim()}@agent.local'
        : _emailController.text.trim();
    final String password = _passwordController.text;
    final String fullName = _fullNameController.text.trim();
    final String? username = _selectedRole == 'agent' ? _usernameController.text.trim() : null;
    final int? agentCreationLimit = (_selectedRole == 'manager' && currentUserRole == 'admin')
        ? (int.tryParse(_quotaController.text) ?? 0)
        : null;

    try {
      // Step 1: Create user in auth.users
      // Pass essential data for the handle_new_user trigger
      final AuthResponse authResponse = await supabase.auth.signUp(
        email: emailForAuth,
        password: password,
        data: {
          'full_name': fullName,
          'role': _selectedRole,
          'creator_id': currentUserId // Pass creator_id for the trigger
        },
      );

      if (authResponse.user == null) {
        throw Exception('User creation failed: No user returned from signUp.');
      }
      final String newUserId = authResponse.user!.id;

      // Step 2: Update the profile created by the trigger with additional details
      // The simplified trigger now only inserts the 'id'.
      // This client-side update needs to set all other necessary fields.
      Map<String, dynamic> updateProfileData = {
        'full_name': fullName,
        'role': _selectedRole,
        'created_by': currentUserId,
        'status': 'active',
        'email': emailForAuth, // Store the email used for auth (e.g., user@agent.local or manager's real email)
      };

      if (_selectedRole == 'agent') {
        if (username == null || username.isEmpty) {
          throw Exception('Username is required for agent role.');
        }
        updateProfileData['username'] = username;
      } else if (_selectedRole == 'manager') {
        if (currentUserRole != 'admin') {
           throw Exception('Only admins can create manager users.');
        }
        // email is already handled by the trigger if passed in raw_user_meta_data,
        // but let's ensure it's set if not passed or if updating is desired.
        // The trigger uses COALESCE(NEW.raw_user_meta_data->>'email', NEW.email)
        // so it should pick up the auth email. If a different profile email is needed, set it here.
        // updateProfileData['email'] = emailForAuth; // Usually not needed if auth email is profile email
        if (agentCreationLimit != null) {
          updateProfileData['agent_creation_limit'] = agentCreationLimit;
        }
      }
      
      // Only update if there's something to update beyond what trigger sets
      if (updateProfileData.isNotEmpty) {
        await supabase
            .from('profiles')
            .update(updateProfileData)
            .eq('id', newUserId);
      }

      if (!mounted) return;
      context.showSnackBar('User "$fullName" created successfully!');
      Navigator.of(context).pop(true); 

    } catch (e) {
      if (!mounted) return;
      // Basic error handling. More sophisticated cleanup might be needed.
      // For example, if profile insert fails, the auth user still exists.
      // An admin might need to manually delete the auth user or fix the profile.
      // String newUserIdForCleanup = ''; // Removed unused variable
      if (e is AuthException && e.message.contains("User already registered") ) {
         // Try to find user if already registered to attempt cleanup
         // This is complex as we don't have the ID easily.
      } else if (e.toString().contains('profiles') && supabase.auth.currentUser?.id != null && currentUserRole == 'admin') {
        // If profile insert failed, and current user is admin, they might be able to delete the orphaned auth user.
        // However, getting the newUserId from a failed signUp or partial success is not straightforward here.
        // The authResponse might be null or not contain the user if signUp itself threw an error.
        // For now, just show a more informative error.
         context.showSnackBar('Failed to create profile: $e. Auth user might exist without profile.', isError: true);
      } else {
        context.showSnackBar('Failed to create user: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              formSpacer,
              if (isAdmin) // Only admin can choose role initially
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: ['agent', 'manager']
                      .map((role) => DropdownMenuItem(value: role, child: Text(role.toUpperCase())))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedRole = value ?? 'agent'),
                )
              else // If not admin, default to creating 'agent' (manager creating agent)
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Role'),
                  child: Text('AGENT', style: Theme.of(context).textTheme.titleMedium),
                ),
              formSpacer,
              if (_selectedRole == 'manager')
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || !v.contains('@') ? 'Invalid email' : null,
                )
              else // For 'agent'
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              formSpacer,
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) => (v == null || v.length < 6) ? 'Must be at least 6 characters' : null,
              ),
              // Quota field only visible if creating a manager AND current user is admin
              if (isAdmin && _selectedRole == 'manager') ...[
                formSpacer,
                TextFormField(
                  controller: _quotaController,
                  decoration: const InputDecoration(labelText: 'Agent Creation Limit'),
                  keyboardType: TextInputType.number,
                  validator: (v) => int.tryParse(v!) == null ? 'Invalid number' : null,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _createUser,
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Create User'),
        ),
      ],
    );
  }
}
