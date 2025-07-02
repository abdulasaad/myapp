-- Step 4: Create route_assignments table and update agent policies
-- This table assigns routes to agents for execution

CREATE TABLE public.route_assignments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    route_id UUID REFERENCES public.routes(id) ON DELETE CASCADE NOT NULL,
    agent_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    assigned_by UUID REFERENCES public.profiles(id) NOT NULL,
    assigned_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    status TEXT DEFAULT 'assigned' CHECK (status IN ('assigned', 'in_progress', 'completed', 'cancelled')),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    notes TEXT,
    UNIQUE(route_id, agent_id)
);

-- Enable RLS
ALTER TABLE public.route_assignments ENABLE ROW LEVEL SECURITY;

-- RLS policies for route_assignments
CREATE POLICY "route_assignments_manager_admin_all" ON public.route_assignments FOR ALL TO authenticated
USING (get_my_role() = ANY (ARRAY['admin', 'manager']))
WITH CHECK (get_my_role() = ANY (ARRAY['admin', 'manager']));

CREATE POLICY "route_assignments_agent_own" ON public.route_assignments FOR ALL TO authenticated
USING (agent_id = auth.uid())
WITH CHECK (agent_id = auth.uid());

-- Performance indexes
CREATE INDEX idx_route_assignments_route_id ON public.route_assignments(route_id);
CREATE INDEX idx_route_assignments_agent_id ON public.route_assignments(agent_id);
CREATE INDEX idx_route_assignments_status ON public.route_assignments(status);
CREATE INDEX idx_route_assignments_agent_status ON public.route_assignments(agent_id, status);

-- Now update the temporary policies we created earlier
-- Drop and recreate the routes agent read policy
DROP POLICY IF EXISTS "routes_agent_read_temp" ON public.routes;

CREATE POLICY "routes_agent_read" ON public.routes FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.route_assignments ra 
        WHERE ra.route_id = routes.id 
        AND ra.agent_id = auth.uid()
        AND ra.status != 'cancelled'
    ) OR 
    get_my_role() = ANY (ARRAY['admin', 'manager'])
);

-- Drop and recreate the route_places agent read policy
DROP POLICY IF EXISTS "route_places_agent_read_temp" ON public.route_places;

CREATE POLICY "route_places_agent_read" ON public.route_places FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.route_assignments ra 
        WHERE ra.route_id = route_places.route_id 
        AND ra.agent_id = auth.uid()
        AND ra.status != 'cancelled'
    ) OR 
    get_my_role() = ANY (ARRAY['admin', 'manager'])
);

-- Add comment for documentation
COMMENT ON TABLE public.route_assignments IS 'Assigns routes to agents with tracking of execution status';