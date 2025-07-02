-- Step 5: Create place_visits table for tracking check-ins and check-outs
-- This table records actual visits to places with timing and location data

CREATE TABLE public.place_visits (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    route_assignment_id UUID REFERENCES public.route_assignments(id) ON DELETE CASCADE NOT NULL,
    place_id UUID REFERENCES public.places(id) NOT NULL,
    agent_id UUID REFERENCES public.profiles(id) NOT NULL,
    checked_in_at TIMESTAMPTZ,
    checked_out_at TIMESTAMPTZ,
    duration_minutes INTEGER GENERATED ALWAYS AS (
        CASE 
            WHEN checked_in_at IS NOT NULL AND checked_out_at IS NOT NULL 
            THEN EXTRACT(EPOCH FROM (checked_out_at - checked_in_at))::INTEGER / 60
            ELSE NULL 
        END
    ) STORED,
    check_in_latitude DOUBLE PRECISION,
    check_in_longitude DOUBLE PRECISION,
    check_out_latitude DOUBLE PRECISION,
    check_out_longitude DOUBLE PRECISION,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'checked_in', 'completed', 'skipped')),
    visit_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE public.place_visits ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY "place_visits_manager_admin_all" ON public.place_visits FOR ALL TO authenticated
USING (get_my_role() = ANY (ARRAY['admin', 'manager']))
WITH CHECK (get_my_role() = ANY (ARRAY['admin', 'manager']));

-- Agents can manage their own visits
CREATE POLICY "place_visits_agent_own" ON public.place_visits FOR ALL TO authenticated
USING (agent_id = auth.uid())
WITH CHECK (agent_id = auth.uid());

-- Performance indexes
CREATE INDEX idx_place_visits_route_assignment ON public.place_visits(route_assignment_id);
CREATE INDEX idx_place_visits_place_id ON public.place_visits(place_id);
CREATE INDEX idx_place_visits_agent_id ON public.place_visits(agent_id);
CREATE INDEX idx_place_visits_status ON public.place_visits(status);
CREATE INDEX idx_place_visits_check_in ON public.place_visits(checked_in_at);

-- Create a function to ensure only one active check-in per agent
CREATE OR REPLACE FUNCTION check_active_checkin()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'checked_in' THEN
        -- Check if agent already has an active check-in
        IF EXISTS (
            SELECT 1 FROM public.place_visits 
            WHERE agent_id = NEW.agent_id 
            AND status = 'checked_in'
            AND id != NEW.id
        ) THEN
            RAISE EXCEPTION 'Agent already has an active check-in at another place';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to enforce single active check-in
CREATE TRIGGER enforce_single_active_checkin
    BEFORE INSERT OR UPDATE ON public.place_visits
    FOR EACH ROW
    EXECUTE FUNCTION check_active_checkin();

-- Add comment for documentation
COMMENT ON TABLE public.place_visits IS 'Tracks actual agent visits to places with check-in/out times and locations';