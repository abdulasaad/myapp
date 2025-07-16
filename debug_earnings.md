# Debug Earnings System - SQL Commands

Run these SQL commands in your Supabase SQL Editor to debug the earnings issue:

## 1. Check if the task exists and has points
```sql
SELECT id, title, points, campaign_id, status 
FROM tasks 
WHERE title = 'test2';
```

## 2. Check task assignments for the completed task
```sql
SELECT ta.*, p.full_name as agent_name
FROM task_assignments ta
JOIN profiles p ON ta.agent_id = p.id
JOIN tasks t ON ta.task_id = t.id
WHERE t.title = 'test2';
```

## 3. Check if the agent is assigned to the campaign
```sql
SELECT ca.*, p.full_name as agent_name, c.name as campaign_name
FROM campaign_agents ca
JOIN profiles p ON ca.agent_id = p.id
JOIN campaigns c ON ca.campaign_id = c.id
WHERE c.id IN (SELECT campaign_id FROM tasks WHERE title = 'test2');
```

## 4. Check daily participation records
```sql
SELECT cdp.*, p.full_name as agent_name, c.name as campaign_name
FROM campaign_daily_participation cdp
JOIN profiles p ON cdp.agent_id = p.id
JOIN campaigns c ON cdp.campaign_id = c.id
WHERE cdp.campaign_id IN (SELECT campaign_id FROM tasks WHERE title = 'test2');
```

## 5. Test the earnings calculation function
```sql
-- Replace 'AGENT_ID' with the actual agent ID who completed the task
SELECT * FROM get_agent_overall_earnings('AGENT_ID');
```

## 6. Check if triggers exist
```sql
SELECT trigger_name, event_manipulation, event_object_table, action_statement
FROM information_schema.triggers 
WHERE trigger_name LIKE '%daily_participation%';
```

## 7. Check if the RPC functions exist
```sql
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name IN ('get_agent_overall_earnings', 'get_agent_earnings_for_campaign', 'update_daily_participation');
```

## 8. Manually test the daily participation update
```sql
-- Replace with actual values
SELECT update_daily_participation(
    'CAMPAIGN_ID'::UUID,
    'AGENT_ID'::UUID,
    CURRENT_DATE,
    0,  -- hours_worked
    1,  -- tasks_completed
    0   -- touring_tasks_completed
);
```

## Expected Results:
- Task should exist with points > 0
- Task assignment should show status = 'completed'
- Agent should be in campaign_agents table
- Daily participation should have records
- Earnings calculation should return total > 0
- Triggers should exist and be active
- RPC functions should exist

## Common Issues:
1. **Agent not in campaign_agents table** - Agent earnings only count if they're assigned to the campaign
2. **Triggers not working** - Task completion might not be triggering daily participation updates
3. **Missing RPC functions** - The migration might not have run properly
4. **Task not linked to campaign** - Only campaign tasks are counted in earnings