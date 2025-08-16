// lib/services/survey_service.dart

import 'package:flutter/foundation.dart';
import '../utils/constants.dart';
import '../models/touring_survey.dart';
import '../models/survey_field.dart';
import '../models/survey_submission.dart';

class SurveyService {
  // ==================== SURVEY MANAGEMENT ====================

  /// Get survey for a specific touring task
  Future<TouringSurvey?> getSurveyByTouringTask(String touringTaskId) async {
    try {
      final response = await supabase
          .from('touring_task_surveys')
          .select('*')
          .eq('touring_task_id', touringTaskId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;
      return TouringSurvey.fromJson(response);
    } catch (e) {
      debugPrint('Error getting survey by touring task: $e');
      return null;
    }
  }

  /// Get survey with all its fields
  Future<TouringSurvey?> getSurveyWithFields(String surveyId) async {
    try {
      // Prefer the RPC if available (returns a shape: { survey, fields })
      try {
        final response = await supabase
            .rpc('get_survey_with_fields', params: {'survey_uuid': surveyId})
            .single();

        if (response != null && response['survey'] != null) {
          final surveyData = response['survey'];
          final fieldsData = response['fields'] ?? [];

          final survey = TouringSurvey.fromJson(surveyData);
          final fields = (fieldsData as List)
              .map((fieldJson) => SurveyField.fromJson(fieldJson))
              .toList();

          return survey.copyWith(fields: fields);
        }
      } catch (rpcError) {
        // Fall through to direct table queries if RPC is missing or fails
        debugPrint('RPC get_survey_with_fields failed, using fallback: $rpcError');
      }

      // Fallback: query tables directly
      final surveyRow = await supabase
          .from('touring_task_surveys')
          .select('*')
          .eq('id', surveyId)
          .maybeSingle();

      if (surveyRow == null) return null;

      final fieldsRows = await supabase
          .from('survey_fields')
          .select('*')
          .eq('survey_id', surveyId)
          .order('field_order');

      final survey = TouringSurvey.fromJson(surveyRow);
      final fields = (fieldsRows as List)
          .map((json) => SurveyField.fromJson(json))
          .toList();

      return survey.copyWith(fields: fields);
    } catch (e) {
      debugPrint('Error getting survey with fields (final): $e');
      return null;
    }
  }

  /// Get survey with fields by touring task ID
  Future<TouringSurvey?> getSurveyWithFieldsByTouringTask(String touringTaskId) async {
    try {
      // First get the survey
      final survey = await getSurveyByTouringTask(touringTaskId);
      if (survey == null) return null;

      // Then get with fields
      final withFields = await getSurveyWithFields(survey.id);
      if (withFields != null) return withFields;

      // As a secondary fallback, if getSurveyWithFields failed, try fetching fields directly
      try {
        final fields = await getSurveyFields(survey.id);
        return survey.copyWith(fields: fields);
      } catch (_) {
        return survey; // At least return the survey so UI can reflect existence
      }
    } catch (e) {
      debugPrint('Error getting survey with fields by touring task: $e');
      return null;
    }
  }

  /// Create a new survey
  Future<TouringSurvey?> createSurvey({
    required String touringTaskId,
    required String title,
    String? description,
    bool isRequired = true,
  }) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final response = await supabase
          .from('touring_task_surveys')
          .insert({
            'touring_task_id': touringTaskId,
            'title': title,
            'description': description,
            'is_required': isRequired,
            'is_active': true,
            'created_by': currentUser.id,
          })
          .select()
          .single();

      return TouringSurvey.fromJson(response);
    } catch (e) {
      debugPrint('Error creating survey: $e');
      return null;
    }
  }

  /// Update survey
  Future<TouringSurvey?> updateSurvey({
    required String surveyId,
    String? title,
    String? description,
    bool? isRequired,
    bool? isActive,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (isRequired != null) updateData['is_required'] = isRequired;
      if (isActive != null) updateData['is_active'] = isActive;

      if (updateData.isEmpty) return null;

      final response = await supabase
          .from('touring_task_surveys')
          .update(updateData)
          .eq('id', surveyId)
          .select()
          .single();

      return TouringSurvey.fromJson(response);
    } catch (e) {
      debugPrint('Error updating survey: $e');
      return null;
    }
  }

  /// Delete survey (also deletes all fields and submissions)
  Future<bool> deleteSurvey(String surveyId) async {
    try {
      await supabase
          .from('touring_task_surveys')
          .delete()
          .eq('id', surveyId);

      return true;
    } catch (e) {
      debugPrint('Error deleting survey: $e');
      return false;
    }
  }

  // ==================== FIELD MANAGEMENT ====================

  /// Get fields for a survey
  Future<List<SurveyField>> getSurveyFields(String surveyId) async {
    try {
      final response = await supabase
          .from('survey_fields')
          .select('*')
          .eq('survey_id', surveyId)
          .order('field_order');

      return response.map((json) => SurveyField.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting survey fields: $e');
      return [];
    }
  }

  /// Create a new survey field
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
      final fieldData = {
        'survey_id': surveyId,
        'field_name': fieldName,
        'field_type': fieldType.name,
        'field_label': fieldLabel,
        'field_placeholder': fieldPlaceholder,
        'is_required': isRequired,
        'field_order': fieldOrder,
      };

      // Add field options if provided
      if (fieldOptions != null && fieldOptions.isNotEmpty) {
        fieldData['field_options'] = {'options': fieldOptions};
      }

      // Add validation rules if provided
      if (validationRules != null) {
        fieldData['validation_rules'] = validationRules.toJson();
      }

      final response = await supabase
          .from('survey_fields')
          .insert(fieldData)
          .select()
          .single();

      return SurveyField.fromJson(response);
    } catch (e) {
      debugPrint('Error creating survey field: $e');
      return null;
    }
  }

  /// Update survey field
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
      final updateData = <String, dynamic>{};
      if (fieldName != null) updateData['field_name'] = fieldName;
      if (fieldType != null) updateData['field_type'] = fieldType.name;
      if (fieldLabel != null) updateData['field_label'] = fieldLabel;
      if (fieldPlaceholder != null) updateData['field_placeholder'] = fieldPlaceholder;
      if (isRequired != null) updateData['is_required'] = isRequired;
      if (fieldOrder != null) updateData['field_order'] = fieldOrder;

      if (fieldOptions != null) {
        updateData['field_options'] = fieldOptions.isNotEmpty 
            ? {'options': fieldOptions}
            : null;
      }

      if (validationRules != null) {
        updateData['validation_rules'] = validationRules.toJson();
      }

      if (updateData.isEmpty) return null;

      final response = await supabase
          .from('survey_fields')
          .update(updateData)
          .eq('id', fieldId)
          .select()
          .single();

      return SurveyField.fromJson(response);
    } catch (e) {
      debugPrint('Error updating survey field: $e');
      return null;
    }
  }

  /// Delete survey field
  Future<bool> deleteSurveyField(String fieldId) async {
    try {
      await supabase
          .from('survey_fields')
          .delete()
          .eq('id', fieldId);

      return true;
    } catch (e) {
      debugPrint('Error deleting survey field: $e');
      return false;
    }
  }

  /// Reorder survey fields
  Future<bool> reorderSurveyFields(String surveyId, List<String> fieldIds) async {
    try {
      // Update each field with its new order
      for (int i = 0; i < fieldIds.length; i++) {
        await supabase
            .from('survey_fields')
            .update({'field_order': i})
            .eq('id', fieldIds[i])
            .eq('survey_id', surveyId);
      }

      return true;
    } catch (e) {
      debugPrint('Error reordering survey fields: $e');
      return false;
    }
  }

  // ==================== SUBMISSION MANAGEMENT ====================

  /// Submit survey response
  Future<SurveySubmission?> submitSurveyResponse({
    required String surveyId,
    required String touringTaskId,
    String? sessionId,
    required Map<String, dynamic> submissionData,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final response = await supabase
          .from('survey_submissions')
          .insert({
            'survey_id': surveyId,
            'agent_id': currentUser.id,
            'session_id': sessionId,
            'touring_task_id': touringTaskId,
            'submission_data': submissionData,
            'latitude': latitude,
            'longitude': longitude,
          })
          .select()
          .single();

      return SurveySubmission.fromJson(response);
    } catch (e) {
      debugPrint('Error submitting survey response: $e');
      return null;
    }
  }

  /// Update survey submission
  Future<SurveySubmission?> updateSurveySubmission({
    required String submissionId,
    Map<String, dynamic>? submissionData,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (submissionData != null) updateData['submission_data'] = submissionData;
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;

      if (updateData.isEmpty) return null;

      final response = await supabase
          .from('survey_submissions')
          .update(updateData)
          .eq('id', submissionId)
          .select()
          .single();

      return SurveySubmission.fromJson(response);
    } catch (e) {
      debugPrint('Error updating survey submission: $e');
      return null;
    }
  }

  /// Get agent's submission for a survey
  Future<SurveySubmission?> getAgentSurveySubmission({
    required String surveyId,
    String? agentId,
    String? sessionId,
  }) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null && agentId == null) {
        throw Exception('User not authenticated and no agent ID provided');
      }

      final targetAgentId = agentId ?? currentUser!.id;

      var query = supabase
          .from('survey_submissions')
          .select('*')
          .eq('survey_id', surveyId)
          .eq('agent_id', targetAgentId);

      if (sessionId != null) {
        query = query.eq('session_id', sessionId);
      }

      final response = await query.maybeSingle();

      if (response == null) return null;
      return SurveySubmission.fromJson(response);
    } catch (e) {
      debugPrint('Error getting agent survey submission: $e');
      return null;
    }
  }

  /// Get all submissions for a survey
  Future<List<SurveySubmission>> getSurveySubmissions(String surveyId) async {
    try {
      final response = await supabase
          .from('survey_submissions')
          .select('*')
          .eq('survey_id', surveyId)
          .order('submitted_at', ascending: false);

      return response.map((json) => SurveySubmission.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting survey submissions: $e');
      return [];
    }
  }

  /// Get agent's submissions for a campaign
  Future<List<SurveySubmission>> getAgentCampaignSubmissions({
    required String campaignId,
    String? agentId,
  }) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null && agentId == null) {
        throw Exception('User not authenticated and no agent ID provided');
      }

      final targetAgentId = agentId ?? currentUser!.id;

      // Use the database function to get agent submissions for campaign
      final response = await supabase.rpc('get_agent_survey_submissions',
          params: {
            'agent_uuid': targetAgentId,
            'campaign_uuid': campaignId,
          }).single();

      final submissionsData = response as List;
      return submissionsData
          .map((json) => SurveySubmission.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting agent campaign submissions: $e');
      return [];
    }
  }

  /// Get campaign survey statistics
  Future<Map<String, dynamic>?> getCampaignSurveyStats(String campaignId) async {
    try {
      final response = await supabase.rpc('get_campaign_survey_stats',
          params: {'campaign_uuid': campaignId}).single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error getting campaign survey stats: $e');
      return null;
    }
  }

  /// Delete survey submission
  Future<bool> deleteSurveySubmission(String submissionId) async {
    try {
      await supabase
          .from('survey_submissions')
          .delete()
          .eq('id', submissionId);

      return true;
    } catch (e) {
      debugPrint('Error deleting survey submission: $e');
      return false;
    }
  }

  /// Check if agent has submitted survey for a session
  Future<bool> hasAgentSubmittedSurvey({
    required String surveyId,
    String? agentId,
    String? sessionId,
  }) async {
    try {
      final submission = await getAgentSurveySubmission(
        surveyId: surveyId,
        agentId: agentId,
        sessionId: sessionId,
      );
      return submission != null;
    } catch (e) {
      debugPrint('Error checking if agent submitted survey: $e');
      return false;
    }
  }

  /// Get surveys for a campaign
  Future<List<TouringSurvey>> getCampaignSurveys(String campaignId) async {
    try {
      final response = await supabase
          .from('touring_task_surveys')
          .select('''
            *,
            touring_tasks!inner(campaign_id)
          ''')
          .eq('touring_tasks.campaign_id', campaignId)
          .eq('is_active', true)
          .order('created_at');

      return response.map((json) => TouringSurvey.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting campaign surveys: $e');
      return [];
    }
  }
}
