-- Add Arabic language support to notifications table
-- Add columns for Arabic title and message

ALTER TABLE notifications 
ADD COLUMN title_ar VARCHAR(255),
ADD COLUMN message_ar TEXT;

-- Update existing notifications to have Arabic versions
-- For now, we'll keep the English versions and add Arabic translations later
UPDATE notifications SET 
  title_ar = title,
  message_ar = message
WHERE title_ar IS NULL OR message_ar IS NULL;

-- Create or replace the create_notification function to support Arabic
CREATE OR REPLACE FUNCTION create_notification(
  p_recipient_id UUID,
  p_type VARCHAR(50),
  p_title VARCHAR(255),
  p_message TEXT,
  p_title_ar VARCHAR(255) DEFAULT NULL,
  p_message_ar TEXT DEFAULT NULL,
  p_sender_id UUID DEFAULT NULL,
  p_data JSONB DEFAULT '{}'
) RETURNS UUID AS $$
DECLARE
  notification_id UUID;
BEGIN
  INSERT INTO notifications (
    recipient_id,
    sender_id,
    type,
    title,
    message,
    title_ar,
    message_ar,
    data
  ) VALUES (
    p_recipient_id,
    p_sender_id,
    p_type,
    p_title,
    p_message,
    COALESCE(p_title_ar, p_title), -- Use Arabic if provided, fallback to English
    COALESCE(p_message_ar, p_message), -- Use Arabic if provided, fallback to English
    p_data
  ) RETURNING id INTO notification_id;
  
  RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the automated notification triggers to include Arabic text
-- We'll need to update these with proper translations

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION create_notification TO authenticated;

-- Add comment explaining the changes
COMMENT ON COLUMN notifications.title_ar IS 'Arabic version of notification title';
COMMENT ON COLUMN notifications.message_ar IS 'Arabic version of notification message';
COMMENT ON FUNCTION create_notification IS 'Creates notifications with support for both English and Arabic languages';