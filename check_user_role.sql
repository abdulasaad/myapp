-- Check your current user role
-- Run this in Supabase SQL Editor

-- First, find your user ID by email
SELECT id, email, role 
FROM profiles 
WHERE email = 'your-email@example.com';

-- If your role is not 'admin', update it:
-- UPDATE profiles SET role = 'admin' WHERE email = 'your-email@example.com';