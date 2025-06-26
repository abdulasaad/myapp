-- Clean up test data and add proper sample groups
-- Run this in your Supabase SQL editor

-- Remove the test group with name "1"
DELETE FROM public.groups WHERE name = '1';

-- Add proper sample groups for testing
INSERT INTO public.groups (name, description) VALUES 
    ('Default Group', 'Default group for new users'),
    ('Sales Team', 'Sales and marketing agents'),
    ('Field Operations', 'Field operation agents'),
    ('Customer Support', 'Customer service representatives'),
    ('Management', 'Management and supervisory staff')
ON CONFLICT (name) DO NOTHING;

-- Update any users that might have been assigned to the deleted group
UPDATE public.profiles 
SET default_group_id = (SELECT id FROM public.groups WHERE name = 'Default Group' LIMIT 1)
WHERE default_group_id = 'c8e7add4-aad5-4fdc-9360-f7a69422722e';

-- Show current groups
SELECT id, name, description, manager_id, created_at FROM public.groups ORDER BY name;

-- Show current user count
SELECT 
    role,
    status,
    COUNT(*) as count
FROM public.profiles 
GROUP BY role, status
ORDER BY role, status;

SELECT 'Cleanup completed! You can now test the user management system.' as result;