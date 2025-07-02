-- Step 6: Extend geofences table to support places
-- This allows places to have geofence boundaries for check-in/out enforcement

-- Add place_id column to existing geofences table
ALTER TABLE public.geofences 
ADD COLUMN place_id UUID REFERENCES public.places(id) ON DELETE CASCADE;

-- Create index for place_id
CREATE INDEX idx_geofences_place_id ON public.geofences(place_id);

-- Update the existing constraint to ensure only one parent (campaign, task, or place)
-- First, drop any existing constraint if it exists
ALTER TABLE public.geofences 
DROP CONSTRAINT IF EXISTS geofences_parent_check;

-- Add new constraint that includes place_id
ALTER TABLE public.geofences 
ADD CONSTRAINT geofences_parent_check 
CHECK (
    (campaign_id IS NOT NULL AND task_id IS NULL AND place_id IS NULL) OR
    (campaign_id IS NULL AND task_id IS NOT NULL AND place_id IS NULL) OR
    (campaign_id IS NULL AND task_id IS NULL AND place_id IS NOT NULL)
);

-- Update RLS policies to include place geofences
-- Agents can read geofences for places they're visiting
DROP POLICY IF EXISTS "Geofences: Consolidated SELECT for authenticated" ON public.geofences;

CREATE POLICY "Geofences: Consolidated SELECT for authenticated" ON public.geofences
FOR SELECT TO authenticated
USING (
    -- Existing campaign access
    ((campaign_id IS NOT NULL) AND (EXISTS ( 
        SELECT 1 FROM campaign_agents ca 
        WHERE ca.campaign_id = geofences.campaign_id 
        AND ca.agent_id = auth.uid()
    ))) OR 
    -- Existing task access
    ((task_id IS NOT NULL) AND (EXISTS ( 
        SELECT 1 FROM task_assignments ta 
        WHERE ta.task_id = geofences.task_id 
        AND ta.agent_id = auth.uid()
    ))) OR 
    -- Existing task creator access
    ((task_id IS NOT NULL) AND (EXISTS ( 
        SELECT 1 FROM tasks t 
        WHERE t.id = geofences.task_id 
        AND t.created_by = auth.uid()
    ))) OR
    -- New: Place access for assigned routes
    ((place_id IS NOT NULL) AND (EXISTS (
        SELECT 1 FROM route_assignments ra
        JOIN route_places rp ON rp.route_id = ra.route_id
        WHERE rp.place_id = geofences.place_id
        AND ra.agent_id = auth.uid()
        AND ra.status != 'cancelled'
    ))) OR
    -- Managers and admins can see all
    (get_my_role() = ANY (ARRAY['admin', 'manager']))
);

-- Add comment for documentation
COMMENT ON COLUMN public.geofences.place_id IS 'Reference to place for place-specific geofences';