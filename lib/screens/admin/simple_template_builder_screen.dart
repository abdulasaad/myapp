// lib/screens/admin/simple_template_builder_screen.dart

import 'package:flutter/material.dart';
import '../../models/template_category.dart';
import '../../models/task_template.dart';
import '../../services/template_service.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';

class SimpleTemplateBuilderScreen extends StatefulWidget {
  const SimpleTemplateBuilderScreen({super.key});

  @override
  State<SimpleTemplateBuilderScreen> createState() => _SimpleTemplateBuilderScreenState();
}

class _SimpleTemplateBuilderScreenState extends State<SimpleTemplateBuilderScreen> 
    with SingleTickerProviderStateMixin {
  final TemplateService _templateService = TemplateService();
  final PageController _pageController = PageController();
  late TabController _tabController;
  
  int _currentStep = 0;
  bool _isCreating = false;
  
  // Template data
  String _templateName = '';
  String _templateDescription = '';
  String? _selectedCategoryId;
  DifficultyLevel _difficultyLevel = DifficultyLevel.easy;
  final List<EvidenceType> _evidenceTypes = [EvidenceType.image];
  bool _requiresGeofence = false;
  String _customInstructions = '';
  int _estimatedDuration = 30; // minutes
  int _rewardPoints = 10;
  
  List<TemplateCategory> _categories = [];
  
  final List<String> _stepTitles = [
    'Basic Info',
    'Requirements',
    'Review & Create'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _stepTitles.length, vsync: this);
    _loadCategories();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _templateService.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          if (categories.isNotEmpty) {
            _selectedCategoryId = categories.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.errorLoadingCategories, isError: true);
      }
    }
  }

  void _nextStep() {
    if (_currentStep < _stepTitles.length - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _tabController.animateTo(_currentStep);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _tabController.animateTo(_currentStep);
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0: // Basic Info
        return _templateName.trim().isNotEmpty && 
               _templateDescription.trim().isNotEmpty &&
               _selectedCategoryId != null;
      case 1: // Requirements
        return _evidenceTypes.isNotEmpty && _rewardPoints > 0;
      case 2: // Review
        return true;
      default:
        return false;
    }
  }

  Future<void> _createTemplate() async {
    if (_isCreating) return;
    
    setState(() => _isCreating = true);
    
    try {
      await _templateService.createTemplate(
        name: _templateName.trim(),
        categoryId: _selectedCategoryId!,
        description: _templateDescription.trim(),
        defaultPoints: _rewardPoints,
        requiresGeofence: _requiresGeofence,
        defaultEvidenceCount: 1,
        templateConfig: {
          'customInstructions': _customInstructions.trim(),
          'estimatedDuration': _estimatedDuration,
        },
        evidenceTypes: _evidenceTypes,
        customInstructions: _customInstructions.trim().isNotEmpty ? _customInstructions.trim() : null,
        estimatedDuration: _estimatedDuration,
        difficultyLevel: _difficultyLevel,
      );
      
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.templateCreatedSuccessfully);
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.errorCreatingTemplate, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.createNewTemplate),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Theme.of(context).primaryColor,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey[600],
          tabs: _stepTitles.asMap().entries.map((entry) {
            final index = entry.key;
            final title = entry.value;
            final isCompleted = index < _currentStep;
            final isCurrent = index == _currentStep;
            
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted 
                          ? Colors.green 
                          : isCurrent 
                              ? Theme.of(context).primaryColor 
                              : Colors.grey[300],
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isCurrent ? Colors.white : Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 12)),
                ],
              ),
            );
          }).toList(),
          onTap: (index) {
            // Allow going back to previous steps
            if (index <= _currentStep) {
              setState(() => _currentStep = index);
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.stepXOfY(_currentStep + 1, _stepTitles.length),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${((_currentStep + 1) / _stepTitles.length * 100).round()}%',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentStep + 1) / _stepTitles.length,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                ),
              ],
            ),
          ),
          
          // Step content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildBasicInfoStep(),
                _buildRequirementsStep(),
                _buildReviewStep(),
              ],
            ),
          ),
          
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      child: Text(AppLocalizations.of(context)!.back),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _canProceed() 
                        ? (_currentStep == _stepTitles.length - 1 
                            ? _createTemplate 
                            : _nextStep)
                        : null,
                    child: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_currentStep == _stepTitles.length - 1 
                            ? AppLocalizations.of(context)!.createTemplate 
                            : AppLocalizations.of(context)!.next),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            AppLocalizations.of(context)!.basicInformation,
            AppLocalizations.of(context)!.tellUsAboutTemplate,
            Icons.info_outline,
          ),
          const SizedBox(height: 24),
          
          _buildInputCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.templateNameRequired,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.templateNameHint,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _templateName = value),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                
                Text(
                  AppLocalizations.of(context)!.descriptionRequired,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.describeAgentTask,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (value) => setState(() => _templateDescription = value),
                ),
                const SizedBox(height: 16),
                
                Text(
                  AppLocalizations.of(context)!.categoryRequired,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategoryId,
                      isExpanded: true,
                      hint: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(AppLocalizations.of(context)!.selectCategory),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category.id,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(_getCategoryIcon(category.iconName), size: 20),
                                const SizedBox(width: 8),
                                Text(category.name),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedCategoryId = value),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            AppLocalizations.of(context)!.taskRequirements,
            AppLocalizations.of(context)!.configureAgentRequirements,
            Icons.assignment_outlined,
          ),
          const SizedBox(height: 24),
          
          _buildInputCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.difficultyLevel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: DifficultyLevel.values.map((level) {
                    final isSelected = _difficultyLevel == level;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _difficultyLevel = level),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _getDifficultyIcon(level),
                                  color: isSelected ? Colors.white : Colors.grey[600],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  level.name.toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          _buildInputCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.evidenceRequired,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: EvidenceType.values.map((type) {
                    final isSelected = _evidenceTypes.contains(type);
                    return FilterChip(
                      label: Text(_getEvidenceTypeLabel(type)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _evidenceTypes.add(type);
                          } else {
                            _evidenceTypes.remove(type);
                          }
                        });
                      },
                      avatar: Icon(_getEvidenceTypeIcon(type), size: 18),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          _buildInputCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.estimatedDurationMinutes,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _estimatedDuration.toString(),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              suffixText: AppLocalizations.of(context)!.minutesShort,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              final duration = int.tryParse(value) ?? 30;
                              setState(() => _estimatedDuration = duration);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.rewardPoints,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _rewardPoints.toString(),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              suffixText: AppLocalizations.of(context)!.pointsShort,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              final points = int.tryParse(value) ?? 10;
                              setState(() => _rewardPoints = points);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)!.requiresGeofence),
                  subtitle: Text(AppLocalizations.of(context)!.taskMustBeCompletedAtLocation),
                  value: _requiresGeofence,
                  onChanged: (value) => setState(() => _requiresGeofence = value),
                  contentPadding: EdgeInsets.zero,
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  AppLocalizations.of(context)!.customInstructionsOptional,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.additionalInstructionsForAgents,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (value) => setState(() => _customInstructions = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            AppLocalizations.of(context)!.reviewAndCreate,
            AppLocalizations.of(context)!.verifyTemplateBeforeCreating,
            Icons.check_circle_outline,
          ),
          const SizedBox(height: 24),
          
          _buildInputCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _selectedCategoryId != null 
                            ? _getCategoryIcon(_categories.firstWhere((c) => c.id == _selectedCategoryId).iconName)
                            : Icons.category,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _templateName.isNotEmpty ? _templateName : AppLocalizations.of(context)!.templateName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _templateDescription.isNotEmpty ? _templateDescription : AppLocalizations.of(context)!.description,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                _buildReviewSection(AppLocalizations.of(context)!.category, _selectedCategoryId != null 
                    ? _categories.firstWhere((c) => c.id == _selectedCategoryId).name
                    : AppLocalizations.of(context)!.notSelected),
                
                _buildReviewSection(AppLocalizations.of(context)!.difficulty, _difficultyLevel.name.toUpperCase()),
                
                _buildReviewSection(AppLocalizations.of(context)!.evidenceRequired, 
                    _evidenceTypes.map((type) => _getEvidenceTypeLabel(type)).join(', ')),
                
                _buildReviewSection(AppLocalizations.of(context)!.duration, AppLocalizations.of(context)!.minutesFormat(_estimatedDuration.toString())),
                
                _buildReviewSection(AppLocalizations.of(context)!.reward, AppLocalizations.of(context)!.pointsFormat(_rewardPoints.toString())),
                
                _buildReviewSection(AppLocalizations.of(context)!.geofenceRequired, _requiresGeofence ? AppLocalizations.of(context)!.yes : AppLocalizations.of(context)!.no),
                
                if (_customInstructions.isNotEmpty)
                  _buildReviewSection(AppLocalizations.of(context)!.instructions, _customInstructions),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildReviewSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'business_development': return Icons.trending_up;
      case 'sales_orders': return Icons.shopping_cart;
      case 'service_support': return Icons.support_agent;
      case 'compliance_audit': return Icons.verified_user;
      case 'operations': return Icons.settings;
      case 'marketing': return Icons.campaign;
      default: return Icons.category;
    }
  }

  IconData _getDifficultyIcon(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.easy: return Icons.sentiment_satisfied;
      case DifficultyLevel.medium: return Icons.sentiment_neutral;
      case DifficultyLevel.hard: return Icons.sentiment_dissatisfied;
    }
  }

  String _getEvidenceTypeLabel(EvidenceType type) {
    switch (type) {
      case EvidenceType.image: return AppLocalizations.of(context)!.photo;
      case EvidenceType.video: return AppLocalizations.of(context)!.video;
      case EvidenceType.document: return AppLocalizations.of(context)!.document;
      case EvidenceType.pdf: return AppLocalizations.of(context)!.pdf;
      case EvidenceType.audio: return AppLocalizations.of(context)!.audio;
    }
  }


  IconData _getEvidenceTypeIcon(EvidenceType type) {
    switch (type) {
      case EvidenceType.image: return Icons.camera_alt;
      case EvidenceType.video: return Icons.videocam;
      case EvidenceType.document: return Icons.description;
      case EvidenceType.pdf: return Icons.picture_as_pdf;
      case EvidenceType.audio: return Icons.mic;
    }
  }
}