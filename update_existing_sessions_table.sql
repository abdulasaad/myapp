-- Update existing sessions table for device session management
-- Your table already exists, this script adds missing components

-- ================================
-- Add missing updated_at column if it doesn't exist
-- ================================

DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'sessions' 
                   AND column_name = 'updated_at') THEN
        ALTER TABLE public.sessions 
        ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        
        -- Set updated_at to created_at for existing records
        UPDATE public.sessions SET updated_at = created_at WHERE updated_at IS NULL;
    END IF;
END $$;

-- ================================
-- Create indexes for performance (if they don't exist)
-- ================================

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON public.sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_active ON public.sessions(is_active);
CREATE INDEX IF NOT EXISTS idx_sessions_user_active ON public.sessions(user_id, is_active);

-- ================================
-- Enable RLS (Row Level Security) if not already enabled
-- ================================

ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

-- ================================
-- Create RLS policies (drop existing ones first to avoid conflicts)
-- ================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own sessions" ON public.sessions;
DROP POLICY IF EXISTS "Users can insert their own sessions" ON public.sessions;
DROP POLICY IF EXISTS "Users can update their own sessions" ON public.sessions;
DROP POLICY IF EXISTS "Users can delete their own sessions" ON public.sessions;

-- Create new policies
CREATE POLICY "Users can view their own sessions" ON public.sessions
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own sessions" ON public.sessions
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own sessions" ON public.sessions
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own sessions" ON public.sessions
  FOR DELETE
  USING (auth.uid() = user_id);

-- ================================
-- Create function to auto-update updated_at (if not exists)
-- ================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- ================================
-- Create trigger for updated_at (drop existing first)
-- ================================

DROP TRIGGER IF EXISTS update_sessions_updated_at ON public.sessions;
CREATE TRIGGER update_sessions_updated_at
  BEFORE UPDATE ON public.sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ================================
-- Create function to cleanup old inactive sessions
-- ================================

CREATE OR REPLACE FUNCTION cleanup_old_sessions()
RETURNS void AS $$
BEGIN
  -- Delete inactive sessions older than 30 days
  DELETE FROM public.sessions 
  WHERE is_active = false 
    AND (updated_at < NOW() - INTERVAL '30 days' 
         OR (updated_at IS NULL AND created_at < NOW() - INTERVAL '30 days'));
END;
$$ language 'plpgsql';

-- ================================
-- Clean up any existing invalid sessions
-- ================================

-- Mark all existing sessions as inactive (force fresh login for all users)
UPDATE public.sessions SET is_active = false WHERE is_active = true;

-- ================================
-- Verification
-- ================================

SELECT 'Sessions table updated successfully!' as result;

-- Show current session count
SELECT 
    COUNT(*) as total_sessions,
    COUNT(*) FILTER (WHERE is_active = true) as active_sessions,
    COUNT(*) FILTER (WHERE is_active = false) as inactive_sessions
FROM public.sessions;

-- Show table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_schema = 'public' AND table_name = 'sessions'
ORDER BY ordinal_position;