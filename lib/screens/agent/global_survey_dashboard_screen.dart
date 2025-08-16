// lib/screens/agent/global_survey_dashboard_screen.dart

import 'package:flutter/material.dart';
import '../../services/global_survey_service.dart';
import '../../models/global_survey.dart';
import '../../models/survey_field.dart';
import '../../models/global_survey_submission.dart';
import '../../utils/constants.dart';
import '../../widgets/modern_notification.dart';

class AgentGlobalSurveyDashboardScreen extends StatefulWidget {
  const AgentGlobalSurveyDashboardScreen({super.key});

  @override
  State<AgentGlobalSurveyDashboardScreen> createState() => _AgentGlobalSurveyDashboardScreenState();
}

class _AgentGlobalSurveyDashboardScreenState extends State<AgentGlobalSurveyDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = GlobalSurveyService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('Surveys'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Available'), Tab(text: 'My Submissions')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AgentAvailableSurveysTab(),
          _AgentMySubmissionsTab(),
        ],
      ),
    );
  }
}

class _AgentAvailableSurveysTab extends StatelessWidget {
  const _AgentAvailableSurveysTab();

  @override
  Widget build(BuildContext context) {
    final service = GlobalSurveyService();
    return FutureBuilder<List<GlobalSurvey>>(
      future: service.getAgentSurveys(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) return const Center(child: Text('No surveys available'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final s = list[i];
            return ListTile(
              tileColor: surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(s.title),
              subtitle: Text(s.description ?? ''),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => _AgentGlobalSurveyFillScreen(survey: s),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AgentMySubmissionsTab extends StatelessWidget {
  const _AgentMySubmissionsTab();
  @override
  Widget build(BuildContext context) {
    final service = GlobalSurveyService();
    return FutureBuilder<List<GlobalSurveySubmission>>(
      future: service.getAgentMySubmissions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) return const Center(child: Text('No submissions yet'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final s = list[i];
            return ListTile(
              tileColor: surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Submitted: ${s.submittedAt}'),
              subtitle: Text(s.submissionData.keys.join(', ')),
            );
          },
        );
      },
    );
  }
}

class _AgentGlobalSurveyFillScreen extends StatefulWidget {
  final GlobalSurvey survey;
  const _AgentGlobalSurveyFillScreen({required this.survey});

  @override
  State<_AgentGlobalSurveyFillScreen> createState() => _AgentGlobalSurveyFillScreenState();
}

class _AgentGlobalSurveyFillScreenState extends State<_AgentGlobalSurveyFillScreen> {
  final _service = GlobalSurveyService();
  bool _loading = true;
  List<SurveyField> _fields = [];
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _data = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fields = await _service.getSurveyFields(widget.survey.id);
    setState(() {
      _fields = fields;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final res = await _service.submitResponse(
        surveyId: widget.survey.id,
        submissionData: _data,
      );
      if (mounted) {
        if (res != null) {
          ModernNotification.success(context, message: 'Submitted');
          Navigator.pop(context);
        } else {
          ModernNotification.error(context, message: 'Submit failed');
        }
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.survey.title),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.survey.description != null && widget.survey.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(widget.survey.description!),
                    ),
                  ..._fields.map(_buildField),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                    label: Text(_submitting ? 'Submitting...' : 'Submit'),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildField(SurveyField f) {
    switch (f.fieldType) {
      case SurveyFieldType.text:
      case SurveyFieldType.textarea:
      case SurveyFieldType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            decoration: InputDecoration(labelText: f.fieldLabel, hintText: f.fieldPlaceholder),
            keyboardType: f.fieldType == SurveyFieldType.number ? TextInputType.number : TextInputType.text,
            maxLines: f.fieldType == SurveyFieldType.textarea ? 4 : 1,
            validator: (v) => f.validateValue(v),
            onChanged: (v) => _data[f.fieldName] = v,
          ),
        );
      case SurveyFieldType.boolean:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(f.fieldLabel)),
            RadioListTile<bool>(
              value: true,
              groupValue: _data[f.fieldName] as bool?,
              onChanged: (v) => setState(() => _data[f.fieldName] = v),
              title: const Text('Yes'),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<bool>(
              value: false,
              groupValue: _data[f.fieldName] as bool?,
              onChanged: (v) => setState(() => _data[f.fieldName] = v),
              title: const Text('No'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        );
      case SurveyFieldType.select:
      case SurveyFieldType.multiselect:
        final options = f.fieldOptions ?? [];
        if (options.isEmpty) return const SizedBox.shrink();
        if (f.fieldType == SurveyFieldType.select) {
          final v = _data[f.fieldName]?.toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              value: v,
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (val) => setState(() => _data[f.fieldName] = val),
              decoration: InputDecoration(labelText: f.fieldLabel),
              validator: (val) => f.isRequired && (val == null || val.isEmpty) ? '${f.fieldLabel} is required' : null,
            ),
          );
        } else {
          final values = List<String>.from(_data[f.fieldName] ?? []);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.fieldLabel),
                ...options.map((o) => CheckboxListTile(
                      value: values.contains(o),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            values.add(o);
                          } else {
                            values.remove(o);
                          }
                          _data[f.fieldName] = values;
                        });
                      },
                      title: Text(o),
                      contentPadding: EdgeInsets.zero,
                    )),
              ],
            ),
          );
        }
      case SurveyFieldType.date:
      case SurveyFieldType.rating:
      case SurveyFieldType.photo:
        // Minimal: treat as text input for now
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            decoration: InputDecoration(labelText: f.fieldLabel, hintText: f.fieldPlaceholder),
            validator: (v) => f.validateValue(v),
            onChanged: (v) => _data[f.fieldName] = v,
          ),
        );
    }
  }
}

