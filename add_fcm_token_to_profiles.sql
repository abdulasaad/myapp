-- Add FCM token column to profiles table for push notifications

-- 1. Add fcm_token column to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 2. Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token 
ON profiles(fcm_token) 
WHERE fcm_token IS NOT NULL;

-- 3. Verify the column was added
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'profiles'
AND column_name = 'fcm_token';