-- Debug FCM Token Status
-- Run this query in Supabase SQL editor to check FCM token status

-- Check all users and their FCM token status
SELECT 
    id,
    full_name,
    email,
    role,
    CASE 
        WHEN fcm_token IS NULL THEN 'NO_TOKEN'
        WHEN fcm_token = '' THEN 'EMPTY_TOKEN'
        WHEN LENGTH(fcm_token) < 100 THEN 'INVALID_TOKEN'
        ELSE 'VALID_TOKEN'
    END as token_status,
    CASE 
        WHEN fcm_token IS NOT NULL THEN LENGTH(fcm_token)
        ELSE 0
    END as token_length,
    CASE 
        WHEN fcm_token IS NOT NULL THEN LEFT(fcm_token, 20) || '...'
        ELSE 'No token'
    END as token_preview,
    created_at,
    updated_at
FROM profiles
ORDER BY 
    CASE 
        WHEN fcm_token IS NULL THEN 3
        WHEN fcm_token = '' THEN 2
        WHEN LENGTH(fcm_token) < 100 THEN 1
        ELSE 0
    END,
    full_name;

-- Summary of FCM token status
SELECT 
    CASE 
        WHEN fcm_token IS NULL THEN 'NO_TOKEN'
        WHEN fcm_token = '' THEN 'EMPTY_TOKEN'
        WHEN LENGTH(fcm_token) < 100 THEN 'INVALID_TOKEN'
        ELSE 'VALID_TOKEN'
    END as token_status,
    COUNT(*) as user_count
FROM profiles
GROUP BY 
    CASE 
        WHEN fcm_token IS NULL THEN 'NO_TOKEN'
        WHEN fcm_token = '' THEN 'EMPTY_TOKEN'
        WHEN LENGTH(fcm_token) < 100 THEN 'INVALID_TOKEN'
        ELSE 'VALID_TOKEN'
    END
ORDER BY user_count DESC;

-- Check if any users have duplicate FCM tokens (problematic)
SELECT 
    fcm_token,
    COUNT(*) as users_with_same_token,
    ARRAY_AGG(email) as emails
FROM profiles 
WHERE fcm_token IS NOT NULL AND fcm_token != ''
GROUP BY fcm_token
HAVING COUNT(*) > 1;

-- Check recent notifications and their delivery status
SELECT 
    n.id,
    n.title,
    n.message,
    n.type,
    n.created_at,
    p.email as recipient_email,
    p.full_name as recipient_name,
    CASE 
        WHEN p.fcm_token IS NULL THEN 'NO_TOKEN'
        WHEN p.fcm_token = '' THEN 'EMPTY_TOKEN'
        WHEN LENGTH(p.fcm_token) < 100 THEN 'INVALID_TOKEN'
        ELSE 'VALID_TOKEN'
    END as recipient_token_status,
    n.read_at
FROM notifications n
JOIN profiles p ON n.recipient_id = p.id
WHERE n.created_at > NOW() - INTERVAL '24 hours'
ORDER BY n.created_at DESC
LIMIT 20;