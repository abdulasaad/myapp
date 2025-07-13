ALTER TABLE touring_task_assignments 
ADD CONSTRAINT touring_task_assignments_agent_id_fkey 
FOREIGN KEY (agent_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE touring_tasks 
ADD CONSTRAINT touring_tasks_geofence_id_fkey 
FOREIGN KEY (geofence_id) REFERENCES campaign_geofences(id) ON DELETE CASCADE;

ALTER TABLE touring_tasks 
ADD CONSTRAINT touring_tasks_campaign_id_fkey 
FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE;