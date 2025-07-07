-- Create ONLY the missing notifications table and setup
-- The functions already exist, so we skip those

-- Step 1: Create notifications table
CREATE TABLE public.notifications (
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
CREATE INDEX idx_notifications_recipient_id ON notifications(recipient_id);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX idx_notifications_unread ON notifications(recipient_id, read_at) WHERE read_at IS NULL;

-- Step 3: Enable Row Level Security
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Step 4: Create RLS policies
-- Users can only see their own notifications
CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
USING (auth.uid() = recipient_id);

-- Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
USING (auth.uid() = recipient_id);

-- Authenticated users can insert notifications (for system/admin use)
CREATE POLICY "Authenticated users can insert notifications"
ON notifications FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Step 5: Create updated_at trigger function (if it doesn't exist)
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 6: Create trigger for updated_at
CREATE TRIGGER notifications_updated_at
  BEFORE UPDATE ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION handle_updated_at();

-- Step 7: Verify the table was created
SELECT 'Table created successfully!' as status, COUNT(*) as column_count 
FROM information_schema.columns 
WHERE table_schema = 'public' AND table_name = 'notifications';

-- Step 8: Test by creating a notification for yourself
INSERT INTO notifications (
    recipient_id,
    type,
    title,
    message,
    data
) VALUES (
    auth.uid(),
    'system',
    'Welcome to Notifications!',
    'Your notification system is now set up and working.',
    '{"test": true}'::JSONB
);

-- Step 9: Verify the test notification was created
SELECT * FROM notifications WHERE recipient_id = auth.uid();