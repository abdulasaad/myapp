-- Test notification creation with a real user ID
-- Using the first user from your list: aboodealtikrity1@gmail.com

-- 1. Create a test notification directly
INSERT INTO notifications (
    recipient_id,
    type,
    title,
    message,
    data
) VALUES (
    '80cb4bac-1ad2-4c35-8e09-c01ef275114e'::UUID,
    'test',
    'Test Notification',
    'This is a test notification to verify the system works',
    '{"test": true}'::JSONB
);

-- 2. Verify it was created
SELECT * FROM notifications ORDER BY created_at DESC;

-- 3. Test the create_notification function
SELECT create_notification(
    '80cb4bac-1ad2-4c35-8e09-c01ef275114e'::UUID,  -- recipient_id
    'campaign_assignment',                          -- type
    'Campaign Assignment Test',                     -- title
    'Testing function creation',                    -- message
    NULL,                                          -- sender_id (optional)
    '{"campaign_id": "test123"}'::JSONB           -- data
);

-- 4. Check all notifications again
SELECT 
    id,
    recipient_id,
    type,
    title,
    message,
    read_at,
    created_at
FROM notifications 
ORDER BY created_at DESC;