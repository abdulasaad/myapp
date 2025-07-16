# Earnings System Database Migration

Copy and paste the following SQL code into your Supabase SQL Editor to create the earnings management system:

```sql
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

CREATE TABLE IF NOT EXISTS campaign_agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    agent_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    assigned_by_manager_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(campaign_id, agent_id)
);

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

CREATE INDEX IF NOT EXISTS idx_payments_agent_id ON payments(agent_id);
CREATE INDEX IF NOT EXISTS idx_payments_campaign_id ON payments(campaign_id);
CREATE INDEX IF NOT EXISTS idx_payments_payment_date ON payments(payment_date);
CREATE INDEX IF NOT EXISTS idx_campaign_agents_campaign_id ON campaign_agents(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_agents_agent_id ON campaign_agents(agent_id);
CREATE INDEX IF NOT EXISTS idx_campaign_daily_participation_campaign_agent ON campaign_daily_participation(campaign_id, agent_id);
CREATE INDEX IF NOT EXISTS idx_campaign_daily_participation_date ON campaign_daily_participation(participation_date);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaign_agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaign_daily_participation ENABLE ROW LEVEL SECURITY;

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

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_campaign_daily_participation_updated_at BEFORE UPDATE ON campaign_daily_participation
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE FUNCTION get_agent_earnings_for_campaign(
    p_agent_id UUID,
    p_campaign_id UUID
) RETURNS JSON AS $$
DECLARE
    total_earned INTEGER := 0;
    total_paid INTEGER := 0;
    outstanding_balance INTEGER := 0;
    task_points INTEGER := 0;
    touring_task_points INTEGER := 0;
    daily_participation_points INTEGER := 0;
BEGIN
    SELECT COALESCE(SUM(t.points), 0) INTO task_points
    FROM task_assignments ta
    JOIN tasks t ON ta.task_id = t.id
    WHERE ta.agent_id = p_agent_id
    AND t.campaign_id = p_campaign_id
    AND ta.status = 'completed';
    
    SELECT COALESCE(SUM(tt.points), 0) INTO touring_task_points
    FROM touring_task_assignments tta
    JOIN touring_tasks tt ON tta.touring_task_id = tt.id
    WHERE tta.agent_id = p_agent_id
    AND tt.campaign_id = p_campaign_id
    AND tta.status = 'completed';
    
    SELECT COALESCE(SUM(daily_points_earned), 0) INTO daily_participation_points
    FROM campaign_daily_participation
    WHERE agent_id = p_agent_id
    AND campaign_id = p_campaign_id;
    
    total_earned := task_points + touring_task_points + daily_participation_points;
    
    SELECT COALESCE(SUM(amount), 0) INTO total_paid
    FROM payments
    WHERE agent_id = p_agent_id
    AND campaign_id = p_campaign_id;
    
    outstanding_balance := total_earned - total_paid;
    
    RETURN json_build_object(
        'total_earned', total_earned,
        'total_paid', total_paid,
        'outstanding_balance', outstanding_balance,
        'task_points', task_points,
        'touring_task_points', touring_task_points,
        'daily_participation_points', daily_participation_points
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_agent_overall_earnings(
    p_agent_id UUID
) RETURNS JSON AS $$
DECLARE
    total_earned INTEGER := 0;
    total_paid INTEGER := 0;
    outstanding_balance INTEGER := 0;
    campaign_task_points INTEGER := 0;
    standalone_task_points INTEGER := 0;
    touring_task_points INTEGER := 0;
    daily_participation_points INTEGER := 0;
BEGIN
    SELECT COALESCE(SUM(t.points), 0) INTO campaign_task_points
    FROM task_assignments ta
    JOIN tasks t ON ta.task_id = t.id
    WHERE ta.agent_id = p_agent_id
    AND t.campaign_id IS NOT NULL
    AND ta.status = 'completed';
    
    SELECT COALESCE(SUM(t.points), 0) INTO standalone_task_points
    FROM task_assignments ta
    JOIN tasks t ON ta.task_id = t.id
    WHERE ta.agent_id = p_agent_id
    AND t.campaign_id IS NULL
    AND ta.status = 'completed';
    
    SELECT COALESCE(SUM(tt.points), 0) INTO touring_task_points
    FROM touring_task_assignments tta
    JOIN touring_tasks tt ON tta.touring_task_id = tt.id
    WHERE tta.agent_id = p_agent_id
    AND tta.status = 'completed';
    
    SELECT COALESCE(SUM(daily_points_earned), 0) INTO daily_participation_points
    FROM campaign_daily_participation
    WHERE agent_id = p_agent_id;
    
    total_earned := campaign_task_points + standalone_task_points + touring_task_points + daily_participation_points;
    
    SELECT COALESCE(SUM(amount), 0) INTO total_paid
    FROM payments
    WHERE agent_id = p_agent_id;
    
    outstanding_balance := total_earned - total_paid;
    
    RETURN json_build_object(
        'total_earned', total_earned,
        'total_paid', total_paid,
        'outstanding_balance', outstanding_balance,
        'campaign_task_points', campaign_task_points,
        'standalone_task_points', standalone_task_points,
        'touring_task_points', touring_task_points,
        'daily_participation_points', daily_participation_points
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_daily_participation(
    p_campaign_id UUID,
    p_agent_id UUID,
    p_participation_date DATE,
    p_hours_worked DECIMAL DEFAULT 0,
    p_tasks_completed INTEGER DEFAULT 0,
    p_touring_tasks_completed INTEGER DEFAULT 0
) RETURNS JSON AS $$
DECLARE
    daily_points INTEGER := 0;
    campaign_daily_rate INTEGER := 0;
    result JSON;
BEGIN
    daily_points := (p_hours_worked * 10)::INTEGER + (p_tasks_completed * 5) + (p_touring_tasks_completed * 10);
    
    INSERT INTO campaign_daily_participation (
        campaign_id,
        agent_id,
        participation_date,
        hours_worked,
        tasks_completed,
        touring_tasks_completed,
        daily_points_earned
    ) VALUES (
        p_campaign_id,
        p_agent_id,
        p_participation_date,
        p_hours_worked,
        p_tasks_completed,
        p_touring_tasks_completed,
        daily_points
    )
    ON CONFLICT (campaign_id, agent_id, participation_date)
    DO UPDATE SET
        hours_worked = EXCLUDED.hours_worked,
        tasks_completed = EXCLUDED.tasks_completed,
        touring_tasks_completed = EXCLUDED.touring_tasks_completed,
        daily_points_earned = EXCLUDED.daily_points_earned,
        updated_at = NOW();
    
    SELECT json_build_object(
        'campaign_id', campaign_id,
        'agent_id', agent_id,
        'participation_date', participation_date,
        'hours_worked', hours_worked,
        'tasks_completed', tasks_completed,
        'touring_tasks_completed', touring_tasks_completed,
        'daily_points_earned', daily_points_earned
    ) INTO result
    FROM campaign_daily_participation
    WHERE campaign_id = p_campaign_id
    AND agent_id = p_agent_id
    AND participation_date = p_participation_date;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION auto_update_daily_participation()
RETURNS TRIGGER AS $$
DECLARE
    task_campaign_id UUID;
    completion_date DATE;
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        IF TG_TABLE_NAME = 'task_assignments' THEN
            SELECT t.campaign_id INTO task_campaign_id
            FROM tasks t
            WHERE t.id = NEW.task_id;
            
            completion_date := NEW.completed_at::DATE;
        ELSIF TG_TABLE_NAME = 'touring_task_assignments' THEN
            SELECT tt.campaign_id INTO task_campaign_id
            FROM touring_tasks tt
            WHERE tt.id = NEW.touring_task_id;
            
            completion_date := NEW.completed_at::DATE;
        END IF;
        
        IF task_campaign_id IS NOT NULL THEN
            DECLARE
                current_tasks INTEGER := 0;
                current_touring_tasks INTEGER := 0;
            BEGIN
                SELECT 
                    COALESCE(tasks_completed, 0),
                    COALESCE(touring_tasks_completed, 0)
                INTO current_tasks, current_touring_tasks
                FROM campaign_daily_participation
                WHERE campaign_id = task_campaign_id
                AND agent_id = NEW.agent_id
                AND participation_date = completion_date;
                
                IF TG_TABLE_NAME = 'task_assignments' THEN
                    current_tasks := current_tasks + 1;
                ELSIF TG_TABLE_NAME = 'touring_task_assignments' THEN
                    current_touring_tasks := current_touring_tasks + 1;
                END IF;
                
                PERFORM update_daily_participation(
                    task_campaign_id,
                    NEW.agent_id,
                    completion_date,
                    0,
                    current_tasks,
                    current_touring_tasks
                );
            END;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER auto_update_daily_participation_task_assignments
    AFTER UPDATE ON task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION auto_update_daily_participation();

CREATE TRIGGER auto_update_daily_participation_touring_task_assignments
    AFTER UPDATE ON touring_task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION auto_update_daily_participation();

GRANT EXECUTE ON FUNCTION get_agent_earnings_for_campaign TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_overall_earnings TO authenticated;
GRANT EXECUTE ON FUNCTION update_daily_participation TO authenticated;
```