-- Create earnings and payment system tables
-- Migration: 20250715_create_earnings_tables.sql

-- Create payments table to track all payments made to agents
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task_id UUID REFERENCES tasks(id) ON DELETE SET NULL,
    touring_task_id UUID REFERENCES touring_tasks(id) ON DELETE SET NULL,
    campaign_id UUID REFERENCES campaigns(id) ON DELETE SET NULL,
    amount INTEGER NOT NULL CHECK (amount > 0),
    payment_type TEXT NOT NULL CHECK (payment_type IN ('task_completion', 'campaign_daily', 'touring_task', 'bonus', 'manual')),
    payment_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paid_by_manager_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create campaign_agents table to track agent assignments to campaigns
CREATE TABLE IF NOT EXISTS campaign_agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    agent_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    assigned_by_manager_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(campaign_id, agent_id)
);

-- Create campaign_daily_participation table to track daily participation in campaigns
CREATE TABLE IF NOT EXISTS campaign_daily_participation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    agent_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    participation_date DATE NOT NULL,
    hours_worked DECIMAL(5,2) DEFAULT 0,
    tasks_completed INTEGER DEFAULT 0,
    touring_tasks_completed INTEGER DEFAULT 0,
    daily_points_earned INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(campaign_id, agent_id, participation_date)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_payments_agent_id ON payments(agent_id);
CREATE INDEX IF NOT EXISTS idx_payments_campaign_id ON payments(campaign_id);
CREATE INDEX IF NOT EXISTS idx_payments_payment_date ON payments(payment_date);
CREATE INDEX IF NOT EXISTS idx_campaign_agents_campaign_id ON campaign_agents(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_agents_agent_id ON campaign_agents(agent_id);
CREATE INDEX IF NOT EXISTS idx_campaign_daily_participation_campaign_agent ON campaign_daily_participation(campaign_id, agent_id);
CREATE INDEX IF NOT EXISTS idx_campaign_daily_participation_date ON campaign_daily_participation(participation_date);

-- Enable RLS on all tables
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaign_agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaign_daily_participation ENABLE ROW LEVEL SECURITY;

-- RLS Policies for payments table
CREATE POLICY "payments_select_policy" ON payments FOR SELECT USING (
    auth.uid() = agent_id OR 
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role IN ('admin', 'manager')
    )
);

CREATE POLICY "payments_insert_policy" ON payments FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role IN ('admin', 'manager')
    )
);

CREATE POLICY "payments_update_policy" ON payments FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role IN ('admin', 'manager')
    )
);

-- RLS Policies for campaign_agents table
CREATE POLICY "campaign_agents_select_policy" ON campaign_agents FOR SELECT USING (
    auth.uid() = agent_id OR 
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role IN ('admin', 'manager')
    )
);

CREATE POLICY "campaign_agents_insert_policy" ON campaign_agents FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role IN ('admin', 'manager')
    )
);

CREATE POLICY "campaign_agents_update_policy" ON campaign_agents FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role IN ('admin', 'manager')
    )
);

CREATE POLICY "campaign_agents_delete_policy" ON campaign_agents FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role IN ('admin', 'manager')
    )
);

-- RLS Policies for campaign_daily_participation table
CREATE POLICY "campaign_daily_participation_select_policy" ON campaign_daily_participation FOR SELECT USING (
    auth.uid() = agent_id OR 
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role IN ('admin', 'manager')
    )
);

CREATE POLICY "campaign_daily_participation_insert_policy" ON campaign_daily_participation FOR INSERT WITH CHECK (
    auth.uid() = agent_id OR 
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role IN ('admin', 'manager')
    )
);

CREATE POLICY "campaign_daily_participation_update_policy" ON campaign_daily_participation FOR UPDATE USING (
    auth.uid() = agent_id OR 
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role IN ('admin', 'manager')
    )
);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_campaign_daily_participation_updated_at BEFORE UPDATE ON campaign_daily_participation
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();