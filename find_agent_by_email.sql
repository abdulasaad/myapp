SELECT 
    id as agent_id,
    full_name,
    email,
    role
FROM profiles 
WHERE email = 'user.agent2@test.com';