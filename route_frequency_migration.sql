-- Route Visit Frequency Feature Migration
-- This migration adds support for specifying how many times each place in a route must be visited
-- with a 12-hour cooldown period between visits

-- Step 1: Add frequency column to route_places table
ALTER TABLE route_places 
ADD COLUMN visit_frequency integer DEFAULT 1 CHECK (visit_frequency >= 1);

COMMENT ON COLUMN route_places.visit_frequency IS 'Number of times this place must be visited to complete the route';

-- Step 2: Add visit tracking to place_visits table
ALTER TABLE place_visits 
ADD COLUMN visit_number integer DEFAULT 1;

COMMENT ON COLUMN place_visits.visit_number IS 'Which visit number this is (1st, 2nd, etc.)';

-- Add unique constraint to prevent duplicate visit numbers
ALTER TABLE place_visits 
ADD CONSTRAINT place_visits_unique_visit_number 
UNIQUE (route_assignment_id, place_id, agent_id, visit_number);

-- Step 3: Update existing place_visits to have visit_number = 1
UPDATE place_visits 
SET visit_number = 1 
WHERE visit_number IS NULL;

-- Step 4: Create function to check if a place is available for check-in
CREATE OR REPLACE FUNCTION check_place_visit_availability(
    p_route_assignment_id UUID,
    p_place_id UUID,
    p_agent_id UUID
) RETURNS TABLE (
    can_check_in BOOLEAN,
    reason TEXT,
    completed_visits INTEGER,
    required_visits INTEGER,
    last_checkout_time TIMESTAMPTZ,
    cooldown_remaining_hours NUMERIC
) AS $$
DECLARE
    v_visit_frequency INTEGER;
    v_completed_visits INTEGER;
    v_last_checkout TIMESTAMPTZ;
    v_hours_since_checkout NUMERIC;
    v_active_checkin INTEGER;
BEGIN
    -- Check if there's an active check-in
    SELECT COUNT(*) INTO v_active_checkin
    FROM place_visits
    WHERE route_assignment_id = p_route_assignment_id 
    AND place_id = p_place_id 
    AND agent_id = p_agent_id
    AND status = 'checked_in';
    
    IF v_active_checkin > 0 THEN
        RETURN QUERY SELECT 
            FALSE, 
            'Already checked in',
            0,
            0,
            NULL::TIMESTAMPTZ,
            0::NUMERIC;
        RETURN;
    END IF;

    -- Get the required visit frequency for this place
    SELECT rp.visit_frequency INTO v_visit_frequency
    FROM route_places rp
    JOIN route_assignments ra ON ra.route_id = rp.route_id
    WHERE ra.id = p_route_assignment_id AND rp.place_id = p_place_id;
    
    IF v_visit_frequency IS NULL THEN
        v_visit_frequency := 1; -- Default to 1 if not found
    END IF;
    
    -- Count completed visits
    SELECT COUNT(*), MAX(checked_out_at) 
    INTO v_completed_visits, v_last_checkout
    FROM place_visits
    WHERE route_assignment_id = p_route_assignment_id 
    AND place_id = p_place_id 
    AND agent_id = p_agent_id
    AND status = 'completed';
    
    -- Calculate hours since last checkout
    IF v_last_checkout IS NOT NULL THEN
        v_hours_since_checkout := EXTRACT(EPOCH FROM (NOW() - v_last_checkout)) / 3600;
    ELSE
        v_hours_since_checkout := NULL;
    END IF;
    
    -- Determine if check-in is allowed
    IF v_completed_visits >= v_visit_frequency THEN
        RETURN QUERY SELECT 
            FALSE, 
            'All required visits completed',
            v_completed_visits,
            v_visit_frequency,
            v_last_checkout,
            0::NUMERIC;
    ELSIF v_last_checkout IS NOT NULL AND v_hours_since_checkout < 12 THEN
        RETURN QUERY SELECT 
            FALSE, 
            'Cooldown period active',
            v_completed_visits,
            v_visit_frequency,
            v_last_checkout,
            (12 - v_hours_since_checkout)::NUMERIC;
    ELSE
        RETURN QUERY SELECT 
            TRUE, 
            'Check-in available',
            v_completed_visits,
            v_visit_frequency,
            v_last_checkout,
            0::NUMERIC;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Create helper function to get next visit number
CREATE OR REPLACE FUNCTION get_next_visit_number(
    p_route_assignment_id UUID,
    p_place_id UUID,
    p_agent_id UUID
) RETURNS INTEGER AS $$
DECLARE
    v_max_visit_number INTEGER;
BEGIN
    SELECT COALESCE(MAX(visit_number), 0) + 1 INTO v_max_visit_number
    FROM place_visits
    WHERE route_assignment_id = p_route_assignment_id 
    AND place_id = p_place_id 
    AND agent_id = p_agent_id;
    
    RETURN v_max_visit_number;
END;
$$ LANGUAGE plpgsql;

-- Step 6: Create view to show route completion progress including frequencies
CREATE OR REPLACE VIEW route_completion_progress AS
SELECT 
    ra.id as route_assignment_id,
    ra.route_id,
    ra.agent_id,
    r.name as route_name,
    COUNT(DISTINCT rp.place_id) as total_places,
    SUM(rp.visit_frequency) as total_required_visits,
    COUNT(DISTINCT CASE WHEN pv.status = 'completed' THEN pv.place_id || '-' || pv.visit_number END) as completed_visits,
    CASE 
        WHEN SUM(rp.visit_frequency) > 0 
        THEN (COUNT(DISTINCT CASE WHEN pv.status = 'completed' THEN pv.place_id || '-' || pv.visit_number END)::FLOAT / SUM(rp.visit_frequency)::FLOAT * 100)
        ELSE 0 
    END as completion_percentage,
    CASE 
        WHEN COUNT(DISTINCT CASE WHEN pv.status = 'completed' THEN pv.place_id || '-' || pv.visit_number END) >= SUM(rp.visit_frequency)
        THEN TRUE 
        ELSE FALSE 
    END as is_fully_completed
FROM route_assignments ra
JOIN routes r ON r.id = ra.route_id
JOIN route_places rp ON rp.route_id = ra.route_id
LEFT JOIN place_visits pv ON pv.route_assignment_id = ra.id AND pv.place_id = rp.place_id
GROUP BY ra.id, ra.route_id, ra.agent_id, r.name;

-- Step 7: Update route_assignments status based on frequency completion
-- This trigger will automatically update route status when all frequencies are met
CREATE OR REPLACE FUNCTION update_route_assignment_completion() RETURNS TRIGGER AS $$
DECLARE
    v_is_completed BOOLEAN;
BEGIN
    -- Check if all places have been visited the required number of times
    SELECT is_fully_completed INTO v_is_completed
    FROM route_completion_progress
    WHERE route_assignment_id = NEW.route_assignment_id;
    
    -- Update route assignment status if fully completed
    IF v_is_completed AND NEW.status = 'completed' THEN
        UPDATE route_assignments
        SET status = 'completed',
            completed_at = COALESCE(completed_at, NOW())
        WHERE id = NEW.route_assignment_id
        AND status != 'completed';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_route_completion
AFTER INSERT OR UPDATE ON place_visits
FOR EACH ROW
EXECUTE FUNCTION update_route_assignment_completion();

-- Step 8: Sample query to test the functionality
-- Check if an agent can check in to a place
-- SELECT * FROM check_place_visit_availability(
--     'route_assignment_id_here'::uuid, 
--     'place_id_here'::uuid, 
--     'agent_id_here'::uuid
-- );

-- Get route completion progress
-- SELECT * FROM route_completion_progress WHERE agent_id = 'agent_id_here'::uuid;