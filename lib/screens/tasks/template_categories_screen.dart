// lib/screens/tasks/template_categories_screen.dart

import 'package:flutter/material.dart';
import '../../models/template_category.dart';
import '../../services/template_service.dart';
import '../../utils/constants.dart';
import 'template_grid_screen.dart';

class TemplateCategoriesScreen extends StatefulWidget {
  const TemplateCategoriesScreen({super.key});

  @override
  State<TemplateCategoriesScreen> createState() => _TemplateCategoriesScreenState();
}

class _TemplateCategoriesScreenState extends State<TemplateCategoriesScreen> {
  late Future<List<TemplateCategory>> _categoriesFuture;
  final TemplateService _templateService = TemplateService();

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _templateService.getCategoriesForManager();
  }

  void _refreshCategories() {
    setState(() {
      _categoriesFuture = _templateService.getCategoriesForManager();
    });
  }

  IconData _getIconForCategory(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'business':
        return Icons.business;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'support_agent':
        return Icons.support_agent;
      case 'verified':
        return Icons.verified;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'campaign':
        return Icons.campaign;
      case 'medical_services':
        return Icons.medical_services;
      case 'engineering':
        return Icons.engineering;
      case 'real_estate_agent':
        return Icons.real_estate_agent;
      case 'agriculture':
        return Icons.agriculture;
      default:
        return Icons.category;
    }
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.red,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Category'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: FutureBuilder<List<TemplateCategory>>(
        future: _categoriesFuture,
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
                    'Error loading categories',
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
                    onPressed: _refreshCategories,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final categories = snapshot.data ?? [];
          
          if (categories.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No categories available',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Template categories will appear here when created.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refreshCategories(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.inversePrimary.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a category to browse task templates',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final color = _getColorForIndex(index);
                          
                          return _buildCategoryCard(category, color);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(TemplateCategory category, Color color) {
    return Card(
      elevation: 8,
      shadowColor: color.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TemplateGridScreen(category: category),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForCategory(category.iconName),
                    size: 28,
                    color: color,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Text(
                    category.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}