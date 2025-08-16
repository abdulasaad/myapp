# Survey System Diagnostics & Quick-Fix SQL

Use these queries to verify your survey setup and create a test survey/fields if needed. Replace placeholders in ALL CAPS.

## 1) Basic Presence Checks

```sql
-- Tables exist?
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('touring_task_surveys','survey_fields','survey_submissions');

-- Functions exist?
SELECT proname FROM pg_proc WHERE proname IN (
  'get_survey_with_fields', 'get_campaign_survey_stats', 'get_agent_survey_submissions'
);

-- RLS policies applied?
SELECT schemaname, tablename, policyname, roles, cmd
FROM pg_policies
WHERE tablename IN ('touring_task_surveys','survey_fields','survey_submissions');
```

## 2) Validate Agent Assignment vs Task Campaign

```sql
-- Find the campaign for the task
SELECT id AS task_id, campaign_id
FROM touring_tasks
WHERE id = 'TASK_UUID_HERE';

-- Confirm the agent is assigned to that campaign
SELECT * FROM campaign_agents
WHERE campaign_id = 'CAMPAIGN_UUID_HERE'
  AND agent_id = 'AGENT_UUID_HERE';
```

## 3) Check For Existing Survey For Task

```sql
SELECT * FROM touring_task_surveys
WHERE touring_task_id = 'TASK_UUID_HERE';

SELECT COUNT(*) AS fields_count
FROM survey_fields
WHERE survey_id IN (
  SELECT id FROM touring_task_surveys WHERE touring_task_id = 'TASK_UUID_HERE'
);
```

## 4) Create A Test Survey For A Task

Run these as a privileged role (SQL editor) or ensure the manager user (`created_by`) owns the campaign (matches `campaigns.created_by`).

```sql
-- Create survey
INSERT INTO touring_task_surveys (touring_task_id, title, description, is_required, is_active, created_by)
VALUES (
  'TASK_UUID_HERE',
  'Test Survey',
  'Auto-created for diagnostics',
  true,
  true,
  'MANAGER_UUID_HERE' -- must match campaigns.created_by for that task
)
RETURNING id;

-- Use the returned survey id from above
-- Create at least one field
INSERT INTO survey_fields (survey_id, field_name, field_type, field_label, is_required, field_order)
VALUES (
  'SURVEY_UUID_HERE', 'store_cleanliness', 'rating', 'Rate store cleanliness (1-5)', true, 0
);
```

## 5) Validate Agent Can Read The Survey

```sql
-- As agent (or using SQL editor to simulate), list the surveys for this task
SELECT id, title, is_active
FROM touring_task_surveys
WHERE touring_task_id = 'TASK_UUID_HERE';

SELECT field_name, field_type, field_label
FROM survey_fields
WHERE survey_id = 'SURVEY_UUID_HERE'
ORDER BY field_order;
```

## 6) Common Pitfalls

- Manager toggled “Add survey to task” but didn’t open the builder: app now creates a blank survey on save so agents see the survey entry.
- `created_by` mismatch: Survey insert is blocked by RLS if the manager user doesn’t own the campaign.
- Agent not in `campaign_agents`: Agent can’t read the survey, even if assigned the task elsewhere.

