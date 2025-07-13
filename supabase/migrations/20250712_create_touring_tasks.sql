-- Migration: Create touring tasks system
-- Created: 2025-07-12

-- Create touring_tasks table
CREATE TABLE IF NOT EXISTS touring_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    geofence_id UUID NOT NULL REFERENCES campaign_geofences(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    required_time_minutes INTEGER NOT NULL DEFAULT 30,
    movement_timeout_seconds INTEGER NOT NULL DEFAULT 60,
    min_movement_threshold DECIMAL(8,2) NOT NULL DEFAULT 5.0, -- meters
    points INTEGER NOT NULL DEFAULT 10,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'completed', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    created_by UUID REFERENCES auth.users(id)
);

-- Create touring_task_sessions table to track active sessions
CREATE TABLE IF NOT EXISTS touring_task_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    touring_task_id UUID NOT NULL REFERENCES touring_tasks(id) ON DELETE CASCADE,
    agent_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_time TIMESTAMPTZ,
    elapsed_seconds INTEGER NOT NULL DEFAULT 0, -- Total active time (excluding pauses)
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_paused BOOLEAN NOT NULL DEFAULT false,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    last_movement_time TIMESTAMPTZ,
    last_latitude DECIMAL(10,8),
    last_longitude DECIMAL(11,8),
    pause_reason TEXT,
    last_location_update TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

-- Create touring_task_assignments table (linking agents to touring tasks)
CREATE TABLE IF NOT EXISTS touring_task_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    touring_task_id UUID NOT NULL REFERENCES touring_tasks(id) ON DELETE CASCADE,
    agent_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    assigned_by UUID REFERENCES auth.users(id),
    status TEXT NOT NULL DEFAULT 'assigned' CHECK (status IN ('assigned', 'in_progress', 'completed', 'cancelled')),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    UNIQUE(touring_task_id, agent_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_touring_tasks_campaign_id ON touring_tasks(campaign_id);
CREATE INDEX IF NOT EXISTS idx_touring_tasks_geofence_id ON touring_tasks(geofence_id);
CREATE INDEX IF NOT EXISTS idx_touring_tasks_status ON touring_tasks(status);
CREATE INDEX IF NOT EXISTS idx_touring_task_sessions_touring_task_id ON touring_task_sessions(touring_task_id);
CREATE INDEX IF NOT EXISTS idx_touring_task_sessions_agent_id ON touring_task_sessions(agent_id);
CREATE INDEX IF NOT EXISTS idx_touring_task_sessions_active ON touring_task_sessions(is_active, is_completed);
CREATE INDEX IF NOT EXISTS idx_touring_task_assignments_touring_task_id ON touring_task_assignments(touring_task_id);
CREATE INDEX IF NOT EXISTS idx_touring_task_assignments_agent_id ON touring_task_assignments(agent_id);
CREATE INDEX IF NOT EXISTS idx_touring_task_assignments_status ON touring_task_assignments(status);

-- Enable RLS (Row Level Security)
ALTER TABLE touring_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE touring_task_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE touring_task_assignments ENABLE ROW LEVEL SECURITY;

-- RLS Policies for touring_tasks
CREATE POLICY "Users can view touring tasks in their campaigns" ON touring_tasks
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM campaigns c 
            WHERE c.id = touring_tasks.campaign_id 
            AND (
                c.created_by = auth.uid() 
                OR EXISTS (
                    SELECT 1 FROM campaign_agents ca 
                    WHERE ca.campaign_id = c.id AND ca.agent_id = auth.uid()
                )
            )
        )
    );

CREATE POLICY "Managers can create touring tasks" ON touring_tasks
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles p 
            WHERE p.id = auth.uid() 
            AND p.role IN ('admin', 'manager')
        )
    );

CREATE POLICY "Managers can update touring tasks" ON touring_tasks
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM profiles p 
            WHERE p.id = auth.uid() 
            AND p.role IN ('admin', 'manager')
        )
    );

CREATE POLICY "Managers can delete touring tasks" ON touring_tasks
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM profiles p 
            WHERE p.id = auth.uid() 
            AND p.role IN ('admin', 'manager')
        )
    );

-- RLS Policies for touring_task_sessions
CREATE POLICY "Users can view their own sessions" ON touring_task_sessions
    FOR SELECT USING (agent_id = auth.uid());

CREATE POLICY "Managers can view all sessions in their campaigns" ON touring_task_sessions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM touring_tasks tt
            JOIN campaigns c ON c.id = tt.campaign_id
            WHERE tt.id = touring_task_sessions.touring_task_id
            AND c.created_by = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM profiles p 
            WHERE p.id = auth.uid() 
            AND p.role = 'admin'
        )
    );

CREATE POLICY "Agents can create their own sessions" ON touring_task_sessions
    FOR INSERT WITH CHECK (agent_id = auth.uid());

CREATE POLICY "Agents can update their own sessions" ON touring_task_sessions
    FOR UPDATE USING (agent_id = auth.uid());

-- RLS Policies for touring_task_assignments
CREATE POLICY "Users can view their assignments" ON touring_task_assignments
    FOR SELECT USING (
        agent_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM touring_tasks tt
            JOIN campaigns c ON c.id = tt.campaign_id
            WHERE tt.id = touring_task_assignments.touring_task_id
            AND c.created_by = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM profiles p 
            WHERE p.id = auth.uid() 
            AND p.role = 'admin'
        )
    );

CREATE POLICY "Managers can create assignments" ON touring_task_assignments
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles p 
            WHERE p.id = auth.uid() 
            AND p.role IN ('admin', 'manager')
        )
    );

CREATE POLICY "Managers can update assignments" ON touring_task_assignments
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM profiles p 
            WHERE p.id = auth.uid() 
            AND p.role IN ('admin', 'manager')
        )
        OR agent_id = auth.uid() -- Agents can update their own assignment status
    );

-- Create triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_touring_tasks_updated_at 
    BEFORE UPDATE ON touring_tasks 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_touring_task_sessions_updated_at 
    BEFORE UPDATE ON touring_task_sessions 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create RPC functions for touring task management

-- Function to create a new touring task
CREATE OR REPLACE FUNCTION create_touring_task(
    p_campaign_id UUID,
    p_geofence_id UUID,
    p_title TEXT,
    p_description TEXT DEFAULT NULL,
    p_required_time_minutes INTEGER DEFAULT 30,
    p_movement_timeout_seconds INTEGER DEFAULT 60,
    p_min_movement_threshold DECIMAL DEFAULT 5.0,
    p_points INTEGER DEFAULT 10
) RETURNS JSON AS $$
DECLARE
    task_id UUID;
    result JSON;
BEGIN
    -- Insert the touring task
    INSERT INTO touring_tasks (
        campaign_id,
        geofence_id,
        title,
        description,
        required_time_minutes,
        movement_timeout_seconds,
        min_movement_threshold,
        points,
        created_by
    ) VALUES (
        p_campaign_id,
        p_geofence_id,
        p_title,
        p_description,
        p_required_time_minutes,
        p_movement_timeout_seconds,
        p_min_movement_threshold,
        p_points,
        auth.uid()
    ) RETURNING id INTO task_id;

    -- Return the created task
    SELECT json_build_object(
        'id', id,
        'campaign_id', campaign_id,
        'geofence_id', geofence_id,
        'title', title,
        'description', description,
        'required_time_minutes', required_time_minutes,
        'movement_timeout_seconds', movement_timeout_seconds,
        'min_movement_threshold', min_movement_threshold,
        'points', points,
        'status', status,
        'created_at', created_at,
        'created_by', created_by
    ) INTO result
    FROM touring_tasks
    WHERE id = task_id;

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to assign agents to touring task
CREATE OR REPLACE FUNCTION assign_agents_to_touring_task(
    p_touring_task_id UUID,
    p_agent_ids UUID[]
) RETURNS JSON AS $$
DECLARE
    agent_id UUID;
    assignment_count INTEGER := 0;
BEGIN
    -- Insert assignments for each agent
    FOREACH agent_id IN ARRAY p_agent_ids
    LOOP
        INSERT INTO touring_task_assignments (
            touring_task_id,
            agent_id,
            assigned_by
        ) VALUES (
            p_touring_task_id,
            agent_id,
            auth.uid()
        ) ON CONFLICT (touring_task_id, agent_id) DO NOTHING;
        
        GET DIAGNOSTICS assignment_count = ROW_COUNT;
    END LOOP;

    RETURN json_build_object('success', true, 'assignments_created', assignment_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if a point is within a geofence
CREATE OR REPLACE FUNCTION check_point_in_geofence(
    p_lat DECIMAL,
    p_lng DECIMAL,
    p_geofence_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    geofence_area geometry;
BEGIN
    -- Get the geofence area
    SELECT ST_GeomFromText(area_text) INTO geofence_area
    FROM campaign_geofences
    WHERE id = p_geofence_id;
    
    -- Return false if geofence not found
    IF geofence_area IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Check if point is within the geofence
    RETURN ST_Contains(geofence_area, ST_Point(p_lat, p_lng));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;