-- Create triggers for automatic notification creation

-- 1. Campaign Assignment Trigger
CREATE OR REPLACE FUNCTION notify_campaign_assignment()
RETURNS TRIGGER AS $$
BEGIN
    -- When an agent is assigned to a campaign
    IF TG_OP = 'INSERT' THEN
        INSERT INTO notifications (recipient_id, sender_id, type, title, message, data)
        SELECT 
            NEW.agent_id,
            auth.uid(),
            'campaign_assignment',
            'New Campaign Assignment',
            'You have been assigned to campaign: ' || c.name,
            jsonb_build_object(
                'campaign_id', NEW.campaign_id,
                'campaign_name', c.name,
                'assigned_by', p.full_name
            )
        FROM campaigns c
        LEFT JOIN profiles p ON p.id = auth.uid()
        WHERE c.id = NEW.campaign_id;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for campaign_agents table
CREATE TRIGGER campaign_assignment_notification_trigger
    AFTER INSERT ON campaign_agents
    FOR EACH ROW
    EXECUTE FUNCTION notify_campaign_assignment();

-- 2. Task Assignment Trigger
CREATE OR REPLACE FUNCTION notify_task_assignment()
RETURNS TRIGGER AS $$
BEGIN
    -- When a task is assigned to an agent
    IF TG_OP = 'INSERT' THEN
        INSERT INTO notifications (recipient_id, sender_id, type, title, message, data)
        SELECT 
            NEW.agent_id,
            auth.uid(),
            'task_assignment',
            'New Task Assignment',
            'You have been assigned a new task: ' || t.title,
            jsonb_build_object(
                'task_id', NEW.task_id,
                'task_title', t.title,
                'campaign_id', t.campaign_id,
                'campaign_name', c.name,
                'assigned_by', p.full_name
            )
        FROM tasks t
        LEFT JOIN campaigns c ON c.id = t.campaign_id
        LEFT JOIN profiles p ON p.id = auth.uid()
        WHERE t.id = NEW.task_id;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for task_assignments table
CREATE TRIGGER task_assignment_notification_trigger
    AFTER INSERT ON task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION notify_task_assignment();

-- 3. Route Assignment Trigger
CREATE OR REPLACE FUNCTION notify_route_assignment()
RETURNS TRIGGER AS $$
BEGIN
    -- When an agent is assigned to a route
    IF TG_OP = 'INSERT' THEN
        INSERT INTO notifications (recipient_id, sender_id, type, title, message, data)
        SELECT 
            NEW.agent_id,
            auth.uid(),
            'route_assignment',
            'New Route Assignment',
            'You have been assigned to route: ' || r.name,
            jsonb_build_object(
                'route_id', NEW.route_id,
                'route_name', r.name,
                'assigned_by', p.full_name
            )
        FROM routes r
        LEFT JOIN profiles p ON p.id = auth.uid()
        WHERE r.id = NEW.route_id;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for route_agents table (assuming this table exists)
-- If route_agents table doesn't exist, we'll handle route assignments differently
-- CREATE TRIGGER route_assignment_notification_trigger
--     AFTER INSERT ON route_agents
--     FOR EACH ROW
--     EXECUTE FUNCTION notify_route_assignment();

-- 4. Place Suggestion Approval Trigger
CREATE OR REPLACE FUNCTION notify_place_approval()
RETURNS TRIGGER AS $$
BEGIN
    -- When a suggested place is approved/rejected
    IF TG_OP = 'UPDATE' AND OLD.status != NEW.status AND NEW.status IN ('approved', 'rejected') THEN
        INSERT INTO notifications (recipient_id, sender_id, type, title, message, data)
        SELECT 
            NEW.suggested_by,
            auth.uid(),
            'place_approval',
            CASE 
                WHEN NEW.status = 'approved' THEN 'Place Suggestion Approved'
                ELSE 'Place Suggestion Rejected'
            END,
            CASE 
                WHEN NEW.status = 'approved' THEN 'Your suggested place "' || NEW.name || '" has been approved!'
                ELSE 'Your suggested place "' || NEW.name || '" has been rejected. Reason: ' || COALESCE(NEW.rejection_reason, 'No reason provided')
            END,
            jsonb_build_object(
                'place_id', NEW.id,
                'place_name', NEW.name,
                'status', NEW.status,
                'rejection_reason', NEW.rejection_reason,
                'reviewed_by', p.full_name
            )
        FROM profiles p
        WHERE p.id = auth.uid();
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for places table
CREATE TRIGGER place_approval_notification_trigger
    AFTER UPDATE ON places
    FOR EACH ROW
    EXECUTE FUNCTION notify_place_approval();

-- 5. Evidence Review Trigger
CREATE OR REPLACE FUNCTION notify_evidence_review()
RETURNS TRIGGER AS $$
BEGIN
    -- When evidence is reviewed (approved/rejected)
    IF TG_OP = 'UPDATE' AND OLD.status != NEW.status AND NEW.status IN ('approved', 'rejected') THEN
        INSERT INTO notifications (recipient_id, sender_id, type, title, message, data)
        SELECT 
            NEW.uploader_id,
            auth.uid(),
            'evidence_review',
            CASE 
                WHEN NEW.status = 'approved' THEN 'Evidence Approved'
                ELSE 'Evidence Rejected'
            END,
            CASE 
                WHEN NEW.status = 'approved' THEN 'Your evidence "' || NEW.title || '" has been approved!'
                ELSE 'Your evidence "' || NEW.title || '" has been rejected. Reason: ' || COALESCE(NEW.rejection_reason, 'No reason provided')
            END,
            jsonb_build_object(
                'evidence_id', NEW.id,
                'evidence_title', NEW.title,
                'status', NEW.status,
                'rejection_reason', NEW.rejection_reason,
                'reviewed_by', p.full_name
            )
        FROM profiles p
        WHERE p.id = auth.uid();
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for evidence table
CREATE TRIGGER evidence_review_notification_trigger
    AFTER UPDATE ON evidence
    FOR EACH ROW
    EXECUTE FUNCTION notify_evidence_review();

-- 6. Task Completion Trigger (for managers to know when agents complete tasks)
CREATE OR REPLACE FUNCTION notify_task_completion()
RETURNS TRIGGER AS $$
BEGIN
    -- When a task is marked as completed by an agent
    IF TG_OP = 'UPDATE' AND OLD.status != NEW.status AND NEW.status = 'completed' THEN
        -- Notify managers who have access to this campaign
        INSERT INTO notifications (recipient_id, sender_id, type, title, message, data)
        SELECT DISTINCT
            ug.user_id,
            NEW.agent_id,
            'task_completion',
            'Task Completed',
            'Agent ' || a.full_name || ' has completed task: ' || t.title,
            jsonb_build_object(
                'task_id', NEW.task_id,
                'task_title', t.title,
                'campaign_id', t.campaign_id,
                'campaign_name', c.name,
                'agent_id', NEW.agent_id,
                'agent_name', a.full_name,
                'completed_at', NEW.updated_at
            )
        FROM tasks t
        LEFT JOIN campaigns c ON c.id = t.campaign_id
        LEFT JOIN profiles a ON a.id = NEW.agent_id
        LEFT JOIN user_groups ug ON ug.group_id = c.group_id
        LEFT JOIN profiles p ON p.id = ug.user_id
        WHERE t.id = NEW.task_id 
        AND p.role IN ('admin', 'manager');
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for task_assignments table
CREATE TRIGGER task_completion_notification_trigger
    AFTER UPDATE ON task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION notify_task_completion();