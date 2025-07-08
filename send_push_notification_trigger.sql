-- Function to send push notification when a new notification is created
-- This is a placeholder that needs to be connected to your FCM backend

-- First, create a function that will be called when a notification is inserted
CREATE OR REPLACE FUNCTION send_push_notification_on_insert()
RETURNS TRIGGER AS $$
BEGIN
  -- Log that a push notification should be sent
  -- In production, this would call an edge function or external API
  RAISE NOTICE 'Push notification should be sent for notification ID: %, to user: %', 
    NEW.id, NEW.recipient_id;
  
  -- You can add logic here to:
  -- 1. Call a Supabase Edge Function
  -- 2. Insert into a queue table for processing
  -- 3. Call an external webhook
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to call the function on notification insert
DROP TRIGGER IF EXISTS send_push_on_notification_insert ON notifications;
CREATE TRIGGER send_push_on_notification_insert
  AFTER INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION send_push_notification_on_insert();

-- Alternative: Create a queue table for push notifications
CREATE TABLE IF NOT EXISTS push_notification_queue (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  notification_id UUID REFERENCES notifications(id),
  recipient_id UUID REFERENCES auth.users(id),
  fcm_token TEXT,
  title TEXT,
  message TEXT,
  data JSONB,
  status TEXT DEFAULT 'pending', -- pending, sent, failed
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  sent_at TIMESTAMP WITH TIME ZONE,
  error TEXT
);

-- Function to queue push notification
CREATE OR REPLACE FUNCTION queue_push_notification()
RETURNS TRIGGER AS $$
DECLARE
  recipient_fcm_token TEXT;
BEGIN
  -- Get recipient's FCM token
  SELECT fcm_token INTO recipient_fcm_token
  FROM profiles
  WHERE id = NEW.recipient_id;
  
  -- Only queue if FCM token exists
  IF recipient_fcm_token IS NOT NULL THEN
    INSERT INTO push_notification_queue (
      notification_id,
      recipient_id,
      fcm_token,
      title,
      message,
      data
    ) VALUES (
      NEW.id,
      NEW.recipient_id,
      recipient_fcm_token,
      NEW.title,
      NEW.message,
      NEW.data
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Replace the previous trigger with this one
DROP TRIGGER IF EXISTS send_push_on_notification_insert ON notifications;
CREATE TRIGGER queue_push_on_notification_insert
  AFTER INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION queue_push_notification();