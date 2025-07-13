CREATE TABLE touring_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    geofence_id UUID NOT NULL REFERENCES campaign_geofences(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    required_time_minutes INTEGER NOT NULL DEFAULT 30,
    movement_timeout_seconds INTEGER NOT NULL DEFAULT 60,
    min_movement_threshold DECIMAL(8,2) NOT NULL DEFAULT 5.0,
    points INTEGER NOT NULL DEFAULT 10,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    created_by UUID,
    CONSTRAINT touring_tasks_status_check CHECK (status IN ('pending', 'active', 'completed', 'cancelled'))
);