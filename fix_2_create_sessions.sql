CREATE TABLE touring_task_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    touring_task_id UUID NOT NULL REFERENCES touring_tasks(id) ON DELETE CASCADE,
    agent_id UUID NOT NULL,
    start_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_time TIMESTAMPTZ,
    elapsed_seconds INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_paused BOOLEAN NOT NULL DEFAULT false,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    last_movement_time TIMESTAMPTZ,
    last_latitude DECIMAL(10,8),
    last_longitude DECIMAL(11,8),
    pause_reason TEXT,
    last_location_update TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);