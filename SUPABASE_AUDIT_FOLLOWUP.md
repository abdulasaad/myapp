# Supabase Structure Audit — Follow‑Up SQL

This follow‑up addresses gaps and errors seen in the first run (failed function defs, schema privileges), and adds deeper security/replication detail. Run blocks in order and paste outputs under each block with a leading `*` like before.

Notes:
- Limits to app schemas: public, auth, storage, realtime, cron (adjust if needed).
- Excludes aggregates to avoid errors.
- All queries are read‑only.

---

## A) Functions and RPCs

```sql
-- A1) Function inventory (metadata only; excludes aggregates)
select n.nspname                                  as schema,
       p.proname                                   as function,
       pg_get_function_identity_arguments(p.oid)   as args,
       pg_get_function_result(p.oid)               as returns,
       case p.prokind when 'f' then 'function' when 'p' then 'procedure' end as kind,
       p.prosecdef                                 as security_definer,
        p.provolatile                               as volatility,
       p.proparallel                               as parallel,
       p.proretset                                 as returns_set
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.prokind in ('f','p')
  and n.nspname in ('public','auth','storage','realtime','cron')
order by 1, 2, 3;
```
* 
| schema | function                               | args                                                                                                                                                                                                                                                                      | returns                                                                                                                                                                                                                                                                                                                                                                                                                                                | kind     | security_definer | volatility | parallel | returns_set |
| ------ | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ---------------- | ---------- | -------- | ----------- |
| auth   | email                                  |                                                                                                                                                                                                                                                                           | text                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | false            | s          | u        | false       |
| auth   | jwt                                    |                                                                                                                                                                                                                                                                           | jsonb                                                                                                                                                                                                                                                                                                                                                                                                                                                  | function | false            | s          | u        | false       |
| auth   | role                                   |                                                                                                                                                                                                                                                                           | text                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | false            | s          | u        | false       |
| auth   | uid                                    |                                                                                                                                                                                                                                                                           | uuid                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | false            | s          | u        | false       |
| cron   | alter_job                              | job_id bigint, schedule text, command text, database text, username text, active boolean                                                                                                                                                                                  | void                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | false            | v          | u        | false       |
| cron   | job_cache_invalidate                   |                                                                                                                                                                                                                                                                           | trigger                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | false            | v          | u        | false       |
| cron   | schedule                               | job_name text, schedule text, command text                                                                                                                                                                                                                                | bigint                                                                                                                                                                                                                                                                                                                                                                                                                                                 | function | false            | v          | u        | false       |
| cron   | schedule                               | schedule text, command text                                                                                                                                                                                                                                               | bigint                                                                                                                                                                                                                                                                                                                                                                                                                                                 | function | false            | v          | u        | false       |
| cron   | schedule_in_database                   | job_name text, schedule text, command text, database text, username text, active boolean                                                                                                                                                                                  | bigint                                                                                                                                                                                                                                                                                                                                                                                                                                                 | function | false            | v          | u        | false       |
| cron   | unschedule                             | job_id bigint                                                                                                                                                                                                                                                             | boolean                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | false            | v          | u        | false       |
| cron   | unschedule                             | job_name text                                                                                                                                                                                                                                                             | boolean                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | false            | v          | u        | false       |
| public | assign_agent_to_geofence               | p_campaign_id uuid, p_geofence_id uuid, p_agent_id uuid                                                                                                                                                                                                                   | jsonb                                                                                                                                                                                                                                                                                                                                                                                                                                                  | function | false            | v          | u        | false       |
| public | audit_trigger                          |                                                                                                                                                                                                                                                                           | trigger                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | true             | v          | u        | false       |
| public | auto_assign_new_task_to_agents         |                                                                                                                                                                                                                                                                           | trigger                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | false            | v          | u        | false       |
| public | auto_assign_tasks_to_new_agent         |                                                                                                                                                                                                                                                                           | trigger                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | false            | v          | u        | false       |
| public | auto_checkout_on_new_assignment        |                                                                                                                                                                                                                                                                           | trigger                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | false            | v          | u        | false       |
| public | auto_update_daily_participation        |                                                                                                                                                                                                                                                                           | trigger                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | false            | v          | u        | false       |
| public | can_create_agent                       |                                                                                                                                                                                                                                                                           | boolean                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | false            | v          | u        | false       |
| public | can_update_profile                     | target_user_id uuid                                                                                                                                                                                                                                                       | boolean                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | true             | v          | u        | false       |
| public | check_active_checkin                   |                                                                                                                                                                                                                                                                           | trigger                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | false            | v          | u        | false       |
| public | check_agent_in_campaign_geofence       | p_agent_id uuid, p_campaign_id uuid                                                                                                                                                                                                                                       | boolean                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | true             | v          | u        | false       |
| public | check_agent_in_place_geofence          | place_uuid uuid, agent_lat double precision, agent_lng double precision                                                                                                                                                                                                   | boolean                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | true             | v          | u        | false       |
| public | check_agent_in_task_geofence           | p_agent_id uuid, p_task_id uuid, p_agent_lat double precision, p_agent_lng double precision                                                                                                                                                                               | boolean                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | true             | v          | u        | false       |
| public | check_geofence_capacity                | p_geofence_id uuid                                                                                                                                                                                                                                                        | TABLE(current_agents integer, max_agents integer, is_full boolean, available_spots integer)                                                                                                                                                                                                                                                                                                                                                            | function | false            | v          | u        | true        |
| public | check_place_visit_availability         | p_route_assignment_id uuid, p_place_id uuid, p_agent_id uuid                                                                                                                                                                                                              | TABLE(can_check_in boolean, reason text, completed_visits integer, required_visits integer, last_checkout_time timestamp with time zone, cooldown_remaining_hours numeric)                                                                                                                                                                                                                                                                             | function | false            | v          | u        | true        |
| public | check_place_visit_evidence_complete    | visit_id uuid                                                                                                                                                                                                                                                             | boolean                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | true             | v          | u        | false       |
| public | check_point_in_geofence                | p_lat numeric, p_lng numeric, p_geofence_id uuid                                                                                                                                                                                                                          | boolean                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | false            | v          | u        | false       |
| public | check_profile_select_permission        | target_user_id uuid                                                                                                                                                                                                                                                       | boolean                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | true             | v          | u        | false       |
| public | check_profile_update_permission        | target_user_id uuid                                                                                                                                                                                                                                                       | boolean                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | true             | s          | u        | false       |
| public | clean_campaigns_policies               |                                                                                                                                                                                                                                                                           | text                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | cleanup_old_sessions                   |                                                                                                                                                                                                                                                                           | void                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | false            | v          | u        | false       |
| public | confirm_user_email                     | target_user_id uuid                                                                                                                                                                                                                                                       | json                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | create_campaign_geofence               | p_campaign_id uuid, p_name text, p_area_text text, p_max_agents integer, p_color text, p_description text, p_created_by uuid                                                                                                                                              | json                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | create_notification                    | p_recipient_id uuid, p_type text, p_title text, p_message text, p_sender_id uuid, p_data jsonb                                                                                                                                                                            | void                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | create_touring_task                    | p_campaign_id uuid, p_geofence_id uuid, p_title text, p_description text, p_required_time_minutes integer, p_movement_timeout_seconds integer, p_min_movement_threshold numeric, p_points integer, p_use_schedule boolean, p_daily_start_time text, p_daily_end_time text | touring_tasks                                                                                                                                                                                                                                                                                                                                                                                                                                          | function | true             | v          | u        | false       |
| public | daily_status_reset                     |                                                                                                                                                                                                                                                                           | void                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | false            | v          | u        | false       |
| public | debug_location_data                    | requesting_user_id uuid                                                                                                                                                                                                                                                   | TABLE(debug_step text, debug_info text, debug_data jsonb)                                                                                                                                                                                                                                                                                                                                                                                              | function | true             | v          | u        | true        |
| public | debug_location_updates                 |                                                                                                                                                                                                                                                                           | TABLE(user_id uuid, full_name text, role text, heartbeat_status text, heartbeat_age_minutes numeric, location_status text, location_age_minutes numeric, last_heartbeat timestamp with time zone, last_location_update timestamp with time zone)                                                                                                                                                                                                       | function | true             | v          | u        | true        |
| public | delete_user_by_admin                   | user_id_to_delete uuid                                                                                                                                                                                                                                                    | text                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | ensure_agent_in_campaign               |                                                                                                                                                                                                                                                                           | trigger                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | false            | v          | u        | false       |
| public | ensure_agent_in_campaign_touring       |                                                                                                                                                                                                                                                                           | trigger                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | false            | v          | u        | false       |
| public | get_active_agents                      |                                                                                                                                                                                                                                                                           | TABLE(user_id uuid, full_name text, last_location geography, last_seen timestamp with time zone)                                                                                                                                                                                                                                                                                                                                                       | function | false            | v          | u        | true        |
| public | get_active_agents_for_manager          |                                                                                                                                                                                                                                                                           | TABLE(user_id uuid, full_name text, last_location geography, last_seen timestamp with time zone)                                                                                                                                                                                                                                                                                                                                                       | function | true             | v          | u        | true        |
| public | get_agent_campaign_details             | p_agent_id uuid, p_campaign_id uuid                                                                                                                                                                                                                                       | jsonb                                                                                                                                                                                                                                                                                                                                                                                                                                                  | function | false            | v          | u        | false       |
| public | get_agent_campaign_details_fixed       | p_campaign_id uuid, p_agent_id uuid                                                                                                                                                                                                                                       | json                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | false            | s          | u        | false       |
| public | get_agent_earnings_for_campaign        | p_agent_id uuid, p_campaign_id uuid                                                                                                                                                                                                                                       | json                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | get_agent_location_history             | p_agent_id uuid, p_start_date timestamp with time zone, p_end_date timestamp with time zone, p_limit integer                                                                                                                                                              | TABLE(id uuid, user_id uuid, latitude double precision, longitude double precision, accuracy real, speed real, recorded_at timestamp with time zone, created_at timestamp with time zone)                                                                                                                                                                                                                                                              | function | true             | v          | u        | true        |
| public | get_agent_overall_earnings             | p_agent_id uuid                                                                                                                                                                                                                                                           | json                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | get_agent_progress_for_campaign        | p_campaign_id uuid, p_agent_id uuid                                                                                                                                                                                                                                       | json                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | false            | v          | u        | false       |
| public | get_agent_progress_for_task            | p_task_id uuid, p_agent_id uuid                                                                                                                                                                                                                                           | TABLE(agent_name text, assignment_status text, evidence_required integer, evidence_uploaded integer, points_total integer, points_paid integer, outstanding_balance integer)                                                                                                                                                                                                                                                                           | function | false            | v          | u        | true        |
| public | get_agent_survey_submissions           | agent_uuid uuid, campaign_uuid uuid                                                                                                                                                                                                                                       | json                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | get_agent_tasks_for_campaign           | p_campaign_id uuid                                                                                                                                                                                                                                                        | TABLE(task_id uuid, title text, description text, points integer, assignment_status text, evidence_urls text[])                                                                                                                                                                                                                                                                                                                                        | function | false            | v          | u        | true        |
| public | get_agents_in_geofence                 | geofence_id uuid                                                                                                                                                                                                                                                          | TABLE(agent_id uuid, agent_name text, last_location text, last_seen timestamp with time zone, distance_meters numeric)                                                                                                                                                                                                                                                                                                                                 | function | true             | v          | u        | true        |
| public | get_agents_in_manager_groups           | manager_user_id uuid                                                                                                                                                                                                                                                      | TABLE(user_id uuid, full_name text, last_location geography, last_seen timestamp with time zone)                                                                                                                                                                                                                                                                                                                                                       | function | true             | v          | u        | true        |
| public | get_agents_with_last_location          |                                                                                                                                                                                                                                                                           | TABLE(id uuid, full_name text, username text, role text, status text, connection_status text, last_heartbeat timestamp with time zone, last_location text, last_seen timestamp with time zone)                                                                                                                                                                                                                                                         | function | true             | v          | u        | true        |
| public | get_agents_within_radius               | center_lat double precision, center_lng double precision, radius_meters integer                                                                                                                                                                                           | TABLE(agent_id uuid, agent_name text, last_location text, last_seen timestamp with time zone, distance_meters numeric)                                                                                                                                                                                                                                                                                                                                 | function | true             | v          | u        | true        |
| public | get_all_agents_for_admin               |                                                                                                                                                                                                                                                                           | TABLE(id uuid, full_name text, username text, email text, role text, status text, connection_status text, last_heartbeat timestamp with time zone, last_location text, last_seen timestamp with time zone, created_at timestamp with time zone)                                                                                                                                                                                                        | function | true             | v          | u        | true        |
| public | get_all_agents_with_location_for_admin | requesting_user_id uuid                                                                                                                                                                                                                                                   | TABLE(id uuid, full_name text, role text, status text, last_heartbeat timestamp with time zone, last_location text, last_seen timestamp with time zone, connection_status text)                                                                                                                                                                                                                                                                        | function | true             | v          | u        | true        |
| public | get_all_geofences_wkt                  |                                                                                                                                                                                                                                                                           | TABLE(geofence_id uuid, geofence_name text, geofence_area_wkt text, geofence_type text, geofence_color text, campaign_id uuid, campaign_name text, touring_task_id uuid, touring_task_title text, max_agents integer, is_active boolean, touring_tasks_info text)                                                                                                                                                                                      | function | true             | v          | u        | true        |
| public | get_area_wkt                           | g geofences                                                                                                                                                                                                                                                               | text                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | false            | i          | u        | false       |
| public | get_assigned_agents                    | p_campaign_id uuid                                                                                                                                                                                                                                                        | TABLE(id uuid, full_name text)                                                                                                                                                                                                                                                                                                                                                                                                                         | function | false            | v          | u        | true        |
| public | get_available_geofences_for_campaign   | p_campaign_id uuid                                                                                                                                                                                                                                                        | TABLE(id uuid, campaign_id uuid, name text, description text, max_agents integer, current_agents integer, is_full boolean, available_spots integer, color text, area_text text, is_active boolean, created_at timestamp with time zone, updated_at timestamp with time zone, created_by uuid)                                                                                                                                                          | function | false            | v          | u        | true        |
| public | get_calendar_events                    | month_start text, month_end text                                                                                                                                                                                                                                          | TABLE(id uuid, title text, type text, start_date date, end_date date, description text, status text)                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | true        |
| public | get_campaign_report_data               | p_campaign_id uuid                                                                                                                                                                                                                                                        | TABLE(total_tasks bigint, completed_tasks bigint, total_points_earned bigint, assigned_agents bigint)                                                                                                                                                                                                                                                                                                                                                  | function | false            | v          | u        | true        |
| public | get_campaign_survey_stats              | campaign_uuid uuid                                                                                                                                                                                                                                                        | json                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | get_campaigns_scoped                   | manager_user_id uuid                                                                                                                                                                                                                                                      | TABLE(id uuid, name text, description text, status text, start_date date, end_date date, created_at timestamp with time zone, created_by uuid, assigned_manager_id uuid, client_id uuid, package_type text, reset_status_daily boolean)                                                                                                                                                                                                                | function | true             | v          | u        | true        |
| public | get_current_user_id                    |                                                                                                                                                                                                                                                                           | uuid                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | get_dashboard_metrics                  |                                                                                                                                                                                                                                                                           | TABLE(total_accounts bigint, total_accounts_change bigint, active_groups bigint, active_groups_change bigint, active_campaigns bigint, active_campaigns_change bigint, completed_tasks bigint, completed_tasks_change bigint, connected_agents bigint, total_agents bigint, active_routes bigint, points_granted numeric, points_granted_change numeric, new_accounts bigint, new_accounts_change bigint, pending_tasks bigint, pending_points bigint) | function | false            | s          | u        | true        |
| public | get_geofence_for_campaign              | p_campaign_id uuid                                                                                                                                                                                                                                                        | text                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | false            | v          | u        | false       |
| public | get_geofence_for_task                  | p_task_id uuid                                                                                                                                                                                                                                                            | text                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | false            | v          | u        | false       |
| public | get_geofences_for_parent               | parent_id uuid                                                                                                                                                                                                                                                            | TABLE(id uuid, name text, color text, area_wkt text)                                                                                                                                                                                                                                                                                                                                                                                                   | function | false            | v          | u        | true        |
| public | get_manager_agent_profiles             |                                                                                                                                                                                                                                                                           | TABLE(id uuid, full_name text, username text, email text, role text, status text, connection_status text, last_heartbeat timestamp with time zone, last_location text, last_seen timestamp with time zone, created_at timestamp with time zone, group_name text)                                                                                                                                                                                       | function | true             | v          | u        | true        |
| public | get_manager_campaigns                  | manager_user_id uuid                                                                                                                                                                                                                                                      | TABLE(id uuid, name text, description text, status text, start_date date, end_date date, created_at timestamp with time zone, assigned_agents bigint, total_tasks bigint, completed_tasks bigint)                                                                                                                                                                                                                                                      | function | true             | v          | u        | true        |
| public | get_manager_timezone                   | agent_id uuid                                                                                                                                                                                                                                                             | text                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | get_my_creation_count                  |                                                                                                                                                                                                                                                                           | integer                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | false            | v          | u        | false       |
| public | get_my_role                            |                                                                                                                                                                                                                                                                           | text                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | s          | u        | false       |
| public | get_next_place_in_route                | route_assignment_uuid uuid                                                                                                                                                                                                                                                | TABLE(place_id uuid, place_name text, visit_order integer, instructions text, latitude double precision, longitude double precision, estimated_duration_minutes integer)                                                                                                                                                                                                                                                                               | function | true             | v          | u        | true        |
| public | get_next_visit_number                  | p_route_assignment_id uuid, p_place_id uuid, p_agent_id uuid                                                                                                                                                                                                              | integer                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | false            | v          | u        | false       |
| public | get_place_visit_evidence_count         | visit_id uuid                                                                                                                                                                                                                                                             | integer                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | true             | v          | u        | false       |
| public | get_report_agent_performance           | manager_user_id uuid, from_date date, to_date date                                                                                                                                                                                                                        | TABLE(agent_id uuid, full_name text, last_seen timestamp with time zone, tasks_completed integer, on_time_ratio numeric, avg_completion_hours numeric, routes_completed integer, points_earned integer, points_paid integer, outstanding integer)                                                                                                                                                                                                      | function | true             | v          | u        | true        |
| public | get_report_campaign_summary            | manager_user_id uuid, from_date date, to_date date                                                                                                                                                                                                                        | TABLE(campaign_id uuid, name text, status text, start_date date, end_date date, created_at timestamp with time zone, created_by uuid, agents_assigned integer, total_tasks integer, completed_tasks integer, completion_rate numeric)                                                                                                                                                                                                                  | function | true             | v          | u        | true        |
| public | get_route_progress                     | route_assignment_uuid uuid                                                                                                                                                                                                                                                | TABLE(total_places integer, completed_places integer, in_progress_places integer, pending_places integer, total_duration_minutes integer, progress_percentage numeric)                                                                                                                                                                                                                                                                                 | function | true             | v          | u        | true        |
| public | get_routes_scoped                      | manager_user_id uuid                                                                                                                                                                                                                                                      | TABLE(id uuid, name text, description text, status text, start_date date, created_at timestamp with time zone, created_by uuid, assigned_manager_id uuid, metadata jsonb, estimated_duration_hours integer, updated_at timestamp with time zone)                                                                                                                                                                                                       | function | true             | v          | u        | true        |
| public | get_survey_with_fields                 | survey_uuid uuid                                                                                                                                                                                                                                                          | json                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | get_task_agent_progress_batch          | p_task_id uuid                                                                                                                                                                                                                                                            | TABLE(agent_id uuid, agent_name text, assignment_status text, evidence_required integer, evidence_uploaded integer, points_total integer, points_paid integer, outstanding_balance integer)                                                                                                                                                                                                                                                            | function | true             | v          | u        | true        |
| public | get_template_with_fields               | template_id uuid                                                                                                                                                                                                                                                          | jsonb                                                                                                                                                                                                                                                                                                                                                                                                                                                  | function | true             | v          | u        | false       |
| public | get_templates_by_category              | category_name text                                                                                                                                                                                                                                                        | TABLE(template_id uuid, template_name text, description text, default_points integer, requires_geofence boolean, difficulty_level text, estimated_duration integer)                                                                                                                                                                                                                                                                                    | function | true             | v          | u        | true        |
| public | get_unread_notification_count          | user_id uuid                                                                                                                                                                                                                                                              | integer                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | true             | v          | u        | false       |
| public | get_user_location_history_fixed        | user_uuid uuid, start_date timestamp with time zone, end_date timestamp with time zone, limit_count integer                                                                                                                                                               | TABLE(id uuid, latitude double precision, longitude double precision, accuracy real, speed real, recorded_at timestamp with time zone)                                                                                                                                                                                                                                                                                                                 | function | true             | v          | u        | true        |
| public | get_user_role_secure                   | user_uuid uuid                                                                                                                                                                                                                                                            | text                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | s          | u        | false       |
| public | get_user_timezone                      | user_id uuid                                                                                                                                                                                                                                                              | text                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | get_users_by_status                    | status_filter text, group_id_filter uuid                                                                                                                                                                                                                                  | TABLE(id uuid, full_name text, username text, role text, connection_status text, last_heartbeat timestamp with time zone, last_location text, last_seen timestamp with time zone)                                                                                                                                                                                                                                                                      | function | true             | v          | u        | true        |
| public | handle_new_user                        |                                                                                                                                                                                                                                                                           | trigger                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | true             | v          | u        | false       |
| public | handle_updated_at                      |                                                                                                                                                                                                                                                                           | trigger                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | false            | v          | u        | false       |
| public | insert_location_coordinates            | p_user_id uuid, p_longitude double precision, p_latitude double precision, p_accuracy double precision, p_speed double precision                                                                                                                                          | void                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | insert_location_point                  | user_uuid uuid, lat double precision, lng double precision, acc real, spd real                                                                                                                                                                                            | uuid                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | insert_location_update                 | p_user_id uuid, p_location text, p_accuracy double precision, p_speed double precision                                                                                                                                                                                    | void                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | insert_task_geofence                   | task_id_param uuid, geofence_name text, wkt_polygon text                                                                                                                                                                                                                  | void                                                                                                                                                                                                                                                                                                                                                                                                                                                   | function | true             | v          | u        | false       |
| public | is_touring_task_available_at_time      | task_id uuid, check_time timestamp with time zone                                                                                                                                                                                                                         | boolean                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | true             | v          | u        | false       |
| public | is_user_admin                          | user_uuid uuid                                                                                                                                                                                                                                                            | boolean                                                                                                                                                                                                                                                                                                                                                                                                                                                | function | true             | s          | u        | false       |


```sql
-- A2) Function definitions (safe subset; excludes aggregates)
select n.nspname as schema,
       p.proname as function,
       pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.prokind in ('f','p')
  and n.nspname in ('public','auth','storage','realtime','cron')
order by 1, 2;
```
* 
| schema | function                               | definition                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ------ | -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| auth   | email                                  | CREATE OR REPLACE FUNCTION auth.email()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| auth   | jwt                                    | CREATE OR REPLACE FUNCTION auth.jwt()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| auth   | role                                   | CREATE OR REPLACE FUNCTION auth.role()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| auth   | uid                                    | CREATE OR REPLACE FUNCTION auth.uid()
 RETURNS uuid
 LANGUAGE sql
 STABLE
AS $function$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| cron   | alter_job                              | CREATE OR REPLACE FUNCTION cron.alter_job(job_id bigint, schedule text DEFAULT NULL::text, command text DEFAULT NULL::text, database text DEFAULT NULL::text, username text DEFAULT NULL::text, active boolean DEFAULT NULL::boolean)
 RETURNS void
 LANGUAGE c
AS '$libdir/pg_cron', $function$cron_alter_job$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| cron   | job_cache_invalidate                   | CREATE OR REPLACE FUNCTION cron.job_cache_invalidate()
 RETURNS trigger
 LANGUAGE c
AS '$libdir/pg_cron', $function$cron_job_cache_invalidate$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| cron   | schedule                               | CREATE OR REPLACE FUNCTION cron.schedule(schedule text, command text)
 RETURNS bigint
 LANGUAGE c
 STRICT
AS '$libdir/pg_cron', $function$cron_schedule$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| cron   | schedule                               | CREATE OR REPLACE FUNCTION cron.schedule(job_name text, schedule text, command text)
 RETURNS bigint
 LANGUAGE c
AS '$libdir/pg_cron', $function$cron_schedule_named$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| cron   | schedule_in_database                   | CREATE OR REPLACE FUNCTION cron.schedule_in_database(job_name text, schedule text, command text, database text, username text DEFAULT NULL::text, active boolean DEFAULT true)
 RETURNS bigint
 LANGUAGE c
AS '$libdir/pg_cron', $function$cron_schedule_named$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| cron   | unschedule                             | CREATE OR REPLACE FUNCTION cron.unschedule(job_id bigint)
 RETURNS boolean
 LANGUAGE c
 STRICT
AS '$libdir/pg_cron', $function$cron_unschedule$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| cron   | unschedule                             | CREATE OR REPLACE FUNCTION cron.unschedule(job_name text)
 RETURNS boolean
 LANGUAGE c
 STRICT
AS '$libdir/pg_cron', $function$cron_unschedule_named$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| public | assign_agent_to_geofence               | CREATE OR REPLACE FUNCTION public.assign_agent_to_geofence(p_campaign_id uuid, p_geofence_id uuid, p_agent_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_capacity_info RECORD;
    v_existing_assignment UUID;
    v_assignment_id UUID;
BEGIN
    -- Check if geofence has capacity
    SELECT * INTO v_capacity_info 
    FROM check_geofence_capacity(p_geofence_id);
    
    IF v_capacity_info.is_full THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Geofence is at maximum capacity',
            'current_agents', v_capacity_info.current_agents,
            'max_agents', v_capacity_info.max_agents
        );
    END IF;
    
    -- Check if agent already has an active assignment in this campaign
    SELECT id INTO v_existing_assignment
    FROM public.agent_geofence_assignments
    WHERE campaign_id = p_campaign_id 
        AND agent_id = p_agent_id 
        AND status = 'active';
    
    IF v_existing_assignment IS NOT NULL THEN
        -- Cancel existing assignment
        UPDATE public.agent_geofence_assignments
        SET status = 'cancelled',
            exit_time = NOW()
        WHERE id = v_existing_assignment;
    END IF;
    
    -- Create new assignment
    INSERT INTO public.agent_geofence_assignments (
        campaign_id, geofence_id, agent_id, status
    ) VALUES (
        p_campaign_id, p_geofence_id, p_agent_id, 'active'
    ) RETURNING id INTO v_assignment_id;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'assignment_id', v_assignment_id,
        'message', 'Agent successfully assigned to geofence'
    );
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| public | audit_trigger                          | CREATE OR REPLACE FUNCTION public.audit_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.audit_log (
    user_id,
    action,
    table_name,
    record_id,
    old_data,
    new_data
  ) VALUES (
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END
  );
  
  RETURN COALESCE(NEW, OLD);
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| public | auto_assign_new_task_to_agents         | CREATE OR REPLACE FUNCTION public.auto_assign_new_task_to_agents()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Insert a new task_assignment for every agent who is
  -- already assigned to the new task's parent campaign.
  -- Status is now 'assigned' by default, not 'pending'
  INSERT INTO public.task_assignments (task_id, agent_id, status, started_at)
  SELECT
    NEW.id, -- The ID of the task that was just created
    ca.agent_id,
    'assigned', -- Explicitly set to assigned instead of pending
    NOW() -- Set started_at to current time
  FROM
    public.campaign_agents ca
  WHERE
    ca.campaign_id = NEW.campaign_id;
  
  RETURN NEW;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| public | auto_assign_tasks_to_new_agent         | CREATE OR REPLACE FUNCTION public.auto_assign_tasks_to_new_agent()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- This is the core logic:
  -- Insert into the task_assignments table for the new agent (NEW.agent_id)
  -- by selecting all task IDs from the campaign (NEW.campaign_id)
  -- that do NOT already have an assignment for this agent.
  -- Status is now 'assigned' by default, not 'pending'
  INSERT INTO public.task_assignments (task_id, agent_id, status, started_at)
  SELECT
    t.id,          -- The ID of the task
    NEW.agent_id,  -- The ID of the agent who was just assigned to the campaign
    'assigned',    -- Explicitly set to assigned instead of pending
    NOW()          -- Set started_at to current time
  FROM
    public.tasks t
  WHERE
    t.campaign_id = NEW.campaign_id
  ON CONFLICT (task_id, agent_id) DO NOTHING; -- If an assignment already exists, do nothing.

  -- The function must return the new row for an AFTER trigger.
  RETURN NEW;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| public | auto_checkout_on_new_assignment        | CREATE OR REPLACE FUNCTION public.auto_checkout_on_new_assignment()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Auto check-out from any active place visits
    UPDATE place_visits 
    SET 
        checked_out_at = NOW(),
        status = 'completed',
        visit_notes = COALESCE(visit_notes || E'\n', '') || 'Auto checked-out due to new assignment'
    WHERE agent_id = NEW.agent_id 
    AND status = 'checked_in';
    
    RETURN NEW;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| public | auto_update_daily_participation        | CREATE OR REPLACE FUNCTION public.auto_update_daily_participation()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| public | can_create_agent                       | CREATE OR REPLACE FUNCTION public.can_create_agent()
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT (
    (SELECT get_my_creation_count())
    <
    (SELECT COALESCE(agent_creation_limit, 0) FROM public.profiles WHERE id = auth.uid())
  );
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| public | can_update_profile                     | CREATE OR REPLACE FUNCTION public.can_update_profile(target_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    current_user_id UUID;
    current_user_role TEXT;
    target_user_role TEXT;
    shares_group BOOLEAN;
BEGIN
    -- Get current user ID
    current_user_id := auth.uid();
    
    -- User can always update their own profile
    IF current_user_id = target_user_id THEN
        RETURN TRUE;
    END IF;
    
    -- Get current user's role
    SELECT role INTO current_user_role
    FROM profiles
    WHERE id = current_user_id;
    
    -- Admins can update any profile
    IF current_user_role = 'admin' THEN
        RETURN TRUE;
    END IF;
    
    -- Only managers can update other profiles
    IF current_user_role != 'manager' THEN
        RETURN FALSE;
    END IF;
    
    -- Get target user's role
    SELECT role INTO target_user_role
    FROM profiles
    WHERE id = target_user_id;
    
    -- Managers can only update agents
    IF target_user_role != 'agent' THEN
        RETURN FALSE;
    END IF;
    
    -- Check if manager and agent share at least one group
    SELECT EXISTS (
        SELECT 1 
        FROM user_groups ug1
        JOIN user_groups ug2 ON ug1.group_id = ug2.group_id
        WHERE ug1.user_id = current_user_id
        AND ug2.user_id = target_user_id
    ) INTO shares_group;
    
    RETURN shares_group;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| public | check_active_checkin                   | CREATE OR REPLACE FUNCTION public.check_active_checkin()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.status = 'checked_in' THEN
        -- Check if agent already has an active check-in
        IF EXISTS (
            SELECT 1 FROM public.place_visits 
            WHERE agent_id = NEW.agent_id 
            AND status = 'checked_in'
            AND id != NEW.id
        ) THEN
            RAISE EXCEPTION 'Agent already has an active check-in at another place';
        END IF;
    END IF;
    RETURN NEW;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| public | check_agent_in_campaign_geofence       | CREATE OR REPLACE FUNCTION public.check_agent_in_campaign_geofence(p_agent_id uuid, p_campaign_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    latest_location GEOGRAPHY(POINT);
    geofence_area GEOGRAPHY(POLYGON);
    v_intersects_result BOOLEAN := FALSE;
BEGIN
    -- Get the agent's most recent location
    SELECT location INTO latest_location
    FROM location_history
    WHERE user_id = p_agent_id
    ORDER BY recorded_at DESC
    LIMIT 1;

    -- Get the geofence for the campaign
    SELECT area INTO geofence_area
    FROM geofences
    WHERE campaign_id = p_campaign_id
    LIMIT 1;

    -- If either is missing, they can't be inside
    IF latest_location IS NULL OR geofence_area IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Use ST_DWithin for better geography handling (returns true if within 0 meters)
    v_intersects_result := ST_DWithin(latest_location, geofence_area, 0);

    RETURN v_intersects_result;
    
EXCEPTION WHEN OTHERS THEN
    -- Log the error and return false instead of failing
    RAISE LOG 'Error in check_agent_in_campaign_geofence: %', SQLERRM;
    RETURN FALSE;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| public | check_agent_in_place_geofence          | CREATE OR REPLACE FUNCTION public.check_agent_in_place_geofence(place_uuid uuid, agent_lat double precision, agent_lng double precision)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    is_inside BOOLEAN := false;
BEGIN
    -- Check if the agent's location is within any geofence for this place
    SELECT EXISTS (
        SELECT 1 
        FROM geofences g
        WHERE g.place_id = place_uuid
        AND ST_Contains(
            g.area::geometry, 
            ST_SetSRID(ST_Point(agent_lng, agent_lat), 4326)
        )
    ) INTO is_inside;
    
    RETURN is_inside;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| public | check_agent_in_task_geofence           | CREATE OR REPLACE FUNCTION public.check_agent_in_task_geofence(p_agent_id uuid, p_task_id uuid, p_agent_lat double precision, p_agent_lng double precision)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    task_enforce_geofence BOOLEAN;
    agent_point GEOMETRY;
    geofence_geometry GEOMETRY;
    is_inside BOOLEAN := FALSE;
BEGIN
    SELECT enforce_geofence INTO task_enforce_geofence
    FROM tasks
    WHERE id = p_task_id;
    
    IF task_enforce_geofence IS NULL OR task_enforce_geofence = FALSE THEN
        RETURN TRUE;
    END IF;
    
    agent_point := ST_SetSRID(ST_MakePoint(p_agent_lng, p_agent_lat), 4326);
    
    SELECT area INTO geofence_geometry
    FROM geofences
    WHERE task_id = p_task_id
    LIMIT 1;
    
    IF geofence_geometry IS NULL THEN
        RETURN TRUE;
    END IF;
    
    SELECT ST_Within(agent_point, geofence_geometry) INTO is_inside;
    
    RETURN COALESCE(is_inside, FALSE);
END
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| public | check_geofence_capacity                | CREATE OR REPLACE FUNCTION public.check_geofence_capacity(p_geofence_id uuid)
 RETURNS TABLE(current_agents integer, max_agents integer, is_full boolean, available_spots integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(COUNT(aga.id)::INTEGER, 0) as current_agents,
        cg.max_agents,
        (COALESCE(COUNT(aga.id), 0) >= cg.max_agents) as is_full,
        GREATEST(0, cg.max_agents - COALESCE(COUNT(aga.id)::INTEGER, 0)) as available_spots
    FROM public.campaign_geofences cg
    LEFT JOIN public.agent_geofence_assignments aga ON cg.id = aga.geofence_id 
        AND aga.status = 'active'
    WHERE cg.id = p_geofence_id
    GROUP BY cg.id, cg.max_agents;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| public | check_place_visit_availability         | CREATE OR REPLACE FUNCTION public.check_place_visit_availability(p_route_assignment_id uuid, p_place_id uuid, p_agent_id uuid)
 RETURNS TABLE(can_check_in boolean, reason text, completed_visits integer, required_visits integer, last_checkout_time timestamp with time zone, cooldown_remaining_hours numeric)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_visit_frequency INTEGER;
    v_completed_visits INTEGER;
    v_last_checkout TIMESTAMPTZ;
    v_hours_since_checkout NUMERIC;
    v_active_checkin INTEGER;
BEGIN
    -- Check if there's an active check-in
    SELECT COUNT(*) INTO v_active_checkin
    FROM place_visits
    WHERE route_assignment_id = p_route_assignment_id 
    AND place_id = p_place_id 
    AND agent_id = p_agent_id
    AND status = 'checked_in';
    
    IF v_active_checkin > 0 THEN
        RETURN QUERY SELECT 
            FALSE, 
            'Already checked in',
            0,
            0,
            NULL::TIMESTAMPTZ,
            0::NUMERIC;
        RETURN;
    END IF;

    -- Get the required visit frequency for this place
    SELECT rp.visit_frequency INTO v_visit_frequency
    FROM route_places rp
    JOIN route_assignments ra ON ra.route_id = rp.route_id
    WHERE ra.id = p_route_assignment_id AND rp.place_id = p_place_id;
    
    IF v_visit_frequency IS NULL THEN
        v_visit_frequency := 1; -- Default to 1 if not found
    END IF;
    
    -- Count completed visits
    SELECT COUNT(*), MAX(checked_out_at) 
    INTO v_completed_visits, v_last_checkout
    FROM place_visits
    WHERE route_assignment_id = p_route_assignment_id 
    AND place_id = p_place_id 
    AND agent_id = p_agent_id
    AND status = 'completed';
    
    -- Calculate hours since last checkout
    IF v_last_checkout IS NOT NULL THEN
        v_hours_since_checkout := EXTRACT(EPOCH FROM (NOW() - v_last_checkout)) / 3600;
    ELSE
        v_hours_since_checkout := NULL;
    END IF;
    
    -- Determine if check-in is allowed
    IF v_completed_visits >= v_visit_frequency THEN
        RETURN QUERY SELECT 
            FALSE, 
            'All required visits completed',
            v_completed_visits,
            v_visit_frequency,
            v_last_checkout,
            0::NUMERIC;
    ELSIF v_last_checkout IS NOT NULL AND v_hours_since_checkout < 12 THEN
        RETURN QUERY SELECT 
            FALSE, 
            'Cooldown period active',
            v_completed_visits,
            v_visit_frequency,
            v_last_checkout,
            (12 - v_hours_since_checkout)::NUMERIC;
    ELSE
        RETURN QUERY SELECT 
            TRUE, 
            'Check-in available',
            v_completed_visits,
            v_visit_frequency,
            v_last_checkout,
            0::NUMERIC;
    END IF;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| public | check_place_visit_evidence_complete    | CREATE OR REPLACE FUNCTION public.check_place_visit_evidence_complete(visit_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    required_count INTEGER;
    actual_count INTEGER;
BEGIN
    -- Get required evidence count from route_places
    SELECT rp.required_evidence_count INTO required_count
    FROM public.place_visits pv
    JOIN public.route_places rp ON pv.place_id = rp.place_id
    JOIN public.route_assignments ra ON pv.route_assignment_id = ra.id
    WHERE pv.id = visit_id
    AND rp.route_id = ra.route_id;
    
    -- Get actual approved evidence count
    SELECT COUNT(*) INTO actual_count
    FROM public.evidence
    WHERE place_visit_id = visit_id
    AND status = 'approved';
    
    RETURN COALESCE(actual_count, 0) >= COALESCE(required_count, 1);
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| public | check_point_in_geofence                | CREATE OR REPLACE FUNCTION public.check_point_in_geofence(p_lat numeric, p_lng numeric, p_geofence_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    geofence_area geometry;
BEGIN
    SELECT geometry INTO geofence_area
    FROM campaign_geofences
    WHERE id = p_geofence_id;
    
    IF geofence_area IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- IMPORTANT: The polygon is stored as (lat, lng) but ST_Point expects (lng, lat)
    -- So we need to create the point as ST_Point(lat, lng) to match the polygon format
    RETURN ST_Contains(geofence_area, ST_SetSRID(ST_Point(p_lat, p_lng), 4326));
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| public | check_profile_select_permission        | CREATE OR REPLACE FUNCTION public.check_profile_select_permission(target_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    current_user_id UUID;
    current_user_role TEXT;
    target_user_role TEXT;
    has_shared_group BOOLEAN := FALSE;
BEGIN
    -- Get current authenticated user ID
    current_user_id := auth.uid();
    
    -- If no authenticated user, deny access
    IF current_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- User can always view their own profile
    IF current_user_id = target_user_id THEN
        RETURN TRUE;
    END IF;
    
    -- Get current user's role (direct query, no recursion)
    SELECT role INTO current_user_role
    FROM profiles
    WHERE id = current_user_id
    LIMIT 1;
    
    -- If we can't find the current user's role, deny access
    IF current_user_role IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Admins can view any profile
    IF current_user_role = 'admin' THEN
        RETURN TRUE;
    END IF;
    
    -- Get target user's role
    SELECT role INTO target_user_role
    FROM profiles
    WHERE id = target_user_id
    LIMIT 1;
    
    -- Managers can view clients (this is the key addition)
    IF current_user_role = 'manager' AND target_user_role = 'client' THEN
        RETURN TRUE;
    END IF;
    
    -- For other cases, managers can only view agents in shared groups
    IF current_user_role = 'manager' AND target_user_role = 'agent' THEN
        -- Check if manager and agent share at least one group
        SELECT EXISTS (
            SELECT 1 
            FROM user_groups ug_manager
            INNER JOIN user_groups ug_agent 
            ON ug_manager.group_id = ug_agent.group_id
            WHERE ug_manager.user_id = current_user_id
            AND ug_agent.user_id = target_user_id
        ) INTO has_shared_group;
        
        RETURN has_shared_group;
    END IF;
    
    -- For all other roles/combinations, deny access
    RETURN FALSE;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| public | check_profile_update_permission        | CREATE OR REPLACE FUNCTION public.check_profile_update_permission(target_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
    current_user_id UUID;
    current_user_role TEXT;
    target_user_role TEXT;
    has_shared_group BOOLEAN := FALSE;
BEGIN
    -- Get current authenticated user ID
    current_user_id := auth.uid();
    
    -- If no authenticated user, deny access
    IF current_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- User can always update their own profile
    IF current_user_id = target_user_id THEN
        RETURN TRUE;
    END IF;
    
    -- Get current user's role (avoid recursion by using direct query)
    SELECT role INTO current_user_role
    FROM profiles
    WHERE id = current_user_id
    LIMIT 1;
    
    -- If we can't find the current user's role, deny access
    IF current_user_role IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Admins can update any profile
    IF current_user_role = 'admin' THEN
        RETURN TRUE;
    END IF;
    
    -- Only managers can update other users' profiles
    IF current_user_role != 'manager' THEN
        RETURN FALSE;
    END IF;
    
    -- Get target user's role
    SELECT role INTO target_user_role
    FROM profiles
    WHERE id = target_user_id
    LIMIT 1;
    
    -- Managers can only update agents
    IF target_user_role != 'agent' THEN
        RETURN FALSE;
    END IF;
    
    -- Check if manager and agent share at least one group
    SELECT EXISTS (
        SELECT 1 
        FROM user_groups ug_manager
        INNER JOIN user_groups ug_agent 
        ON ug_manager.group_id = ug_agent.group_id
        WHERE ug_manager.user_id = current_user_id
        AND ug_agent.user_id = target_user_id
    ) INTO has_shared_group;
    
    RETURN has_shared_group;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| public | clean_campaigns_policies               | CREATE OR REPLACE FUNCTION public.clean_campaigns_policies()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    -- Drop all potentially conflicting policies by exact name
    DROP POLICY IF EXISTS "Agents can view assigned campaigns" ON campaigns;
    DROP POLICY IF EXISTS "Clients can view their campaigns" ON campaigns;
    DROP POLICY IF EXISTS "Manager campaign access" ON campaigns;
    DROP POLICY IF EXISTS "Managers can create campaigns" ON campaigns;
    DROP POLICY IF EXISTS "Managers can update campaigns" ON campaigns;
    DROP POLICY IF EXISTS "Agent campaign SELECT" ON campaigns;
    DROP POLICY IF EXISTS "Client campaign SELECT" ON campaigns;
    DROP POLICY IF EXISTS "Manager campaign SELECT" ON campaigns;
    DROP POLICY IF EXISTS "Manager campaign INSERT" ON campaigns;
    DROP POLICY IF EXISTS "Manager campaign UPDATE" ON campaigns;
    DROP POLICY IF EXISTS "Admin full access" ON campaigns;
    
    -- Return success message
    RETURN 'Campaigns policies cleaned successfully';
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| public | cleanup_old_sessions                   | CREATE OR REPLACE FUNCTION public.cleanup_old_sessions()
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  DELETE FROM public.sessions 
  WHERE is_active = false 
    AND (updated_at < NOW() - INTERVAL '30 days' 
         OR (updated_at IS NULL AND created_at < NOW() - INTERVAL '30 days'));
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| public | confirm_user_email                     | CREATE OR REPLACE FUNCTION public.confirm_user_email(target_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    current_user_role TEXT;
    target_user_email TEXT;
    rows_updated INTEGER;
BEGIN
    -- Get current user's role
    SELECT role INTO current_user_role
    FROM profiles
    WHERE id = auth.uid();

    -- Check if current user is admin or manager
    IF current_user_role NOT IN ('admin', 'manager') THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Insufficient permissions'
        );
    END IF;

    -- Get target user's email
    SELECT email INTO target_user_email
    FROM profiles
    WHERE id = target_user_id;

    -- Check if target user exists
    IF target_user_email IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User not found'
        );
    END IF;

    -- Update email confirmation in auth.users table
    UPDATE auth.users
    SET 
        email_confirmed_at = CASE 
            WHEN email_confirmed_at IS NULL THEN NOW()
            ELSE email_confirmed_at
        END,
        updated_at = NOW()
    WHERE id = target_user_id;

    GET DIAGNOSTICS rows_updated = ROW_COUNT;

    IF rows_updated = 0 THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Failed to confirm email - user not found in auth system'
        );
    END IF;

    RETURN json_build_object(
        'success', true,
        'message', 'Email confirmed successfully',
        'target_user_email', target_user_email
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Database error: ' || SQLERRM
        );
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| public | create_campaign_geofence               | CREATE OR REPLACE FUNCTION public.create_campaign_geofence(p_campaign_id uuid, p_name text, p_area_text text, p_max_agents integer, p_color text, p_description text DEFAULT NULL::text, p_created_by uuid DEFAULT NULL::uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_geofence_id UUID;
  v_result JSON;
BEGIN
  -- Insert the new geofence
  INSERT INTO campaign_geofences (
    campaign_id,
    name,
    description,
    area_text,
    geometry,
    max_agents,
    color,
    created_by
  ) VALUES (
    p_campaign_id,
    p_name,
    p_description,
    p_area_text,
    ST_GeomFromText(p_area_text, 4326),
    p_max_agents,
    p_color,
    p_created_by
  ) RETURNING id INTO v_geofence_id;

  -- Return the created geofence with additional information
  SELECT json_build_object(
    'id', cg.id,
    'campaign_id', cg.campaign_id,
    'name', cg.name,
    'description', cg.description,
    'area_text', cg.area_text,
    'max_agents', cg.max_agents,
    'color', cg.color,
    'is_active', cg.is_active,
    'created_by', cg.created_by,
    'created_at', cg.created_at,
    'current_agents', 0,
    'is_full', false
  ) INTO v_result
  FROM campaign_geofences cg
  WHERE cg.id = v_geofence_id;

  RETURN v_result;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| public | create_notification                    | CREATE OR REPLACE FUNCTION public.create_notification(p_recipient_id uuid, p_type text, p_title text, p_message text, p_sender_id uuid DEFAULT NULL::uuid, p_data jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO notifications (
    recipient_id,
    sender_id,
    type,
    title,
    message,
    data,
    created_at,
    updated_at
  ) VALUES (
    p_recipient_id,
    p_sender_id,
    p_type,
    p_title,
    p_message,
    p_data,
    NOW(),
    NOW()
  );
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| public | create_touring_task                    | CREATE OR REPLACE FUNCTION public.create_touring_task(p_campaign_id uuid, p_geofence_id uuid, p_title text, p_description text DEFAULT NULL::text, p_required_time_minutes integer DEFAULT 30, p_movement_timeout_seconds integer DEFAULT 60, p_min_movement_threshold numeric DEFAULT 5.0, p_points integer DEFAULT 10, p_use_schedule boolean DEFAULT false, p_daily_start_time text DEFAULT NULL::text, p_daily_end_time text DEFAULT NULL::text)
 RETURNS touring_tasks
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    new_task touring_tasks;
BEGIN
    -- Insert the new touring task
    INSERT INTO touring_tasks (
        campaign_id,
        geofence_id,
        title,
        description,
        required_time_minutes,
        movement_timeout_seconds,
        min_movement_threshold,
        points,
        use_schedule,
        daily_start_time,
        daily_end_time,
        status,
        created_at,
        created_by
    ) VALUES (
        p_campaign_id,
        p_geofence_id,
        p_title,
        p_description,
        p_required_time_minutes,
        p_movement_timeout_seconds,
        p_min_movement_threshold,
        p_points,
        p_use_schedule,
        p_daily_start_time,
        p_daily_end_time,
        'active',
        NOW(),
        auth.uid()
    ) RETURNING * INTO new_task;
    
    RETURN new_task;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| public | daily_status_reset                     | CREATE OR REPLACE FUNCTION public.daily_status_reset()
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.task_assignments
  SET
    status = 'pending',
    completed_at = NULL
  WHERE
    task_id IN (SELECT id FROM public.tasks WHERE reset_status_daily = TRUE);
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| public | debug_location_data                    | CREATE OR REPLACE FUNCTION public.debug_location_data(requesting_user_id uuid)
 RETURNS TABLE(debug_step text, debug_info text, debug_data jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
  DECLARE
      user_role TEXT;
      agent_count INTEGER;
      location_count INTEGER;
      active_agents_count INTEGER;
  BEGIN
      -- Step 1: Check user role
      SELECT p.role INTO user_role
      FROM profiles p
      WHERE p.id = requesting_user_id;

      RETURN QUERY
      SELECT
          'user_role'::TEXT,
          'Current user role check'::TEXT,
          jsonb_build_object('user_id', requesting_user_id, 'role',
   COALESCE(user_role, 'NOT_FOUND'))::JSONB;

      -- Step 2: Count agents
      SELECT COUNT(*) INTO agent_count
      FROM profiles p
      WHERE p.role = 'agent';

      RETURN QUERY
      SELECT
          'agent_count'::TEXT,
          'Total agents in profiles table'::TEXT,
          jsonb_build_object('count', agent_count)::JSONB;

      -- Step 3: Count location_history records
      SELECT COUNT(*) INTO location_count
      FROM location_history;

      RETURN QUERY
      SELECT
          'location_history_count'::TEXT,
          'Total location records'::TEXT,
          jsonb_build_object('count', location_count)::JSONB;

      -- Step 4: Count active_agents records
      SELECT COUNT(*) INTO active_agents_count
      FROM active_agents;

      RETURN QUERY
      SELECT
          'active_agents_count'::TEXT,
          'Total active_agents records'::TEXT,
          jsonb_build_object('count', active_agents_count)::JSONB;

      -- Step 5: Show sample location_history data
      RETURN QUERY
      SELECT
          'location_history_sample'::TEXT,
          'Sample location_history records'::TEXT,
          COALESCE(jsonb_agg(
              jsonb_build_object(
                  'user_id', lh.user_id,
                  'location', lh.location::TEXT,
                  'recorded_at', lh.recorded_at,
                  'accuracy', lh.accuracy
              )
          ), '[]'::jsonb)::JSONB
      FROM (
          SELECT * FROM location_history
          ORDER BY recorded_at DESC
          LIMIT 3
      ) lh;

      -- Step 6: Show sample active_agents data (fixed column names)
      RETURN QUERY
      SELECT
          'active_agents_sample'::TEXT,
          'Sample active_agents records'::TEXT,
          COALESCE(jsonb_agg(
              jsonb_build_object(
                  'user_id', aa.user_id,
                  'last_location', aa.last_location::TEXT,
                  'last_seen', aa.last_seen,
                  'accuracy', aa.accuracy
              )
          ), '[]'::jsonb)::JSONB
      FROM (
          SELECT * FROM active_agents
          ORDER BY last_seen DESC
          LIMIT 3
      ) aa;

      -- Step 7: Show agents with location data joined (fixed JOIN)
      RETURN QUERY
      SELECT
          'agents_with_location'::TEXT,
          'Agents with location data'::TEXT,
          COALESCE(jsonb_agg(
              jsonb_build_object(
                  'agent_id', p.id,
                  'full_name', p.full_name,
                  'location_history_location', lh.location::TEXT,
                  'location_history_time', lh.recorded_at,
                  'active_agents_location', aa.last_location::TEXT,
                  'active_agents_time', aa.last_seen,
                  'heartbeat', p.last_heartbeat
              )
          ), '[]'::jsonb)::JSONB
      FROM profiles p
      LEFT JOIN LATERAL (
          SELECT location, recorded_at
          FROM location_history lh_sub
          WHERE lh_sub.user_id = p.id
          ORDER BY lh_sub.recorded_at DESC
          LIMIT 1
      ) lh ON true
      LEFT JOIN active_agents aa ON aa.user_id = p.id
      WHERE p.role = 'agent'
      LIMIT 5;

  END;
  $function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| public | debug_location_updates                 | CREATE OR REPLACE FUNCTION public.debug_location_updates()
 RETURNS TABLE(user_id uuid, full_name text, role text, heartbeat_status text, heartbeat_age_minutes numeric, location_status text, location_age_minutes numeric, last_heartbeat timestamp with time zone, last_location_update timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    p.role,
    CASE 
      WHEN p.last_heartbeat IS NULL THEN 'NEVER'
      WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 'CURRENT'
      WHEN NOW() - p.last_heartbeat < INTERVAL '5 minutes' THEN 'RECENT'
      WHEN NOW() - p.last_heartbeat < INTERVAL '15 minutes' THEN 'OLD'
      ELSE 'STALE'
    END as heartbeat_status,
    EXTRACT(EPOCH FROM (NOW() - p.last_heartbeat)) / 60 as heartbeat_age_minutes,
    CASE 
      WHEN aa.last_seen IS NULL THEN 'NO LOCATION'
      WHEN NOW() - aa.last_seen < INTERVAL '1 minute' THEN 'CURRENT'
      WHEN NOW() - aa.last_seen < INTERVAL '5 minutes' THEN 'RECENT'
      WHEN NOW() - aa.last_seen < INTERVAL '15 minutes' THEN 'OLD'
      ELSE 'STALE'
    END as location_status,
    EXTRACT(EPOCH FROM (NOW() - aa.last_seen)) / 60 as location_age_minutes,
    p.last_heartbeat,
    aa.last_seen
  FROM profiles p
  LEFT JOIN active_agents aa ON p.id = aa.user_id
  WHERE p.status = 'active' AND p.role IN ('agent', 'manager')
  ORDER BY 
    CASE 
      WHEN p.last_heartbeat IS NULL THEN 3
      WHEN NOW() - p.last_heartbeat < INTERVAL '1 minute' THEN 0
      WHEN NOW() - p.last_heartbeat < INTERVAL '15 minutes' THEN 1
      ELSE 2
    END,
    p.last_heartbeat DESC NULLS LAST;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| public | delete_user_by_admin                   | CREATE OR REPLACE FUNCTION public.delete_user_by_admin(user_id_to_delete uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Check if the user calling this function is an admin
  IF NOT (public.is_user_admin()) THEN
    RAISE EXCEPTION 'Permission denied: You are not an admin.';
  END IF;

  -- Delete the user from auth
  PERFORM auth.admin_delete_user(user_id_to_delete);
  
  RETURN 'User successfully deleted.';
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| public | ensure_agent_in_campaign               | CREATE OR REPLACE FUNCTION public.ensure_agent_in_campaign()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Only process completed tasks
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        -- Get campaign ID from the task
        DECLARE
            task_campaign_id UUID;
        BEGIN
            SELECT t.campaign_id INTO task_campaign_id
            FROM tasks t
            WHERE t.id = NEW.task_id;
            
            -- If this is a campaign task, ensure agent is in campaign_agents
            IF task_campaign_id IS NOT NULL THEN
                INSERT INTO campaign_agents (campaign_id, agent_id, assigned_at)
                VALUES (task_campaign_id, NEW.agent_id, NEW.completed_at)
                ON CONFLICT (campaign_id, agent_id) DO NOTHING;
            END IF;
        END;
    END IF;
    
    RETURN NEW;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| public | ensure_agent_in_campaign_touring       | CREATE OR REPLACE FUNCTION public.ensure_agent_in_campaign_touring()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Only process completed tasks
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        -- Get campaign ID from the touring task
        DECLARE
            task_campaign_id UUID;
        BEGIN
            SELECT tt.campaign_id INTO task_campaign_id
            FROM touring_tasks tt
            WHERE tt.id = NEW.touring_task_id;
            
            -- If this is a campaign task, ensure agent is in campaign_agents
            IF task_campaign_id IS NOT NULL THEN
                INSERT INTO campaign_agents (campaign_id, agent_id, assigned_at)
                VALUES (task_campaign_id, NEW.agent_id, NEW.completed_at)
                ON CONFLICT (campaign_id, agent_id) DO NOTHING;
            END IF;
        END;
    END IF;
    
    RETURN NEW;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| public | get_active_agents                      | CREATE OR REPLACE FUNCTION public.get_active_agents()
 RETURNS TABLE(user_id uuid, full_name text, last_location geography, last_seen timestamp with time zone)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT DISTINCT ON (lh.user_id)
    lh.user_id,
    p.full_name,
    lh.location AS last_location,
    lh.recorded_at AS last_seen
  FROM
    location_history lh
  JOIN
    profiles p ON lh.user_id = p.id
  WHERE
    -- Filter for locations recorded in the last 10 minutes
    lh.recorded_at > (NOW() - INTERVAL '10 minutes')
  ORDER BY
    lh.user_id, lh.recorded_at DESC;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| public | get_active_agents_for_manager          | CREATE OR REPLACE FUNCTION public.get_active_agents_for_manager()
 RETURNS TABLE(user_id uuid, full_name text, last_location geography, last_seen timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    current_user_role TEXT;
    current_user_id UUID;
    user_has_groups BOOLEAN;
BEGIN
    -- Get current user ID and role
    current_user_id := auth.uid();
    current_user_role := get_my_role();
    
    -- If admin, return all agents from active_agents table
    IF current_user_role = 'admin' THEN
        RETURN QUERY
        SELECT 
            aa.user_id,
            p.full_name,
            aa.last_location::geography AS last_location,
            aa.last_seen
        FROM active_agents aa
        JOIN profiles p ON aa.user_id = p.id
        WHERE p.role = 'agent'
        ORDER BY aa.last_seen DESC;
        
    -- If manager or client
    ELSIF current_user_role IN ('manager', 'client') THEN
        -- Check if user has any group assignments
        SELECT EXISTS (
            SELECT 1 FROM user_groups WHERE user_id = current_user_id
        ) INTO user_has_groups;
        
        -- If user has groups, show only agents in their groups
        IF user_has_groups THEN
            RETURN QUERY
            SELECT 
                aa.user_id,
                p.full_name,
                aa.last_location::geography AS last_location,
                aa.last_seen
            FROM active_agents aa
            JOIN profiles p ON aa.user_id = p.id
            JOIN user_groups ug_agent ON ug_agent.user_id = aa.user_id
            JOIN user_groups ug_current_user ON ug_current_user.group_id = ug_agent.group_id
            WHERE ug_current_user.user_id = current_user_id
            AND p.role = 'agent'
            ORDER BY aa.last_seen DESC;
        ELSE
            -- If user has no groups, show all agents (backward compatibility)
            RETURN QUERY
            SELECT 
                aa.user_id,
                p.full_name,
                aa.last_location::geography AS last_location,
                aa.last_seen
            FROM active_agents aa
            JOIN profiles p ON aa.user_id = p.id
            WHERE p.role = 'agent'
            ORDER BY aa.last_seen DESC;
        END IF;
        
    -- For other roles, return empty result
    ELSE
        RETURN;
    END IF;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| public | get_agent_campaign_details             | CREATE OR REPLACE FUNCTION public.get_agent_campaign_details(p_agent_id uuid, p_campaign_id uuid)
 RETURNS jsonb
 LANGUAGE sql
AS $function$
  SELECT
    jsonb_build_object(
      -- Section 1: Agent's earnings summary for this campaign
      'earnings', (
        SELECT
          jsonb_build_object(
            'total_points', COALESCE(SUM(t.points), 0),
            'paid_points', COALESCE((SELECT SUM(p.amount) FROM public.payments p WHERE p.agent_id = p_agent_id AND p.campaign_id = p_campaign_id), 0)
          )
        FROM
          public.task_assignments ta
        JOIN
          public.tasks t ON ta.task_id = t.id
        WHERE
          ta.agent_id = p_agent_id AND
          t.campaign_id = p_campaign_id AND
          ta.status = 'completed'
      ),
      -- Section 2: List of all tasks assigned to the agent in this campaign
      'tasks', (
        SELECT
          COALESCE(jsonb_agg(
            jsonb_build_object(
              'id', t.id,
              'title', t.title,
              'description', t.description,
              'points', t.points,
              'status', ta.status,
              'evidence_required', t.required_evidence_count,
              'evidence_uploaded', (
                SELECT COUNT(*) FROM public.evidence e WHERE e.task_assignment_id = ta.id
              )
            )
          ), '[]'::jsonb)
        FROM
          public.tasks t
        JOIN
          public.task_assignments ta ON t.id = ta.task_id
        WHERE
          t.campaign_id = p_campaign_id AND
          ta.agent_id = p_agent_id
      ),
      -- Section 3: Flat list of all evidence files for this agent in this campaign
      'files', (
        SELECT
          COALESCE(jsonb_agg(
            jsonb_build_object(
              'id', e.id,
              'title', e.title,
              'file_url', e.file_url,
              'created_at', e.created_at,
              'task_title', t.title
            ) ORDER BY e.created_at DESC
          ), '[]'::jsonb)
        FROM
          public.evidence e
        JOIN
          public.task_assignments ta ON e.task_assignment_id = ta.id
        JOIN
          public.tasks t ON ta.task_id = t.id
        WHERE
          ta.agent_id = p_agent_id AND
          t.campaign_id = p_campaign_id
      )
    )
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| public | get_agent_campaign_details_fixed       | CREATE OR REPLACE FUNCTION public.get_agent_campaign_details_fixed(p_campaign_id uuid, p_agent_id uuid)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT
    jsonb_build_object(
      'earnings', (
        SELECT
          jsonb_build_object(
            'total_points', COALESCE(SUM(t.points), 0),
            'paid_points', COALESCE((SELECT SUM(p.amount) FROM public.payments p WHERE p.agent_id = p_agent_id AND p.campaign_id = p_campaign_id), 0)
          )
        FROM
          public.task_assignments ta
        JOIN
          public.tasks t ON ta.task_id = t.id
        WHERE
          ta.agent_id = p_agent_id AND
          t.campaign_id = p_campaign_id AND
          ta.status = 'completed'
      ),
      'tasks', (
        SELECT
          COALESCE(jsonb_agg(
            jsonb_build_object(
              'id', t.id,
              'title', t.title,
              'description', t.description,
              'points', t.points,
              'status', ta.status,
              'evidence_required', t.required_evidence_count,
              'evidence_uploaded', COALESCE(array_length(ta.evidence_urls, 1), 0)
            )
          ), '[]'::jsonb)
        FROM
          public.tasks t
        JOIN
          public.task_assignments ta ON t.id = ta.task_id
        WHERE
          t.campaign_id = p_campaign_id AND
          ta.agent_id = p_agent_id
      ),
      'files', (
        WITH evidence_files AS (
          SELECT 
            ta.id as assignment_id,
            t.title as task_title,
            evidence_url,
            COALESCE(ta.completed_at, ta.started_at, t.created_at) as file_date,
            ROW_NUMBER() OVER (PARTITION BY ta.id ORDER BY evidence_url) as file_index
          FROM
            public.task_assignments ta
          JOIN
            public.tasks t ON ta.task_id = t.id
          CROSS JOIN LATERAL unnest(COALESCE(ta.evidence_urls, ARRAY[]::text[])) AS evidence_url
          WHERE
            ta.agent_id = p_agent_id AND
            t.campaign_id = p_campaign_id AND
            ta.evidence_urls IS NOT NULL AND
            array_length(ta.evidence_urls, 1) > 0
        )
        SELECT
          COALESCE(jsonb_agg(
            jsonb_build_object(
              'id', assignment_id || '_' || file_index::text,
              'title', 'Evidence ' || file_index::text,
              'file_url', evidence_url,
              'created_at', file_date,
              'task_title', task_title
            ) ORDER BY file_date DESC
          ), '[]'::jsonb)
        FROM evidence_files
      )
    )
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| public | get_agent_earnings_for_campaign        | CREATE OR REPLACE FUNCTION public.get_agent_earnings_for_campaign(p_agent_id uuid, p_campaign_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| public | get_agent_location_history             | CREATE OR REPLACE FUNCTION public.get_agent_location_history(p_agent_id uuid, p_start_date timestamp with time zone, p_end_date timestamp with time zone, p_limit integer DEFAULT 1000)
 RETURNS TABLE(id uuid, user_id uuid, latitude double precision, longitude double precision, accuracy real, speed real, recorded_at timestamp with time zone, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    -- Check if user is authenticated
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT 
        lh.id,
        lh.user_id,
        ST_Y(lh.location::geometry) as latitude,
        ST_X(lh.location::geometry) as longitude,
        lh.accuracy,
        lh.speed,
        lh.recorded_at,
        lh.recorded_at as created_at  -- Alias for app compatibility
    FROM location_history lh
    WHERE lh.user_id = p_agent_id
    AND lh.recorded_at >= p_start_date
    AND lh.recorded_at <= p_end_date
    ORDER BY lh.recorded_at DESC
    LIMIT p_limit;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| public | get_agent_overall_earnings             | CREATE OR REPLACE FUNCTION public.get_agent_overall_earnings(p_agent_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| public | get_agent_progress_for_campaign        | CREATE OR REPLACE FUNCTION public.get_agent_progress_for_campaign(p_campaign_id uuid, p_agent_id uuid)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
  caller_id uuid := auth.uid();
  agent_creator_id uuid;
  progress_summary json;
  evidence_list json;
BEGIN
  -- Security Check: Ensure the caller is the creator of the agent they are querying.
  -- An admin can view anyone's progress.
  SELECT created_by INTO agent_creator_id FROM public.profiles WHERE id = p_agent_id;
  
  IF (SELECT role FROM public.profiles WHERE id = caller_id) != 'admin' AND agent_creator_id != caller_id THEN
    RAISE EXCEPTION 'You are not authorized to view this agent''s progress.';
  END IF;

  -- 1. Get the progress summary
  SELECT
    json_build_object(
      'tasks_assigned', COUNT(*),
      'tasks_completed', COUNT(*) FILTER (WHERE status = 'completed')
    )
  INTO
    progress_summary
  FROM
    public.task_assignments
  WHERE
    agent_id = p_agent_id AND
    task_id IN (SELECT id FROM public.tasks WHERE campaign_id = p_campaign_id);

  -- 2. Get the list of evidence files
  SELECT
    COALESCE(json_agg(
      json_build_object(
        'id', e.id,
        'title', e.title,
        'file_url', e.file_url,
        'created_at', e.created_at,
        'task_title', t.title
      ) ORDER BY e.created_at DESC
    ), '[]'::json)
  INTO
    evidence_list
  FROM
    public.evidence e
  JOIN
    public.task_assignments ta ON e.task_assignment_id = ta.id
  JOIN
    public.tasks t ON ta.task_id = t.id
  WHERE
    ta.agent_id = p_agent_id AND
    t.campaign_id = p_campaign_id;

  -- 3. Combine and return the final JSON object
  RETURN json_build_object(
    'summary', progress_summary,
    'evidence', evidence_list
  );
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| public | get_agent_progress_for_task            | CREATE OR REPLACE FUNCTION public.get_agent_progress_for_task(p_task_id uuid, p_agent_id uuid)
 RETURNS TABLE(agent_name text, assignment_status text, evidence_required integer, evidence_uploaded integer, points_total integer, points_paid integer, outstanding_balance integer)
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        p.full_name AS agent_name,
        ta.status AS assignment_status,
        t.required_evidence_count AS evidence_required,
        (SELECT COUNT(*) FROM public.evidence e WHERE e.task_assignment_id = ta.id)::INT AS evidence_uploaded,
        t.points AS points_total,
        (SELECT COALESCE(SUM(py.amount), 0)::INT FROM public.payments py WHERE py.agent_id = p_agent_id AND py.task_id = p_task_id) AS points_paid,
        (t.points - (SELECT COALESCE(SUM(py.amount), 0)::INT FROM public.payments py WHERE py.agent_id = p_agent_id AND py.task_id = p_task_id))::INT AS outstanding_balance
    FROM
        public.task_assignments ta
    JOIN
        public.profiles p ON ta.agent_id = p.id
    JOIN
        public.tasks t ON ta.task_id = t.id
    WHERE
        ta.task_id = p_task_id AND ta.agent_id = p_agent_id;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| public | get_agent_survey_submissions           | CREATE OR REPLACE FUNCTION public.get_agent_survey_submissions(agent_uuid uuid, campaign_uuid uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE result JSON; BEGIN
  SELECT COALESCE(json_agg(json_build_object(
    'submission_id', ss.id,
    'survey_id', ss.survey_id,
    'survey_title', tts.title,
    'task_title', tt.title,
    'touring_task_id', ss.touring_task_id,
    'submitted_at', ss.submitted_at,
    'location', json_build_object('latitude', ss.latitude, 'longitude', ss.longitude),
    'data', ss.submission_data
  ) ORDER BY ss.submitted_at DESC), '[]'::json) INTO result
  FROM survey_submissions ss
  JOIN touring_task_surveys tts ON ss.survey_id = tts.id
  JOIN touring_tasks tt ON tts.touring_task_id = tt.id
  JOIN campaigns c ON tt.campaign_id = c.id
  WHERE ss.agent_id = agent_uuid AND c.id = campaign_uuid;
  RETURN result;
END; $function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| public | get_agent_tasks_for_campaign           | CREATE OR REPLACE FUNCTION public.get_agent_tasks_for_campaign(p_campaign_id uuid)
 RETURNS TABLE(task_id uuid, title text, description text, points integer, assignment_status text, evidence_urls text[])
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        t.id AS task_id,
        t.title,
        t.description,
        t.points,
        COALESCE(ta.status, 'pending') AS assignment_status, -- Shows 'pending' if not yet assigned
        ta.evidence_urls
    FROM
        public.tasks t
    LEFT JOIN
        public.task_assignments ta ON t.id = ta.task_id AND ta.agent_id = auth.uid()
    WHERE
        t.campaign_id = p_campaign_id
    ORDER BY
        t.created_at;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| public | get_agents_in_geofence                 | CREATE OR REPLACE FUNCTION public.get_agents_in_geofence(geofence_id uuid)
 RETURNS TABLE(agent_id uuid, agent_name text, last_location text, last_seen timestamp with time zone, distance_meters numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        aa.user_id,
        p.full_name,
        ST_AsText(aa.location_geo) as last_location,
        aa.last_seen,
        ST_Distance(aa.location_geo, g.area) as distance_meters
    FROM public.active_agents aa
    JOIN public.profiles p ON aa.user_id = p.id
    JOIN public.geofences g ON g.id = geofence_id
    WHERE aa.location_geo IS NOT NULL
    AND ST_DWithin(aa.location_geo, g.area, 0)
    AND p.role = 'agent'
    ORDER BY distance_meters;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| public | get_agents_in_manager_groups           | CREATE OR REPLACE FUNCTION public.get_agents_in_manager_groups(manager_user_id uuid)
 RETURNS TABLE(user_id uuid, full_name text, last_location geography, last_seen timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (lh.user_id)
    lh.user_id,
    p.full_name,
    lh.location AS last_location,
    lh.recorded_at AS last_seen
  FROM
    location_history lh
  JOIN
    profiles p ON lh.user_id = p.id
  JOIN
    user_groups ug_agent ON p.id = ug_agent.user_id
  JOIN
    user_groups ug_manager ON ug_agent.group_id = ug_manager.group_id
  WHERE
    ug_manager.user_id = manager_user_id
    AND p.role = 'agent'
    AND lh.recorded_at > (NOW() - INTERVAL '10 minutes')
  ORDER BY
    lh.user_id, lh.recorded_at DESC;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| public | get_agents_with_last_location          | CREATE OR REPLACE FUNCTION public.get_agents_with_last_location()
 RETURNS TABLE(id uuid, full_name text, username text, role text, status text, connection_status text, last_heartbeat timestamp with time zone, last_location text, last_seen timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
  BEGIN
    RETURN QUERY
    SELECT
      p.id,
      p.full_name,
      p.username,
      p.role,
      p.status,
      CASE
        WHEN p.last_heartbeat IS NULL THEN
  'offline'
        WHEN NOW() - p.last_heartbeat < INTERVAL
  '45 seconds' THEN 'active'
        WHEN NOW() - p.last_heartbeat < INTERVAL
  '10 minutes' THEN 'away'
        ELSE 'offline'
      END as connection_status,
      p.last_heartbeat,
      CASE
        WHEN aa.last_location IS NOT NULL THEN
          'POINT(' || aa.last_location[0] || ' ' ||
   aa.last_location[1] || ')'
        ELSE NULL
      END as last_location,
      aa.last_seen
    FROM profiles p
    LEFT JOIN active_agents aa ON aa.user_id = p.id
    WHERE p.status = 'active'
      AND p.role = 'agent'  -- ONLY AGENTS, NOT MANAGERS
      AND p.last_heartbeat IS NOT NULL
      AND p.last_heartbeat > NOW() - INTERVAL '24 
  hours'
    ORDER BY
      CASE
        WHEN NOW() - p.last_heartbeat < INTERVAL
  '45 seconds' THEN 1
        WHEN NOW() - p.last_heartbeat < INTERVAL
  '10 minutes' THEN 2
        ELSE 3
      END,
      p.last_heartbeat DESC NULLS LAST,
      aa.last_seen DESC NULLS LAST;
  END;
  $function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| public | get_agents_within_radius               | CREATE OR REPLACE FUNCTION public.get_agents_within_radius(center_lat double precision, center_lng double precision, radius_meters integer DEFAULT 1000)
 RETURNS TABLE(agent_id uuid, agent_name text, last_location text, last_seen timestamp with time zone, distance_meters numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    center_point geography;
BEGIN
    center_point := ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography;
    
    RETURN QUERY
    SELECT 
        aa.user_id,
        p.full_name,
        ST_AsText(aa.location_geo) as last_location,
        aa.last_seen,
        ST_Distance(aa.location_geo, center_point) as distance_meters
    FROM public.active_agents aa
    JOIN public.profiles p ON aa.user_id = p.id
    WHERE aa.location_geo IS NOT NULL
    AND ST_DWithin(aa.location_geo, center_point, radius_meters)
    AND p.role = 'agent'
    ORDER BY distance_meters;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| public | get_all_agents_for_admin               | CREATE OR REPLACE FUNCTION public.get_all_agents_for_admin()
 RETURNS TABLE(id uuid, full_name text, username text, email text, role text, status text, connection_status text, last_heartbeat timestamp with time zone, last_location text, last_seen timestamp with time zone, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    p.username,
    COALESCE(u.email, p.email)::TEXT as email,  -- Cast to TEXT to match return type
    p.role,
    p.status,
    CASE 
      WHEN p.last_heartbeat IS NULL THEN 'offline'
      WHEN NOW() - p.last_heartbeat < INTERVAL '45 seconds' THEN 'active'
      WHEN NOW() - p.last_heartbeat < INTERVAL '10 minutes' THEN 'away'
      ELSE 'offline'
    END as connection_status,
    p.last_heartbeat,
    CASE 
      WHEN aa.last_location IS NOT NULL THEN 
        'POINT(' || aa.last_location[0] || ' ' || aa.last_location[1] || ')'
      ELSE NULL
    END as last_location,
    aa.last_seen,
    p.created_at
  FROM profiles p
  LEFT JOIN auth.users u ON p.id = u.id
  LEFT JOIN active_agents aa ON aa.user_id = p.id
  WHERE p.status = 'active' 
    AND p.role = 'agent'
  ORDER BY 
    CASE 
      WHEN NOW() - p.last_heartbeat < INTERVAL '45 seconds' THEN 1
      WHEN NOW() - p.last_heartbeat < INTERVAL '10 minutes' THEN 2
      ELSE 3
    END,
    p.last_heartbeat DESC NULLS LAST,
    aa.last_seen DESC NULLS LAST,
    p.full_name;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| public | get_all_agents_with_location_for_admin | CREATE OR REPLACE FUNCTION public.get_all_agents_with_location_for_admin(requesting_user_id uuid)
 RETURNS TABLE(id uuid, full_name text, role text, status text, last_heartbeat timestamp with time zone, last_location text, last_seen timestamp with time zone, connection_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
  DECLARE
      user_role TEXT;
  BEGIN
      -- Check if the requesting user is an admin
      SELECT p.role INTO user_role
      FROM profiles p
      WHERE p.id = requesting_user_id;

      -- Only allow admin users to access this function
      IF user_role != 'admin' THEN
          RETURN;
      END IF;

      -- Return all agents with their location data
      RETURN QUERY
      SELECT
          p.id,
          p.full_name,
          p.role,
          p.status,
          p.last_heartbeat,
          CASE
              WHEN aa.last_location IS NOT NULL THEN
                  'POINT' || aa.last_location::TEXT
              ELSE NULL
          END as last_location,
          aa.last_seen as last_seen,
          CASE
              WHEN p.last_heartbeat IS NULL THEN 'offline'
              WHEN EXTRACT(EPOCH FROM (NOW() - p.last_heartbeat)) <
   45 THEN 'active'
              WHEN EXTRACT(EPOCH FROM (NOW() - p.last_heartbeat)) <
   600 THEN 'away'
              ELSE 'offline'
          END as connection_status
      FROM profiles p
      LEFT JOIN active_agents aa ON aa.user_id = p.id
      WHERE p.role = 'agent'
      ORDER BY p.full_name;
  END;
  $function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| public | get_all_geofences_wkt                  | CREATE OR REPLACE FUNCTION public.get_all_geofences_wkt()
 RETURNS TABLE(geofence_id uuid, geofence_name text, geofence_area_wkt text, geofence_type text, geofence_color text, campaign_id uuid, campaign_name text, touring_task_id uuid, touring_task_title text, max_agents integer, is_active boolean, touring_tasks_info text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        cg.id as geofence_id,
        cg.name as geofence_name,
        cg.area_text as geofence_area_wkt,
        'campaign'::TEXT as geofence_type,
        COALESCE(cg.color, 'FFA500') as geofence_color,
        cg.campaign_id,
        c.name as campaign_name,
        NULL::UUID as touring_task_id,
        NULL::TEXT as touring_task_title,
        cg.max_agents,
        cg.is_active,
        (
            SELECT STRING_AGG(tt.title, ', ')
            FROM touring_tasks tt
            WHERE tt.geofence_id = cg.id AND tt.status = 'active'
        ) as touring_tasks_info
    FROM campaign_geofences cg
    JOIN campaigns c ON cg.campaign_id = c.id
    WHERE cg.is_active = true;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| public | get_area_wkt                           | CREATE OR REPLACE FUNCTION public.get_area_wkt(g geofences)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT ST_AsText(g.area);
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| public | get_assigned_agents                    | CREATE OR REPLACE FUNCTION public.get_assigned_agents(p_campaign_id uuid)
 RETURNS TABLE(id uuid, full_name text)
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
    SELECT
      p.id,
      p.full_name
    FROM
      profiles AS p
    JOIN
      campaign_agents AS ca ON p.id = ca.agent_id
    WHERE
      ca.campaign_id = p_campaign_id;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| public | get_available_geofences_for_campaign   | CREATE OR REPLACE FUNCTION public.get_available_geofences_for_campaign(p_campaign_id uuid)
 RETURNS TABLE(id uuid, campaign_id uuid, name text, description text, max_agents integer, current_agents integer, is_full boolean, available_spots integer, color text, area_text text, is_active boolean, created_at timestamp with time zone, updated_at timestamp with time zone, created_by uuid)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        cg.id,
        cg.campaign_id,
        cg.name,
        cg.description,
        cg.max_agents,
        COALESCE(COUNT(aga.id)::INTEGER, 0) as current_agents,
        (COALESCE(COUNT(aga.id), 0) >= cg.max_agents) as is_full,
        GREATEST(0, cg.max_agents - COALESCE(COUNT(aga.id)::INTEGER, 0)) as available_spots,
        cg.color,
        cg.area_text,
        cg.is_active,
        cg.created_at,
        cg.updated_at,
        cg.created_by
    FROM public.campaign_geofences cg
    LEFT JOIN public.agent_geofence_assignments aga ON cg.id = aga.geofence_id 
        AND aga.status = 'active'
    WHERE cg.campaign_id = p_campaign_id 
        AND cg.is_active = TRUE
    GROUP BY cg.id, cg.campaign_id, cg.name, cg.description, cg.max_agents, cg.color, cg.area_text, cg.is_active, cg.created_at, cg.updated_at, cg.created_by
    ORDER BY cg.name;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| public | get_calendar_events                    | CREATE OR REPLACE FUNCTION public.get_calendar_events(month_start text, month_end text)
 RETURNS TABLE(id uuid, title text, type text, start_date date, end_date date, description text, status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
  DECLARE
      current_user_id UUID := auth.uid();
      user_role TEXT;
      user_group_ids UUID[];
  BEGIN
      -- Get user role
      SELECT p.role INTO user_role FROM profiles
  p WHERE p.id = current_user_id;

      -- If admin, show all events
      IF user_role = 'admin' THEN
          RETURN QUERY
          SELECT
              c.id, c.name as title,
  'campaign'::text as type,
              c.start_date::DATE,
  COALESCE(c.end_date::DATE, c.start_date::DATE)
  as end_date,
              c.description, c.status
          FROM campaigns c
          WHERE c.start_date::DATE <=
  month_end::DATE
          AND COALESCE(c.end_date::DATE,
  c.start_date::DATE) >= month_start::DATE
          AND c.status IN ('active', 'draft',
  'completed')

          UNION ALL

          SELECT
              t.id, t.title as title,
  'task'::text as type,
              t.created_at::DATE as start_date,
  t.created_at::DATE as end_date,
              t.description, t.status
          FROM tasks t
          WHERE t.campaign_id IS NULL
          AND t.created_at::DATE <=
  month_end::DATE
          AND t.created_at::DATE >=
  month_start::DATE
          AND t.status IN ('active', 'draft',
  'completed')

          UNION ALL

          SELECT
              pv.id, COALESCE(p.name || ' Visit',
   'Place Visit') as title,
              'route_visit'::text as type,
              COALESCE(pv.checked_in_at::DATE,
  pv.created_at::DATE) as start_date,
              COALESCE(pv.checked_out_at::DATE,
  pv.checked_in_at::DATE, pv.created_at::DATE) as
   end_date,
              COALESCE(pv.visit_notes, 'Route 
  place visit') as description,
              pv.status
          FROM place_visits pv
          JOIN places p ON p.id = pv.place_id
          WHERE COALESCE(pv.checked_in_at::DATE,
  pv.created_at::DATE) <= month_end::DATE
          AND COALESCE(pv.checked_in_at::DATE,
  pv.created_at::DATE) >= month_start::DATE
          AND pv.status IN ('pending',
  'checked_in', 'completed')

          ORDER BY start_date, title;
          RETURN;
      END IF;

      -- For managers and agents, get their grouIDs
      SELECT ARRAY_AGG(ug.group_id) INTO
  user_group_ids
      FROM user_groups ug
      WHERE ug.user_id = current_user_id;

      -- If no groups, return empty
      IF user_group_ids IS NULL OR
  array_length(user_group_ids, 1) IS NULL THEN
          RETURN;
      END IF;

      RETURN QUERY
      -- Get campaigns (group-filtered)
      SELECT
          c.id, c.name as title, 'campaign'::text
   as type,
          c.start_date::DATE,
  COALESCE(c.end_date::DATE, c.start_date::DATE)
  as end_date,
          c.description, c.status
      FROM campaigns c
      WHERE c.start_date::DATE <= month_end::DATE
      AND COALESCE(c.end_date::DATE,
  c.start_date::DATE) >= month_start::DATE
      AND c.status IN ('active', 'draft',
  'completed')
      AND (
          c.created_by = current_user_id OR -- Own campaigns
          c.created_by IN ( -- Campaigns from group members
              SELECT ug2.user_id
              FROM user_groups ug2
              WHERE ug2.group_id =
  ANY(user_group_ids)
          )
      )

      UNION ALL

      -- Get standalone tasks (group-filtered)
      SELECT
          t.id, t.title as title, 'task'::text as
   type,
          t.created_at::DATE as start_date,
  t.created_at::DATE as end_date,
          t.description, t.status
      FROM tasks t
      WHERE t.campaign_id IS NULL
      AND t.created_at::DATE <= month_end::DATE
      AND t.created_at::DATE >= month_start::DATE
      AND t.status IN ('active', 'draft',
  'completed')
      AND (
          t.created_by = current_user_id OR -- Own tasks
          t.created_by IN ( -- Tasks from group members
              SELECT ug3.user_id
              FROM user_groups ug3
              WHERE ug3.group_id =
  ANY(user_group_ids)
          )
      )

      UNION ALL

      -- Get route visits (group-filtered)
      SELECT
          pv.id, COALESCE(pl.name || ' Visit',
  'Place Visit') as title,
          'route_visit'::text as type,
          COALESCE(pv.checked_in_at::DATE,
  pv.created_at::DATE) as start_date,
          COALESCE(pv.checked_out_at::DATE,
  pv.checked_in_at::DATE, pv.created_at::DATE) as
   end_date,
          COALESCE(pv.visit_notes, 'Route place 
  visit') as description,
          pv.status
      FROM place_visits pv
      JOIN places pl ON pl.id = pv.place_id
      WHERE COALESCE(pv.checked_in_at::DATE,
  pv.created_at::DATE) <= month_end::DATE
      AND COALESCE(pv.checked_in_at::DATE,
  pv.created_at::DATE) >= month_start::DATE
      AND pv.status IN ('pending', 'checked_in',
  'completed')
      AND (
          pv.agent_id = current_user_id OR -- Ownvisits
          pv.agent_id IN ( -- Visits from group members
              SELECT ug4.user_id
              FROM user_groups ug4
              WHERE ug4.group_id =
  ANY(user_group_ids)
          )
      )

      ORDER BY start_date, title;
  END;
  $function$
 |
| public | get_campaign_report_data               | CREATE OR REPLACE FUNCTION public.get_campaign_report_data(p_campaign_id uuid)
 RETURNS TABLE(total_tasks bigint, completed_tasks bigint, total_points_earned bigint, assigned_agents bigint)
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        -- 1. Count all tasks associated with this campaign
        (SELECT COUNT(*) FROM public.tasks WHERE campaign_id = p_campaign_id) AS total_tasks,

        -- 2. Count only the tasks that are marked 'completed'
        (SELECT COUNT(*)
         FROM public.task_assignments ta
         JOIN public.tasks t ON ta.task_id = t.id
         WHERE t.campaign_id = p_campaign_id AND ta.status = 'completed'
        ) AS completed_tasks,

        -- 3. Sum the points of all completed tasks for this campaign
        (SELECT COALESCE(SUM(t.points), 0)
         FROM public.task_assignments ta
         JOIN public.tasks t ON ta.task_id = t.id
         WHERE t.campaign_id = p_campaign_id AND ta.status = 'completed'
        ) AS total_points_earned,

        -- 4. Count the number of unique agents assigned to this campaign
        (SELECT COUNT(DISTINCT agent_id) FROM public.campaign_agents WHERE campaign_id = p_campaign_id) AS assigned_agents;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| public | get_campaign_survey_stats              | CREATE OR REPLACE FUNCTION public.get_campaign_survey_stats(campaign_uuid uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE result JSON; BEGIN
  SELECT json_build_object(
    'total_surveys', COUNT(DISTINCT tts.id),
    'total_submissions', COUNT(DISTINCT ss.id),
    'unique_agents_submitted', COUNT(DISTINCT ss.agent_id),
    'completion_rate', CASE WHEN COUNT(DISTINCT tts.id) > 0
      THEN ROUND((COUNT(DISTINCT ss.id)::DECIMAL / COUNT(DISTINCT tts.id)) * 100, 2)
      ELSE 0 END,
    'surveys_by_task', COALESCE(json_agg(DISTINCT json_build_object(
        'task_id', tt.id,
        'task_title', tt.title,
        'survey_id', tts.id,
        'survey_title', tts.title,
        'submissions_count', (SELECT COUNT(*) FROM survey_submissions ss2 WHERE ss2.survey_id = tts.id)
      )) FILTER (WHERE tts.id IS NOT NULL), '[]'::json)
  ) INTO result
  FROM campaigns c
  LEFT JOIN touring_tasks tt ON c.id = tt.campaign_id
  LEFT JOIN touring_task_surveys tts ON tt.id = tts.touring_task_id
  LEFT JOIN survey_submissions ss ON tts.id = ss.survey_id
  WHERE c.id = campaign_uuid;
  RETURN result;
END; $function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| public | get_campaigns_scoped                   | CREATE OR REPLACE FUNCTION public.get_campaigns_scoped(manager_user_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(id uuid, name text, description text, status text, start_date date, end_date date, created_at timestamp with time zone, created_by uuid, assigned_manager_id uuid, client_id uuid, package_type text, reset_status_daily boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.name,
        c.description,
        c.status,
        c.start_date,
        c.end_date,
        c.created_at,
        c.created_by,
        c.assigned_manager_id,
        c.client_id,
        c.package_type,
        c.reset_status_daily
    FROM campaigns c
    WHERE (
        manager_user_id IS NULL -- Admin case: show all campaigns
        OR c.created_by = manager_user_id -- Manager created the campaign
        OR c.assigned_manager_id = manager_user_id -- Manager is assigned to the campaign
        OR EXISTS ( -- Manager has agents in the campaign
            SELECT 1 
            FROM campaign_agents ca
            JOIN user_groups ug_agent ON ca.agent_id = ug_agent.user_id
            JOIN user_groups ug_manager ON ug_agent.group_id = ug_manager.group_id
            WHERE ca.campaign_id = c.id
            AND ug_manager.user_id = manager_user_id
        )
    )
    ORDER BY c.created_at DESC;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| public | get_current_user_id                    | CREATE OR REPLACE FUNCTION public.get_current_user_id()
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    -- Return the authenticated user ID, or null if not authenticated
    RETURN auth.uid();
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| public | get_dashboard_metrics                  | CREATE OR REPLACE FUNCTION public.get_dashboard_metrics()
 RETURNS TABLE(total_accounts bigint, total_accounts_change bigint, active_groups bigint, active_groups_change bigint, active_campaigns bigint, active_campaigns_change bigint, completed_tasks bigint, completed_tasks_change bigint, connected_agents bigint, total_agents bigint, active_routes bigint, points_granted numeric, points_granted_change numeric, new_accounts bigint, new_accounts_change bigint, pending_tasks bigint, pending_points bigint)
 LANGUAGE sql
 STABLE
AS $function$
with now_ts as (
  select now() as now
),
current_month as (
  select date_trunc('month', (select now from now_ts)) as start
),
last_month as (
  select (date_trunc('month', (select now from now_ts)) - interval '1 month') as start
),
current_week as (
  select (select now from now_ts) - interval '7 days' as start
),
last_week as (
  select (select now from now_ts) - interval '14 days' as start
),
five_minutes_ago as (
  select (select now from now_ts) - interval '5 minutes' as ts
),
accounts as (
  select 
    count(*)::bigint as total,
    count(*) filter (where created_at >= (select start from current_month))::bigint as this_month,
    count(*) filter (where created_at >= (select start from last_month) and created_at < (select start from current_month))::bigint as last_month
  from profiles
),
groups_cte as (
  select 
    count(*)::bigint as total,
    count(*) filter (where created_at >= (select start from current_month))::bigint as this_month,
    count(*) filter (where created_at >= (select start from last_month) and created_at < (select start from current_month))::bigint as last_month
  from groups
),
campaigns_cte as (
  select
    count(*) filter (where status in ('active','in_progress','ongoing'))::bigint as active_total,
    count(*) filter (where created_at >= (select start from current_week))::bigint as this_week,
    count(*) filter (where created_at >= (select start from last_week) and created_at < (select start from current_week))::bigint as last_week
  from campaigns
),
tasks_cte as (
  select
    count(*) filter (where status = 'completed')::bigint as completed_total,
    count(*) filter (where status = 'completed' and completed_at >= (select start from current_month))::bigint as this_month,
    count(*) filter (where status = 'completed' and completed_at >= (select start from last_month) and completed_at < (select start from current_month))::bigint as last_month
  from task_assignments
),
agents_cte as (
  select
    count(*)::bigint as total_agents,
    count(*) filter (where connection_status = 'online' or (last_seen is not null and last_seen >= (select ts from five_minutes_ago)))::bigint as connected
  from active_agents
),
routes_cte as (
  select count(*) filter (where status in ('active','in_progress','ongoing'))::bigint as active_total
  from routes
),
payments_cte as (
  select
    coalesce(sum(payment_amount),0)::numeric as total,
    coalesce(sum(payment_amount) filter (where paid_at >= (select start from current_month)),0)::numeric as this_month,
    coalesce(sum(payment_amount) filter (where paid_at >= (select start from last_month) and paid_at < (select start from current_month)),0)::numeric as last_month
  from payments
),
pending_tasks_cte as (
  select count(*) filter (where status in ('assigned','in_progress','pending'))::bigint as pending_total
  from task_assignments
),
evidence_cte as (
  select count(*) filter (where status = 'pending')::bigint as pending_total
  from evidence
),
new_accounts_cte as (
  select
    count(*) filter (where created_at >= (select start from current_week))::bigint as this_week,
    count(*) filter (where created_at >= (select start from last_week) and created_at < (select start from current_week))::bigint as last_week
  from profiles
)
select
  a.total as total_accounts,
  (a.this_month - a.last_month) as total_accounts_change,
  g.total as active_groups,
  (g.this_month - g.last_month) as active_groups_change,
  c.active_total as active_campaigns,
  (c.this_week - c.last_week) as active_campaigns_change,
  t.completed_total as completed_tasks,
  (t.this_month - t.last_month) as completed_tasks_change,
  ag.connected as connected_agents,
  ag.total_agents as total_agents,
  r.active_total as active_routes,
  p.total as points_granted,
  (p.this_month - p.last_month) as points_granted_change,
  na.this_week as new_accounts,
  (na.this_week - na.last_week) as new_accounts_change,
  pt.pending_total as pending_tasks,
  ev.pending_total as pending_points
from accounts a
cross join groups_cte g
cross join campaigns_cte c
cross join tasks_cte t
cross join agents_cte ag
cross join routes_cte r
cross join payments_cte p
cross join new_accounts_cte na
cross join pending_tasks_cte pt
cross join evidence_cte ev
$function$
                                                                                                                                                                                                                                                                                                                                 |
| public | get_geofence_for_campaign              | CREATE OR REPLACE FUNCTION public.get_geofence_for_campaign(p_campaign_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    geofence_wkt TEXT;
BEGIN
    SELECT
        ST_AsText(area) -- This command converts GEOGRAPHY to a simple TEXT string
    INTO
        geofence_wkt
    FROM
        public.geofences
    WHERE
        campaign_id = p_campaign_id
    LIMIT 1;

    RETURN geofence_wkt;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| public | get_geofence_for_task                  | CREATE OR REPLACE FUNCTION public.get_geofence_for_task(p_task_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    geofence_wkt TEXT;
BEGIN
    SELECT
        ST_AsText(area) -- This command converts the geometry to a simple TEXT string
    INTO
        geofence_wkt
    FROM
        public.geofences
    WHERE
        task_id = p_task_id
    LIMIT 1;

    RETURN geofence_wkt;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| public | get_geofences_for_parent               | CREATE OR REPLACE FUNCTION public.get_geofences_for_parent(parent_id uuid)
 RETURNS TABLE(id uuid, name text, color text, area_wkt text)
 LANGUAGE sql
AS $function$
  SELECT
    g.id,
    g.name,
    g.color,
    st_astext(g.area::geometry) AS area_wkt -- The critical fix is casting area to geometry
  FROM
    public.geofences AS g
  WHERE
    g.campaign_id = parent_id OR g.task_id = parent_id;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| public | get_manager_agent_profiles             | CREATE OR REPLACE FUNCTION public.get_manager_agent_profiles()
 RETURNS TABLE(id uuid, full_name text, username text, email text, role text, status text, connection_status text, last_heartbeat timestamp with time zone, last_location text, last_seen timestamp with time zone, created_at timestamp with time zone, group_name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    current_user_role TEXT;
    current_user_id UUID;
BEGIN
    -- Get current user ID and role
    current_user_id := auth.uid();
    
    -- Return empty if no authenticated user
    IF current_user_id IS NULL THEN
        RETURN;
    END IF;
    
    SELECT profiles.role INTO current_user_role
    FROM profiles
    WHERE profiles.id = current_user_id;
    
    -- If admin, return all agents
    IF current_user_role = 'admin' THEN
        RETURN QUERY
        SELECT 
            p.id,
            p.full_name,
            p.username,
            p.email,
            p.role,
            p.status,
            p.connection_status,
            p.last_heartbeat,
            aa.last_location::text,
            aa.last_seen,
            p.created_at,
            g.name as group_name
        FROM profiles p
        LEFT JOIN active_agents aa ON p.id = aa.user_id
        LEFT JOIN user_groups ug ON p.id = ug.user_id
        LEFT JOIN groups g ON ug.group_id = g.id
        WHERE p.role = 'agent'
        ORDER BY p.full_name;
        
    -- If manager or client, return only agents in their groups
    ELSIF current_user_role IN ('manager', 'client') THEN
        RETURN QUERY
        SELECT 
            p.id,
            p.full_name,
            p.username,
            p.email,
            p.role,
            p.status,
            p.connection_status,
            p.last_heartbeat,
            aa.last_location::text,
            aa.last_seen,
            p.created_at,
            g.name as group_name
        FROM profiles p
        LEFT JOIN active_agents aa ON p.id = aa.user_id
        JOIN user_groups ug_agent ON p.id = ug_agent.user_id
        JOIN user_groups ug_current_user ON ug_agent.group_id = ug_current_user.group_id
        LEFT JOIN groups g ON ug_agent.group_id = g.id
        WHERE p.role = 'agent'
        AND ug_current_user.user_id = current_user_id
        ORDER BY p.full_name;
        
    -- For other roles, return empty result
    ELSE
        RETURN;
    END IF;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| public | get_manager_campaigns                  | CREATE OR REPLACE FUNCTION public.get_manager_campaigns(manager_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(id uuid, name text, description text, status text, start_date date, end_date date, created_at timestamp with time zone, assigned_agents bigint, total_tasks bigint, completed_tasks bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  user_role TEXT;
BEGIN
  -- Get user role
  SELECT role INTO user_role FROM public.profiles WHERE id = manager_user_id;
  
  -- Admin can see all campaigns
  IF user_role = 'admin' THEN
    RETURN QUERY
    SELECT 
      c.id,
      c.name,
      c.description,
      c.status,
      c.start_date,
      c.end_date,
      c.created_at,
      COALESCE(agent_counts.agent_count, 0) as assigned_agents,
      COALESCE(task_counts.total_tasks, 0) as total_tasks,
      COALESCE(task_counts.completed_tasks, 0) as completed_tasks
    FROM public.campaigns c
    LEFT JOIN (
      SELECT campaign_id, COUNT(DISTINCT agent_id) as agent_count
      FROM public.campaign_agents
      GROUP BY campaign_id
    ) agent_counts ON c.id = agent_counts.campaign_id
    LEFT JOIN (
      SELECT 
        t.campaign_id,
        COUNT(*) as total_tasks,
        COUNT(*) FILTER (WHERE ta.status = 'completed') as completed_tasks
      FROM public.tasks t
      LEFT JOIN public.task_assignments ta ON t.id = ta.task_id
      GROUP BY t.campaign_id
    ) task_counts ON c.id = task_counts.campaign_id;
  
  -- Manager can only see campaigns with their group agents
  ELSIF user_role = 'manager' THEN
    RETURN QUERY
    SELECT 
      c.id,
      c.name,
      c.description,
      c.status,
      c.start_date,
      c.end_date,
      c.created_at,
      COALESCE(agent_counts.agent_count, 0) as assigned_agents,
      COALESCE(task_counts.total_tasks, 0) as total_tasks,
      COALESCE(task_counts.completed_tasks, 0) as completed_tasks
    FROM public.campaigns c
    INNER JOIN public.campaign_agents ca ON c.id = ca.campaign_id
    INNER JOIN public.user_groups ug_agent ON ca.agent_id = ug_agent.user_id
    INNER JOIN public.user_groups ug_manager ON ug_agent.group_id = ug_manager.group_id
    LEFT JOIN (
      SELECT campaign_id, COUNT(DISTINCT agent_id) as agent_count
      FROM public.campaign_agents
      GROUP BY campaign_id
    ) agent_counts ON c.id = agent_counts.campaign_id
    LEFT JOIN (
      SELECT 
        t.campaign_id,
        COUNT(*) as total_tasks,
        COUNT(*) FILTER (WHERE ta.status = 'completed') as completed_tasks
      FROM public.tasks t
      LEFT JOIN public.task_assignments ta ON t.id = ta.task_id
      GROUP BY t.campaign_id
    ) task_counts ON c.id = task_counts.campaign_id
    WHERE ug_manager.user_id = manager_user_id
    GROUP BY c.id, c.name, c.description, c.status, c.start_date, c.end_date, c.created_at, agent_counts.agent_count, task_counts.total_tasks, task_counts.completed_tasks;
  
  ELSE
    -- Agents and others get no campaigns
    RETURN;
  END IF;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| public | get_manager_timezone                   | CREATE OR REPLACE FUNCTION public.get_manager_timezone(agent_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    manager_tz TEXT;
BEGIN
    -- Get the timezone of the manager who manages this agent
    SELECT p_manager.timezone INTO manager_tz
    FROM profiles p_agent
    JOIN user_groups ug ON ug.user_id = p_agent.id
    JOIN groups g ON g.id = ug.group_id
    JOIN profiles p_manager ON p_manager.id = g.manager_id
    WHERE p_agent.id = agent_id
    AND p_agent.role = 'agent'
    LIMIT 1;
    
    -- If no manager found, return default Kuwait timezone
    RETURN COALESCE(manager_tz, 'Asia/Kuwait');
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| public | get_my_creation_count                  | CREATE OR REPLACE FUNCTION public.get_my_creation_count()
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM public.profiles
    WHERE created_by = auth.uid()
  );
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| public | get_my_role                            | CREATE OR REPLACE FUNCTION public.get_my_role()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ 
  SELECT role FROM public.profiles WHERE id = auth.uid(); 
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| public | get_next_place_in_route                | CREATE OR REPLACE FUNCTION public.get_next_place_in_route(route_assignment_uuid uuid)
 RETURNS TABLE(place_id uuid, place_name text, visit_order integer, instructions text, latitude double precision, longitude double precision, estimated_duration_minutes integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        rp.place_id,
        p.name,
        rp.visit_order,
        rp.instructions,
        p.latitude,
        p.longitude,
        rp.estimated_duration_minutes
    FROM route_places rp
    JOIN places p ON p.id = rp.place_id
    JOIN route_assignments ra ON ra.route_id = rp.route_id
    WHERE ra.id = route_assignment_uuid
    AND NOT EXISTS (
        -- Exclude places that have been completed
        SELECT 1 FROM place_visits pv 
        WHERE pv.route_assignment_id = route_assignment_uuid 
        AND pv.place_id = rp.place_id 
        AND pv.status = 'completed'
    )
    ORDER BY rp.visit_order
    LIMIT 1;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| public | get_next_visit_number                  | CREATE OR REPLACE FUNCTION public.get_next_visit_number(p_route_assignment_id uuid, p_place_id uuid, p_agent_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_max_visit_number INTEGER;
BEGIN
    SELECT COALESCE(MAX(visit_number), 0) + 1 INTO v_max_visit_number
    FROM place_visits
    WHERE route_assignment_id = p_route_assignment_id 
    AND place_id = p_place_id 
    AND agent_id = p_agent_id;
    
    RETURN v_max_visit_number;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| public | get_place_visit_evidence_count         | CREATE OR REPLACE FUNCTION public.get_place_visit_evidence_count(visit_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM public.evidence
        WHERE place_visit_id = visit_id
        AND status = 'approved'
    );
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| public | get_report_agent_performance           | CREATE OR REPLACE FUNCTION public.get_report_agent_performance(manager_user_id uuid DEFAULT NULL::uuid, from_date date DEFAULT NULL::date, to_date date DEFAULT NULL::date)
 RETURNS TABLE(agent_id uuid, full_name text, last_seen timestamp with time zone, tasks_completed integer, on_time_ratio numeric, avg_completion_hours numeric, routes_completed integer, points_earned integer, points_paid integer, outstanding integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    WITH date_bounds AS (
        SELECT 
            from_date AS from_d,
            (CASE WHEN to_date IS NULL THEN NULL ELSE to_date + INTERVAL '1 day' END) AS to_d
    ),
    manager_groups AS (
        SELECT ug.group_id
        FROM user_groups ug
        WHERE manager_user_id IS NOT NULL AND ug.user_id = manager_user_id
    ),
    scoped_agents AS (
        SELECT p.id, p.full_name
        FROM profiles p
        WHERE p.role = 'agent' 
        AND p.status = 'active'
        AND (
            manager_user_id IS NULL -- Admin case
            OR EXISTS (
                SELECT 1 FROM user_groups ug2
                WHERE ug2.user_id = p.id 
                AND ug2.group_id IN (SELECT group_id FROM manager_groups)
            )
        )
    ),
    agent_tasks AS (
        SELECT 
            ta.agent_id,
            COUNT(*) FILTER (WHERE ta.status = 'completed' 
                AND (from_date IS NULL OR ta.completed_at >= (SELECT from_d FROM date_bounds))
                AND (to_date IS NULL OR ta.completed_at < (SELECT to_d FROM date_bounds))
            ) AS tasks_completed,
            AVG(
                CASE WHEN ta.status = 'completed' 
                    AND (from_date IS NULL OR ta.completed_at >= (SELECT from_d FROM date_bounds))
                    AND (to_date IS NULL OR ta.completed_at < (SELECT to_d FROM date_bounds))
                THEN EXTRACT(EPOCH FROM (ta.completed_at - ta.started_at)) / 3600.0 
                END
            ) AS avg_completion_hours,
            (COUNT(*) FILTER (WHERE ta.status = 'completed' 
                AND ta.completed_at <= COALESCE(t.due_date, ta.completed_at)
                AND (from_date IS NULL OR ta.completed_at >= (SELECT from_d FROM date_bounds))
                AND (to_date IS NULL OR ta.completed_at < (SELECT to_d FROM date_bounds))
            )::NUMERIC / NULLIF(COUNT(*) FILTER (WHERE ta.status = 'completed' 
                AND (from_date IS NULL OR ta.completed_at >= (SELECT from_d FROM date_bounds))
                AND (to_date IS NULL OR ta.completed_at < (SELECT to_d FROM date_bounds))
            ), 0)) * 100 AS on_time_ratio,
            SUM(
                CASE WHEN ta.status = 'completed' 
                    AND (from_date IS NULL OR ta.completed_at >= (SELECT from_d FROM date_bounds))
                    AND (to_date IS NULL OR ta.completed_at < (SELECT to_d FROM date_bounds))
                THEN t.points ELSE 0 END
            ) AS points_earned
        FROM task_assignments ta
        JOIN tasks t ON ta.task_id = t.id
        WHERE ta.agent_id IN (SELECT id FROM scoped_agents)
        GROUP BY ta.agent_id
    ),
    agent_routes AS (
        SELECT 
            ra.agent_id,
            COUNT(*) FILTER (WHERE ra.status = 'completed'
                AND (from_date IS NULL OR ra.completed_at >= (SELECT from_d FROM date_bounds))
                AND (to_date IS NULL OR ra.completed_at < (SELECT to_d FROM date_bounds))
            ) AS routes_completed
        FROM route_assignments ra
        WHERE ra.agent_id IN (SELECT id FROM scoped_agents)
        GROUP BY ra.agent_id
    ),
    agent_payments AS (
        SELECT 
            p.agent_id,
            SUM(p.amount) AS points_paid
        FROM payments p
        WHERE p.agent_id IN (SELECT id FROM scoped_agents)
        AND (from_date IS NULL OR p.paid_at >= (SELECT from_d FROM date_bounds))
        AND (to_date IS NULL OR p.paid_at < (SELECT to_d FROM date_bounds))
        GROUP BY p.agent_id
    )
    SELECT 
        sa.id,
        sa.full_name,
        aa.last_seen,
        COALESCE(at.tasks_completed, 0)::INTEGER,
        COALESCE(at.on_time_ratio, 0)::NUMERIC,
        COALESCE(at.avg_completion_hours, 0)::NUMERIC,
        COALESCE(ar.routes_completed, 0)::INTEGER,
        COALESCE(at.points_earned, 0)::INTEGER,
        COALESCE(ap.points_paid, 0)::INTEGER,
        COALESCE(at.points_earned, 0) - COALESCE(ap.points_paid, 0) AS outstanding
    FROM scoped_agents sa
    LEFT JOIN active_agents aa ON aa.user_id = sa.id
    LEFT JOIN agent_tasks at ON at.agent_id = sa.id
    LEFT JOIN agent_routes ar ON ar.agent_id = sa.id
    LEFT JOIN agent_payments ap ON ap.agent_id = sa.id
    ORDER BY sa.full_name;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| public | get_report_campaign_summary            | CREATE OR REPLACE FUNCTION public.get_report_campaign_summary(manager_user_id uuid DEFAULT NULL::uuid, from_date date DEFAULT NULL::date, to_date date DEFAULT NULL::date)
 RETURNS TABLE(campaign_id uuid, name text, status text, start_date date, end_date date, created_at timestamp with time zone, created_by uuid, agents_assigned integer, total_tasks integer, completed_tasks integer, completion_rate numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    WITH date_bounds AS (
        SELECT 
            from_date AS from_d,
            (CASE WHEN to_date IS NULL THEN NULL ELSE to_date + INTERVAL '1 day' END) AS to_d
    ),
    manager_groups AS (
        SELECT ug.group_id
        FROM user_groups ug
        WHERE manager_user_id IS NOT NULL AND ug.user_id = manager_user_id
    ),
    scoped_campaigns AS (
        SELECT DISTINCT c.*
        FROM campaigns c
        WHERE (
            manager_user_id IS NULL -- Admin case
            OR c.created_by = manager_user_id -- Manager created campaign
            OR EXISTS ( -- Campaign has tasks handled by manager's agents
                SELECT 1 
                FROM tasks t
                JOIN task_assignments ta ON t.id = ta.task_id
                JOIN user_groups ug ON ta.agent_id = ug.user_id
                WHERE t.campaign_id = c.id
                AND ug.group_id IN (SELECT group_id FROM manager_groups)
            )
        )
    ),
    campaign_agents_count AS (
        SELECT 
            ca.campaign_id,
            COUNT(DISTINCT ca.agent_id) AS agents_assigned
        FROM campaign_agents ca
        WHERE ca.campaign_id IN (SELECT id FROM scoped_campaigns)
        GROUP BY ca.campaign_id
    ),
    campaign_tasks_count AS (
        SELECT 
            t.campaign_id,
            COUNT(*) FILTER (WHERE 
                from_date IS NULL OR t.created_at >= (SELECT from_d FROM date_bounds)
                AND (to_date IS NULL OR t.created_at < (SELECT to_d FROM date_bounds))
            ) AS total_tasks,
            COUNT(*) FILTER (WHERE ta.status = 'completed'
                AND (from_date IS NULL OR ta.completed_at >= (SELECT from_d FROM date_bounds))
                AND (to_date IS NULL OR ta.completed_at < (SELECT to_d FROM date_bounds))
            ) AS completed_tasks
        FROM tasks t
        LEFT JOIN task_assignments ta ON t.id = ta.task_id
        WHERE t.campaign_id IN (SELECT id FROM scoped_campaigns)
        GROUP BY t.campaign_id
    )
    SELECT 
        sc.id,
        sc.name,
        sc.status,
        sc.start_date,
        sc.end_date,
        sc.created_at,
        sc.created_by,
        COALESCE(cac.agents_assigned, 0)::INTEGER,
        COALESCE(ctc.total_tasks, 0)::INTEGER,
        COALESCE(ctc.completed_tasks, 0)::INTEGER,
        CASE 
            WHEN COALESCE(ctc.total_tasks, 0) > 0 
            THEN (COALESCE(ctc.completed_tasks, 0)::NUMERIC / ctc.total_tasks::NUMERIC) * 100
            ELSE 0
        END AS completion_rate
    FROM scoped_campaigns sc
    LEFT JOIN campaign_agents_count cac ON cac.campaign_id = sc.id
    LEFT JOIN campaign_tasks_count ctc ON ctc.campaign_id = sc.id
    ORDER BY sc.created_at DESC;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| public | get_route_progress                     | CREATE OR REPLACE FUNCTION public.get_route_progress(route_assignment_uuid uuid)
 RETURNS TABLE(total_places integer, completed_places integer, in_progress_places integer, pending_places integer, total_duration_minutes integer, progress_percentage numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    WITH route_stats AS (
        SELECT 
            COUNT(DISTINCT rp.place_id) as total,
            COUNT(DISTINCT CASE WHEN pv.status = 'completed' THEN pv.place_id END) as completed,
            COUNT(DISTINCT CASE WHEN pv.status = 'checked_in' THEN pv.place_id END) as in_progress,
            COUNT(DISTINCT CASE WHEN pv.status = 'pending' OR pv.status IS NULL THEN rp.place_id END) as pending,
            SUM(CASE WHEN pv.duration_minutes IS NOT NULL THEN pv.duration_minutes ELSE 0 END)::INTEGER as total_duration
        FROM route_assignments ra
        JOIN route_places rp ON rp.route_id = ra.route_id
        LEFT JOIN place_visits pv ON pv.route_assignment_id = ra.id AND pv.place_id = rp.place_id
        WHERE ra.id = route_assignment_uuid
    )
    SELECT 
        total,
        completed,
        in_progress,
        pending,
        total_duration,
        CASE 
            WHEN total > 0 THEN ROUND((completed::NUMERIC / total::NUMERIC) * 100, 2)
            ELSE 0
        END as progress_percentage
    FROM route_stats;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| public | get_routes_scoped                      | CREATE OR REPLACE FUNCTION public.get_routes_scoped(manager_user_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(id uuid, name text, description text, status text, start_date date, created_at timestamp with time zone, created_by uuid, assigned_manager_id uuid, metadata jsonb, estimated_duration_hours integer, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        r.name,
        r.description,
        r.status,
        r.start_date,
        r.created_at,
        r.created_by,
        r.assigned_manager_id,
        r.metadata,
        r.estimated_duration_hours,
        r.updated_at
    FROM routes r
    WHERE (
        manager_user_id IS NULL -- Admin case: show all routes
        OR r.created_by = manager_user_id -- Manager created the route
        OR r.assigned_manager_id = manager_user_id -- Manager is assigned to the route
        OR EXISTS ( -- Manager has agents assigned to the route
            SELECT 1 
            FROM route_assignments ra
            JOIN user_groups ug_agent ON ra.agent_id = ug_agent.user_id
            JOIN user_groups ug_manager ON ug_agent.group_id = ug_manager.group_id
            WHERE ra.route_id = r.id
            AND ug_manager.user_id = manager_user_id
        )
    )
    ORDER BY r.created_at DESC;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| public | get_survey_with_fields                 | CREATE OR REPLACE FUNCTION public.get_survey_with_fields(survey_uuid uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE result JSON; BEGIN
  SELECT json_build_object(
    'survey', to_json(s.*),
    'fields', COALESCE(json_agg(to_json(sf.*) ORDER BY sf.field_order, sf.created_at)
              FILTER (WHERE sf.id IS NOT NULL), '[]'::json)
  ) INTO result
  FROM touring_task_surveys s
  LEFT JOIN survey_fields sf ON s.id = sf.survey_id
  WHERE s.id = survey_uuid
  GROUP BY s.id, s.touring_task_id, s.title, s.description, s.is_required, s.is_active,
           s.created_at, s.updated_at, s.created_by;
  RETURN result;
END; $function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| public | get_task_agent_progress_batch          | CREATE OR REPLACE FUNCTION public.get_task_agent_progress_batch(p_task_id uuid)
 RETURNS TABLE(agent_id uuid, agent_name text, assignment_status text, evidence_required integer, evidence_uploaded integer, points_total integer, points_paid integer, outstanding_balance integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| public | get_template_with_fields               | CREATE OR REPLACE FUNCTION public.get_template_with_fields(template_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'template', row_to_json(tt.*),
        'fields', COALESCE(
            (SELECT jsonb_agg(tf.* ORDER BY tf.sort_order)
             FROM template_fields tf 
             WHERE tf.template_id = tt.id), 
            '[]'::jsonb
        )
    ) INTO result
    FROM task_templates tt
    WHERE tt.id = get_template_with_fields.template_id;
    
    RETURN result;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| public | get_templates_by_category              | CREATE OR REPLACE FUNCTION public.get_templates_by_category(category_name text)
 RETURNS TABLE(template_id uuid, template_name text, description text, default_points integer, requires_geofence boolean, difficulty_level text, estimated_duration integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        tt.id,
        tt.name,
        tt.description,
        tt.default_points,
        tt.requires_geofence,
        tt.difficulty_level,
        tt.estimated_duration
    FROM task_templates tt
    JOIN template_categories tc ON tt.category_id = tc.id
    WHERE tc.name = category_name 
    AND tt.is_active = true
    ORDER BY tt.name;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| public | get_unread_notification_count          | CREATE OR REPLACE FUNCTION public.get_unread_notification_count(user_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Count unread notifications for the user
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM notifications
    WHERE recipient_id = user_id
    AND read_at IS NULL
  );
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| public | get_user_location_history_fixed        | CREATE OR REPLACE FUNCTION public.get_user_location_history_fixed(user_uuid uuid, start_date timestamp with time zone DEFAULT NULL::timestamp with time zone, end_date timestamp with time zone DEFAULT NULL::timestamp with time zone, limit_count integer DEFAULT 100)
 RETURNS TABLE(id uuid, latitude double precision, longitude double precision, accuracy real, speed real, recorded_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        lh.id,
        ST_Y(lh.location) as latitude,
        ST_X(lh.location) as longitude,
        lh.accuracy,
        lh.speed,
        lh.recorded_at
    FROM location_history lh
    WHERE lh.user_id = user_uuid
    AND (start_date IS NULL OR lh.recorded_at >= start_date)
    AND (end_date IS NULL OR lh.recorded_at <= end_date)
    ORDER BY lh.recorded_at DESC
    LIMIT limit_count;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| public | get_user_role_secure                   | CREATE OR REPLACE FUNCTION public.get_user_role_secure(user_uuid uuid DEFAULT auth.uid())
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT role FROM public.profiles WHERE id = user_uuid;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| public | get_user_timezone                      | CREATE OR REPLACE FUNCTION public.get_user_timezone(user_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    user_role TEXT;
    user_tz TEXT;
BEGIN
    -- Get user role and timezone
    SELECT role, timezone INTO user_role, user_tz
    FROM profiles 
    WHERE id = user_id;
    
    -- If manager/admin, return their own timezone
    IF user_role IN ('manager', 'admin') THEN
        RETURN COALESCE(user_tz, 'Asia/Kuwait');
    END IF;
    
    -- If agent, return manager's timezone
    IF user_role = 'agent' THEN
        RETURN get_manager_timezone(user_id);
    END IF;
    
    -- Default fallback
    RETURN 'Asia/Kuwait';
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| public | get_users_by_status                    | CREATE OR REPLACE FUNCTION public.get_users_by_status(status_filter text DEFAULT NULL::text, group_id_filter uuid DEFAULT NULL::uuid)
 RETURNS TABLE(id uuid, full_name text, username text, role text, connection_status text, last_heartbeat timestamp with time zone, last_location text, last_seen timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Check if active_agents table exists
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'active_agents') THEN
    RETURN QUERY
    SELECT 
      p.id,
      p.full_name,
      p.username,
      p.role,
      p.connection_status,
      p.last_heartbeat,
      aa.last_location::TEXT,
      aa.last_seen
    FROM profiles p
    LEFT JOIN active_agents aa ON aa.user_id = p.id
    LEFT JOIN user_groups ug ON ug.user_id = p.id
    WHERE 
      (status_filter IS NULL OR p.connection_status = status_filter)
      AND (group_id_filter IS NULL OR ug.group_id = group_id_filter)
      AND p.status = 'active'
    ORDER BY 
      CASE p.connection_status 
        WHEN 'active' THEN 1
        WHEN 'away' THEN 2
        WHEN 'offline' THEN 3
        ELSE 4
      END,
      p.last_heartbeat DESC NULLS LAST;
  ELSE
    -- Fallback when active_agents table doesn't exist
    RETURN QUERY
    SELECT 
      p.id,
      p.full_name,
      p.username,
      p.role,
      p.connection_status,
      p.last_heartbeat,
      NULL::TEXT as last_location,
      NULL::TIMESTAMP WITH TIME ZONE as last_seen
    FROM profiles p
    LEFT JOIN user_groups ug ON ug.user_id = p.id
    WHERE 
      (status_filter IS NULL OR p.connection_status = status_filter)
      AND (group_id_filter IS NULL OR ug.group_id = group_id_filter)
      AND p.status = 'active'
    ORDER BY 
      CASE p.connection_status 
        WHEN 'active' THEN 1
        WHEN 'away' THEN 2
        WHEN 'offline' THEN 3
        ELSE 4
      END,
      p.last_heartbeat DESC NULLS LAST;
  END IF;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| public | handle_new_user                        | CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.profiles (
    id, 
    role, 
    full_name, 
    created_by, 
    email, 
    status, 
    agent_creation_limit,
    username
  )
  VALUES (
    NEW.id, 
    COALESCE(NEW.raw_app_meta_data->>'role', 'agent'),
    NEW.raw_app_meta_data->>'full_name',
    (NEW.raw_app_meta_data->>'creator_id')::uuid,
    NEW.email,
    'active',
    COALESCE((NEW.raw_app_meta_data->>'agent_creation_limit')::integer, 0),
    NEW.raw_app_meta_data->>'username'
  );
  RETURN NEW;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| public | handle_updated_at                      | CREATE OR REPLACE FUNCTION public.handle_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| public | insert_location_coordinates            | CREATE OR REPLACE FUNCTION public.insert_location_coordinates(p_user_id uuid, p_longitude double precision, p_latitude double precision, p_accuracy double precision DEFAULT NULL::double precision, p_speed double precision DEFAULT NULL::double precision)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    -- 1. Insert into location_history table (for location history screen)
    INSERT INTO location_history (
        user_id,
        location,
        accuracy,
        speed,
        recorded_at
    ) VALUES (
        p_user_id,
        ST_GeogFromText('POINT(' || p_longitude || ' ' || p_latitude || ')'),
        p_accuracy,
        p_speed,
        NOW()
    );
    
    -- 2. Update active_agents table (for live map) - keep existing logic
    INSERT INTO active_agents (
        user_id,
        last_location, 
        last_seen, 
        accuracy,
        speed
    ) VALUES (
        p_user_id,
        POINT(p_longitude, p_latitude),
        NOW(), 
        p_accuracy, 
        p_speed
    )
    ON CONFLICT (user_id)
    DO UPDATE SET
        last_location = EXCLUDED.last_location,
        last_seen = EXCLUDED.last_seen,
        accuracy = EXCLUDED.accuracy,
        speed = EXCLUDED.speed,
        updated_at = NOW();
        
    -- Function now saves to both tables correctly
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| public | insert_location_point                  | CREATE OR REPLACE FUNCTION public.insert_location_point(user_uuid uuid, lat double precision, lng double precision, acc real DEFAULT NULL::real, spd real DEFAULT NULL::real)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    new_id UUID;
BEGIN
    INSERT INTO location_history (user_id, location, accuracy, speed)
    VALUES (user_uuid, ST_Point(lng, lat), acc, spd)
    RETURNING id INTO new_id;
    
    RETURN new_id;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| public | insert_location_update                 | CREATE OR REPLACE FUNCTION public.insert_location_update(p_user_id uuid, p_location text, p_accuracy double precision DEFAULT NULL::double precision, p_speed double precision DEFAULT NULL::double precision)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO active_agents (user_id, last_location, last_seen, accuracy, speed)
  VALUES (p_user_id, p_location::POINT, NOW(), p_accuracy, p_speed)
  ON CONFLICT (user_id)
  DO UPDATE SET
    last_location = EXCLUDED.last_location,
    last_seen = EXCLUDED.last_seen,
    accuracy = EXCLUDED.accuracy,
    speed = EXCLUDED.speed,
    updated_at = NOW();
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| public | insert_task_geofence                   | CREATE OR REPLACE FUNCTION public.insert_task_geofence(task_id_param uuid, geofence_name text, wkt_polygon text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
  BEGIN
      INSERT INTO geofences
  (task_id, name, area,
  area_text)
      VALUES (
          task_id_param,
          geofence_name,

  ST_GeomFromText(wkt_polygon,
  4326),
          wkt_polygon
      );
  END;
  $function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| public | is_touring_task_available_at_time      | CREATE OR REPLACE FUNCTION public.is_touring_task_available_at_time(task_id uuid, check_time timestamp with time zone DEFAULT now())
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    task_record touring_tasks;
    current_time_of_day TIME;
    start_time TIME;
    end_time TIME;
BEGIN
    -- Get the task record
    SELECT * INTO task_record FROM touring_tasks WHERE id = task_id;
    
    -- If task doesn't exist, return false
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- If task doesn't use schedule, it's always available
    IF NOT task_record.use_schedule OR task_record.daily_start_time IS NULL OR task_record.daily_end_time IS NULL THEN
        RETURN TRUE;
    END IF;
    
    -- Get current time of day
    current_time_of_day := (check_time AT TIME ZONE 'UTC')::TIME;
    
    -- Parse start and end times
    start_time := task_record.daily_start_time::TIME;
    end_time := task_record.daily_end_time::TIME;
    
    -- Check if current time is within the range
    IF start_time <= end_time THEN
        -- Same day range
        RETURN current_time_of_day >= start_time AND current_time_of_day <= end_time;
    ELSE
        -- Crosses midnight
        RETURN current_time_of_day >= start_time OR current_time_of_day <= end_time;
    END IF;
END;
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| public | is_user_admin                          | CREATE OR REPLACE FUNCTION public.is_user_admin(user_uuid uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = user_uuid AND role = 'admin'
  );
$function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |

---

## B) Privileges

```sql
-- B1) Schema privileges (fixed: uses correct alias)
select n.nspname as schema,
       gr.rolname as grantee,
       a.privilege_type,
       a.is_grantable
from pg_namespace n
cross join lateral (
  select (aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner)))).*
) as a(grantee, grantor, privilege_type, is_grantable)
join pg_roles gr on gr.oid = a.grantee
where n.nspname not in ('pg_catalog','information_schema')
order by 1, 2, 3;
```
* 
| schema           | grantee        | privilege_type | is_grantable |
| ---------------- | -------------- | -------------- | ------------ |
| auth             | supabase_admin | CREATE         | false        |
| auth             | supabase_admin | CREATE         | false        |
| auth             | supabase_admin | CREATE         | false        |
| auth             | supabase_admin | USAGE          | false        |
| auth             | supabase_admin | USAGE          | false        |
| auth             | supabase_admin | USAGE          | false        |
| auth             | supabase_admin | USAGE          | false        |
| auth             | supabase_admin | USAGE          | false        |
| auth             | supabase_admin | USAGE          | false        |
| auth             | supabase_admin | USAGE          | false        |
| cron             | supabase_admin | CREATE         | false        |
| cron             | supabase_admin | USAGE          | false        |
| cron             | supabase_admin | USAGE          | true         |
| extensions       | postgres       | CREATE         | false        |
| extensions       | postgres       | CREATE         | false        |
| extensions       | postgres       | USAGE          | false        |
| extensions       | postgres       | USAGE          | false        |
| extensions       | postgres       | USAGE          | false        |
| extensions       | postgres       | USAGE          | false        |
| extensions       | postgres       | USAGE          | false        |
| graphql          | supabase_admin | CREATE         | false        |
| graphql          | supabase_admin | USAGE          | true         |
| graphql          | supabase_admin | USAGE          | false        |
| graphql          | supabase_admin | USAGE          | false        |
| graphql          | supabase_admin | USAGE          | false        |
| graphql          | supabase_admin | USAGE          | false        |
| graphql_public   | supabase_admin | CREATE         | false        |
| graphql_public   | supabase_admin | USAGE          | false        |
| graphql_public   | supabase_admin | USAGE          | false        |
| graphql_public   | supabase_admin | USAGE          | true         |
| graphql_public   | supabase_admin | USAGE          | false        |
| graphql_public   | supabase_admin | USAGE          | false        |
| pg_temp_10       | supabase_admin | CREATE         | false        |
| pg_temp_10       | supabase_admin | USAGE          | false        |
| pg_temp_11       | supabase_admin | CREATE         | false        |
| pg_temp_11       | supabase_admin | USAGE          | false        |
| pg_temp_12       | supabase_admin | CREATE         | false        |
| pg_temp_12       | supabase_admin | USAGE          | false        |
| pg_temp_13       | supabase_admin | CREATE         | false        |
| pg_temp_13       | supabase_admin | USAGE          | false        |
| pg_temp_14       | supabase_admin | CREATE         | false        |
| pg_temp_14       | supabase_admin | USAGE          | false        |
| pg_temp_15       | supabase_admin | CREATE         | false        |
| pg_temp_15       | supabase_admin | USAGE          | false        |
| pg_temp_16       | supabase_admin | CREATE         | false        |
| pg_temp_16       | supabase_admin | USAGE          | false        |
| pg_temp_17       | supabase_admin | CREATE         | false        |
| pg_temp_17       | supabase_admin | USAGE          | false        |
| pg_temp_18       | supabase_admin | CREATE         | false        |
| pg_temp_18       | supabase_admin | USAGE          | false        |
| pg_temp_19       | supabase_admin | CREATE         | false        |
| pg_temp_19       | supabase_admin | USAGE          | false        |
| pg_temp_20       | supabase_admin | CREATE         | false        |
| pg_temp_20       | supabase_admin | USAGE          | false        |
| pg_temp_21       | supabase_admin | CREATE         | false        |
| pg_temp_21       | supabase_admin | USAGE          | false        |
| pg_temp_22       | supabase_admin | CREATE         | false        |
| pg_temp_22       | supabase_admin | USAGE          | false        |
| pg_temp_23       | supabase_admin | CREATE         | false        |
| pg_temp_23       | supabase_admin | USAGE          | false        |
| pg_temp_24       | supabase_admin | CREATE         | false        |
| pg_temp_24       | supabase_admin | USAGE          | false        |
| pg_temp_25       | supabase_admin | CREATE         | false        |
| pg_temp_25       | supabase_admin | USAGE          | false        |
| pg_temp_6        | supabase_admin | CREATE         | false        |
| pg_temp_6        | supabase_admin | USAGE          | false        |
| pg_temp_7        | supabase_admin | CREATE         | false        |
| pg_temp_7        | supabase_admin | USAGE          | false        |
| pg_temp_8        | supabase_admin | CREATE         | false        |
| pg_temp_8        | supabase_admin | USAGE          | false        |
| pg_temp_9        | supabase_admin | CREATE         | false        |
| pg_temp_9        | supabase_admin | USAGE          | false        |
| pg_toast         | supabase_admin | CREATE         | false        |
| pg_toast         | supabase_admin | USAGE          | false        |
| pg_toast_temp_10 | supabase_admin | CREATE         | false        |
| pg_toast_temp_10 | supabase_admin | USAGE          | false        |
| pg_toast_temp_11 | supabase_admin | CREATE         | false        |
| pg_toast_temp_11 | supabase_admin | USAGE          | false        |
| pg_toast_temp_12 | supabase_admin | CREATE         | false        |
| pg_toast_temp_12 | supabase_admin | USAGE          | false        |
| pg_toast_temp_13 | supabase_admin | CREATE         | false        |
| pg_toast_temp_13 | supabase_admin | USAGE          | false        |
| pg_toast_temp_14 | supabase_admin | CREATE         | false        |
| pg_toast_temp_14 | supabase_admin | USAGE          | false        |
| pg_toast_temp_15 | supabase_admin | CREATE         | false        |
| pg_toast_temp_15 | supabase_admin | USAGE          | false        |
| pg_toast_temp_16 | supabase_admin | CREATE         | false        |
| pg_toast_temp_16 | supabase_admin | USAGE          | false        |
| pg_toast_temp_17 | supabase_admin | CREATE         | false        |
| pg_toast_temp_17 | supabase_admin | USAGE          | false        |
| pg_toast_temp_18 | supabase_admin | CREATE         | false        |
| pg_toast_temp_18 | supabase_admin | USAGE          | false        |
| pg_toast_temp_19 | supabase_admin | CREATE         | false        |
| pg_toast_temp_19 | supabase_admin | USAGE          | false        |
| pg_toast_temp_20 | supabase_admin | CREATE         | false        |
| pg_toast_temp_20 | supabase_admin | USAGE          | false        |
| pg_toast_temp_21 | supabase_admin | CREATE         | false        |
| pg_toast_temp_21 | supabase_admin | USAGE          | false        |
| pg_toast_temp_22 | supabase_admin | CREATE         | false        |
| pg_toast_temp_22 | supabase_admin | USAGE          | false        |

```sql
-- B2) Sequence privileges (often missed; required for nextval/usage via API)
select sequence_schema as schema,
       sequence_name,
       grantee,
       privilege_type,
       is_grantable
from information_schema.sequence_privileges
where sequence_schema not in ('pg_catalog','information_schema')
order by 1, 2, 3, 4;
```
* 


```sql
-- B3) Column privileges (rare; but surface if used anywhere)
select table_schema as schema,
       table_name,
       column_name,
       grantee,
       privilege_type
from information_schema.column_privileges
where table_schema not in ('pg_catalog','information_schema')
order by 1, 2, 3, 4;
```
* 
| schema | table_name        | column_name            | grantee  | privilege_type |
| ------ | ----------------- | ---------------------- | -------- | -------------- |
| auth   | audit_log_entries | created_at             | postgres | UPDATE         |
| auth   | audit_log_entries | created_at             | postgres | REFERENCES     |
| auth   | audit_log_entries | created_at             | postgres | SELECT         |
| auth   | audit_log_entries | created_at             | postgres | INSERT         |
| auth   | audit_log_entries | id                     | postgres | INSERT         |
| auth   | audit_log_entries | id                     | postgres | SELECT         |
| auth   | audit_log_entries | id                     | postgres | REFERENCES     |
| auth   | audit_log_entries | id                     | postgres | UPDATE         |
| auth   | audit_log_entries | instance_id            | postgres | SELECT         |
| auth   | audit_log_entries | instance_id            | postgres | INSERT         |
| auth   | audit_log_entries | instance_id            | postgres | REFERENCES     |
| auth   | audit_log_entries | instance_id            | postgres | UPDATE         |
| auth   | audit_log_entries | ip_address             | postgres | SELECT         |
| auth   | audit_log_entries | ip_address             | postgres | UPDATE         |
| auth   | audit_log_entries | ip_address             | postgres | INSERT         |
| auth   | audit_log_entries | ip_address             | postgres | REFERENCES     |
| auth   | audit_log_entries | payload                | postgres | INSERT         |
| auth   | audit_log_entries | payload                | postgres | SELECT         |
| auth   | audit_log_entries | payload                | postgres | UPDATE         |
| auth   | audit_log_entries | payload                | postgres | REFERENCES     |
| auth   | flow_state        | auth_code              | postgres | UPDATE         |
| auth   | flow_state        | auth_code              | postgres | REFERENCES     |
| auth   | flow_state        | auth_code              | postgres | SELECT         |
| auth   | flow_state        | auth_code              | postgres | INSERT         |
| auth   | flow_state        | auth_code_issued_at    | postgres | REFERENCES     |
| auth   | flow_state        | auth_code_issued_at    | postgres | UPDATE         |
| auth   | flow_state        | auth_code_issued_at    | postgres | INSERT         |
| auth   | flow_state        | auth_code_issued_at    | postgres | SELECT         |
| auth   | flow_state        | authentication_method  | postgres | INSERT         |
| auth   | flow_state        | authentication_method  | postgres | UPDATE         |
| auth   | flow_state        | authentication_method  | postgres | REFERENCES     |
| auth   | flow_state        | authentication_method  | postgres | SELECT         |
| auth   | flow_state        | code_challenge         | postgres | SELECT         |
| auth   | flow_state        | code_challenge         | postgres | INSERT         |
| auth   | flow_state        | code_challenge         | postgres | REFERENCES     |
| auth   | flow_state        | code_challenge         | postgres | UPDATE         |
| auth   | flow_state        | code_challenge_method  | postgres | UPDATE         |
| auth   | flow_state        | code_challenge_method  | postgres | SELECT         |
| auth   | flow_state        | code_challenge_method  | postgres | REFERENCES     |
| auth   | flow_state        | code_challenge_method  | postgres | INSERT         |
| auth   | flow_state        | created_at             | postgres | INSERT         |
| auth   | flow_state        | created_at             | postgres | REFERENCES     |
| auth   | flow_state        | created_at             | postgres | UPDATE         |
| auth   | flow_state        | created_at             | postgres | SELECT         |
| auth   | flow_state        | id                     | postgres | UPDATE         |
| auth   | flow_state        | id                     | postgres | SELECT         |
| auth   | flow_state        | id                     | postgres | REFERENCES     |
| auth   | flow_state        | id                     | postgres | INSERT         |
| auth   | flow_state        | provider_access_token  | postgres | REFERENCES     |
| auth   | flow_state        | provider_access_token  | postgres | SELECT         |
| auth   | flow_state        | provider_access_token  | postgres | INSERT         |
| auth   | flow_state        | provider_access_token  | postgres | UPDATE         |
| auth   | flow_state        | provider_refresh_token | postgres | SELECT         |
| auth   | flow_state        | provider_refresh_token | postgres | REFERENCES     |
| auth   | flow_state        | provider_refresh_token | postgres | UPDATE         |
| auth   | flow_state        | provider_refresh_token | postgres | INSERT         |
| auth   | flow_state        | provider_type          | postgres | INSERT         |
| auth   | flow_state        | provider_type          | postgres | UPDATE         |
| auth   | flow_state        | provider_type          | postgres | SELECT         |
| auth   | flow_state        | provider_type          | postgres | REFERENCES     |
| auth   | flow_state        | updated_at             | postgres | UPDATE         |
| auth   | flow_state        | updated_at             | postgres | SELECT         |
| auth   | flow_state        | updated_at             | postgres | INSERT         |
| auth   | flow_state        | updated_at             | postgres | REFERENCES     |
| auth   | flow_state        | user_id                | postgres | UPDATE         |
| auth   | flow_state        | user_id                | postgres | SELECT         |
| auth   | flow_state        | user_id                | postgres | REFERENCES     |
| auth   | flow_state        | user_id                | postgres | INSERT         |
| auth   | identities        | created_at             | postgres | INSERT         |
| auth   | identities        | created_at             | postgres | UPDATE         |
| auth   | identities        | created_at             | postgres | REFERENCES     |
| auth   | identities        | created_at             | postgres | SELECT         |
| auth   | identities        | email                  | postgres | UPDATE         |
| auth   | identities        | email                  | postgres | INSERT         |
| auth   | identities        | email                  | postgres | SELECT         |
| auth   | identities        | email                  | postgres | REFERENCES     |
| auth   | identities        | id                     | postgres | SELECT         |
| auth   | identities        | id                     | postgres | REFERENCES     |
| auth   | identities        | id                     | postgres | INSERT         |
| auth   | identities        | id                     | postgres | UPDATE         |
| auth   | identities        | identity_data          | postgres | INSERT         |
| auth   | identities        | identity_data          | postgres | SELECT         |
| auth   | identities        | identity_data          | postgres | REFERENCES     |
| auth   | identities        | identity_data          | postgres | UPDATE         |
| auth   | identities        | last_sign_in_at        | postgres | SELECT         |
| auth   | identities        | last_sign_in_at        | postgres | INSERT         |
| auth   | identities        | last_sign_in_at        | postgres | REFERENCES     |
| auth   | identities        | last_sign_in_at        | postgres | UPDATE         |
| auth   | identities        | provider               | postgres | INSERT         |
| auth   | identities        | provider               | postgres | SELECT         |
| auth   | identities        | provider               | postgres | UPDATE         |
| auth   | identities        | provider               | postgres | REFERENCES     |
| auth   | identities        | provider_id            | postgres | UPDATE         |
| auth   | identities        | provider_id            | postgres | INSERT         |
| auth   | identities        | provider_id            | postgres | SELECT         |
| auth   | identities        | provider_id            | postgres | REFERENCES     |
| auth   | identities        | updated_at             | postgres | INSERT         |
| auth   | identities        | updated_at             | postgres | UPDATE         |
| auth   | identities        | updated_at             | postgres | REFERENCES     |
| auth   | identities        | updated_at             | postgres | SELECT         |

```sql
-- B4) Tables with RLS enabled but no policies (can cause silent denials)
with rls_tables as (
  select n.nspname as schema, c.relname as table
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where c.relkind in ('r','p')
    and n.nspname not in ('pg_catalog','information_schema')
    and c.relrowsecurity
)
select r.schema, r.table
from rls_tables r
left join pg_policies p
  on p.schemaname = r.schema and p.tablename = r.table
where p.tablename is null
order by 1, 2;
```
* 
| schema   | table                      |
| -------- | -------------------------- |
| auth     | audit_log_entries          |
| auth     | flow_state                 |
| auth     | identities                 |
| auth     | instances                  |
| auth     | mfa_amr_claims             |
| auth     | mfa_challenges             |
| auth     | mfa_factors                |
| auth     | one_time_tokens            |
| auth     | refresh_tokens             |
| auth     | saml_providers             |
| auth     | saml_relay_states          |
| auth     | schema_migrations          |
| auth     | sessions                   |
| auth     | sso_domains                |
| auth     | sso_providers              |
| auth     | users                      |
| realtime | messages                   |
| storage  | buckets                    |
| storage  | buckets_analytics          |
| storage  | migrations                 |
| storage  | prefixes                   |
| storage  | s3_multipart_uploads       |
| storage  | s3_multipart_uploads_parts |

---

## C) Publications & Replication

```sql
-- C1) Publications overview
select pubname, puballtables, pubinsert, pubupdate, pubdelete, pubtruncate, pubviaroot
from pg_publication
order by 1;
```
* 
| pubname                                | puballtables | pubinsert | pubupdate | pubdelete | pubtruncate | pubviaroot |
| -------------------------------------- | ------------ | --------- | --------- | --------- | ----------- | ---------- |
| supabase_realtime                      | false        | true      | true      | true      | true        | false      |
| supabase_realtime_messages_publication | false        | true      | true      | true      | true        | false      |

```sql
-- C2) Publication tables
select pt.pubname,
       pt.schemaname as schema,
       pt.tablename  as table
from pg_publication_tables pt
order by 1, 2, 3;
```
* 
| pubname                                | schema   | table               |
| -------------------------------------- | -------- | ------------------- |
| supabase_realtime_messages_publication | realtime | messages_2025_08_17 |
| supabase_realtime_messages_publication | realtime | messages_2025_08_18 |
| supabase_realtime_messages_publication | realtime | messages_2025_08_19 |
| supabase_realtime_messages_publication | realtime | messages_2025_08_20 |
| supabase_realtime_messages_publication | realtime | messages_2025_08_21 |
| supabase_realtime_messages_publication | realtime | messages_2025_08_22 |
| supabase_realtime_messages_publication | realtime | messages_2025_08_23 |

```sql
-- C3) Replication identity per table (Realtime needs suitable identity)
select n.nspname as schema,
       c.relname  as table,
       case c.relreplident
         when 'd' then 'DEFAULT'
         when 'n' then 'NOTHING'
         when 'f' then 'FULL'
         when 'i' then 'INDEX'
       end as repl_identity
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r'
  and n.nspname not in ('pg_catalog','information_schema')
order by 1, 2;
```
* 
| schema              | table                        | repl_identity |
| ------------------- | ---------------------------- | ------------- |
| auth                | audit_log_entries            | DEFAULT       |
| auth                | flow_state                   | DEFAULT       |
| auth                | identities                   | DEFAULT       |
| auth                | instances                    | DEFAULT       |
| auth                | mfa_amr_claims               | DEFAULT       |
| auth                | mfa_challenges               | DEFAULT       |
| auth                | mfa_factors                  | DEFAULT       |
| auth                | one_time_tokens              | DEFAULT       |
| auth                | refresh_tokens               | DEFAULT       |
| auth                | saml_providers               | DEFAULT       |
| auth                | saml_relay_states            | DEFAULT       |
| auth                | schema_migrations            | DEFAULT       |
| auth                | sessions                     | DEFAULT       |
| auth                | sso_domains                  | DEFAULT       |
| auth                | sso_providers                | DEFAULT       |
| auth                | users                        | DEFAULT       |
| cron                | job                          | DEFAULT       |
| cron                | job_run_details              | DEFAULT       |
| extensions          | spatial_ref_sys              | DEFAULT       |
| public              | active_agents                | DEFAULT       |
| public              | admin_audit_log              | DEFAULT       |
| public              | admin_users                  | DEFAULT       |
| public              | agent_geofence_assignments   | DEFAULT       |
| public              | agent_location_tracking      | DEFAULT       |
| public              | app_settings                 | DEFAULT       |
| public              | app_versions                 | DEFAULT       |
| public              | audit_log                    | DEFAULT       |
| public              | campaign_agents              | DEFAULT       |
| public              | campaign_daily_participation | DEFAULT       |
| public              | campaign_geofences           | DEFAULT       |
| public              | campaign_settings            | DEFAULT       |
| public              | campaigns                    | DEFAULT       |
| public              | evidence                     | DEFAULT       |
| public              | geofences                    | DEFAULT       |
| public              | global_survey_agents         | DEFAULT       |
| public              | global_survey_clients        | DEFAULT       |
| public              | global_survey_fields         | DEFAULT       |
| public              | global_survey_submissions    | DEFAULT       |
| public              | global_surveys               | DEFAULT       |
| public              | groups                       | DEFAULT       |
| public              | location_history             | DEFAULT       |
| public              | manager_template_access      | DEFAULT       |
| public              | notifications                | DEFAULT       |
| public              | password_reset_logs          | DEFAULT       |
| public              | payments                     | DEFAULT       |
| public              | place_visits                 | DEFAULT       |
| public              | places                       | DEFAULT       |
| public              | profiles                     | DEFAULT       |
| public              | report_exports               | DEFAULT       |
| public              | route_assignments            | DEFAULT       |
| public              | route_places                 | DEFAULT       |
| public              | routes                       | DEFAULT       |
| public              | sessions                     | DEFAULT       |
| public              | survey_fields                | DEFAULT       |
| public              | survey_submissions           | DEFAULT       |
| public              | task_assignments             | DEFAULT       |
| public              | task_dynamic_fields          | DEFAULT       |
| public              | task_templates               | DEFAULT       |
| public              | tasks                        | DEFAULT       |
| public              | template_categories          | DEFAULT       |
| public              | template_fields              | DEFAULT       |
| public              | template_usage_analytics     | DEFAULT       |
| public              | touring_task_assignments     | DEFAULT       |
| public              | touring_task_sessions        | DEFAULT       |
| public              | touring_task_surveys         | DEFAULT       |
| public              | touring_tasks                | DEFAULT       |
| public              | user_groups                  | DEFAULT       |
| realtime            | messages_2025_08_17          | DEFAULT       |
| realtime            | messages_2025_08_18          | DEFAULT       |
| realtime            | messages_2025_08_19          | DEFAULT       |
| realtime            | messages_2025_08_20          | DEFAULT       |
| realtime            | messages_2025_08_21          | DEFAULT       |
| realtime            | messages_2025_08_22          | DEFAULT       |
| realtime            | messages_2025_08_23          | DEFAULT       |
| realtime            | schema_migrations            | DEFAULT       |
| realtime            | subscription                 | DEFAULT       |
| storage             | buckets                      | DEFAULT       |
| storage             | buckets_analytics            | DEFAULT       |
| storage             | migrations                   | DEFAULT       |
| storage             | objects                      | DEFAULT       |
| storage             | prefixes                     | DEFAULT       |
| storage             | s3_multipart_uploads         | DEFAULT       |
| storage             | s3_multipart_uploads_parts   | DEFAULT       |
| supabase_migrations | schema_migrations            | DEFAULT       |
| topology            | layer                        | DEFAULT       |
| topology            | topology                     | DEFAULT       |
| vault               | secrets                      | DEFAULT       |

---

## D) Default Privileges (future grants)

```sql
-- D1) Default privileges by owner (apply when new objects are created)
select r.rolname as owner,
       n.nspname as schema,
       case d.defaclobjtype
         when 'r' then 'table'
         when 'S' then 'sequence'
         when 'f' then 'function'
         when 'T' then 'type'
         when 'n' then 'schema'
       end as object_type,
       gr.rolname as grantee,
       a.privilege_type,
       a.is_grantable
from pg_default_acl d
left join pg_namespace n on n.oid = d.defaclnamespace
join pg_roles r on r.oid = d.defaclrole
cross join lateral (
  select (aclexplode(d.defaclacl)).*
) as a(grantee, grantor, privilege_type, is_grantable)
join pg_roles gr on gr.oid = a.grantee
order by 1, 2, 3, 4, 5;
```
* 
| owner          | schema     | object_type | grantee        | privilege_type | is_grantable |
| -------------- | ---------- | ----------- | -------------- | -------------- | ------------ |
| postgres       | public     | function    | postgres       | EXECUTE        | false        |
| postgres       | public     | function    | postgres       | EXECUTE        | false        |
| postgres       | public     | function    | postgres       | EXECUTE        | false        |
| postgres       | public     | function    | postgres       | EXECUTE        | false        |
| postgres       | public     | sequence    | postgres       | SELECT         | false        |
| postgres       | public     | sequence    | postgres       | SELECT         | false        |
| postgres       | public     | sequence    | postgres       | SELECT         | false        |
| postgres       | public     | sequence    | postgres       | SELECT         | false        |
| postgres       | public     | sequence    | postgres       | UPDATE         | false        |
| postgres       | public     | sequence    | postgres       | UPDATE         | false        |
| postgres       | public     | sequence    | postgres       | UPDATE         | false        |
| postgres       | public     | sequence    | postgres       | UPDATE         | false        |
| postgres       | public     | sequence    | postgres       | USAGE          | false        |
| postgres       | public     | sequence    | postgres       | USAGE          | false        |
| postgres       | public     | sequence    | postgres       | USAGE          | false        |
| postgres       | public     | sequence    | postgres       | USAGE          | false        |
| postgres       | public     | table       | postgres       | DELETE         | false        |
| postgres       | public     | table       | postgres       | DELETE         | false        |
| postgres       | public     | table       | postgres       | DELETE         | false        |
| postgres       | public     | table       | postgres       | DELETE         | false        |
| postgres       | public     | table       | postgres       | INSERT         | false        |
| postgres       | public     | table       | postgres       | INSERT         | false        |
| postgres       | public     | table       | postgres       | INSERT         | false        |
| postgres       | public     | table       | postgres       | INSERT         | false        |
| postgres       | public     | table       | postgres       | REFERENCES     | false        |
| postgres       | public     | table       | postgres       | REFERENCES     | false        |
| postgres       | public     | table       | postgres       | REFERENCES     | false        |
| postgres       | public     | table       | postgres       | REFERENCES     | false        |
| postgres       | public     | table       | postgres       | SELECT         | false        |
| postgres       | public     | table       | postgres       | SELECT         | false        |
| postgres       | public     | table       | postgres       | SELECT         | false        |
| postgres       | public     | table       | postgres       | SELECT         | false        |
| postgres       | public     | table       | postgres       | TRIGGER        | false        |
| postgres       | public     | table       | postgres       | TRIGGER        | false        |
| postgres       | public     | table       | postgres       | TRIGGER        | false        |
| postgres       | public     | table       | postgres       | TRIGGER        | false        |
| postgres       | public     | table       | postgres       | TRUNCATE       | false        |
| postgres       | public     | table       | postgres       | TRUNCATE       | false        |
| postgres       | public     | table       | postgres       | TRUNCATE       | false        |
| postgres       | public     | table       | postgres       | TRUNCATE       | false        |
| postgres       | public     | table       | postgres       | UPDATE         | false        |
| postgres       | public     | table       | postgres       | UPDATE         | false        |
| postgres       | public     | table       | postgres       | UPDATE         | false        |
| postgres       | public     | table       | postgres       | UPDATE         | false        |
| postgres       | storage    | function    | postgres       | EXECUTE        | false        |
| postgres       | storage    | function    | postgres       | EXECUTE        | false        |
| postgres       | storage    | function    | postgres       | EXECUTE        | false        |
| postgres       | storage    | function    | postgres       | EXECUTE        | false        |
| postgres       | storage    | sequence    | postgres       | SELECT         | false        |
| postgres       | storage    | sequence    | postgres       | SELECT         | false        |
| postgres       | storage    | sequence    | postgres       | SELECT         | false        |
| postgres       | storage    | sequence    | postgres       | SELECT         | false        |
| postgres       | storage    | sequence    | postgres       | UPDATE         | false        |
| postgres       | storage    | sequence    | postgres       | UPDATE         | false        |
| postgres       | storage    | sequence    | postgres       | UPDATE         | false        |
| postgres       | storage    | sequence    | postgres       | UPDATE         | false        |
| postgres       | storage    | sequence    | postgres       | USAGE          | false        |
| postgres       | storage    | sequence    | postgres       | USAGE          | false        |
| postgres       | storage    | sequence    | postgres       | USAGE          | false        |
| postgres       | storage    | sequence    | postgres       | USAGE          | false        |
| postgres       | storage    | table       | postgres       | DELETE         | false        |
| postgres       | storage    | table       | postgres       | DELETE         | false        |
| postgres       | storage    | table       | postgres       | DELETE         | false        |
| postgres       | storage    | table       | postgres       | DELETE         | false        |
| postgres       | storage    | table       | postgres       | INSERT         | false        |
| postgres       | storage    | table       | postgres       | INSERT         | false        |
| postgres       | storage    | table       | postgres       | INSERT         | false        |
| postgres       | storage    | table       | postgres       | INSERT         | false        |
| postgres       | storage    | table       | postgres       | REFERENCES     | false        |
| postgres       | storage    | table       | postgres       | REFERENCES     | false        |
| postgres       | storage    | table       | postgres       | REFERENCES     | false        |
| postgres       | storage    | table       | postgres       | REFERENCES     | false        |
| postgres       | storage    | table       | postgres       | SELECT         | false        |
| postgres       | storage    | table       | postgres       | SELECT         | false        |
| postgres       | storage    | table       | postgres       | SELECT         | false        |
| postgres       | storage    | table       | postgres       | SELECT         | false        |
| postgres       | storage    | table       | postgres       | TRIGGER        | false        |
| postgres       | storage    | table       | postgres       | TRIGGER        | false        |
| postgres       | storage    | table       | postgres       | TRIGGER        | false        |
| postgres       | storage    | table       | postgres       | TRIGGER        | false        |
| postgres       | storage    | table       | postgres       | TRUNCATE       | false        |
| postgres       | storage    | table       | postgres       | TRUNCATE       | false        |
| postgres       | storage    | table       | postgres       | TRUNCATE       | false        |
| postgres       | storage    | table       | postgres       | TRUNCATE       | false        |
| postgres       | storage    | table       | postgres       | UPDATE         | false        |
| postgres       | storage    | table       | postgres       | UPDATE         | false        |
| postgres       | storage    | table       | postgres       | UPDATE         | false        |
| postgres       | storage    | table       | postgres       | UPDATE         | false        |
| supabase_admin | cron       | function    | supabase_admin | EXECUTE        | true         |
| supabase_admin | cron       | sequence    | supabase_admin | SELECT         | true         |
| supabase_admin | cron       | sequence    | supabase_admin | UPDATE         | true         |
| supabase_admin | cron       | sequence    | supabase_admin | USAGE          | true         |
| supabase_admin | cron       | table       | supabase_admin | DELETE         | true         |
| supabase_admin | cron       | table       | supabase_admin | INSERT         | true         |
| supabase_admin | cron       | table       | supabase_admin | REFERENCES     | true         |
| supabase_admin | cron       | table       | supabase_admin | SELECT         | true         |
| supabase_admin | cron       | table       | supabase_admin | TRIGGER        | true         |
| supabase_admin | cron       | table       | supabase_admin | TRUNCATE       | true         |
| supabase_admin | cron       | table       | supabase_admin | UPDATE         | true         |
| supabase_admin | extensions | function    | supabase_admin | EXECUTE        | true         |

---

## E) Roles & Settings

```sql
-- E1) Role inventory
select rolname,
       rolcanlogin,
       rolsuper,
       rolcreatedb,
       rolcreaterole,
       rolreplication,
       rolbypassrls
from pg_roles
order by 1;
```
* 
| rolname                    | rolcanlogin | rolsuper | rolcreatedb | rolcreaterole | rolreplication | rolbypassrls |
| -------------------------- | ----------- | -------- | ----------- | ------------- | -------------- | ------------ |
| anon                       | false       | false    | false       | false         | false          | false        |
| authenticated              | false       | false    | false       | false         | false          | false        |
| authenticator              | true        | false    | false       | false         | false          | false        |
| dashboard_user             | false       | false    | true        | true          | true           | false        |
| pg_checkpoint              | false       | false    | false       | false         | false          | false        |
| pg_database_owner          | false       | false    | false       | false         | false          | false        |
| pg_execute_server_program  | false       | false    | false       | false         | false          | false        |
| pg_monitor                 | false       | false    | false       | false         | false          | false        |
| pg_read_all_data           | false       | false    | false       | false         | false          | false        |
| pg_read_all_settings       | false       | false    | false       | false         | false          | false        |
| pg_read_all_stats          | false       | false    | false       | false         | false          | false        |
| pg_read_server_files       | false       | false    | false       | false         | false          | false        |
| pg_signal_backend          | false       | false    | false       | false         | false          | false        |
| pg_stat_scan_tables        | false       | false    | false       | false         | false          | false        |
| pg_write_all_data          | false       | false    | false       | false         | false          | false        |
| pg_write_server_files      | false       | false    | false       | false         | false          | false        |
| pgbouncer                  | true        | false    | false       | false         | false          | false        |
| postgres                   | true        | false    | true        | true          | true           | true         |
| service_role               | false       | false    | false       | false         | false          | true         |
| supabase_admin             | true        | true     | true        | true          | true           | true         |
| supabase_auth_admin        | true        | false    | false       | true          | false          | false        |
| supabase_read_only_user    | true        | false    | false       | false         | false          | true         |
| supabase_realtime_admin    | false       | false    | false       | false         | false          | false        |
| supabase_replication_admin | true        | false    | false       | false         | true           | false        |
| supabase_storage_admin     | true        | false    | false       | true          | false          | false        |

```sql
-- E2) Role memberships (role -> member)
select pr.rolname as role,
       pm.rolname as member
from pg_auth_members m
join pg_roles pr on pr.oid = m.roleid
join pg_roles pm on pm.oid = m.member
order by 1, 2;
```
* 
| role                    | member                  |
| ----------------------- | ----------------------- |
| anon                    | authenticator           |
| anon                    | postgres                |
| authenticated           | authenticator           |
| authenticated           | postgres                |
| authenticator           | supabase_storage_admin  |
| pg_monitor              | postgres                |
| pg_read_all_data        | postgres                |
| pg_read_all_data        | supabase_read_only_user |
| pg_read_all_settings    | pg_monitor              |
| pg_read_all_stats       | pg_monitor              |
| pg_signal_backend       | postgres                |
| pg_stat_scan_tables     | pg_monitor              |
| service_role            | authenticator           |
| service_role            | postgres                |
| supabase_realtime_admin | postgres                |


```sql
-- E3) Role settings (e.g., search_path overrides)
select r.rolname,
       string_agg(unnest.setconfig, ' | ') as settings
from pg_db_role_setting s
join pg_roles r on r.oid = s.setrole
cross join lateral unnest(s.setconfig) as unnest(setconfig)
where s.setdatabase = 0 -- role-level (any DB)
   or s.setdatabase = (select oid from pg_database where datname = current_database())
group by r.rolname
order by 1;
```
* 
| rolname                | settings                                                                          |
| ---------------------- | --------------------------------------------------------------------------------- |
| anon                   | statement_timeout=3s                                                              |
| authenticated          | statement_timeout=8s                                                              |
| authenticator          | lock_timeout=8s | session_preload_libraries=safeupdate | statement_timeout=8s     |
| postgres               | search_path="\$user", public, extensions                                          |
| supabase_admin         | search_path="$user", public, auth, extensions | log_statement=none                |
| supabase_auth_admin    | log_statement=none | search_path=auth | idle_in_transaction_session_timeout=60000 |
| supabase_storage_admin | search_path=storage | log_statement=none                                          |

```sql
-- E4) Quick check: effective grants for anon/authenticated on public tables
select t.table_schema as schema,
       t.table_name as table,
       g.grantee,
       g.privilege_type
from information_schema.tables t
left join information_schema.table_privileges g
  on g.table_schema = t.table_schema and g.table_name = t.table_name
where t.table_schema = 'public'
  and g.grantee in ('anon','authenticated')
order by 1, 2, 3, 4;
```
* 
| schema | table                      | grantee       | privilege_type |
| ------ | -------------------------- | ------------- | -------------- |
| public | active_agents              | anon          | DELETE         |
| public | active_agents              | anon          | INSERT         |
| public | active_agents              | anon          | REFERENCES     |
| public | active_agents              | anon          | SELECT         |
| public | active_agents              | anon          | TRIGGER        |
| public | active_agents              | anon          | TRUNCATE       |
| public | active_agents              | anon          | UPDATE         |
| public | active_agents              | authenticated | DELETE         |
| public | active_agents              | authenticated | INSERT         |
| public | active_agents              | authenticated | REFERENCES     |
| public | active_agents              | authenticated | SELECT         |
| public | active_agents              | authenticated | TRIGGER        |
| public | active_agents              | authenticated | TRUNCATE       |
| public | active_agents              | authenticated | UPDATE         |
| public | admin_audit_log            | anon          | DELETE         |
| public | admin_audit_log            | anon          | INSERT         |
| public | admin_audit_log            | anon          | REFERENCES     |
| public | admin_audit_log            | anon          | SELECT         |
| public | admin_audit_log            | anon          | TRIGGER        |
| public | admin_audit_log            | anon          | TRUNCATE       |
| public | admin_audit_log            | anon          | UPDATE         |
| public | admin_audit_log            | authenticated | DELETE         |
| public | admin_audit_log            | authenticated | INSERT         |
| public | admin_audit_log            | authenticated | REFERENCES     |
| public | admin_audit_log            | authenticated | SELECT         |
| public | admin_audit_log            | authenticated | TRIGGER        |
| public | admin_audit_log            | authenticated | TRUNCATE       |
| public | admin_audit_log            | authenticated | UPDATE         |
| public | admin_users                | anon          | DELETE         |
| public | admin_users                | anon          | INSERT         |
| public | admin_users                | anon          | REFERENCES     |
| public | admin_users                | anon          | SELECT         |
| public | admin_users                | anon          | TRIGGER        |
| public | admin_users                | anon          | TRUNCATE       |
| public | admin_users                | anon          | UPDATE         |
| public | admin_users                | authenticated | DELETE         |
| public | admin_users                | authenticated | INSERT         |
| public | admin_users                | authenticated | REFERENCES     |
| public | admin_users                | authenticated | SELECT         |
| public | admin_users                | authenticated | TRIGGER        |
| public | admin_users                | authenticated | TRUNCATE       |
| public | admin_users                | authenticated | UPDATE         |
| public | agent_geofence_assignments | anon          | DELETE         |
| public | agent_geofence_assignments | anon          | INSERT         |
| public | agent_geofence_assignments | anon          | REFERENCES     |
| public | agent_geofence_assignments | anon          | SELECT         |
| public | agent_geofence_assignments | anon          | TRIGGER        |
| public | agent_geofence_assignments | anon          | TRUNCATE       |
| public | agent_geofence_assignments | anon          | UPDATE         |
| public | agent_geofence_assignments | authenticated | DELETE         |
| public | agent_geofence_assignments | authenticated | INSERT         |
| public | agent_geofence_assignments | authenticated | REFERENCES     |
| public | agent_geofence_assignments | authenticated | SELECT         |
| public | agent_geofence_assignments | authenticated | TRIGGER        |
| public | agent_geofence_assignments | authenticated | TRUNCATE       |
| public | agent_geofence_assignments | authenticated | UPDATE         |
| public | agent_location_tracking    | anon          | DELETE         |
| public | agent_location_tracking    | anon          | INSERT         |
| public | agent_location_tracking    | anon          | REFERENCES     |
| public | agent_location_tracking    | anon          | SELECT         |
| public | agent_location_tracking    | anon          | TRIGGER        |
| public | agent_location_tracking    | anon          | TRUNCATE       |
| public | agent_location_tracking    | anon          | UPDATE         |
| public | agent_location_tracking    | authenticated | DELETE         |
| public | agent_location_tracking    | authenticated | INSERT         |
| public | agent_location_tracking    | authenticated | REFERENCES     |
| public | agent_location_tracking    | authenticated | SELECT         |
| public | agent_location_tracking    | authenticated | TRIGGER        |
| public | agent_location_tracking    | authenticated | TRUNCATE       |
| public | agent_location_tracking    | authenticated | UPDATE         |
| public | app_settings               | anon          | DELETE         |
| public | app_settings               | anon          | INSERT         |
| public | app_settings               | anon          | REFERENCES     |
| public | app_settings               | anon          | SELECT         |
| public | app_settings               | anon          | TRIGGER        |
| public | app_settings               | anon          | TRUNCATE       |
| public | app_settings               | anon          | UPDATE         |
| public | app_settings               | authenticated | DELETE         |
| public | app_settings               | authenticated | INSERT         |
| public | app_settings               | authenticated | REFERENCES     |
| public | app_settings               | authenticated | SELECT         |
| public | app_settings               | authenticated | TRIGGER        |
| public | app_settings               | authenticated | TRUNCATE       |
| public | app_settings               | authenticated | UPDATE         |
| public | app_versions               | anon          | DELETE         |
| public | app_versions               | anon          | INSERT         |
| public | app_versions               | anon          | REFERENCES     |
| public | app_versions               | anon          | SELECT         |
| public | app_versions               | anon          | TRIGGER        |
| public | app_versions               | anon          | TRUNCATE       |
| public | app_versions               | anon          | UPDATE         |
| public | app_versions               | authenticated | DELETE         |
| public | app_versions               | authenticated | INSERT         |
| public | app_versions               | authenticated | REFERENCES     |
| public | app_versions               | authenticated | SELECT         |
| public | app_versions               | authenticated | TRIGGER        |
| public | app_versions               | authenticated | TRUNCATE       |
| public | app_versions               | authenticated | UPDATE         |
| public | audit_log                  | anon          | DELETE         |
| public | audit_log                  | anon          | INSERT         |


---

## F) Views (extras)

```sql
-- F1) Views with check option (can block writes via view)
select table_schema as schema,
       table_name   as view,
       check_option,
       is_updatable
from information_schema.views
where table_schema not in ('pg_catalog','information_schema')
order by 1, 2;
```
* 
| schema     | view                        | check_option | is_updatable |
| ---------- | --------------------------- | ------------ | ------------ |
| extensions | geography_columns           | NONE         | NO           |
| extensions | geometry_columns            | NONE         | YES          |
| extensions | pg_stat_statements          | NONE         | NO           |
| extensions | pg_stat_statements_info     | NONE         | NO           |
| public     | location_history_app_format | NONE         | YES          |
| public     | route_completion_progress   | NONE         | NO           |
| public     | user_status_view            | NONE         | NO           |
| vault      | decrypted_secrets           | NONE         | YES          |

---

## G) Optional Diagnostics

```sql
-- G1) Orphan sequences (not owned by any column)
select n.nspname as schema,
       c.relname  as sequence
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_depend d on d.objid = c.oid and d.deptype = 'a'
where c.relkind = 'S'
  and n.nspname not in ('pg_catalog','information_schema')
  and d.objid is null
order by 1, 2;
```
* 
| schema   | sequence            |
| -------- | ------------------- |
| cron     | jobid_seq           |
| cron     | runid_seq           |
| graphql  | seq_schema_version  |
| realtime | subscription_id_seq |

```sql
-- G2) Foreign servers (if any fdw configured)
select s.srvname as server,
       s.srvtype as type,
       s.srvversion as version,
       s.srvowner::regrole as owner
from pg_foreign_server s
order by 1;
```
* 
Success. No rows returned
```
-- G3) Event triggers (rare, but useful to surface)
select evtname as trigger_name,
       evtenabled as enabled,
       evtfoid::regproc as function
from pg_event_trigger
order by 1;
```

---

If you prefer a narrower scope, tell me which schema(s) to filter and I’ll trim the queries accordingly.
