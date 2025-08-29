# Manager → Group → Agents — Next Steps (No placeholders; matches your schema)

Based on your outputs:
- user_groups columns: id, user_id, group_id, created_at.
- user_groups.user_id → profiles.id (FK), user_groups.group_id → groups.id (FK).
- No role column on user_groups; use membership only.
- RLS enabled on profiles/groups/user_groups, but user_groups has permissive SELECT policies for authenticated.

Run these blocks in order. These avoid the earlier placeholder and ANY(array[...]) issues.

---

## 1) Impersonate Manager (optional but recommended)

```sql
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);
select current_user as running_as_role,
       current_setting('request.jwt.claims', true) as claims,
       auth.uid() as uid;
```
* 
| running_as_role | claims                                           | uid                                  |
| --------------- | ------------------------------------------------ | ------------------------------------ |
| authenticated   | {"sub" : "272afd47-5e8d-4411-8369-81b03abaf9c5"} | 272afd47-5e8d-4411-8369-81b03abaf9c5 |

---

## 2) Manager’s Group Membership (direct check)

```sql
select *
from public.user_groups ug
where ug.user_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid
order by ug.group_id
limit 100;
```
* 
| id                                   | user_id                              | group_id                             | created_at                    |
| ------------------------------------ | ------------------------------------ | ------------------------------------ | ----------------------------- |
| 627d85bc-c8a8-423e-a081-3d5d05202351 | 272afd47-5e8d-4411-8369-81b03abaf9c5 | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | 2025-07-10 11:58:48.381559+00 |

---

## 3) Ground‑Truth: Agents in Manager’s Groups (uses user_groups.user_id)

```sql
select p.id as agent_id, p.email, g.id as group_id, g.name as group_name
from public.user_groups gm                            -- rows where the manager belongs
join public.groups g on g.id = gm.group_id            -- the manager's groups
join public.user_groups ag on ag.group_id = g.id      -- other members of those groups
join public.profiles p on p.id = ag.user_id           -- member user profiles
where gm.user_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid
  and p.role = 'agent'
order by g.id, p.email;
```
* 
| agent_id                             | email                   | group_id                             | group_name |
| ------------------------------------ | ----------------------- | ------------------------------------ | ---------- |
| d7ec615c-480c-4292-8e5a-89b265778c48 | abseealaseel@gmail.com  | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | AL-Tijwal  |
| c351d635-82a5-4efa-a636-5db3676e0cb4 | dhyabmstfy34@gmail.com  | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | AL-Tijwal  |
| e73f3ea1-75e7-4c19-9ef3-fd982de5e2da | fadelkhaled41@gmail.com | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | AL-Tijwal  |
| 6cd99aa8-b005-4958-a8ec-a1fb410686e7 | gafar6760@gmail.com     | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | AL-Tijwal  |
| a34beabd-ea6c-4105-8491-105d83b85a5a | iraqi900iraqi@gmail.com | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | AL-Tijwal  |
| 40a2950d-1b87-461d-9562-2bf0be766c57 | kadmmhmdkadm2@gmail.com | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | AL-Tijwal  |
| 263e832c-f73c-48f3-bfd2-1b567cbff0b1 | user.agent2@test.com    | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | AL-Tijwal  |

```sql
-- Count only
select count(*) from (
  select 1
  from public.user_groups gm
  join public.user_groups ag on ag.group_id = gm.group_id
  join public.profiles p on p.id = ag.user_id and p.role = 'agent'
  where gm.user_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid
) s;
```
* 
| count |
| ----- |
| 7     |

---

## 4) Locate Suspect Function (simplified; avoids ANY/array)

```sql
select n.nspname as schema, p.proname as function, p.oid
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public','auth')
  and (
    lower(p.proname) like '%agent%' or lower(p.proname) like '%group%' or lower(p.proname) like '%manager%'
    or lower(pg_get_functiondef(p.oid)) like '%user_groups%'
    or lower(pg_get_functiondef(p.oid)) like '% groups %'
    or lower(pg_get_functiondef(p.oid)) like '%profiles%'
  )
order by 1,2;
```
* 
| schema | function                                  | oid    |
| ------ | ----------------------------------------- | ------ |
| public | assign_agent_to_geofence                  | 79052  |
| public | auto_assign_new_task_to_agents            | 24577  |
| public | auto_assign_tasks_to_new_agent            | 20108  |
| public | can_create_agent                          | 28811  |
| public | can_update_profile                        | 56672  |
| public | check_agent_in_campaign_geofence          | 21806  |
| public | check_agent_in_place_geofence             | 60894  |
| public | check_agent_in_task_geofence              | 44866  |
| public | check_profile_select_permission           | 92006  |
| public | check_profile_update_permission           | 56776  |
| public | confirm_user_email                        | 113788 |
| public | debug_location_data                       | 87772  |
| public | debug_location_updates                    | 75729  |
| public | ensure_agent_in_campaign                  | 84170  |
| public | ensure_agent_in_campaign_touring          | 84172  |
| public | get_active_agents                         | 20432  |
| public | get_active_agents_for_manager             | 123925 |
| public | get_agent_campaign_details                | 38882  |
| public | get_agent_campaign_details_fixed          | 39105  |
| public | get_agent_earnings_for_campaign           | 84144  |
| public | get_agent_location_history                | 106544 |
| public | get_agent_overall_earnings                | 84145  |
| public | get_agent_progress_for_campaign           | 38861  |
| public | get_agent_progress_for_task               | 27488  |
| public | get_agent_survey_submissions              | 132820 |
| public | get_agent_tasks_for_campaign              | 23332  |
| public | get_agents_in_geofence                    | 128906 |
| public | get_agents_in_manager_groups              | 141323 |
| public | get_agents_with_last_location             | 75896  |
| public | get_agents_within_radius                  | 128907 |
| public | get_all_agents_for_admin                  | 77251  |
| public | get_all_agents_with_location_for_admin    | 87960  |
| public | get_assigned_agents                       | 20086  |
| public | get_calendar_events                       | 62370  |
| public | get_campaigns_scoped                      | 129016 |
| public | get_dashboard_metrics                     | 123844 |
| public | get_manager_agent_profiles                | 142472 |
| public | get_manager_campaigns                     | 128841 |
| public | get_manager_timezone                      | 66934  |
| public | get_my_creation_count                     | 28810  |
| public | get_my_role                               | 18571  |
| public | get_report_agent_performance              | 129012 |
| public | get_report_campaign_summary               | 129013 |
| public | get_routes_scoped                         | 129017 |
| public | get_task_agent_progress_batch             | 44908  |
| public | get_user_role_secure                      | 120483 |
| public | get_user_timezone                         | 66935  |
| public | get_users_by_status                       | 75101  |
| public | handle_new_user                           | 18381  |
| public | is_user_admin                             | 120484 |
| public | reset_user_password_direct                | 56630  |
| public | sync_active_agents_fields                 | 93776  |
| public | sync_campaign_agents_from_tasks           | 97462  |
| public | test_client_access                        | 94268  |
| public | update_agent_geofence_status              | 79074  |
| public | update_agent_name_secure                  | 56902  |
| public | update_manager_template_access_updated_at | 50188  |
| public | update_user_heartbeat                     | 75256  |

```sql
-- Show DDL by OID (replace 12345 with picked oid)
select pg_get_functiondef(12345::oid) as ddl;
```
* 
| ddl  |
| ---- |
| null |

```sql
-- If you know the function name but not signature
select p.oid, p.proname, pg_get_function_identity_arguments(p.oid) as args
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname ilike '%agent%';
-- Then: select pg_get_functiondef(<oid>)
```
* 
| oid    | proname                                | args                                                                                                         |
| ------ | -------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| 38861  | get_agent_progress_for_campaign        | p_campaign_id uuid, p_agent_id uuid                                                                          |
| 27488  | get_agent_progress_for_task            | p_task_id uuid, p_agent_id uuid                                                                              |
| 38882  | get_agent_campaign_details             | p_agent_id uuid, p_campaign_id uuid                                                                          |
| 20086  | get_assigned_agents                    | p_campaign_id uuid                                                                                           |
| 23332  | get_agent_tasks_for_campaign           | p_campaign_id uuid                                                                                           |
| 28811  | can_create_agent                       |                                                                                                              |
| 39105  | get_agent_campaign_details_fixed       | p_campaign_id uuid, p_agent_id uuid                                                                          |
| 20432  | get_active_agents                      |                                                                                                              |
| 142472 | get_manager_agent_profiles             |                                                                                                              |
| 21806  | check_agent_in_campaign_geofence       | p_agent_id uuid, p_campaign_id uuid                                                                          |
| 60894  | check_agent_in_place_geofence          | place_uuid uuid, agent_lat double precision, agent_lng double precision                                      |
| 44866  | check_agent_in_task_geofence           | p_agent_id uuid, p_task_id uuid, p_agent_lat double precision, p_agent_lng double precision                  |
| 44908  | get_task_agent_progress_batch          | p_task_id uuid                                                                                               |
| 56902  | update_agent_name_secure               | target_user_id uuid, new_full_name text                                                                      |
| 97462  | sync_campaign_agents_from_tasks        |                                                                                                              |
| 84145  | get_agent_overall_earnings             | p_agent_id uuid                                                                                              |
| 128906 | get_agents_in_geofence                 | geofence_id uuid                                                                                             |
| 84144  | get_agent_earnings_for_campaign        | p_agent_id uuid, p_campaign_id uuid                                                                          |
| 77251  | get_all_agents_for_admin               |                                                                                                              |
| 128907 | get_agents_within_radius               | center_lat double precision, center_lng double precision, radius_meters integer                              |
| 84170  | ensure_agent_in_campaign               |                                                                                                              |
| 84172  | ensure_agent_in_campaign_touring       |                                                                                                              |
| 123925 | get_active_agents_for_manager          |                                                                                                              |
| 24577  | auto_assign_new_task_to_agents         |                                                                                                              |
| 20108  | auto_assign_tasks_to_new_agent         |                                                                                                              |
| 93776  | sync_active_agents_fields              |                                                                                                              |
| 87960  | get_all_agents_with_location_for_admin | requesting_user_id uuid                                                                                      |
| 132820 | get_agent_survey_submissions           | agent_uuid uuid, campaign_uuid uuid                                                                          |
| 141323 | get_agents_in_manager_groups           | manager_user_id uuid                                                                                         |
| 129012 | get_report_agent_performance           | manager_user_id uuid, from_date date, to_date date                                                           |
| 79052  | assign_agent_to_geofence               | p_campaign_id uuid, p_geofence_id uuid, p_agent_id uuid                                                      |
| 106544 | get_agent_location_history             | p_agent_id uuid, p_start_date timestamp with time zone, p_end_date timestamp with time zone, p_limit integer |
| 79074  | update_agent_geofence_status           | p_agent_id uuid, p_geofence_id uuid, p_latitude numeric, p_longitude numeric, p_is_inside boolean            |
| 75896  | get_agents_with_last_location          |                                                                                                              |

---

## 5) Proposed Fix Function (uses membership; no reliance on groups.manager_id)

```sql
-- Returns agent ids visible to current manager
create or replace function public.get_manager_agent_ids()
returns setof uuid
language sql
security invoker
stable
as $$
  select p.id
  from public.user_groups gm
  join public.user_groups ag on ag.group_id = gm.group_id
  join public.profiles p on p.id = ag.user_id and p.role = 'agent'
  where gm.user_id = auth.uid()
$$;
```
* 
Success. No rows returned

```sql
-- Quick test (after creating function). Still impersonate manager from step 1
select * from public.get_manager_agent_ids() limit 50;
```
* 
Success. No rows returned

---

## 6) Optional: RLS sanity

```sql
-- Ensure manager can at least read needed rows
select 'profiles' src, count(*) from public.profiles
union all
select 'user_groups', count(*) from public.user_groups
union all
select 'groups', count(*) from public.groups;
```
* 
| src         | count |
| ----------- | ----- |
| profiles    | 15    |
| user_groups | 12    |
| groups      | 3     |

Notes
- If step 4 reveals the real function, share its DDL and I’ll adapt the fix accordingly.
- If step 6 shows zero for user_groups, RLS blocks reads despite permissive policies; paste E2 policies for user_groups again.
