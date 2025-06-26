// lib/screens/admin/template_setup_screen.dart

import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../models/app_user.dart';

class TemplateSetupScreen extends StatefulWidget {
  const TemplateSetupScreen({super.key});

  @override
  State<TemplateSetupScreen> createState() => _TemplateSetupScreenState();
}

class _TemplateSetupScreenState extends State<TemplateSetupScreen> with TickerProviderStateMixin {
  bool _isCreating = false;
  bool _isLoadingManagers = false;
  late TabController _tabController;
  List<AppUser> _managers = [];
  Map<String, List<String>> _managerTemplateAssignments = {};
  
  final List<TemplateCategory> _templateCategories = [
    TemplateCategory('Data Collection', 'assignment', ['Customer Survey', 'Market Research', 'Customer Visit']),
    TemplateCategory('Location Tasks', 'location_on', ['Site Monitoring', 'Security Patrol']),
    TemplateCategory('Inspections', 'fact_check', ['Equipment Inspection', 'Safety Compliance']),
    TemplateCategory('Customer Service', 'support_agent', ['Package Delivery']),
    TemplateCategory('Operations', 'engineering', ['Equipment Maintenance', 'Simple Evidence Task']),
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadManagers();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Template Management'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.rocket_launch), text: 'Setup Templates'),
            Tab(icon: Icon(Icons.person_add), text: 'Manager Access'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTemplateSetupTab(),
          _buildManagerAccessTab(),
        ],
      ),
    );
  }

  Widget _buildTemplateSetupTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Setup Enhanced Templates',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create the enhanced template categories and templates for the new task types.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What will be created:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTemplateItem('📝 Data Collection', 'Form-based data entry with custom fields'),
                  _buildTemplateItem('📍 Location Stay', 'Stay in designated area for duration'),
                  _buildTemplateItem('🔍 Inspection', 'Detailed checklists and inspections'),
                  _buildTemplateItem('📊 Survey', 'Questionnaires and feedback forms'),
                  _buildTemplateItem('🚚 Delivery', 'Delivery confirmation with signatures'),
                  _buildTemplateItem('🔧 Maintenance', 'Equipment maintenance reports'),
                  _buildTemplateItem('👁️ Monitoring', 'Observation and monitoring tasks'),
                  _buildTemplateItem('📸 Evidence Upload', 'Simple photo/document upload'),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCreating ? null : _createTemplates,
              icon: _isCreating 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.rocket_launch),
              label: Text(_isCreating ? 'Creating Templates...' : 'Create Enhanced Templates'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildManagerAccessTab() {
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
  
  Widget _buildTemplateItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
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
          '${assignedTemplates.length} template categories assigned',
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
                Text(
                  'Template Categories Access:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._templateCategories.map((category) => 
                  _buildCategoryCheckbox(manager.id, category, assignedTemplates)
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => _selectAllCategories(manager.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Select All'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => _clearAllCategories(manager.id),
                      child: const Text('Clear All'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => _saveManagerTemplateAssignments(manager.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Save'),
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
  
  Widget _buildCategoryCheckbox(String managerId, TemplateCategory category, List<String> assignedTemplates) {
    final isAssigned = assignedTemplates.contains(category.name);
    
    return CheckboxListTile(
      title: Row(
        children: [
          Icon(category.getIconData(), size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(category.name),
        ],
      ),
      subtitle: Text(
        'Templates: ${category.templates.join(', ')}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      value: isAssigned,
      onChanged: (value) {
        setState(() {
          if (value == true) {
            if (!assignedTemplates.contains(category.name)) {
              _managerTemplateAssignments[managerId] = [...assignedTemplates, category.name];
            }
          } else {
            _managerTemplateAssignments[managerId] = assignedTemplates.where((t) => t != category.name).toList();
          }
        });
      },
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Future<void> _loadManagers() async {
    setState(() => _isLoadingManagers = true);
    
    try {
      final response = await supabase
          .from('profiles')
          .select('*')
          .eq('role', 'manager')
          .order('full_name');
      
      final managers = response.map((json) => AppUser.fromJson(json)).toList();
      
      // Load existing template assignments
      final assignmentsResponse = await supabase
          .from('manager_template_access')
          .select('manager_id, template_categories');
      
      final assignments = <String, List<String>>{};
      for (final assignment in assignmentsResponse) {
        final managerId = assignment['manager_id'] as String;
        final categories = (assignment['template_categories'] as List<dynamic>?)?.cast<String>() ?? [];
        assignments[managerId] = categories;
      }
      
      setState(() {
        _managers = managers;
        _managerTemplateAssignments = assignments;
        _isLoadingManagers = false;
      });
    } catch (e) {
      setState(() => _isLoadingManagers = false);
      if (mounted) {
        context.showSnackBar('Failed to load managers: $e', isError: true);
      }
    }
  }
  
  void _selectAllCategories(String managerId) {
    setState(() {
      _managerTemplateAssignments[managerId] = _templateCategories.map((c) => c.name).toList();
    });
  }
  
  void _clearAllCategories(String managerId) {
    setState(() {
      _managerTemplateAssignments[managerId] = [];
    });
  }
  
  Future<void> _saveManagerTemplateAssignments(String managerId) async {
    try {
      final categories = _managerTemplateAssignments[managerId] ?? [];
      
      // Use upsert to either insert or update
      await supabase
          .from('manager_template_access')
          .upsert({
            'manager_id': managerId,
            'template_categories': categories,
            'updated_at': DateTime.now().toIso8601String(),
          });
      
      if (mounted) {
        context.showSnackBar('Template assignments saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to save assignments: $e', isError: true);
      }
    }
  }

  Future<void> _createTemplates() async {
    setState(() => _isCreating = true);

    try {
      // First, create the template categories if they don't exist
      await _createTemplateCategories();
      
      // Then create the enhanced templates
      await _createEnhancedTemplates();
      
      if (mounted) {
        context.showSnackBar('Enhanced templates created successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to create templates: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _createTemplateCategories() async {
    final categories = [
      {
        'name': 'Data Collection',
        'description': 'Form-based data collection with custom fields',
        'icon_name': 'assignment',
        'sort_order': 1,
      },
      {
        'name': 'Location Tasks',
        'description': 'Location-based tasks and monitoring',
        'icon_name': 'location_on',
        'sort_order': 2,
      },
      {
        'name': 'Inspections',
        'description': 'Quality control and inspection tasks',
        'icon_name': 'fact_check',
        'sort_order': 3,
      },
      {
        'name': 'Customer Service',
        'description': 'Customer interaction and service tasks',
        'icon_name': 'support_agent',
        'sort_order': 4,
      },
      {
        'name': 'Operations',
        'description': 'Operational and maintenance tasks',
        'icon_name': 'engineering',
        'sort_order': 5,
      },
    ];

    for (final category in categories) {
      try {
        await supabase.from('template_categories').insert(category);
      } catch (e) {
        // Category might already exist, continue
        debugPrint('Category already exists: ${category['name']}');
      }
    }
  }

  Future<void> _createEnhancedTemplates() async {
    // Get category IDs
    final categoriesResponse = await supabase
        .from('template_categories')
        .select('id, name');
    
    final categoryMap = <String, String>{};
    for (final cat in categoriesResponse) {
      categoryMap[cat['name']] = cat['id'];
    }

    final templates = [
      // Data Collection Templates
      {
        'name': 'Customer Survey',
        'category_id': categoryMap['Data Collection'],
        'description': 'Collect customer feedback and satisfaction data',
        'task_type': 'dataCollection',
        'default_points': 15,
        'requires_geofence': false,
        'default_evidence_count': 0,
        'evidence_types': ['document'],
        'difficulty_level': 'easy',
        'estimated_duration': 10,
      },
      {
        'name': 'Market Research',
        'category_id': categoryMap['Data Collection'],
        'description': 'Gather market data and consumer insights',
        'task_type': 'survey',
        'default_points': 20,
        'requires_geofence': true,
        'default_evidence_count': 1,
        'evidence_types': ['document'],
        'difficulty_level': 'medium',
        'estimated_duration': 15,
      },
      
      // Location Tasks
      {
        'name': 'Site Monitoring',
        'category_id': categoryMap['Location Tasks'],
        'description': 'Monitor specific location for security or compliance',
        'task_type': 'geofenceStay',
        'default_points': 25,
        'requires_geofence': true,
        'default_evidence_count': 2,
        'evidence_types': ['image'],
        'difficulty_level': 'easy',
        'estimated_duration': 30,
        'template_config': {
          'required_stay_minutes': 30,
          'allow_early_completion': false,
        },
      },
      {
        'name': 'Security Patrol',
        'category_id': categoryMap['Location Tasks'],
        'description': 'Patrol designated area and report observations',
        'task_type': 'monitoring',
        'default_points': 20,
        'requires_geofence': true,
        'default_evidence_count': 3,
        'evidence_types': ['image'],
        'difficulty_level': 'medium',
        'estimated_duration': 45,
      },
      
      // Inspection Templates
      {
        'name': 'Equipment Inspection',
        'category_id': categoryMap['Inspections'],
        'description': 'Detailed equipment safety and functionality check',
        'task_type': 'inspection',
        'default_points': 30,
        'requires_geofence': true,
        'default_evidence_count': 2,
        'evidence_types': ['image', 'document'],
        'difficulty_level': 'hard',
        'estimated_duration': 20,
      },
      {
        'name': 'Safety Compliance',
        'category_id': categoryMap['Inspections'],
        'description': 'Verify safety protocols and compliance standards',
        'task_type': 'inspection',
        'default_points': 25,
        'requires_geofence': true,
        'default_evidence_count': 3,
        'evidence_types': ['image', 'document'],
        'difficulty_level': 'medium',
        'estimated_duration': 25,
      },
      
      // Customer Service Templates
      {
        'name': 'Package Delivery',
        'category_id': categoryMap['Customer Service'],
        'description': 'Deliver package and obtain customer signature',
        'task_type': 'delivery',
        'default_points': 10,
        'requires_geofence': true,
        'default_evidence_count': 1,
        'evidence_types': ['image'],
        'difficulty_level': 'easy',
        'estimated_duration': 5,
      },
      {
        'name': 'Customer Visit',
        'category_id': categoryMap['Customer Service'],
        'description': 'Visit customer location for service or support',
        'task_type': 'dataCollection',
        'default_points': 20,
        'requires_geofence': true,
        'default_evidence_count': 1,
        'evidence_types': ['image', 'document'],
        'difficulty_level': 'medium',
        'estimated_duration': 30,
      },
      
      // Operations Templates
      {
        'name': 'Equipment Maintenance',
        'category_id': categoryMap['Operations'],
        'description': 'Perform routine maintenance and document work',
        'task_type': 'maintenance',
        'default_points': 35,
        'requires_geofence': true,
        'default_evidence_count': 2,
        'evidence_types': ['image', 'document'],
        'difficulty_level': 'hard',
        'estimated_duration': 60,
      },
      {
        'name': 'Simple Evidence Task',
        'category_id': categoryMap['Operations'],
        'description': 'Basic photo or document upload task',
        'task_type': 'simpleEvidence',
        'default_points': 5,
        'requires_geofence': false,
        'default_evidence_count': 1,
        'evidence_types': ['image'],
        'difficulty_level': 'easy',
        'estimated_duration': 5,
      },
    ];

    for (final template in templates) {
      await supabase.from('task_templates').insert(template);
    }

    // Create sample template fields for data collection tasks
    await _createSampleTemplateFields();
  }

  Future<void> _createSampleTemplateFields() async {
    // Get template IDs
    final templatesResponse = await supabase
        .from('task_templates')
        .select('id, name')
        .inFilter('task_type', ['dataCollection', 'survey', 'inspection', 'delivery', 'maintenance']);
    
    final templateMap = <String, String>{};
    for (final template in templatesResponse) {
      templateMap[template['name']] = template['id'];
    }

    final fields = [
      // Customer Survey Fields
      {
        'template_id': templateMap['Customer Survey'],
        'field_name': 'customer_name',
        'field_type': 'text',
        'field_label': 'Customer Name',
        'placeholder_text': 'Enter customer full name',
        'is_required': true,
        'sort_order': 1,
      },
      {
        'template_id': templateMap['Customer Survey'],
        'field_name': 'satisfaction_rating',
        'field_type': 'select',
        'field_label': 'Satisfaction Rating',
        'field_options': ['Very Satisfied', 'Satisfied', 'Neutral', 'Dissatisfied', 'Very Dissatisfied'],
        'is_required': true,
        'sort_order': 2,
      },
      {
        'template_id': templateMap['Customer Survey'],
        'field_name': 'feedback',
        'field_type': 'textarea',
        'field_label': 'Additional Feedback',
        'placeholder_text': 'Any additional comments or suggestions...',
        'is_required': false,
        'sort_order': 3,
      },
      
      // Equipment Inspection Fields
      {
        'template_id': templateMap['Equipment Inspection'],
        'field_name': 'equipment_id',
        'field_type': 'text',
        'field_label': 'Equipment ID',
        'placeholder_text': 'Enter equipment serial number',
        'is_required': true,
        'sort_order': 1,
      },
      {
        'template_id': templateMap['Equipment Inspection'],
        'field_name': 'condition_status',
        'field_type': 'radio',
        'field_label': 'Equipment Condition',
        'field_options': ['Excellent', 'Good', 'Fair', 'Poor', 'Requires Maintenance'],
        'is_required': true,
        'sort_order': 2,
      },
      {
        'template_id': templateMap['Equipment Inspection'],
        'field_name': 'safety_compliant',
        'field_type': 'checkbox',
        'field_label': 'Meets Safety Standards',
        'is_required': true,
        'sort_order': 3,
      },
      
      // Package Delivery Fields
      {
        'template_id': templateMap['Package Delivery'],
        'field_name': 'recipient_name',
        'field_type': 'text',
        'field_label': 'Recipient Name',
        'placeholder_text': 'Name of person receiving package',
        'is_required': true,
        'sort_order': 1,
      },
      {
        'template_id': templateMap['Package Delivery'],
        'field_name': 'delivery_time',
        'field_type': 'time',
        'field_label': 'Delivery Time',
        'is_required': true,
        'sort_order': 2,
      },
    ];

    for (final field in fields) {
      try {
        await supabase.from('template_fields').insert(field);
      } catch (e) {
        debugPrint('Error creating field: $e');
      }
    }
  }
}

class TemplateCategory {
  final String name;
  final String iconName;
  final List<String> templates;
  
  TemplateCategory(this.name, this.iconName, this.templates);
  
  IconData getIconData() {
    switch (iconName) {
      case 'assignment':
        return Icons.assignment;
      case 'location_on':
        return Icons.location_on;
      case 'fact_check':
        return Icons.fact_check;
      case 'support_agent':
        return Icons.support_agent;
      case 'engineering':
        return Icons.engineering;
      default:
        return Icons.category;
    }
  }
}