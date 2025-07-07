-- Complete Notification System Setup for Supabase
-- Run this entire file in your Supabase SQL editor

-- Step 1: Create notifications table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    recipient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    data JSONB DEFAULT '{}'::JSONB,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 2: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_id ON notifications(recipient_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(recipient_id, read_at) WHERE read_at IS NULL;

-- Step 3: Enable Row Level Security
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Step 4: Create RLS policies
-- Users can only see their own notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
USING (auth.uid() = recipient_id);

-- Users can update their own notifications (mark as read)
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
USING (auth.uid() = recipient_id);

-- Authenticated users can insert notifications (for system/admin use)
DROP POLICY IF EXISTS "Authenticated users can insert notifications" ON notifications;
CREATE POLICY "Authenticated users can insert notifications"
ON notifications FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Step 5: Create notification count function
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_unread_notification_count(UUID) TO authenticated;

-- Step 6: Create notification function
CREATE OR REPLACE FUNCTION public.create_notification(
  p_recipient_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_message TEXT,
  p_sender_id UUID DEFAULT NULL,
  p_data JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID AS $$
DECLARE
  notification_id UUID;
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
  ) RETURNING id INTO notification_id;
  
  RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, UUID, JSONB) TO authenticated;

-- Step 7: Create mark notification as read function
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.mark_notification_read(UUID) TO authenticated;

-- Step 8: Create mark all notifications as read function
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated;

-- Step 9: Create updated_at trigger function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 10: Create trigger for updated_at
DROP TRIGGER IF EXISTS notifications_updated_at ON notifications;
CREATE TRIGGER notifications_updated_at
  BEFORE UPDATE ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION handle_updated_at();

-- Step 11: Test notification creation (remove this after testing)
-- This will create a test notification for the current user
-- Uncomment the lines below to test:

-- INSERT INTO notifications (
--   recipient_id,
--   type,
--   title,
--   message,
--   data
-- ) VALUES (
--   auth.uid(),
--   'test',
--   'Test Notification',
--   'This is a test notification to verify the system is working',
--   '{"test": true}'::JSONB
-- );

-- Verification queries (you can run these to check the setup):
-- SELECT COUNT(*) as notification_count FROM notifications;
-- SELECT * FROM notifications WHERE recipient_id = auth.uid() ORDER BY created_at DESC LIMIT 5;