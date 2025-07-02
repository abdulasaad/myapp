-- Step 2: Create routes table for route visit system
-- This table stores route definitions that contain multiple places to visit

CREATE TABLE public.routes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    created_by UUID REFERENCES public.profiles(id) NOT NULL,
    assigned_manager_id UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    start_date DATE,
    end_date DATE,
    status TEXT DEFAULT 'active' CHECK (status IN ('draft', 'active', 'completed', 'archived')),
    estimated_duration_hours INTEGER,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Enable RLS
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;

-- RLS policies for routes
CREATE POLICY "routes_manager_admin_all" ON public.routes FOR ALL TO authenticated
USING (get_my_role() = ANY (ARRAY['admin', 'manager']))
WITH CHECK (get_my_role() = ANY (ARRAY['admin', 'manager']));

-- Agents can read routes that are assigned to them (will be determined via route_assignments table)
CREATE POLICY "routes_agent_read" ON public.routes FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.route_assignments ra 
        WHERE ra.route_id = routes.id AND ra.agent_id = auth.uid()
    ) OR 
    get_my_role() = ANY (ARRAY['admin', 'manager'])
);

-- Performance indexes
CREATE INDEX idx_routes_created_by ON public.routes(created_by);
CREATE INDEX idx_routes_assigned_manager ON public.routes(assigned_manager_id);
CREATE INDEX idx_routes_status ON public.routes(status);
CREATE INDEX idx_routes_dates ON public.routes(start_date, end_date);

-- Add comment for documentation
COMMENT ON TABLE public.routes IS 'Stores route definitions containing multiple places for agent visits';