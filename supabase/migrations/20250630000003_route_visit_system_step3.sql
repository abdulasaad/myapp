-- Step 3: Create route_places junction table
-- This table links routes to places with ordering and visit instructions

CREATE TABLE public.route_places (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    route_id UUID REFERENCES public.routes(id) ON DELETE CASCADE NOT NULL,
    place_id UUID REFERENCES public.places(id) ON DELETE CASCADE NOT NULL,
    visit_order INTEGER NOT NULL,
    estimated_duration_minutes INTEGER DEFAULT 30,
    required_evidence_count INTEGER DEFAULT 1,
    instructions TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE(route_id, place_id),
    UNIQUE(route_id, visit_order)
);

-- Enable RLS
ALTER TABLE public.route_places ENABLE ROW LEVEL SECURITY;

-- RLS policies - inherit permissions from routes table
CREATE POLICY "route_places_manager_admin_all" ON public.route_places FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.routes r 
        WHERE r.id = route_places.route_id 
        AND get_my_role() = ANY (ARRAY['admin', 'manager'])
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.routes r 
        WHERE r.id = route_places.route_id 
        AND get_my_role() = ANY (ARRAY['admin', 'manager'])
    )
);

-- Agents can read route places for their assigned routes (will be enabled after route_assignments)
CREATE POLICY "route_places_agent_read_temp" ON public.route_places FOR SELECT TO authenticated
USING (false); -- Temporary: will be updated after creating route_assignments

-- Performance indexes
CREATE INDEX idx_route_places_route_id ON public.route_places(route_id);
CREATE INDEX idx_route_places_place_id ON public.route_places(place_id);
CREATE INDEX idx_route_places_route_order ON public.route_places(route_id, visit_order);

-- Add comment for documentation
COMMENT ON TABLE public.route_places IS 'Junction table linking routes to places with visit order and instructions';