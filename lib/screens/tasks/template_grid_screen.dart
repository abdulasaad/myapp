// lib/screens/tasks/template_grid_screen.dart

import 'package:flutter/material.dart';
import '../../models/template_category.dart';
import '../../models/task_template.dart';
import '../../services/template_service.dart';
import '../../utils/constants.dart';
import 'create_task_from_template_screen.dart';
import 'template_preview_screen.dart';

class TemplateGridScreen extends StatefulWidget {
  final TemplateCategory category;

  const TemplateGridScreen({super.key, required this.category});

  @override
  State<TemplateGridScreen> createState() => _TemplateGridScreenState();
}

class _TemplateGridScreenState extends State<TemplateGridScreen> {
  late Future<List<TaskTemplate>> _templatesFuture;
  final TemplateService _templateService = TemplateService();
  String _searchQuery = '';
  String _difficultyFilter = 'all';
  bool _geofenceFilter = false;

  @override
  void initState() {
    super.initState();
    _templatesFuture = _templateService.getTemplatesByCategory(widget.category.id);
  }

  void _refreshTemplates() {
    setState(() {
      _templatesFuture = _templateService.getTemplatesByCategory(widget.category.id);
    });
  }

  List<TaskTemplate> _filterTemplates(List<TaskTemplate> templates) {
    var filtered = templates;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((template) {
        return template.name.toLowerCase().contains(query) ||
               template.description.toLowerCase().contains(query) ||
               template.customInstructions?.toLowerCase().contains(query) == true;
      }).toList();
    }

    // Difficulty filter
    if (_difficultyFilter != 'all') {
      final difficulty = DifficultyLevel.values.firstWhere(
        (d) => d.name == _difficultyFilter,
        orElse: () => DifficultyLevel.medium,
      );
      filtered = filtered.where((template) => template.difficultyLevel == difficulty).toList();
    }

    // Geofence filter
    if (_geofenceFilter) {
      filtered = filtered.where((template) => template.requiresGeofence).toList();
    }

    return filtered;
  }

  Color _getDifficultyColor(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.easy:
        return Colors.green;
      case DifficultyLevel.medium:
        return Colors.orange;
      case DifficultyLevel.hard:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: FutureBuilder<List<TaskTemplate>>(
              future: _templatesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return preloader;
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading templates',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshTemplates,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final allTemplates = snapshot.data ?? [];
                final filteredTemplates = _filterTemplates(allTemplates);
                
                if (filteredTemplates.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _difficultyFilter != 'all' || _geofenceFilter
                              ? 'No templates match your filters'
                              : 'No templates in this category',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        if (_searchQuery.isNotEmpty || _difficultyFilter != 'all' || _geofenceFilter)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _difficultyFilter = 'all';
                                _geofenceFilter = false;
                              });
                            },
                            child: const Text('Clear filters'),
                          ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refreshTemplates(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTemplates.length,
                    itemBuilder: (context, index) {
                      final template = filteredTemplates[index];
                      return _buildTemplateCard(template);
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

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: const InputDecoration(
          hintText: 'Search templates...',
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final hasActiveFilters = _difficultyFilter != 'all' || _geofenceFilter;
    
    if (!hasActiveFilters) return const SizedBox.shrink();

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_difficultyFilter != 'all')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('Difficulty: ${_difficultyFilter.toUpperCase()}'),
                onDeleted: () => setState(() => _difficultyFilter = 'all'),
                deleteIcon: const Icon(Icons.close, size: 18),
              ),
            ),
          if (_geofenceFilter)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Requires Location'),
                onDeleted: () => setState(() => _geofenceFilter = false),
                deleteIcon: const Icon(Icons.close, size: 18),
              ),
            ),
          TextButton(
            onPressed: () {
              setState(() {
                _difficultyFilter = 'all';
                _geofenceFilter = false;
              });
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(TaskTemplate template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showTemplateActions(template),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(template.difficultyLevel).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      template.difficultyDisplayName,
                      style: TextStyle(
                        color: _getDifficultyColor(template.difficultyLevel),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                template.description,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(Icons.stars, '${template.defaultPoints} pts', Colors.amber),
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.upload_file, '${template.defaultEvidenceCount} evidence', Colors.blue),
                  if (template.requiresGeofence) ...[
                    const SizedBox(width: 8),
                    _buildInfoChip(Icons.location_on, 'Location', Colors.green),
                  ],
                ],
              ),
              if (template.estimatedDuration != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Est. ${template.estimatedDurationDisplay}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => _previewTemplate(template),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Preview'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _createTaskFromTemplate(template),
                    icon: const Icon(Icons.add_task, size: 16),
                    label: const Text('Use Template'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showTemplateActions(TaskTemplate template) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Preview Template'),
              onTap: () {
                Navigator.pop(context);
                _previewTemplate(template);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_task),
              title: const Text('Create Task from Template'),
              onTap: () {
                Navigator.pop(context);
                _createTaskFromTemplate(template);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _previewTemplate(TaskTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TemplatePreviewScreen(template: template),
      ),
    );
  }

  void _createTaskFromTemplate(TaskTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateTaskFromTemplateScreen(template: template),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Templates'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Difficulty Level:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _difficultyFilter,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Levels')),
                  DropdownMenuItem(value: 'easy', child: Text('Easy')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'hard', child: Text('Hard')),
                ],
                onChanged: (value) => setState(() => _difficultyFilter = value!),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Requires Location'),
                subtitle: const Text('Only show location-based tasks'),
                value: _geofenceFilter,
                onChanged: (value) => setState(() => _geofenceFilter = value!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {}); // Refresh the main screen
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}