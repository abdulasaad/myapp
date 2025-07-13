CREATE TABLE IF NOT EXISTS campaign_geofences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL,
    name TEXT NOT NULL,
    area_text TEXT NOT NULL,
    max_agents INTEGER DEFAULT 1,
    color TEXT DEFAULT '#2196F3',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    created_by UUID
);