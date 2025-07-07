-- Create the missing notification count function
-- Run this SQL in your Supabase SQL editor

CREATE OR REPLACE FUNCTION public.get_unread_notification_count(user_id UUID)
RETURNS INTEGER AS $$
BEGIN
  -- Count unread notifications for the user
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM notifications
    WHERE recipient_id = user_id
    AND read_at IS NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_unread_notification_count(UUID) TO authenticated;

-- Create notification function
CREATE OR REPLACE FUNCTION public.create_notification(
  p_recipient_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_message TEXT,
  p_sender_id UUID DEFAULT NULL,
  p_data JSONB DEFAULT '{}'::JSONB
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO notifications (
    recipient_id,
    sender_id,
    type,
    title,
    message,
    data,
    created_at,
    updated_at
  ) VALUES (
    p_recipient_id,
    p_sender_id,
    p_type,
    p_title,
    p_message,
    p_data,
    NOW(),
    NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, UUID, JSONB) TO authenticated;

-- Create mark notification as read function
CREATE OR REPLACE FUNCTION public.mark_notification_read(notification_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE notifications 
  SET read_at = NOW(), updated_at = NOW()
  WHERE id = notification_id 
  AND recipient_id = auth.uid();
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.mark_notification_read(UUID) TO authenticated;

-- Create mark all notifications as read function
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS INTEGER AS $$
DECLARE
  affected_count INTEGER;
BEGIN
  UPDATE notifications 
  SET read_at = NOW(), updated_at = NOW()
  WHERE recipient_id = auth.uid()
  AND read_at IS NULL;
  
  GET DIAGNOSTICS affected_count = ROW_COUNT;
  RETURN affected_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated;

-- Insert a test notification for the agent user
INSERT INTO notifications (
    recipient_id,
    title,
    message,
    type,
    created_at
) VALUES (
    '263e832c-f73c-48f3-bfd2-1b567cbff0b1',
    'Test Real-time Notification',
    'This is a test to verify the notification system is working automatically without user interaction.',
    'general',
    NOW()
);