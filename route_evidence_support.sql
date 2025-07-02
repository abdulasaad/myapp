-- Add route evidence support to the evidence table
-- This allows evidence to be linked to place visits and route assignments

-- First check if the columns already exist
DO $$
BEGIN
    -- Add place_visit_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'evidence' 
        AND column_name = 'place_visit_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.evidence 
        ADD COLUMN place_visit_id UUID REFERENCES public.place_visits(id) ON DELETE CASCADE;
        
        COMMENT ON COLUMN public.evidence.place_visit_id IS 'Links evidence to a specific place visit (for route evidence)';
    END IF;
    
    -- Add route_assignment_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'evidence' 
        AND column_name = 'route_assignment_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.evidence 
        ADD COLUMN route_assignment_id UUID REFERENCES public.route_assignments(id) ON DELETE CASCADE;
        
        COMMENT ON COLUMN public.evidence.route_assignment_id IS 'Links evidence to a route assignment (for route evidence)';
    END IF;

    -- Make task_assignment_id nullable if it isn't already
    -- This allows evidence to be either task-based OR route-based
    ALTER TABLE public.evidence 
    ALTER COLUMN task_assignment_id DROP NOT NULL;

END $$;

-- Update RLS policies for route evidence
-- Agents can view their own route evidence
DROP POLICY IF EXISTS "agents_route_evidence_select" ON public.evidence;
CREATE POLICY "agents_route_evidence_select" ON public.evidence
    FOR SELECT 
    USING (
        auth.uid() = uploader_id 
        OR (
            -- Allow access if this is route evidence and user is the agent
            route_assignment_id IS NOT NULL 
            AND EXISTS (
                SELECT 1 FROM public.route_assignments ra
                WHERE ra.id = route_assignment_id
                AND ra.agent_id = auth.uid()
            )
        )
    );

-- Agents can insert their own route evidence
DROP POLICY IF EXISTS "agents_route_evidence_insert" ON public.evidence;
CREATE POLICY "agents_route_evidence_insert" ON public.evidence
    FOR INSERT 
    WITH CHECK (
        auth.uid() = uploader_id
        AND (
            -- Either task evidence (existing logic)
            task_assignment_id IS NOT NULL
            OR 
            -- Or route evidence with valid route assignment
            (
                route_assignment_id IS NOT NULL 
                AND EXISTS (
                    SELECT 1 FROM public.route_assignments ra
                    WHERE ra.id = route_assignment_id
                    AND ra.agent_id = auth.uid()
                    AND ra.status IN ('assigned', 'in_progress')
                )
            )
        )
    );

-- Managers can view evidence from their groups (route evidence)
DROP POLICY IF EXISTS "managers_route_evidence_select" ON public.evidence;
CREATE POLICY "managers_route_evidence_select" ON public.evidence
    FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
            AND p.role IN ('manager', 'admin')
            AND (
                -- Task evidence (existing logic)
                (
                    task_assignment_id IS NOT NULL 
                    AND EXISTS (
                        SELECT 1 FROM public.task_assignments ta
                        JOIN public.user_groups ug ON ta.agent_id = ug.user_id
                        JOIN public.user_groups mg ON ug.group_id = mg.group_id
                        WHERE ta.id = task_assignment_id
                        AND mg.user_id = auth.uid()
                    )
                )
                OR
                -- Route evidence
                (
                    route_assignment_id IS NOT NULL 
                    AND EXISTS (
                        SELECT 1 FROM public.route_assignments ra
                        JOIN public.user_groups ug ON ra.agent_id = ug.user_id
                        JOIN public.user_groups mg ON ug.group_id = mg.group_id
                        WHERE ra.id = route_assignment_id
                        AND mg.user_id = auth.uid()
                    )
                )
            )
        )
    );

-- Managers can update evidence status (approve/reject) for route evidence
DROP POLICY IF EXISTS "managers_route_evidence_update" ON public.evidence;
CREATE POLICY "managers_route_evidence_update" ON public.evidence
    FOR UPDATE 
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
            AND p.role IN ('manager', 'admin')
            AND (
                -- Task evidence (existing logic)
                (
                    task_assignment_id IS NOT NULL 
                    AND EXISTS (
                        SELECT 1 FROM public.task_assignments ta
                        JOIN public.user_groups ug ON ta.agent_id = ug.user_id
                        JOIN public.user_groups mg ON ug.group_id = mg.group_id
                        WHERE ta.id = task_assignment_id
                        AND mg.user_id = auth.uid()
                    )
                )
                OR
                -- Route evidence
                (
                    route_assignment_id IS NOT NULL 
                    AND EXISTS (
                        SELECT 1 FROM public.route_assignments ra
                        JOIN public.user_groups ug ON ra.agent_id = ug.user_id
                        JOIN public.user_groups mg ON ug.group_id = mg.group_id
                        WHERE ra.id = route_assignment_id
                        AND mg.user_id = auth.uid()
                    )
                )
            )
        )
    );

-- Create function to get evidence count for a place visit
CREATE OR REPLACE FUNCTION get_place_visit_evidence_count(visit_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM public.evidence
        WHERE place_visit_id = visit_id
        AND status = 'approved'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if place visit has required evidence
CREATE OR REPLACE FUNCTION check_place_visit_evidence_complete(visit_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    required_count INTEGER;
    actual_count INTEGER;
BEGIN
    -- Get required evidence count from route_places
    SELECT rp.required_evidence_count INTO required_count
    FROM public.place_visits pv
    JOIN public.route_places rp ON pv.place_id = rp.place_id
    JOIN public.route_assignments ra ON pv.route_assignment_id = ra.id
    WHERE pv.id = visit_id
    AND rp.route_id = ra.route_id;
    
    -- Get actual approved evidence count
    SELECT COUNT(*) INTO actual_count
    FROM public.evidence
    WHERE place_visit_id = visit_id
    AND status = 'approved';
    
    RETURN COALESCE(actual_count, 0) >= COALESCE(required_count, 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_place_visit_evidence_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_place_visit_evidence_complete(UUID) TO authenticated;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_evidence_place_visit_id ON public.evidence(place_visit_id);
CREATE INDEX IF NOT EXISTS idx_evidence_route_assignment_id ON public.evidence(route_assignment_id);

-- Update the evidence table comment
COMMENT ON TABLE public.evidence IS 'Stores evidence files uploaded by agents. Can be linked to either tasks (task_assignment_id) or route visits (place_visit_id + route_assignment_id).';

COMMIT;