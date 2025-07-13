-- Migration to create RPC function for geofence creation
-- This handles the PostGIS geometry conversion properly

CREATE OR REPLACE FUNCTION create_campaign_geofence(
  p_campaign_id UUID,
  p_name TEXT,
  p_area_text TEXT,
  p_max_agents INTEGER,
  p_color TEXT,
  p_description TEXT DEFAULT NULL,
  p_created_by UUID DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
  v_geofence_id UUID;
  v_result JSON;
BEGIN
  -- Insert the new geofence
  INSERT INTO campaign_geofences (
    campaign_id,
    name,
    description,
    area_text,
    geometry,
    max_agents,
    color,
    created_by
  ) VALUES (
    p_campaign_id,
    p_name,
    p_description,
    p_area_text,
    ST_GeomFromText(p_area_text, 4326),
    p_max_agents,
    p_color,
    p_created_by
  ) RETURNING id INTO v_geofence_id;

  -- Return the created geofence with additional information
  SELECT json_build_object(
    'id', cg.id,
    'campaign_id', cg.campaign_id,
    'name', cg.name,
    'description', cg.description,
    'area_text', cg.area_text,
    'max_agents', cg.max_agents,
    'color', cg.color,
    'is_active', cg.is_active,
    'created_by', cg.created_by,
    'created_at', cg.created_at,
    'current_agents', 0,
    'is_full', false
  ) INTO v_result
  FROM campaign_geofences cg
  WHERE cg.id = v_geofence_id;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION create_campaign_geofence TO authenticated;

-- Function to update existing geofence
CREATE OR REPLACE FUNCTION update_campaign_geofence(
  p_geofence_id UUID,
  p_name TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_area_text TEXT DEFAULT NULL,
  p_max_agents INTEGER DEFAULT NULL,
  p_color TEXT DEFAULT NULL,
  p_is_active BOOLEAN DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
  v_result JSON;
BEGIN
  -- Update the geofence
  UPDATE campaign_geofences 
  SET 
    name = COALESCE(p_name, name),
    description = COALESCE(p_description, description),
    area_text = COALESCE(p_area_text, area_text),
    geometry = CASE 
      WHEN p_area_text IS NOT NULL THEN ST_GeomFromText(p_area_text, 4326)
      ELSE geometry
    END,
    max_agents = COALESCE(p_max_agents, max_agents),
    color = COALESCE(p_color, color),
    is_active = COALESCE(p_is_active, is_active)
  WHERE id = p_geofence_id;

  -- Return the updated geofence with additional information
  SELECT json_build_object(
    'id', cg.id,
    'campaign_id', cg.campaign_id,
    'name', cg.name,
    'description', cg.description,
    'area_text', cg.area_text,
    'max_agents', cg.max_agents,
    'color', cg.color,
    'is_active', cg.is_active,
    'created_by', cg.created_by,
    'created_at', cg.created_at,
    'current_agents', COALESCE(
      (SELECT COUNT(*) 
       FROM agent_geofence_assignments aga 
       WHERE aga.geofence_id = cg.id AND aga.status = 'active'), 
      0
    ),
    'is_full', COALESCE(
      (SELECT COUNT(*) 
       FROM agent_geofence_assignments aga 
       WHERE aga.geofence_id = cg.id AND aga.status = 'active'), 
      0
    ) >= cg.max_agents
  ) INTO v_result
  FROM campaign_geofences cg
  WHERE cg.id = p_geofence_id;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION update_campaign_geofence TO authenticated;