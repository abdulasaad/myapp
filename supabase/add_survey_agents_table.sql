-- Add global survey agents assignment table

-- Create the table
CREATE TABLE IF NOT EXISTS global_survey_agents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id UUID NOT NULL REFERENCES global_surveys(id) ON DELETE CASCADE,
  agent_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_survey_agent UNIQUE (survey_id, agent_id)
);

-- Enable RLS
ALTER TABLE global_survey_agents ENABLE ROW LEVEL SECURITY;

-- Managers can manage assignments for their surveys
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Managers can manage survey agent assignments' AND tablename = 'global_survey_agents'
  ) THEN
    CREATE POLICY "Managers can manage survey agent assignments" ON global_survey_agents
      FOR ALL USING (
        EXISTS (
          SELECT 1 FROM global_surveys gs
          WHERE gs.id = global_survey_agents.survey_id AND gs.created_by = auth.uid()
        )
      );
  END IF;
END $$;

-- Agents can view their own assignments
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Agents can view their survey assignments' AND tablename = 'global_survey_agents'
  ) THEN
    CREATE POLICY "Agents can view their survey assignments" ON global_survey_agents
      FOR SELECT USING (agent_id = auth.uid());
  END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_global_survey_agents_survey_id ON global_survey_agents(survey_id);
CREATE INDEX IF NOT EXISTS idx_global_survey_agents_agent_id ON global_survey_agents(agent_id);
CREATE INDEX IF NOT EXISTS idx_global_survey_agents_assigned_at ON global_survey_agents(assigned_at);