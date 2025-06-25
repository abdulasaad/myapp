-- Batch function to get all agent progress for a specific task
-- Optimized replacement for multiple individual get_agent_progress_for_task calls

CREATE OR REPLACE FUNCTION get_task_agent_progress_batch(p_task_id UUID)
RETURNS TABLE (
    agent_id UUID,
    agent_name TEXT,
    assignment_status TEXT,
    evidence_required INTEGER,
    evidence_uploaded INTEGER,
    points_total INTEGER,
    points_paid INTEGER,
    outstanding_balance INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ta.agent_id,
        p.full_name as agent_name,
        ta.status as assignment_status,
        COALESCE(t.required_evidence_count, 1) as evidence_required,
        (
            SELECT COUNT(*)::INTEGER 
            FROM evidence e 
            WHERE e.task_assignment_id = ta.id
            AND e.status = 'approved'
        ) as evidence_uploaded,
        COALESCE(t.points, 0) as points_total,
        COALESCE(
            (
                SELECT SUM(amount)::INTEGER 
                FROM payments pay 
                WHERE pay.agent_id = ta.agent_id 
                AND pay.task_id = p_task_id
            ), 
            0
        ) as points_paid,
        CASE 
            WHEN ta.status = 'completed' THEN 
                GREATEST(
                    0, 
                    COALESCE(t.points, 0) - COALESCE(
                        (
                            SELECT SUM(amount)::INTEGER 
                            FROM payments pay 
                            WHERE pay.agent_id = ta.agent_id 
                            AND pay.task_id = p_task_id
                        ), 
                        0
                    )
                )
            ELSE 0
        END as outstanding_balance
    FROM task_assignments ta
    JOIN profiles p ON ta.agent_id = p.id
    JOIN tasks t ON ta.task_id = t.id
    WHERE ta.task_id = p_task_id
    ORDER BY p.full_name;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_task_agent_progress_batch(UUID) TO authenticated;

COMMENT ON FUNCTION get_task_agent_progress_batch IS 'Gets progress information for all agents assigned to a specific task in a single batch operation';