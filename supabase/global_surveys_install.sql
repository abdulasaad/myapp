-- Global Surveys (standalone, decoupled from campaigns/tasks)

-- 1) Tables
CREATE TABLE IF NOT EXISTS global_surveys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  is_required BOOLEAN DEFAULT true,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID NOT NULL REFERENCES profiles(id)
);

CREATE TABLE IF NOT EXISTS global_survey_fields (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id UUID NOT NULL REFERENCES global_surveys(id) ON DELETE CASCADE,
  field_name VARCHAR(255) NOT NULL,
  field_type VARCHAR(50) NOT NULL CHECK (field_type IN ('text','number','select','multiselect','boolean','date','textarea','rating','photo')),
  field_label VARCHAR(255) NOT NULL,
  field_placeholder VARCHAR(255),
  field_options JSONB,
  is_required BOOLEAN DEFAULT false,
  field_order INTEGER DEFAULT 0,
  validation_rules JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_field_name_per_global_survey UNIQUE (survey_id, field_name)
);

CREATE TABLE IF NOT EXISTS global_survey_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id UUID NOT NULL REFERENCES global_surveys(id) ON DELETE CASCADE,
  agent_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  submission_data JSONB NOT NULL,
  submitted_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION
);

-- 2) RLS
ALTER TABLE global_surveys ENABLE ROW LEVEL SECURITY;
ALTER TABLE global_survey_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE global_survey_submissions ENABLE ROW LEVEL SECURITY;

-- Managers: manage their own surveys
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Managers can manage global surveys' AND tablename = 'global_surveys'
  ) THEN
    CREATE POLICY "Managers can manage global surveys" ON global_surveys
      FOR ALL USING (created_by = auth.uid());
  END IF;
END $$;

-- Agents: view surveys created by managers they are associated with via campaign assignment
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Agents can view global surveys' AND tablename = 'global_surveys'
  ) THEN
    CREATE POLICY "Agents can view global surveys" ON global_surveys
      FOR SELECT USING (
        EXISTS (
          SELECT 1
          FROM campaigns c
          JOIN campaign_agents ca ON ca.campaign_id = c.id
          WHERE c.created_by = global_surveys.created_by
            AND ca.agent_id = auth.uid()
        )
      );
  END IF;
END $$;

-- Fields follow the same rule as their parent survey
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Managers can manage global survey fields' AND tablename = 'global_survey_fields'
  ) THEN
    CREATE POLICY "Managers can manage global survey fields" ON global_survey_fields
      FOR ALL USING (
        EXISTS (
          SELECT 1 FROM global_surveys gs
          WHERE gs.id = global_survey_fields.survey_id AND gs.created_by = auth.uid()
        )
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Agents can view global survey fields' AND tablename = 'global_survey_fields'
  ) THEN
    CREATE POLICY "Agents can view global survey fields" ON global_survey_fields
      FOR SELECT USING (
        EXISTS (
          SELECT 1 FROM global_surveys gs
          JOIN campaigns c ON c.created_by = gs.created_by
          JOIN campaign_agents ca ON ca.campaign_id = c.id
          WHERE gs.id = global_survey_fields.survey_id AND ca.agent_id = auth.uid()
        )
      );
  END IF;
END $$;

-- Submissions: agents manage their own; managers read for their surveys
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Agents manage their global survey submissions' AND tablename = 'global_survey_submissions'
  ) THEN
    CREATE POLICY "Agents manage their global survey submissions" ON global_survey_submissions
      FOR ALL USING (agent_id = auth.uid());
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Managers view global survey submissions' AND tablename = 'global_survey_submissions'
  ) THEN
    CREATE POLICY "Managers view global survey submissions" ON global_survey_submissions
      FOR SELECT USING (
        EXISTS (
          SELECT 1 FROM global_surveys gs
          WHERE gs.id = global_survey_submissions.survey_id AND gs.created_by = auth.uid()
        )
      );
  END IF;
END $$;

-- 3) Indexes
CREATE INDEX IF NOT EXISTS idx_global_surveys_created_by ON global_surveys(created_by);
CREATE INDEX IF NOT EXISTS idx_global_survey_fields_survey_id ON global_survey_fields(survey_id);
CREATE INDEX IF NOT EXISTS idx_global_survey_fields_order ON global_survey_fields(survey_id, field_order);
CREATE INDEX IF NOT EXISTS idx_global_survey_submissions_survey_id ON global_survey_submissions(survey_id);
CREATE INDEX IF NOT EXISTS idx_global_survey_submissions_agent_id ON global_survey_submissions(agent_id);
CREATE INDEX IF NOT EXISTS idx_global_survey_submissions_submitted_at ON global_survey_submissions(submitted_at);

-- 4) Triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_global_surveys_updated_at') THEN
    CREATE TRIGGER update_global_surveys_updated_at
      BEFORE UPDATE ON global_surveys
      FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_global_survey_submissions_updated_at') THEN
    CREATE TRIGGER update_global_survey_submissions_updated_at
      BEFORE UPDATE ON global_survey_submissions
      FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
  END IF;
END $$;

