// lib/screens/campaigns/create_campaign_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';

class CreateCampaignScreen extends StatefulWidget {
  const CreateCampaignScreen({super.key});

  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = DateTime.now();
    final newDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (newDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = newDate;
        } else {
          _endDate = newDate;
        }
      });
    }
  }

  Future<void> _saveCampaign() async {
    if (_formKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null) {
        context.showSnackBar(
          'Please select both start and end dates.',
          isError: true,
        );
        return;
      }
      if (_endDate!.isBefore(_startDate!)) {
        context.showSnackBar(
          'End date cannot be before the start date.',
          isError: true,
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        final userId = supabase.auth.currentUser!.id;
        await supabase.from('campaigns').insert({
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'start_date': _startDate!.toIso8601String(),
          'end_date': _endDate!.toIso8601String(),
          'created_by': userId,
        });

        if (mounted) {
          context.showSnackBar('Campaign created successfully!');
          Navigator.of(context).pop(); // Go back to the previous screen
        }
      } catch (e) {
        if (mounted) {
          context.showSnackBar(
            'Failed to create campaign. Please try again.',
            isError: true,
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Campaign')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Campaign Name'),
                validator:
                    (value) =>
                        (value == null || value.isEmpty)
                            ? 'Required field'
                            : null,
              ),
              formSpacer,
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              formSpacer,
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Date',
                        ),
                        child: Text(
                          _startDate == null
                              ? 'Select a date'
                              : DateFormat.yMMMd().format(_startDate!),
                        ),
                      ),
                    ),
                  ),
                  formSpacerHorizontal,
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Date',
                        ),
                        child: Text(
                          _endDate == null
                              ? 'Select a date'
                              : DateFormat.yMMMd().format(_endDate!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveCampaign,
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Campaign'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
