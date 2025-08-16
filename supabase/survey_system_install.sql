-- Survey System Installation (Tables, Policies, Indexes, Functions, Triggers)
-- Safe to run multiple times due to IF NOT EXISTS guards where possible.

-- 1) Tables
CREATE TABLE IF NOT EXISTS touring_task_surveys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    touring_task_id UUID NOT NULL REFERENCES touring_tasks(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    is_required BOOLEAN DEFAULT true,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES profiles(id),
    CONSTRAINT unique_survey_per_task UNIQUE (touring_task_id)
);

ALTER TABLE touring_task_surveys ENABLE ROW LEVEL SECURITY;

-- Managers can view surveys for their campaigns
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE policyname = 'Managers can view touring task surveys'
    AND tablename = 'touring_task_surveys') THEN
  CREATE POLICY "Managers can view touring task surveys" ON touring_task_surveys
    FOR SELECT USING (
      EXISTS (
        SELECT 1 FROM touring_tasks tt
        JOIN campaigns c ON tt.campaign_id = c.id
        WHERE tt.id = touring_task_surveys.touring_task_id
          AND c.created_by = auth.uid()
      )
    );
END IF; END $$;

-- Managers can manage surveys
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE policyname = 'Managers can manage touring task surveys'
    AND tablename = 'touring_task_surveys') THEN
  CREATE POLICY "Managers can manage touring task surveys" ON touring_task_surveys
    FOR ALL USING (
      EXISTS (
        SELECT 1 FROM touring_tasks tt
        JOIN campaigns c ON tt.campaign_id = c.id
        WHERE tt.id = touring_task_surveys.touring_task_id
          AND c.created_by = auth.uid()
      )
    );
END IF; END $$;

-- Agents can view surveys for assigned campaigns
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE policyname = 'Agents can view touring task surveys'
    AND tablename = 'touring_task_surveys') THEN
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
END IF; END $$;

-- Survey fields
CREATE TABLE IF NOT EXISTS survey_fields (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    survey_id UUID NOT NULL REFERENCES touring_task_surveys(id) ON DELETE CASCADE,
    field_name VARCHAR(255) NOT NULL,
    field_type VARCHAR(50) NOT NULL CHECK (field_type IN ('text','number','select','multiselect','boolean','date','textarea','rating','photo')),
    field_label VARCHAR(255) NOT NULL,
    field_placeholder VARCHAR(255),
    field_options JSONB,
    is_required BOOLEAN DEFAULT false,
    field_order INTEGER DEFAULT 0,
    validation_rules JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_field_name_per_survey UNIQUE (survey_id, field_name)
);

ALTER TABLE survey_fields ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE policyname = 'Managers can manage survey fields'
    AND tablename = 'survey_fields') THEN
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
END IF; END $$;

DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE policyname = 'Agents can view survey fields'
    AND tablename = 'survey_fields') THEN
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
END IF; END $$;

-- Survey submissions
CREATE TABLE IF NOT EXISTS survey_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    survey_id UUID NOT NULL REFERENCES touring_task_surveys(id) ON DELETE CASCADE,
    agent_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    session_id UUID REFERENCES touring_task_sessions(id) ON DELETE SET NULL,
    touring_task_id UUID NOT NULL REFERENCES touring_tasks(id) ON DELETE CASCADE,
    submission_data JSONB NOT NULL,
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    CONSTRAINT unique_submission_per_session UNIQUE (survey_id, agent_id, session_id)
);

ALTER TABLE survey_submissions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE policyname = 'Agents can manage their survey submissions'
    AND tablename = 'survey_submissions') THEN
  CREATE POLICY "Agents can manage their survey submissions" ON survey_submissions
    FOR ALL USING (agent_id = auth.uid());
END IF; END $$;

DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE policyname = 'Managers can view survey submissions'
    AND tablename = 'survey_submissions') THEN
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
END IF; END $$;

-- 2) Indexes
CREATE INDEX IF NOT EXISTS idx_touring_task_surveys_task_id ON touring_task_surveys(touring_task_id);
CREATE INDEX IF NOT EXISTS idx_touring_task_surveys_created_by ON touring_task_surveys(created_by);
CREATE INDEX IF NOT EXISTS idx_survey_fields_survey_id ON survey_fields(survey_id);
CREATE INDEX IF NOT EXISTS idx_survey_fields_order ON survey_fields(survey_id, field_order);
CREATE INDEX IF NOT EXISTS idx_survey_submissions_survey_id ON survey_submissions(survey_id);
CREATE INDEX IF NOT EXISTS idx_survey_submissions_agent_id ON survey_submissions(agent_id);
CREATE INDEX IF NOT EXISTS idx_survey_submissions_session_id ON survey_submissions(session_id);
CREATE INDEX IF NOT EXISTS idx_survey_submissions_task_id ON survey_submissions(touring_task_id);
CREATE INDEX IF NOT EXISTS idx_survey_submissions_submitted_at ON survey_submissions(submitted_at);

-- 3) Triggers to update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_trigger WHERE tgname = 'update_touring_task_surveys_updated_at'
) THEN
  CREATE TRIGGER update_touring_task_surveys_updated_at
    BEFORE UPDATE ON touring_task_surveys
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
END IF; END $$;

DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_trigger WHERE tgname = 'update_survey_submissions_updated_at'
) THEN
  CREATE TRIGGER update_survey_submissions_updated_at
    BEFORE UPDATE ON survey_submissions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
END IF; END $$;

-- 4) Functions (RPCs)
CREATE OR REPLACE FUNCTION get_survey_with_fields(survey_uuid UUID)
RETURNS JSON AS $$
DECLARE result JSON; BEGIN
  SELECT json_build_object(
    'survey', to_json(s.*),
    'fields', COALESCE(json_agg(to_json(sf.*) ORDER BY sf.field_order, sf.created_at)
              FILTER (WHERE sf.id IS NOT NULL), '[]'::json)
  ) INTO result
  FROM touring_task_surveys s
  LEFT JOIN survey_fields sf ON s.id = sf.survey_id
  WHERE s.id = survey_uuid
  GROUP BY s.id, s.touring_task_id, s.title, s.description, s.is_required, s.is_active,
           s.created_at, s.updated_at, s.created_by;
  RETURN result;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_campaign_survey_stats(campaign_uuid UUID)
RETURNS JSON AS $$
DECLARE result JSON; BEGIN
  SELECT json_build_object(
    'total_surveys', COUNT(DISTINCT tts.id),
    'total_submissions', COUNT(DISTINCT ss.id),
    'unique_agents_submitted', COUNT(DISTINCT ss.agent_id),
    'completion_rate', CASE WHEN COUNT(DISTINCT tts.id) > 0
      THEN ROUND((COUNT(DISTINCT ss.id)::DECIMAL / COUNT(DISTINCT tts.id)) * 100, 2)
      ELSE 0 END,
    'surveys_by_task', COALESCE(json_agg(DISTINCT json_build_object(
        'task_id', tt.id,
        'task_title', tt.title,
        'survey_id', tts.id,
        'survey_title', tts.title,
        'submissions_count', (SELECT COUNT(*) FROM survey_submissions ss2 WHERE ss2.survey_id = tts.id)
      )) FILTER (WHERE tts.id IS NOT NULL), '[]'::json)
  ) INTO result
  FROM campaigns c
  LEFT JOIN touring_tasks tt ON c.id = tt.campaign_id
  LEFT JOIN touring_task_surveys tts ON tt.id = tts.touring_task_id
  LEFT JOIN survey_submissions ss ON tts.id = ss.survey_id
  WHERE c.id = campaign_uuid;
  RETURN result;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_agent_survey_submissions(agent_uuid UUID, campaign_uuid UUID)
RETURNS JSON AS $$
DECLARE result JSON; BEGIN
  SELECT COALESCE(json_agg(json_build_object(
    'submission_id', ss.id,
    'survey_id', ss.survey_id,
    'survey_title', tts.title,
    'task_title', tt.title,
    'touring_task_id', ss.touring_task_id,
    'submitted_at', ss.submitted_at,
    'location', json_build_object('latitude', ss.latitude, 'longitude', ss.longitude),
    'data', ss.submission_data
  ) ORDER BY ss.submitted_at DESC), '[]'::json) INTO result
  FROM survey_submissions ss
  JOIN touring_task_surveys tts ON ss.survey_id = tts.id
  JOIN touring_tasks tt ON tts.touring_task_id = tt.id
  JOIN campaigns c ON tt.campaign_id = c.id
  WHERE ss.agent_id = agent_uuid AND c.id = campaign_uuid;
  RETURN result;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

