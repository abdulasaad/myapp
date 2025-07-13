-- Multi-Geofence Campaign System
-- Creates tables and functions for campaigns with multiple geofences and agent capacity management

-- 1. Create campaign_geofences table
CREATE TABLE IF NOT EXISTS public.campaign_geofences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    campaign_id UUID NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    geometry GEOMETRY(POLYGON, 4326) NOT NULL,
    area_text TEXT, -- WKT representation for easy access
    max_agents INTEGER NOT NULL DEFAULT 1,
    color TEXT NOT NULL DEFAULT '#2196F3', -- Hex color for map display
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id)
);

-- 2. Create agent_geofence_assignments table
CREATE TABLE IF NOT EXISTS public.agent_geofence_assignments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    campaign_id UUID NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
    geofence_id UUID NOT NULL REFERENCES public.campaign_geofences(id) ON DELETE CASCADE,
    agent_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
    entry_time TIMESTAMP WITH TIME ZONE,
    exit_time TIMESTAMP WITH TIME ZONE,
    total_time_inside INTERVAL, -- Calculated field for analytics
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one active assignment per agent per campaign
    UNIQUE(campaign_id, agent_id, status) DEFERRABLE INITIALLY DEFERRED
);

-- 3. Create agent_location_tracking table for movement tracking
CREATE TABLE IF NOT EXISTS public.agent_location_tracking (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    agent_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    campaign_id UUID NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
    geofence_id UUID REFERENCES public.campaign_geofences(id) ON DELETE CASCADE,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    accuracy DECIMAL(8, 2),
    is_inside_geofence BOOLEAN NOT NULL DEFAULT FALSE,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Index for efficient location queries
    CONSTRAINT valid_coordinates CHECK (
        latitude BETWEEN -90 AND 90 AND 
        longitude BETWEEN -180 AND 180
    )
);

-- 4. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_campaign_geofences_campaign_id ON public.campaign_geofences(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_geofences_active ON public.campaign_geofences(campaign_id, is_active);
CREATE INDEX IF NOT EXISTS idx_agent_geofence_assignments_campaign ON public.agent_geofence_assignments(campaign_id, agent_id);
CREATE INDEX IF NOT EXISTS idx_agent_geofence_assignments_geofence ON public.agent_geofence_assignments(geofence_id, status);
CREATE INDEX IF NOT EXISTS idx_agent_location_tracking_agent ON public.agent_location_tracking(agent_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_location_tracking_geofence ON public.agent_location_tracking(geofence_id, recorded_at DESC);

-- 5. Create function to check geofence capacity
CREATE OR REPLACE FUNCTION check_geofence_capacity(p_geofence_id UUID)
RETURNS TABLE(
    current_agents INTEGER,
    max_agents INTEGER,
    is_full BOOLEAN,
    available_spots INTEGER
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(COUNT(aga.id)::INTEGER, 0) as current_agents,
        cg.max_agents,
        (COALESCE(COUNT(aga.id), 0) >= cg.max_agents) as is_full,
        GREATEST(0, cg.max_agents - COALESCE(COUNT(aga.id)::INTEGER, 0)) as available_spots
    FROM public.campaign_geofences cg
    LEFT JOIN public.agent_geofence_assignments aga ON cg.id = aga.geofence_id 
        AND aga.status = 'active'
    WHERE cg.id = p_geofence_id
    GROUP BY cg.id, cg.max_agents;
END;
$$;

-- 6. Create function to get available geofences for a campaign
CREATE OR REPLACE FUNCTION get_available_geofences_for_campaign(p_campaign_id UUID)
RETURNS TABLE(
    id UUID,
    campaign_id UUID,
    name TEXT,
    description TEXT,
    max_agents INTEGER,
    current_agents INTEGER,
    is_full BOOLEAN,
    available_spots INTEGER,
    color TEXT,
    area_text TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    created_by UUID
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cg.id,
        cg.campaign_id,
        cg.name,
        cg.description,
        cg.max_agents,
        COALESCE(COUNT(aga.id)::INTEGER, 0) as current_agents,
        (COALESCE(COUNT(aga.id), 0) >= cg.max_agents) as is_full,
        GREATEST(0, cg.max_agents - COALESCE(COUNT(aga.id)::INTEGER, 0)) as available_spots,
        cg.color,
        cg.area_text,
        cg.is_active,
        cg.created_at,
        cg.updated_at,
        cg.created_by
    FROM public.campaign_geofences cg
    LEFT JOIN public.agent_geofence_assignments aga ON cg.id = aga.geofence_id 
        AND aga.status = 'active'
    WHERE cg.campaign_id = p_campaign_id 
        AND cg.is_active = TRUE
    GROUP BY cg.id, cg.campaign_id, cg.name, cg.description, cg.max_agents, cg.color, cg.area_text, cg.is_active, cg.created_at, cg.updated_at, cg.created_by
    ORDER BY cg.name;
END;
$$;

-- 7. Create function to assign agent to geofence
CREATE OR REPLACE FUNCTION assign_agent_to_geofence(
    p_campaign_id UUID,
    p_geofence_id UUID,
    p_agent_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_capacity_info RECORD;
    v_existing_assignment UUID;
    v_assignment_id UUID;
BEGIN
    -- Check if geofence has capacity
    SELECT * INTO v_capacity_info 
    FROM check_geofence_capacity(p_geofence_id);
    
    IF v_capacity_info.is_full THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Geofence is at maximum capacity',
            'current_agents', v_capacity_info.current_agents,
            'max_agents', v_capacity_info.max_agents
        );
    END IF;
    
    -- Check if agent already has an active assignment in this campaign
    SELECT id INTO v_existing_assignment
    FROM public.agent_geofence_assignments
    WHERE campaign_id = p_campaign_id 
        AND agent_id = p_agent_id 
        AND status = 'active';
    
    IF v_existing_assignment IS NOT NULL THEN
        -- Cancel existing assignment
        UPDATE public.agent_geofence_assignments
        SET status = 'cancelled',
            exit_time = NOW()
        WHERE id = v_existing_assignment;
    END IF;
    
    -- Create new assignment
    INSERT INTO public.agent_geofence_assignments (
        campaign_id, geofence_id, agent_id, status
    ) VALUES (
        p_campaign_id, p_geofence_id, p_agent_id, 'active'
    ) RETURNING id INTO v_assignment_id;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'assignment_id', v_assignment_id,
        'message', 'Agent successfully assigned to geofence'
    );
END;
$$;

-- 8. Create function to track agent entry/exit from geofence
CREATE OR REPLACE FUNCTION update_agent_geofence_status(
    p_agent_id UUID,
    p_geofence_id UUID,
    p_latitude DECIMAL,
    p_longitude DECIMAL,
    p_is_inside BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_assignment_id UUID;
    v_current_entry_time TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Get active assignment
    SELECT id, entry_time INTO v_assignment_id, v_current_entry_time
    FROM public.agent_geofence_assignments
    WHERE geofence_id = p_geofence_id 
        AND agent_id = p_agent_id 
        AND status = 'active';
    
    IF v_assignment_id IS NOT NULL THEN
        -- Update entry/exit times
        IF p_is_inside AND v_current_entry_time IS NULL THEN
            -- Agent entered geofence
            UPDATE public.agent_geofence_assignments
            SET entry_time = NOW()
            WHERE id = v_assignment_id;
        ELSIF NOT p_is_inside AND v_current_entry_time IS NOT NULL THEN
            -- Agent exited geofence
            UPDATE public.agent_geofence_assignments
            SET exit_time = NOW(),
                total_time_inside = COALESCE(total_time_inside, INTERVAL '0') + (NOW() - v_current_entry_time),
                entry_time = NULL -- Reset for next entry
            WHERE id = v_assignment_id;
        END IF;
    END IF;
    
    -- Insert location tracking record
    INSERT INTO public.agent_location_tracking (
        agent_id, 
        campaign_id, 
        geofence_id, 
        latitude, 
        longitude, 
        is_inside_geofence
    ) VALUES (
        p_agent_id,
        (SELECT campaign_id FROM public.campaign_geofences WHERE id = p_geofence_id),
        p_geofence_id,
        p_latitude,
        p_longitude,
        p_is_inside
    );
END;
$$;

-- 9. Create RLS policies for new tables

-- Campaign Geofences policies
ALTER TABLE public.campaign_geofences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Campaign geofences viewable by authenticated users" ON public.campaign_geofences
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Campaign geofences manageable by admin/manager" ON public.campaign_geofences
    FOR ALL USING (
        get_my_role() IN ('admin', 'manager') OR 
        created_by = auth.uid()
    );

-- Agent Geofence Assignments policies
ALTER TABLE public.agent_geofence_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Agent assignments viewable by involved parties" ON public.agent_geofence_assignments
    FOR SELECT USING (
        agent_id = auth.uid() OR 
        get_my_role() IN ('admin', 'manager')
    );

CREATE POLICY "Agent assignments manageable by admin/manager/self" ON public.agent_geofence_assignments
    FOR ALL USING (
        agent_id = auth.uid() OR 
        get_my_role() IN ('admin', 'manager')
    );

-- Agent Location Tracking policies
ALTER TABLE public.agent_location_tracking ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Location tracking viewable by involved parties" ON public.agent_location_tracking
    FOR SELECT USING (
        agent_id = auth.uid() OR 
        get_my_role() IN ('admin', 'manager')
    );

CREATE POLICY "Location tracking insertable by agents" ON public.agent_location_tracking
    FOR INSERT WITH CHECK (
        agent_id = auth.uid() OR 
        get_my_role() IN ('admin', 'manager')
    );

-- 10. Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_campaign_geofences_updated_at
    BEFORE UPDATE ON public.campaign_geofences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.campaign_geofences TO authenticated;
GRANT ALL ON public.agent_geofence_assignments TO authenticated;
GRANT ALL ON public.agent_location_tracking TO authenticated;