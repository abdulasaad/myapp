# Survey System Implementation Summary

This document summarizes the survey functionality added to the AL-Tijwal application and the corresponding Supabase database changes.

## Database Tables Created

### 1. `touring_task_surveys`
Main table for storing survey configurations linked to touring tasks.

**Columns:**
- `id` (UUID, Primary Key)
- `touring_task_id` (UUID, Foreign Key to touring_tasks)
- `title` (VARCHAR, Survey title)
- `description` (TEXT, Optional description)
- `is_required` (BOOLEAN, Whether survey is mandatory)
- `is_active` (BOOLEAN, Whether survey is active)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)
- `created_by` (UUID, Foreign Key to profiles)

**Constraints:**
- `unique_survey_per_task`: One survey per touring task

### 2. `survey_fields`
Dynamic form fields for surveys with 9 supported field types.

**Columns:**
- `id` (UUID, Primary Key)
- `survey_id` (UUID, Foreign Key to touring_task_surveys)
- `field_name` (VARCHAR, Unique field identifier)
- `field_type` (VARCHAR, Enum: text, number, select, multiselect, boolean, date, textarea, rating, photo)
- `field_label` (VARCHAR, Display label)
- `field_placeholder` (VARCHAR, Optional placeholder text)
- `field_options` (JSONB, For select/multiselect options)
- `is_required` (BOOLEAN)
- `field_order` (INTEGER, Display order)
- `validation_rules` (JSONB, Field validation configuration)
- `created_at` (TIMESTAMP)

### 3. `survey_submissions`
Agent responses to surveys.

**Columns:**
- `id` (UUID, Primary Key)
- `survey_id` (UUID, Foreign Key to touring_task_surveys)
- `agent_id` (UUID, Foreign Key to profiles)
- `session_id` (UUID, Optional link to touring_task_sessions)
- `touring_task_id` (UUID, Foreign Key to touring_tasks)
- `submission_data` (JSONB, Survey responses)
- `submitted_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)
- `latitude` (DOUBLE PRECISION, Submission location)
- `longitude` (DOUBLE PRECISION, Submission location)

## Row Level Security (RLS) Policies

### Survey Access Control
- **Managers**: Can create/view/update surveys for campaigns they own
- **Agents**: Can only view surveys for campaigns they're assigned to via `campaign_agents` table
- **Survey Submissions**: Agents can only manage their own submissions

### Key RLS Policy
```sql
-- Agents can view surveys only if assigned to the campaign
CREATE POLICY "Agents can view touring task surveys" ON touring_task_surveys
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM touring_tasks tt
            JOIN campaigns c ON tt.campaign_id = c.id
            JOIN campaign_agents ca ON c.id = ca.campaign_id
            WHERE tt.id = touring_task_surveys.touring_task_id
            AND ca.agent_id = auth.uid()
        )
    );
```

## Database Functions Created

### 1. `get_survey_with_fields(survey_uuid UUID)`
Returns survey data with all associated fields in JSON format.

### 2. `get_campaign_survey_stats(campaign_uuid UUID)`
Provides survey analytics for campaign managers including:
- Total surveys count
- Total submissions count
- Unique agents who submitted
- Completion rate percentage

### 3. `get_agent_survey_submissions(agent_uuid UUID, campaign_uuid UUID)`
Returns all survey submissions by an agent for a specific campaign.

## Flutter App Integration

### New Screens Added
1. **Survey Builder Screen** (`lib/screens/manager/survey_builder_screen.dart`)
   - Dynamic form builder with 9 field types
   - Real-time field management
   - Drag-and-drop reordering

2. **Survey Submission Screen** (`lib/screens/agent/touring_survey_screen.dart`)
   - Dynamic form rendering based on field types
   - Validation and submission handling
   - Location capture during submission

### Services Added
1. **Survey Service** (`lib/services/survey_service.dart`)
   - CRUD operations for surveys, fields, and submissions
   - RLS-compliant database interactions

### Models Added
1. **TouringSurvey** (`lib/models/touring_survey.dart`)
2. **SurveyField** (`lib/models/survey_field.dart`)
3. **SurveySubmission** (`lib/models/survey_submission.dart`)

## Integration Points

### Manager Workflow
1. Create campaign and touring tasks
2. Add surveys during task creation or edit existing tasks
3. Use survey builder to configure dynamic forms
4. View survey results and analytics

### Agent Workflow
1. Navigate to assigned touring tasks
2. Survey icon appears in AppBar during task execution
3. Survey card appears in task dashboard
4. Complete surveys during task process (not after completion)

## Troubleshooting Notes

### Common Issues
1. **Survey icon not visible**: Agent must be assigned to campaign via `campaign_agents` table
2. **RLS permission errors**: Only campaign owners can create surveys
3. **Survey not found**: Verify survey creation completed successfully during task setup

### Debug Points
- Survey loading: Look for `🔍 Loading survey for task:` messages
- Campaign assignment: Check `🗄️ Agent campaign assignments:` output
- Database queries: Monitor `🗄️ Direct DB query result:` messages

## Security Considerations
- Surveys are protected by RLS policies
- Only campaign owners can manage surveys
- Agents can only access surveys for assigned campaigns
- All database operations respect user permissions

## Files Modified/Created
- Database migration: `supabase/survey_system_migration.md`
- Survey service: `lib/services/survey_service.dart`
- Survey models: `lib/models/touring_survey.dart`, `survey_field.dart`, `survey_submission.dart`
- Survey builder: `lib/screens/manager/survey_builder_screen.dart`
- Survey submission: `lib/screens/agent/touring_survey_screen.dart`
- Task execution integration: `lib/screens/agent/touring_task_execution_screen.dart`
- Task creation integration: `lib/screens/tasks/create_touring_task_screen.dart`