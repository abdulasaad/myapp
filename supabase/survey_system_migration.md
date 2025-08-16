# Survey System Database Migration

This file contains all the SQL commands needed to implement the survey system for touring tasks in the AL-Tijwal application.

## Migration Steps

Execute these SQL commands in order in your Supabase SQL editor or migration tool.

---

## 1. Core Survey Tables

### A. Touring Task Surveys Table
```sql
-- Create the main surveys table
CREATE TABLE IF NOT EXISTS touring_task_surveys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    touring_task_id UUID NOT NULL REFERENCES touring_tasks(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    is_required BOOLEAN DEFAULT true,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES profiles(id),
    CONSTRAINT unique_survey_per_task UNIQUE(touring_task_id)
);

-- Add RLS (Row Level Security) policies
ALTER TABLE touring_task_surveys ENABLE ROW LEVEL SECURITY;

-- Policy: Managers can view surveys for their campaigns
CREATE POLICY "Managers can view touring task surveys" ON touring_task_surveys
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM touring_tasks tt
            JOIN campaigns c ON tt.campaign_id = c.id
            WHERE tt.id = touring_task_surveys.touring_task_id
            AND c.created_by = auth.uid()
        )
    );

-- Policy: Managers can create/update surveys for their tasks
CREATE POLICY "Managers can manage touring task surveys" ON touring_task_surveys
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM touring_tasks tt
            JOIN campaigns c ON tt.campaign_id = c.id
            WHERE tt.id = touring_task_surveys.touring_task_id
            AND c.created_by = auth.uid()
        )
    );

-- Policy: Agents can view surveys for tasks they can access
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

### B. Survey Fields Table
```sql
-- Create survey fields table for dynamic form building
CREATE TABLE IF NOT EXISTS survey_fields (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    survey_id UUID NOT NULL REFERENCES touring_task_surveys(id) ON DELETE CASCADE,
    field_name VARCHAR(255) NOT NULL,
    field_type VARCHAR(50) NOT NULL CHECK (field_type IN ('text', 'number', 'select', 'multiselect', 'boolean', 'date', 'textarea', 'rating', 'photo')),
    field_label VARCHAR(255) NOT NULL,
    field_placeholder VARCHAR(255),
    field_options JSONB, -- For select/multiselect options: {"options": ["Option 1", "Option 2"]}
    is_required BOOLEAN DEFAULT false,
    field_order INTEGER DEFAULT 0,
    validation_rules JSONB, -- {"min_length": 5, "max_length": 100, "min_value": 1, "max_value": 10}
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_field_name_per_survey UNIQUE(survey_id, field_name)
);

-- Add RLS policies for survey fields
ALTER TABLE survey_fields ENABLE ROW LEVEL SECURITY;

-- Policy: Follow the same access pattern as surveys
CREATE POLICY "Managers can manage survey fields" ON survey_fields
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM touring_task_surveys tts
            JOIN touring_tasks tt ON tts.touring_task_id = tt.id
            JOIN campaigns c ON tt.campaign_id = c.id
            WHERE tts.id = survey_fields.survey_id
            AND c.created_by = auth.uid()
        )
    );

CREATE POLICY "Agents can view survey fields" ON survey_fields
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM touring_task_surveys tts
            JOIN touring_tasks tt ON tts.touring_task_id = tt.id
            JOIN campaigns c ON tt.campaign_id = c.id
            JOIN campaign_agents ca ON c.id = ca.campaign_id
            WHERE tts.id = survey_fields.survey_id
            AND ca.agent_id = auth.uid()
        )
    );
```

### C. Survey Submissions Table
```sql
-- Create survey submissions table
CREATE TABLE IF NOT EXISTS survey_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    survey_id UUID NOT NULL REFERENCES touring_task_surveys(id) ON DELETE CASCADE,
    agent_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    session_id UUID REFERENCES touring_task_sessions(id) ON DELETE SET NULL,
    touring_task_id UUID NOT NULL REFERENCES touring_tasks(id) ON DELETE CASCADE,
    submission_data JSONB NOT NULL, -- {"field_name": "value", "field_name_2": ["option1", "option2"]}
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    CONSTRAINT unique_submission_per_session UNIQUE(survey_id, agent_id, session_id)
);

-- Add RLS policies for survey submissions
ALTER TABLE survey_submissions ENABLE ROW LEVEL SECURITY;

-- Policy: Agents can only see their own submissions
CREATE POLICY "Agents can manage their survey submissions" ON survey_submissions
    FOR ALL USING (agent_id = auth.uid());

-- Policy: Managers can view submissions for their campaigns
CREATE POLICY "Managers can view survey submissions" ON survey_submissions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM touring_task_surveys tts
            JOIN touring_tasks tt ON tts.touring_task_id = tt.id
            JOIN campaigns c ON tt.campaign_id = c.id
            WHERE tts.id = survey_submissions.survey_id
            AND c.created_by = auth.uid()
        )
    );
```

---

## 2. Indexes for Performance

```sql
-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_touring_task_surveys_task_id ON touring_task_surveys(touring_task_id);
CREATE INDEX IF NOT EXISTS idx_touring_task_surveys_created_by ON touring_task_surveys(created_by);

CREATE INDEX IF NOT EXISTS idx_survey_fields_survey_id ON survey_fields(survey_id);
CREATE INDEX IF NOT EXISTS idx_survey_fields_order ON survey_fields(survey_id, field_order);

CREATE INDEX IF NOT EXISTS idx_survey_submissions_survey_id ON survey_submissions(survey_id);
CREATE INDEX IF NOT EXISTS idx_survey_submissions_agent_id ON survey_submissions(agent_id);
CREATE INDEX IF NOT EXISTS idx_survey_submissions_session_id ON survey_submissions(session_id);
CREATE INDEX IF NOT EXISTS idx_survey_submissions_task_id ON survey_submissions(touring_task_id);
CREATE INDEX IF NOT EXISTS idx_survey_submissions_submitted_at ON survey_submissions(submitted_at);
```

---

## 3. Database Functions

### A. Get Survey with Fields
```sql
-- Function to get survey with all its fields
CREATE OR REPLACE FUNCTION get_survey_with_fields(survey_uuid UUID)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'survey', to_json(s.*),
        'fields', COALESCE(
            json_agg(
                to_json(sf.*) ORDER BY sf.field_order, sf.created_at
            ) FILTER (WHERE sf.id IS NOT NULL), 
            '[]'::json
        )
    )
    INTO result
    FROM touring_task_surveys s
    LEFT JOIN survey_fields sf ON s.id = sf.survey_id
    WHERE s.id = survey_uuid
    GROUP BY s.id, s.touring_task_id, s.title, s.description, s.is_required, s.is_active, s.created_at, s.updated_at, s.created_by;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### B. Get Campaign Survey Statistics
```sql
-- Function to get survey statistics for a campaign
CREATE OR REPLACE FUNCTION get_campaign_survey_stats(campaign_uuid UUID)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total_surveys', COUNT(DISTINCT tts.id),
        'total_submissions', COUNT(DISTINCT ss.id),
        'unique_agents_submitted', COUNT(DISTINCT ss.agent_id),
        'completion_rate', CASE 
            WHEN COUNT(DISTINCT tts.id) > 0 THEN 
                ROUND((COUNT(DISTINCT ss.id)::DECIMAL / COUNT(DISTINCT tts.id)) * 100, 2)
            ELSE 0 
        END,
        'surveys_by_task', json_agg(
            DISTINCT json_build_object(
                'task_id', tt.id,
                'task_title', tt.title,
                'survey_id', tts.id,
                'survey_title', tts.title,
                'submissions_count', (
                    SELECT COUNT(*) FROM survey_submissions ss2 
                    WHERE ss2.survey_id = tts.id
                )
            )
        ) FILTER (WHERE tts.id IS NOT NULL)
    )
    INTO result
    FROM campaigns c
    LEFT JOIN touring_tasks tt ON c.id = tt.campaign_id
    LEFT JOIN touring_task_surveys tts ON tt.id = tts.touring_task_id
    LEFT JOIN survey_submissions ss ON tts.id = ss.survey_id
    WHERE c.id = campaign_uuid;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### C. Get Agent Survey Submissions
```sql
-- Function to get agent's survey submissions for a specific campaign
CREATE OR REPLACE FUNCTION get_agent_survey_submissions(agent_uuid UUID, campaign_uuid UUID)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT COALESCE(json_agg(
        json_build_object(
            'submission_id', ss.id,
            'survey_id', ss.survey_id,
            'survey_title', tts.title,
            'task_title', tt.title,
            'submitted_at', ss.submitted_at,
            'submission_data', ss.submission_data,
            'session_id', ss.session_id
        ) ORDER BY ss.submitted_at DESC
    ), '[]'::json)
    INTO result
    FROM survey_submissions ss
    JOIN touring_task_surveys tts ON ss.survey_id = tts.id
    JOIN touring_tasks tt ON tts.touring_task_id = tt.id
    JOIN campaigns c ON tt.campaign_id = c.id
    WHERE ss.agent_id = agent_uuid
    AND c.id = campaign_uuid;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 4. Database Triggers

### A. Update Timestamp Trigger
```sql
-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to relevant tables
CREATE TRIGGER update_touring_task_surveys_updated_at
    BEFORE UPDATE ON touring_task_surveys
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_survey_submissions_updated_at
    BEFORE UPDATE ON survey_submissions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

---

## 5. Sample Data (Optional)

```sql
-- Insert sample survey data for testing (adjust UUIDs as needed)
-- Note: Replace the UUIDs with actual touring task IDs from your system

-- Example survey for a touring task
INSERT INTO touring_task_surveys (id, touring_task_id, title, description, is_required, created_by)
VALUES (
    gen_random_uuid(),
    'YOUR_TOURING_TASK_ID_HERE',  -- Replace with actual touring task ID
    'Store Visit Survey',
    'Please provide feedback about your store visit experience',
    true,
    'YOUR_MANAGER_ID_HERE'  -- Replace with actual manager ID
);

-- Example survey fields
INSERT INTO survey_fields (survey_id, field_name, field_type, field_label, is_required, field_order, validation_rules)
VALUES
    ((SELECT id FROM touring_task_surveys LIMIT 1), 'store_cleanliness', 'rating', 'Rate store cleanliness (1-5)', true, 1, '{"min_value": 1, "max_value": 5}'),
    ((SELECT id FROM touring_task_surveys LIMIT 1), 'customer_count', 'number', 'Approximate number of customers', true, 2, '{"min_value": 0, "max_value": 1000}'),
    ((SELECT id FROM touring_task_surveys LIMIT 1), 'staff_present', 'boolean', 'Was staff present?', true, 3, null),
    ((SELECT id FROM touring_task_surveys LIMIT 1), 'observations', 'textarea', 'Additional observations', false, 4, '{"max_length": 500}'),
    ((SELECT id FROM touring_task_surveys LIMIT 1), 'store_type', 'select', 'Store type', true, 5, '{"options": ["Grocery", "Electronics", "Clothing", "Restaurant", "Other"]}');
```

---

## 6. Verification Queries

```sql
-- Verify tables were created successfully
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('touring_task_surveys', 'survey_fields', 'survey_submissions');

-- Check RLS policies
SELECT schemaname, tablename, policyname, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('touring_task_surveys', 'survey_fields', 'survey_submissions');

-- Check indexes
SELECT indexname, tablename, indexdef 
FROM pg_indexes 
WHERE tablename IN ('touring_task_surveys', 'survey_fields', 'survey_submissions')
AND schemaname = 'public';

-- Test functions
SELECT get_campaign_survey_stats('00000000-0000-0000-0000-000000000000'::UUID);
```

---

## 7. Rollback Commands (If Needed)

```sql
-- Use these commands only if you need to rollback the migration

-- Drop functions
DROP FUNCTION IF EXISTS get_survey_with_fields(UUID);
DROP FUNCTION IF EXISTS get_campaign_survey_stats(UUID);
DROP FUNCTION IF EXISTS get_agent_survey_submissions(UUID, UUID);
DROP FUNCTION IF EXISTS update_updated_at_column();

-- Drop tables (in reverse dependency order)
DROP TABLE IF EXISTS survey_submissions;
DROP TABLE IF EXISTS survey_fields;
DROP TABLE IF EXISTS touring_task_surveys;
```

---

## Migration Checklist

- [ ] 1. Execute core table creation scripts
- [ ] 2. Apply RLS policies  
- [ ] 3. Create performance indexes
- [ ] 4. Install database functions
- [ ] 5. Setup triggers
- [ ] 6. Run verification queries
- [ ] 7. Test with sample data (optional)

## Notes

1. **UUIDs**: Replace placeholder UUIDs in sample data with actual IDs from your system
2. **Permissions**: Ensure your database user has sufficient privileges to create tables, functions, and policies
3. **Backup**: Always backup your database before running migrations
4. **Testing**: Test thoroughly in development environment before applying to production
5. **Dependencies**: Ensure `touring_tasks`, `campaigns`, `profiles`, and `touring_task_sessions` tables exist

## Support

For any issues with this migration:
1. Check Supabase logs for detailed error messages
2. Verify table dependencies are in place
3. Ensure RLS is properly configured for your use case
4. Test functions with appropriate user permissions