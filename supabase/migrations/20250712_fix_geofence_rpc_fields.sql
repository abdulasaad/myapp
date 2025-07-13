-- Fix RPC function to return all required fields for CampaignGeofence model

-- Drop the existing function first
DROP FUNCTION IF EXISTS get_available_geofences_for_campaign(UUID);

-- Create the function with the correct return type
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