-- Step 1: Create places table for route visit system
-- This table stores location definitions that can be visited by agents

CREATE TABLE public.places (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    address TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    created_by UUID REFERENCES public.profiles(id) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'pending_approval')),
    approval_status TEXT DEFAULT 'approved' CHECK (approval_status IN ('pending', 'approved', 'rejected')),
    approved_by UUID REFERENCES public.profiles(id),
    approved_at TIMESTAMPTZ,
    rejection_reason TEXT,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Enable RLS
ALTER TABLE public.places ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies
CREATE POLICY "places_manager_admin_all" ON public.places FOR ALL TO authenticated
USING (get_my_role() = ANY (ARRAY['admin', 'manager']))
WITH CHECK (get_my_role() = ANY (ARRAY['admin', 'manager']));

CREATE POLICY "places_agent_read" ON public.places FOR SELECT TO authenticated
USING (
    (approval_status = 'approved' AND status = 'active') OR
    (created_by = auth.uid())
);

CREATE POLICY "places_agent_insert" ON public.places FOR INSERT TO authenticated
WITH CHECK (
    get_my_role() = 'agent' AND 
    created_by = auth.uid() AND 
    approval_status = 'pending'
);

-- Performance indexes
CREATE INDEX idx_places_location ON public.places(latitude, longitude);
CREATE INDEX idx_places_created_by ON public.places(created_by);
CREATE INDEX idx_places_status ON public.places(status, approval_status);

-- Add comment for documentation
COMMENT ON TABLE public.places IS 'Stores place definitions for route visit system with approval workflow';