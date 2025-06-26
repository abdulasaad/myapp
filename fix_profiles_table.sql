-- Fix profiles table by adding missing columns for user management
-- Run this SQL in your Supabase SQL editor

-- Check if default_group_id column exists, if not add it
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='profiles' AND column_name='default_group_id') THEN
        ALTER TABLE public.profiles 
        ADD COLUMN default_group_id UUID REFERENCES public.groups(id) ON DELETE SET NULL;
        
        COMMENT ON COLUMN public.profiles.default_group_id IS 'For managers, this is the group to which their newly created agents will be automatically assigned.';
    END IF;
END $$;

-- Check if email column exists, if not add it
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='profiles' AND column_name='email') THEN
        ALTER TABLE public.profiles 
        ADD COLUMN email TEXT;
    END IF;
END $$;

-- Check if created_by column exists, if not add it
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='profiles' AND column_name='created_by') THEN
        ALTER TABLE public.profiles 
        ADD COLUMN created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Check if updated_at column exists, if not add it
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='profiles' AND column_name='updated_at') THEN
        ALTER TABLE public.profiles 
        ADD COLUMN updated_at TIMESTAMPTZ;
    END IF;
END $$;

-- Ensure groups table exists
CREATE TABLE IF NOT EXISTS public.groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    manager_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL UNIQUE
);

-- Ensure user_groups table exists  
CREATE TABLE IF NOT EXISTS public.user_groups (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    PRIMARY KEY (user_id, group_id)
);

-- Enable RLS on tables
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_groups ENABLE ROW LEVEL SECURITY;

-- Create RLS policies if they don't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'groups' AND policyname = 'Admins can manage groups') THEN
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
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'groups' AND policyname = 'Authenticated users can view groups') THEN
        CREATE POLICY "Authenticated users can view groups"
        ON public.groups
        FOR SELECT
        TO authenticated
        USING (true);
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_groups' AND policyname = 'Admins can manage user-group assignments') THEN
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
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_groups' AND policyname = 'Users can view their own group assignments') THEN
        CREATE POLICY "Users can view their own group assignments"
        ON public.user_groups
        FOR SELECT
        TO authenticated
        USING (auth.uid() = user_id);
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_groups' AND policyname = 'Managers can view users in their default group') THEN
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
    END IF;
END $$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_groups_manager_id ON public.groups(manager_id);
CREATE INDEX IF NOT EXISTS idx_user_groups_user_id ON public.user_groups(user_id);
CREATE INDEX IF NOT EXISTS idx_user_groups_group_id ON public.user_groups(group_id);
CREATE INDEX IF NOT EXISTS idx_profiles_default_group_id ON public.profiles(default_group_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_status ON public.profiles(status);

-- Add some sample groups for testing (optional)
INSERT INTO public.groups (name, description)
VALUES 
    ('Default Group', 'Default group for new users'),
    ('Sales Team', 'Sales and marketing agents'),
    ('Field Operations', 'Field operation agents')
ON CONFLICT (name) DO NOTHING;

SELECT 'Database schema updated successfully for user management!' as result;