// lib/screens/admin/template_setup_screen.dart

import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../models/app_user.dart';
import '../../models/task_template.dart';

class TemplateSetupScreen extends StatefulWidget {
  const TemplateSetupScreen({super.key});

  @override
  State<TemplateSetupScreen> createState() => _TemplateSetupScreenState();
}

class _TemplateSetupScreenState extends State<TemplateSetupScreen> {
  bool _isLoadingManagers = false;
  bool _isLoadingTemplates = false;
  List<AppUser> _managers = [];
  List<TaskTemplate> _templates = [];
  Map<String, List<String>> _managerTemplateAssignments = {};
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Template Access'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _buildManagerTemplateAssignment(),
    );
  }

  Widget _buildManagerTemplateAssignment() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manager Template Access',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Assign specific template categories to managers to control what task types they can create.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoadingManagers)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (_managers.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No managers found',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _managers.length,
                itemBuilder: (context, index) {
                  final manager = _managers[index];
                  return _buildManagerCard(manager);
                },
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildManagerCard(AppUser manager) {
    final assignedTemplates = _managerTemplateAssignments[manager.id] ?? [];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Text(
            manager.fullName.isNotEmpty ? manager.fullName[0].toUpperCase() : 'M',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          manager.fullName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${assignedTemplates.length} templates assigned',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Templates:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => _selectAllTemplates(manager.id),
                          child: const Text('Select All'),
                        ),
                        TextButton(
                          onPressed: () => _clearAllTemplates(manager.id),
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoadingTemplates)
                  const Center(child: CircularProgressIndicator())
                else
                  ..._templates.map((template) => 
                    _buildTemplateCheckbox(manager.id, template, assignedTemplates)
                  ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: () => _saveManagerTemplateAssignments(manager.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Save Template Assignments'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTemplateCheckbox(String managerId, TaskTemplate template, List<String> assignedTemplates) {
    final isAssigned = assignedTemplates.contains(template.id);
    
    return CheckboxListTile(
      title: Text(
        template.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            template.description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${template.defaultPoints} pts',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (template.requiresGeofence)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Location Required',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      value: isAssigned,
      onChanged: (value) {
        setState(() {
          if (value == true) {
            if (!assignedTemplates.contains(template.id)) {
              _managerTemplateAssignments[managerId] = [...assignedTemplates, template.id];
            }
          } else {
            _managerTemplateAssignments[managerId] = assignedTemplates.where((t) => t != template.id).toList();
          }
        });
      },
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingManagers = true;
      _isLoadingTemplates = true;
    });
    
    try {
      // Load managers
      final managersResponse = await supabase
          .from('profiles')
          .select('*')
          .eq('role', 'manager')
          .order('full_name');
      
      final managers = managersResponse.map((json) => AppUser.fromJson(json)).toList();
      
      // Load templates
      final templatesResponse = await supabase
          .from('task_templates')
          .select('*')
          .eq('is_active', true)
          .order('name');
      
      final templates = templatesResponse.map((json) => TaskTemplate.fromJson(json)).toList();
      
      // Load existing template assignments
      final assignmentsResponse = await supabase
          .from('manager_template_access')
          .select('manager_id, template_categories');
      
      final assignments = <String, List<String>>{};
      for (final assignment in assignmentsResponse) {
        final managerId = assignment['manager_id'] as String;
        final templateIds = (assignment['template_categories'] as List<dynamic>?)?.cast<String>() ?? [];
        assignments[managerId] = templateIds;
      }
      
      setState(() {
        _managers = managers;
        _templates = templates;
        _managerTemplateAssignments = assignments;
        _isLoadingManagers = false;
        _isLoadingTemplates = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingManagers = false;
        _isLoadingTemplates = false;
      });
      if (mounted) {
        context.showSnackBar('Failed to load data: $e', isError: true);
      }
    }
  }
  
  void _selectAllTemplates(String managerId) {
    setState(() {
      _managerTemplateAssignments[managerId] = _templates.map((t) => t.id).toList();
    });
  }
  
  void _clearAllTemplates(String managerId) {
    setState(() {
      _managerTemplateAssignments[managerId] = [];
    });
  }
  
  Future<void> _saveManagerTemplateAssignments(String managerId) async {
    try {
      final templateIds = _managerTemplateAssignments[managerId] ?? [];
      
      // Use upsert to either insert or update
      await supabase
          .from('manager_template_access')
          .upsert({
            'manager_id': managerId,
            'template_categories': templateIds, // Now stores template IDs instead of category names
            'updated_at': DateTime.now().toIso8601String(),
          });
      
      if (mounted) {
        context.showSnackBar('Template assignments saved successfully!');
        // Collapse the expansion tile after saving
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to save assignments: $e', isError: true);
      }
    }
  }

}