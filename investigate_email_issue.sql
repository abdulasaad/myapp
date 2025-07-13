-- Investigate why email is not showing in team members screen

-- 1. First, check what columns exist in the profiles table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
ORDER BY ordinal_position;

-- 2. Check if profiles table has email data
SELECT id, full_name, username, email, role 
FROM profiles 
WHERE role = 'agent' 
LIMIT 5;

-- 3. Test the current get_agents_in_manager_groups function
-- Replace with actual manager ID (Mostafa's ID)
SELECT * 
FROM get_agents_in_manager_groups('38e6aae3-efab-4668-b1f1-adbc1b513800')
LIMIT 5;

-- 4. Check if the auth.users table has email data
SELECT id, email 
FROM auth.users 
WHERE id IN (
  SELECT id FROM profiles WHERE role = 'agent' LIMIT 5
);

-- 5. If email is in auth.users but not profiles, we need to check the relationship
SELECT 
  p.id,
  p.full_name,
  p.username,
  p.email as profile_email,
  u.email as auth_email
FROM profiles p
LEFT JOIN auth.users u ON p.id = u.id
WHERE p.role = 'agent'
LIMIT 5;

-- 6. Check the function definition to see what it's actually returning
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'get_agents_in_manager_groups';