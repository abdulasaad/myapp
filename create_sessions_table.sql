-- Create sessions table for device session management
-- This prevents multiple simultaneous logins from different devices

-- ================================
-- Create sessions table
-- ================================

CREATE TABLE IF NOT EXISTS public.sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ================================
-- Create indexes for performance
-- ================================

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON public.sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_active ON public.sessions(is_active);
CREATE INDEX IF NOT EXISTS idx_sessions_user_active ON public.sessions(user_id, is_active);

-- ================================
-- Enable RLS (Row Level Security)
-- ================================

ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

-- ================================
-- Create RLS policies
-- ================================

-- Users can only see their own sessions
CREATE POLICY "Users can view their own sessions" ON public.sessions
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own sessions
CREATE POLICY "Users can insert their own sessions" ON public.sessions
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own sessions
CREATE POLICY "Users can update their own sessions" ON public.sessions
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own sessions
CREATE POLICY "Users can delete their own sessions" ON public.sessions
  FOR DELETE
  USING (auth.uid() = user_id);

-- ================================
-- Create function to auto-update updated_at
-- ================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- ================================
-- Create trigger for updated_at
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
    AND updated_at < NOW() - INTERVAL '30 days';
END;
$$ language 'plpgsql';

-- ================================
-- Verification
-- ================================

SELECT 'Sessions table created successfully!' as result;

-- Show table structure
\d public.sessions;

-- Show policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'sessions' AND schemaname = 'public';