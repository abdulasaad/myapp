-- Create groups table
CREATE TABLE public.groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE, -- Group names should be unique
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- User who created the group (admin)
    manager_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL UNIQUE -- Optional: A group can have one manager
);

COMMENT ON TABLE public.groups IS 'Stores information about user groups.';
COMMENT ON COLUMN public.groups.name IS 'Unique name for the group.';
COMMENT ON COLUMN public.groups.created_by IS 'The admin user who created the group.';
COMMENT ON COLUMN public.groups.manager_id IS 'The manager assigned to this group. A manager can only be assigned to one group via this field, and a group can only have one manager directly assigned this way.';

-- Create user_groups junction table
CREATE TABLE public.user_groups (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    PRIMARY KEY (user_id, group_id)
);

COMMENT ON TABLE public.user_groups IS 'Junction table to link users to groups (many-to-many).';

-- Add default_group_id to profiles table for managers
ALTER TABLE public.profiles
ADD COLUMN default_group_id UUID REFERENCES public.groups(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.profiles.default_group_id IS 'For managers, this is the group to which their newly created agents will be automatically assigned. Also used to identify the group a manager is primarily associated with.';

-- Enable RLS for the new tables
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_groups ENABLE ROW LEVEL SECURITY;

-- RLS Policies for groups table
CREATE POLICY "Admins can manage groups"
ON public.groups
FOR ALL
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
)
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);

CREATE POLICY "Authenticated users can view groups"
ON public.groups
FOR SELECT
TO authenticated
USING (true); -- Or more specific: managers can see their group, users can see groups they are in. For now, all can see.

-- RLS Policies for user_groups table
CREATE POLICY "Admins can manage user-group assignments"
ON public.user_groups
FOR ALL
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
)
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);

CREATE POLICY "Users can view their own group assignments"
ON public.user_groups
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Managers can view users in their default group"
ON public.user_groups
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = auth.uid()
        AND p.role = 'manager'
        AND p.default_group_id = public.user_groups.group_id
    )
);

-- Seed a default "Unassigned" group if it doesn't exist
-- This can be useful for users not yet in a specific group.
-- INSERT INTO public.groups (id, name, description)
-- VALUES ('00000000-0000-0000-0000-000000000000', 'Unassigned', 'Default group for users not yet assigned to a specific group')
-- ON CONFLICT (id) DO NOTHING;

-- Note: Consider adding indexes for foreign keys if not automatically created, e.g.,
-- CREATE INDEX idx_groups_manager_id ON public.groups(manager_id);
-- CREATE INDEX idx_user_groups_user_id ON public.user_groups(user_id);
-- CREATE INDEX idx_user_groups_group_id ON public.user_groups(group_id);
-- CREATE INDEX idx_profiles_default_group_id ON public.profiles(default_group_id);
