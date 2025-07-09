// lib/screens/admin/create_edit_group_screen.dart

import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../models/app_user.dart';
import '../../services/group_service.dart';
import '../../utils/constants.dart';

class CreateEditGroupScreen extends StatefulWidget {
  final Group? group;

  const CreateEditGroupScreen({super.key, this.group});

  bool get isEditing => group != null;

  @override
  State<CreateEditGroupScreen> createState() => _CreateEditGroupScreenState();
}

class _CreateEditGroupScreenState extends State<CreateEditGroupScreen> {
  final GroupService _groupService = GroupService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<AppUser> _availableMembers = [];
  List<AppUser> _selectedMembers = [];
  
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (widget.isEditing) {
      _nameController.text = widget.group!.name;
      _descriptionController.text = widget.group!.description ?? '';
    }
  }

  Future<void> _loadData() async {
    try {
      // Get available members (both agents and managers)
      final availableMembers = await _groupService.getAvailableMembersForGroup(widget.group?.id);
      
      setState(() {
        _availableMembers = availableMembers;
      });

      if (widget.isEditing) {
        // Load existing group data
        final groupWithMembers = await _groupService.getGroupWithMembers(widget.group!.id);
        setState(() {
          _selectedMembers = List.from(groupWithMembers.members);
          
          // Ensure all current members are in the available members list to avoid selection issues
          for (final member in groupWithMembers.members) {
            if (!_availableMembers.any((availableMember) => availableMember.id == member.id)) {
              _availableMembers.add(member);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to load data: $e', isError: true);
      }
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _saveGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final memberIds = _selectedMembers.map((member) => member.id).toList();

      if (widget.isEditing) {
        // Update existing group
        await _groupService.updateGroup(
          groupId: widget.group!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
        );

        // Update group members
        final currentGroupWithMembers = await _groupService.getGroupWithMembers(widget.group!.id);
        final currentMemberIds = currentGroupWithMembers.members.map((m) => m.id).toSet();
        final newMemberIds = memberIds.toSet();

        // Remove members that are no longer selected
        final toRemove = currentMemberIds.difference(newMemberIds).toList();
        if (toRemove.isNotEmpty) {
          await _groupService.removeMembersFromGroup(widget.group!.id, toRemove);
        }

        // Add new members
        final toAdd = newMemberIds.difference(currentMemberIds).toList();
        if (toAdd.isNotEmpty) {
          await _groupService.addMembersToGroup(widget.group!.id, toAdd);
        }

        if (mounted) {
          context.showSnackBar('Group updated successfully');
        }
      } else {
        // Create new group
        await _groupService.createGroup(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          memberIds: memberIds,
        );

        if (mounted) {
          context.showSnackBar('Group created successfully');
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          'Failed to ${widget.isEditing ? 'update' : 'create'} group: $e',
          isError: true,
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMemberSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => _buildMemberSelectionSheet(scrollController),
      ),
    );
  }

  Widget _buildMemberSelectionSheet(ScrollController scrollController) {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Select Members',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _availableMembers.length,
                  itemBuilder: (context, index) {
                    final member = _availableMembers[index];
                    final isSelected = _selectedMembers.any((selectedMember) => selectedMember.id == member.id);
                    
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedMembers.add(member);
                          } else {
                            _selectedMembers.removeWhere((selectedMember) => selectedMember.id == member.id);
                          }
                        });
                        setSheetState(() {}); // Update the sheet state too
                      },
                      title: Text(member.fullName),
                      subtitle: Text(
                        member.role.toUpperCase(),
                        style: TextStyle(
                          color: member.role == 'manager' ? Colors.orange : Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      secondary: CircleAvatar(
                        backgroundColor: member.role == 'manager' 
                            ? Colors.orange.withValues(alpha: 0.1)
                            : primaryColor.withValues(alpha: 0.1),
                        child: Icon(
                          member.role == 'manager' ? Icons.supervisor_account : Icons.person,
                          color: member.role == 'manager' ? Colors.orange : primaryColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Done (${_selectedMembers.length} selected)'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Group' : 'Create Group'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
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
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Group Name
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Group Information',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Group Name *',
                              hintText: 'Enter group name',
                              prefixIcon: Icon(Icons.group),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Group name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText: 'Enter group description (optional)',
                              prefixIcon: Icon(Icons.description),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Members Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Group Members',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _showMemberSelection,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Members'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_selectedMembers.isEmpty)
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
                                    'No members selected',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap "Add Members" to select agents and managers',
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
                              children: _selectedMembers.map((member) {
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: member.role == 'manager' 
                                        ? Colors.orange.withValues(alpha: 0.1)
                                        : primaryColor.withValues(alpha: 0.1),
                                    child: Icon(
                                      member.role == 'manager' ? Icons.supervisor_account : Icons.person,
                                      color: member.role == 'manager' ? Colors.orange : primaryColor,
                                    ),
                                  ),
                                  title: Text(member.fullName),
                                  subtitle: Text(
                                    member.role.toUpperCase(),
                                    style: TextStyle(
                                      color: member.role == 'manager' ? Colors.orange : Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedMembers.removeWhere((m) => m.id == member.id);
                                      });
                                    },
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              widget.isEditing ? 'Update Group' : 'Create Group',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}