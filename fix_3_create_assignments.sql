CREATE TABLE touring_task_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    touring_task_id UUID NOT NULL REFERENCES touring_tasks(id) ON DELETE CASCADE,
    agent_id UUID NOT NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    assigned_by UUID,
    status TEXT NOT NULL DEFAULT 'assigned',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    CONSTRAINT touring_task_assignments_status_check CHECK (status IN ('assigned', 'in_progress', 'completed', 'cancelled')),
    UNIQUE(touring_task_id, agent_id)
);