-- Final cleanup steps - run each section separately

-- =========================================
-- STEP 1: Add missing indexes (safe to run in transaction)
-- =========================================
BEGIN;

CREATE INDEX IF NOT EXISTS idx_user_groups_user_id ON user_groups(user_id);
CREATE INDEX IF NOT EXISTS idx_user_groups_group_id ON user_groups(group_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_created_by ON campaigns(created_by);
CREATE INDEX IF NOT EXISTS idx_tasks_campaign_id ON tasks(campaign_id);
CREATE INDEX IF NOT EXISTS idx_task_assignments_task_id ON task_assignments(task_id);
CREATE INDEX IF NOT EXISTS idx_task_assignments_agent_id ON task_assignments(agent_id);
CREATE INDEX IF NOT EXISTS idx_evidence_task_assignment_id ON evidence(task_assignment_id);
CREATE INDEX IF NOT EXISTS idx_evidence_uploader_id ON evidence(uploader_id);

COMMIT;

-- =========================================
-- STEP 2: VACUUM ANALYZE (run WITHOUT transaction)
-- =========================================
-- Run these commands separately, not in a transaction block:
-- VACUUM ANALYZE profiles;
-- VACUUM ANALYZE campaigns;
-- VACUUM ANALYZE tasks;
-- VACUUM ANALYZE evidence;
-- VACUUM ANALYZE user_groups;
-- VACUUM ANALYZE groups;
-- ANALYZE;

-- =========================================
-- STEP 3: Final summary
-- =========================================
SELECT 'DATABASE CLEANUP COMPLETED' as status;

-- Show final table sizes
SELECT 
    t.tablename,
    pg_size_pretty(pg_total_relation_size(t.schemaname||'.'||t.tablename)) as size,
    s.n_live_tup as row_count
FROM pg_tables t
JOIN pg_stat_user_tables s ON t.tablename = s.tablename AND t.schemaname = s.schemaname
WHERE t.schemaname = 'public'
ORDER BY pg_total_relation_size(t.schemaname||'.'||t.tablename) DESC
LIMIT 10;