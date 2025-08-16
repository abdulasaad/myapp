// lib/services/global_survey_service.dart

import 'package:flutter/foundation.dart';
import '../utils/constants.dart';
import '../models/global_survey.dart';
import '../models/survey_field.dart';
import '../models/global_survey_submission.dart';

class GlobalSurveyService {
  // Manager: list own surveys
  Future<List<GlobalSurvey>> getManagerSurveys() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return [];

      final rows = await supabase
          .from('global_surveys')
          .select('*')
          .eq('created_by', currentUser.id)
          .order('created_at', ascending: false);
      return rows.map((j) => GlobalSurvey.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error getManagerSurveys: $e');
      return [];
    }
  }

  // Agent: list accessible active surveys (only assigned surveys)
  Future<List<GlobalSurvey>> getAgentSurveys() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return [];
      
      // First get assigned survey IDs
      final assignedSurveyIds = await supabase
          .from('global_survey_agents')
          .select('survey_id')
          .eq('agent_id', currentUser.id);
      
      if (assignedSurveyIds.isEmpty) return [];
      
      final surveyIds = assignedSurveyIds.map((row) => row['survey_id']).toList();
      
      final rows = await supabase
          .from('global_surveys')
          .select('*')
          .eq('is_active', true)
          .filter('id', 'in', '(${surveyIds.join(',')})')
          .order('created_at', ascending: false);
      return rows.map((j) => GlobalSurvey.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error getAgentSurveys: $e');
      return [];
    }
  }

  Future<GlobalSurvey?> createSurvey({
    required String title,
    String? description,
    bool isRequired = true,
    bool isActive = true,
  }) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return null;
      final row = await supabase
          .from('global_surveys')
          .insert({
            'title': title,
            'description': description,
            'is_required': isRequired,
            'is_active': isActive,
            'created_by': currentUser.id,
          })
          .select()
          .single();
      return GlobalSurvey.fromJson(row);
    } catch (e) {
      debugPrint('Error createSurvey: $e');
      return null;
    }
  }

  Future<GlobalSurvey?> updateSurvey({
    required String surveyId,
    String? title,
    String? description,
    bool? isRequired,
    bool? isActive,
  }) async {
    try {
      final update = <String, dynamic>{};
      if (title != null) update['title'] = title;
      if (description != null) update['description'] = description;
      if (isRequired != null) update['is_required'] = isRequired;
      if (isActive != null) update['is_active'] = isActive;
      if (update.isEmpty) return null;
      final row = await supabase
          .from('global_surveys')
          .update(update)
          .eq('id', surveyId)
          .select()
          .single();
      return GlobalSurvey.fromJson(row);
    } catch (e) {
      debugPrint('Error updateSurvey: $e');
      return null;
    }
  }

  Future<bool> deleteSurvey(String surveyId) async {
    try {
      await supabase.from('global_surveys').delete().eq('id', surveyId);
      return true;
    } catch (e) {
      debugPrint('Error deleteSurvey: $e');
      return false;
    }
  }

  // Fields
  Future<List<SurveyField>> getSurveyFields(String surveyId) async {
    try {
      final rows = await supabase
          .from('global_survey_fields')
          .select('*')
          .eq('survey_id', surveyId)
          .order('field_order', ascending: true);
      return rows.map((j) => SurveyField.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error getSurveyFields: $e');
      return [];
    }
  }

  Future<SurveyField?> createSurveyField({
    required String surveyId,
    required String fieldName,
    required SurveyFieldType fieldType,
    required String fieldLabel,
    String? fieldPlaceholder,
    List<String>? fieldOptions,
    bool isRequired = false,
    int fieldOrder = 0,
    SurveyFieldValidation? validationRules,
  }) async {
    try {
      final data = {
        'survey_id': surveyId,
        'field_name': fieldName,
        'field_type': fieldType.name,
        'field_label': fieldLabel,
        'field_placeholder': fieldPlaceholder,
        'is_required': isRequired,
        'field_order': fieldOrder,
      };
      if (fieldOptions != null && fieldOptions.isNotEmpty) {
        data['field_options'] = {'options': fieldOptions};
      }
      if (validationRules != null) {
        data['validation_rules'] = validationRules.toJson();
      }
      final row = await supabase
          .from('global_survey_fields')
          .insert(data)
          .select()
          .single();
      return SurveyField.fromJson(row);
    } catch (e) {
      debugPrint('Error createSurveyField (global): $e');
      return null;
    }
  }

  Future<SurveyField?> updateSurveyField({
    required String fieldId,
    String? fieldName,
    SurveyFieldType? fieldType,
    String? fieldLabel,
    String? fieldPlaceholder,
    List<String>? fieldOptions,
    bool? isRequired,
    int? fieldOrder,
    SurveyFieldValidation? validationRules,
  }) async {
    try {
      final update = <String, dynamic>{};
      if (fieldName != null) update['field_name'] = fieldName;
      if (fieldType != null) update['field_type'] = fieldType.name;
      if (fieldLabel != null) update['field_label'] = fieldLabel;
      if (fieldPlaceholder != null) update['field_placeholder'] = fieldPlaceholder;
      if (isRequired != null) update['is_required'] = isRequired;
      if (fieldOrder != null) update['field_order'] = fieldOrder;
      if (fieldOptions != null) {
        update['field_options'] = fieldOptions.isNotEmpty ? {'options': fieldOptions} : null;
      }
      if (validationRules != null) update['validation_rules'] = validationRules.toJson();
      if (update.isEmpty) return null;
      final row = await supabase
          .from('global_survey_fields')
          .update(update)
          .eq('id', fieldId)
          .select()
          .single();
      return SurveyField.fromJson(row);
    } catch (e) {
      debugPrint('Error updateSurveyField (global): $e');
      return null;
    }
  }

  Future<bool> deleteSurveyField(String fieldId) async {
    try {
      await supabase.from('global_survey_fields').delete().eq('id', fieldId);
      return true;
    } catch (e) {
      debugPrint('Error deleteSurveyField (global): $e');
      return false;
    }
  }

  // Submissions
  Future<GlobalSurveySubmission?> submitResponse({
    required String surveyId,
    required Map<String, dynamic> submissionData,
  }) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return null;
      final row = await supabase
          .from('global_survey_submissions')
          .insert({
            'survey_id': surveyId,
            'agent_id': currentUser.id,
            'submission_data': submissionData,
          })
          .select()
          .single();
      return GlobalSurveySubmission.fromJson(row);
    } catch (e) {
      debugPrint('Error submitResponse (global): $e');
      return null;
    }
  }

  Future<List<GlobalSurveySubmission>> getManagerSurveySubmissions(String surveyId) async {
    try {
      final rows = await supabase
          .from('global_survey_submissions')
          .select('*')
          .eq('survey_id', surveyId)
          .order('submitted_at', ascending: false);
      return rows.map((j) => GlobalSurveySubmission.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error getManagerSurveySubmissions: $e');
      return [];
    }
  }

  Future<List<GlobalSurveySubmission>> getAgentMySubmissions() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return [];
      final rows = await supabase
          .from('global_survey_submissions')
          .select('*')
          .eq('agent_id', currentUser.id)
          .order('submitted_at', ascending: false);
      return rows.map((j) => GlobalSurveySubmission.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error getAgentMySubmissions: $e');
      return [];
    }
  }

  // Agent Assignment methods
  Future<bool> assignAgentsToSurvey(String surveyId, List<String> agentIds) async {
    try {
      // First remove existing assignments
      await supabase
          .from('global_survey_agents')
          .delete()
          .eq('survey_id', surveyId);
      
      // Then add new assignments
      if (agentIds.isNotEmpty) {
        final assignments = agentIds.map((agentId) => {
          'survey_id': surveyId,
          'agent_id': agentId,
        }).toList();
        
        await supabase
            .from('global_survey_agents')
            .insert(assignments);
      }
      
      return true;
    } catch (e) {
      debugPrint('Error assignAgentsToSurvey: $e');
      return false;
    }
  }

  Future<List<String>> getSurveyAssignedAgentIds(String surveyId) async {
    try {
      final rows = await supabase
          .from('global_survey_agents')
          .select('agent_id')
          .eq('survey_id', surveyId);
      return rows.map((row) => row['agent_id'] as String).toList();
    } catch (e) {
      debugPrint('Error getSurveyAssignedAgentIds: $e');
      return [];
    }
  }
}

