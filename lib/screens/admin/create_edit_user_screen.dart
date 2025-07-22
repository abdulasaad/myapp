// lib/screens/admin/create_edit_user_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/group.dart';
import '../../services/user_management_service.dart';
import '../../utils/constants.dart';

class CreateEditUserScreen extends StatefulWidget {
  final AppUser? user;
  
  const CreateEditUserScreen({super.key, this.user});
  
  bool get isEditing => user != null;

  @override
  State<CreateEditUserScreen> createState() => _CreateEditUserScreenState();
}

class _CreateEditUserScreenState extends State<CreateEditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserManagementService _userService = UserManagementService();

  // Form controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _agentCreationLimitController = TextEditingController();

  // Form state
  String _selectedRole = 'agent';
  String _selectedStatus = 'active';
  List<String> _selectedGroupIds = [];
  List<Group> _availableGroups = [];
  bool _isLoading = false;
  bool _isLoadingGroups = false;
  bool _obscurePassword = true;
  bool _requireEmailConfirmation = true; // Default to requiring email confirmation

  @override
  void initState() {
    super.initState();
    _loadGroups();
    if (widget.isEditing) {
      _populateFields();
    } else {
      _agentCreationLimitController.text = '0';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _agentCreationLimitController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoadingGroups = true);
    try {
      _availableGroups = await _userService.getAllGroups();
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to load groups: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingGroups = false);
      }
    }
  }

  void _populateFields() {
    final user = widget.user!;
    _fullNameController.text = user.fullName;
    _emailController.text = user.email ?? '';
    _usernameController.text = user.username ?? '';
    _selectedRole = user.role;
    _selectedStatus = user.status ?? 'active';
    _agentCreationLimitController.text = user.agentCreationLimit?.toString() ?? '0';
    
    // Load user's groups
    _loadUserGroups();
  }

  Future<void> _loadUserGroups() async {
    if (!widget.isEditing) return;
    
    try {
      final userGroups = await _userService.getUserGroups(widget.user!.id);
      setState(() {
        _selectedGroupIds = userGroups.map((g) => g.id).toList();
      });
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to load user groups: $e', isError: true);
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Full name is required';
    }
    if (value.length < 2) {
      return 'Full name must be at least 2 characters';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (_selectedRole == 'agent') {
      if (value == null || value.isEmpty) {
        return 'Username is required for agents';
      }
      if (value.length < 3) {
        return 'Username must be at least 3 characters';
      }
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
        return 'Username can only contain letters, numbers, and underscores';
      }
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (!widget.isEditing) {
      if (value == null || value.isEmpty) {
        return 'Password is required';
      }
      if (value.length < 6) {
        return 'Password must be at least 6 characters';
      }
    }
    return null;
  }

  String? _validateAgentCreationLimit(String? value) {
    if (_selectedRole == 'manager') {
      if (value == null || value.isEmpty) {
        return 'Agent creation limit is required for managers';
      }
      final limit = int.tryParse(value);
      if (limit == null || limit < 0) {
        return 'Please enter a valid number (0 or greater)';
      }
    }
    return null;
  }

  void _generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    final password = List.generate(12, (index) => chars[(random + index) % chars.length]).join();
    
    setState(() {
      _passwordController.text = password;
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    context.showSnackBar('Copied to clipboard');
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.isEditing) {
        // Update existing user
        final success = await _userService.updateUser(
          userId: widget.user!.id,
          fullName: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          username: _usernameController.text.trim().isEmpty ? null : _usernameController.text.trim(),
          role: _selectedRole,
          status: _selectedStatus,
          agentCreationLimit: _selectedRole == 'manager' ? int.tryParse(_agentCreationLimitController.text) : null,
          groupIds: _selectedGroupIds,
        );

        if (mounted) {
          if (success) {
            context.showSnackBar('User updated successfully');
            Navigator.of(context).pop(true);
          } else {
            context.showSnackBar('Failed to update user', isError: true);
          }
        }
      } else {
        // Create new user
        final result = await _userService.createUser(
          email: _emailController.text.trim(),
          fullName: _fullNameController.text.trim(),
          role: _selectedRole,
          username: _usernameController.text.trim().isEmpty ? null : _usernameController.text.trim(),
          password: _passwordController.text,
          agentCreationLimit: _selectedRole == 'manager' ? int.tryParse(_agentCreationLimitController.text) : null,
          groupIds: _selectedGroupIds,
          requireEmailConfirmation: _requireEmailConfirmation,
        );

        if (mounted) {
          if (result['success'] == true) {
            _showUserCreatedDialog(result);
          } else {
            context.showSnackBar('Failed to create user: ${result['error']}', isError: true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showUserCreatedDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('User Created'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User has been created successfully!'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Login Credentials:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Email: ${_emailController.text}'),
                      ),
                      IconButton(
                        onPressed: () => _copyToClipboard(_emailController.text),
                        icon: Icon(Icons.copy, size: 16),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Password: ${result['password']}'),
                      ),
                      IconButton(
                        onPressed: () => _copyToClipboard(result['password']),
                        icon: Icon(Icons.copy, size: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Please save these credentials securely. The password will not be shown again.',
              style: TextStyle(
                color: Colors.orange[800],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit User' : 'Create User'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
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
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(),
              SizedBox(height: 24),
              _buildRoleSection(),
              SizedBox(height: 24),
              if (_selectedRole == 'agent') _buildAgentSection(),
              if (_selectedRole == 'manager') _buildManagerSection(),
              if (_selectedRole == 'agent' || _selectedRole == 'manager') SizedBox(height: 24),
              _buildGroupsSection(),
              SizedBox(height: 24),
              if (widget.isEditing) _buildStatusSection(),
              if (widget.isEditing) SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSection(
      title: 'Basic Information',
      children: [
        TextFormField(
          controller: _fullNameController,
          decoration: InputDecoration(
            labelText: 'Full Name *',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: _validateFullName,
          textCapitalization: TextCapitalization.words,
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email *',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: _validateEmail,
          keyboardType: TextInputType.emailAddress,
          enabled: !widget.isEditing, // Email cannot be changed after creation
        ),
        if (!widget.isEditing) ...[
          SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password *',
              prefixIcon: Icon(Icons.lock),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _generatePassword,
                    icon: Icon(Icons.auto_awesome),
                    tooltip: 'Generate Password',
                  ),
                  IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  ),
                ],
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            validator: _validatePassword,
            obscureText: _obscurePassword,
          ),
        ],
      ],
    );
  }

  Widget _buildRoleSection() {
    return _buildSection(
      title: 'Role & Permissions',
      children: [
        DropdownButtonFormField<String>(
          value: _selectedRole,
          decoration: InputDecoration(
            labelText: 'Role *',
            prefixIcon: Icon(Icons.admin_panel_settings),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: [
            DropdownMenuItem(value: 'agent', child: Text('Agent')),
            DropdownMenuItem(value: 'manager', child: Text('Manager')),
            DropdownMenuItem(value: 'admin', child: Text('Admin')),
            DropdownMenuItem(value: 'client', child: Text('Client')),
          ],
          onChanged: widget.isEditing ? null : (value) {
            setState(() {
              _selectedRole = value!;
              if (_selectedRole != 'agent') {
                _usernameController.clear();
              }
              if (_selectedRole != 'manager') {
                _agentCreationLimitController.text = '0';
              }
            });
          },
          validator: (value) => value == null ? 'Please select a role' : null,
        ),
        const SizedBox(height: 16),
        // Email Confirmation Toggle
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: SwitchListTile(
            title: const Text(
              'Require Email Confirmation',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              _requireEmailConfirmation 
                ? 'User must verify email before accessing the system'
                : 'User can access immediately after creation',
              style: TextStyle(
                color: _requireEmailConfirmation ? Colors.orange[700] : Colors.green[700],
                fontSize: 12,
              ),
            ),
            value: _requireEmailConfirmation,
            onChanged: widget.isEditing ? null : (value) {
              setState(() {
                _requireEmailConfirmation = value;
              });
            },
            secondary: Icon(
              _requireEmailConfirmation ? Icons.email : Icons.email_outlined,
              color: _requireEmailConfirmation ? Colors.orange : Colors.green,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgentSection() {
    return _buildSection(
      title: 'Agent Settings',
      children: [
        TextFormField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: 'Username *',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            helperText: 'Used for agent login and identification',
          ),
          validator: _validateUsername,
        ),
      ],
    );
  }

  Widget _buildManagerSection() {
    return _buildSection(
      title: 'Manager Settings',
      children: [
        TextFormField(
          controller: _agentCreationLimitController,
          decoration: InputDecoration(
            labelText: 'Agent Creation Limit *',
            prefixIcon: Icon(Icons.group_add),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            helperText: 'Maximum number of agents this manager can create',
          ),
          validator: _validateAgentCreationLimit,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
    );
  }

  Widget _buildGroupsSection() {
    return _buildSection(
      title: 'Group Assignment',
      children: [
        if (_isLoadingGroups)
          Center(child: CircularProgressIndicator())
        else if (_availableGroups.isEmpty)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text('No groups available'),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: _availableGroups.map((group) {
                final isSelected = _selectedGroupIds.contains(group.id);
                return CheckboxListTile(
                  title: Text(group.name),
                  subtitle: group.description != null ? Text(group.description!) : null,
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedGroupIds.add(group.id);
                      } else {
                        _selectedGroupIds.remove(group.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return _buildSection(
      title: 'Status',
      children: [
        DropdownButtonFormField<String>(
          value: _selectedStatus,
          decoration: InputDecoration(
            labelText: 'Status',
            prefixIcon: Icon(Icons.toggle_on),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: [
            DropdownMenuItem(value: 'active', child: Text('Active')),
            DropdownMenuItem(value: 'offline', child: Text('Offline')),
          ],
          onChanged: (value) => setState(() => _selectedStatus = value!),
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
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(widget.isEditing ? 'Update User' : 'Create User'),
          ),
        ),
      ],
    );
  }
}