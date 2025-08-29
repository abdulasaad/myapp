# Manager → Group → Agents — Targeted Fix for Zero Agents

Summary from your latest run
- Manager membership exists in `public.user_groups` for group `66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9`.
- Ground‑truth agents in manager’s groups: 7 (list already shown in your NEXT file).
- Suspect function present: `public.get_manager_agent_profiles` (oid 142472). Likely relies on `groups.manager_id` rather than membership.

Run blocks in order. Stop at the first error and paste it back if anything fails.

---

## A) Verify current function behavior and capture DDL

```sql
-- A1) Actual count returned by the current function (expect 0 right now)
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);
select count(*) as function_count from public.get_manager_agent_profiles();
```
* 
| function_count |
| -------------- |
| 7              |

```sql
-- A2) Dump current function definition (two options; either should work)
select pg_get_functiondef(142472::oid) as ddl;              -- using OID from your list
-- or
select pg_get_functiondef('public.get_manager_agent_profiles'::regproc) as ddl;
```
* 
| ddl                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| CREATE OR REPLACE FUNCTION public.get_manager_agent_profiles()
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

---

## B) Replace function to use membership (Option A: returns full profiles)

```sql
-- Use this if the original function returns rows of public.profiles
create or replace function public.get_manager_agent_profiles()
returns setof public.profiles
language sql
security invoker
stable
as $$
  select p.*
  from public.user_groups gm                      -- manager memberships
  join public.user_groups ag on ag.group_id = gm.group_id
  join public.profiles p on p.id = ag.user_id
  where gm.user_id = auth.uid()
    and p.role = 'agent'
$$;
```
* 
ERROR:  42P13: cannot change return type of existing function
HINT:  Use DROP FUNCTION get_manager_agent_profiles() first.

```sql
-- Sanity check after Option A
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);
select count(*) as function_count_after from public.get_manager_agent_profiles();
select id, email from public.get_manager_agent_profiles() order by email limit 50;
```
* 
| id                                   | email                   |
| ------------------------------------ | ----------------------- |
| d7ec615c-480c-4292-8e5a-89b265778c48 | abseealaseel@gmail.com  |
| c351d635-82a5-4efa-a636-5db3676e0cb4 | dhyabmstfy34@gmail.com  |
| e73f3ea1-75e7-4c19-9ef3-fd982de5e2da | fadelkhaled41@gmail.com |
| 6cd99aa8-b005-4958-a8ec-a1fb410686e7 | gafar6760@gmail.com     |
| a34beabd-ea6c-4105-8491-105d83b85a5a | iraqi900iraqi@gmail.com |
| 40a2950d-1b87-461d-9562-2bf0be766c57 | kadmmhmdkadm2@gmail.com |
| 263e832c-f73c-48f3-bfd2-1b567cbff0b1 | user.agent2@test.com    |

---

## C) Alternative shape (Option B: returns only agent ids)

```sql
-- Use this if Option A errors due to return type mismatch and the original returns IDs
create or replace function public.get_manager_agent_profiles()
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
ERROR:  42P13: cannot change return type of existing function
HINT:  Use DROP FUNCTION get_manager_agent_profiles() first.

```sql
-- Sanity check after Option B
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);
select count(*) as function_count_after from public.get_manager_agent_profiles();
select * from public.get_manager_agent_profiles() limit 50;
```
* 
| id                                   | full_name         | username      | email                   | role  | status | connection_status | last_heartbeat                | last_location           | last_seen                     | created_at                    | group_name |
| ------------------------------------ | ----------------- | ------------- | ----------------------- | ----- | ------ | ----------------- | ----------------------------- | ----------------------- | ----------------------------- | ----------------------------- | ---------- |
| 263e832c-f73c-48f3-bfd2-1b567cbff0b1 | Ahmed Ali         | agent2        | user.agent2@test.com    | agent | active | active            | 2025-08-20 07:04:26.557256+00 | (44.3868342,33.3166776) | 2025-08-20 07:04:44.801457+00 | 2025-06-26 22:09:49.637687+00 | AL-Tijwal  |
| a34beabd-ea6c-4105-8491-105d83b85a5a | اسعد عبدالله مراد | asaad         | iraqi900iraqi@gmail.com | agent | active | offline           | 2025-08-01 19:08:17.7568+00   | (44.3626734,33.3678534) | 2025-08-01 19:08:18.654148+00 | 2025-07-12 12:21:43.395755+00 | AL-Tijwal  |
| 6cd99aa8-b005-4958-a8ec-a1fb410686e7 | جعفر طارق صبيح    | gafar         | gafar6760@gmail.com     | agent | active | offline           | 2025-08-22 20:47:32.065429+00 | (44.453996,33.3775192)  | 2025-08-22 20:43:17.812499+00 | 2025-07-10 13:16:16.633328+00 | AL-Tijwal  |
| 40a2950d-1b87-461d-9562-2bf0be766c57 | حبيب كاظم محمد    | kadmmhmdkadm2 | kadmmhmdkadm2@gmail.com | agent | active | offline           | 2025-08-29 10:19:16.962561+00 | null                    | null                          | 2025-08-15 06:59:03.298631+00 | AL-Tijwal  |
| d7ec615c-480c-4292-8e5a-89b265778c48 | عباس عزالدين محسن | abas          | abseealaseel@gmail.com  | agent | active | offline           | null                          | null                    | null                          | 2025-07-10 11:32:14.179103+00 | AL-Tijwal  |
| e73f3ea1-75e7-4c19-9ef3-fd982de5e2da | فاضل خالد صالح    | null          | fadelkhaled41@gmail.com | agent | active | offline           | 2025-08-01 20:26:31.141219+00 | (44.2631507,33.347145)  | 2025-08-01 20:26:19.851658+00 | 2025-08-01 19:12:33.522008+00 | AL-Tijwal  |
| c351d635-82a5-4efa-a636-5db3676e0cb4 | مصطفى ذياب        | mustafa       | dhyabmstfy34@gmail.com  | agent | active | offline           | 2025-08-15 22:24:41.187378+00 | (44.2617802,33.3472055) | 2025-08-15 22:13:41.291948+00 | 2025-07-10 11:35:24.537014+00 | AL-Tijwal  |
---

Notes
- Keep `security invoker` so RLS still applies. Your current policies already allow managers to read required rows.
- If both options fail, paste the exact DDL (from A2) and the error; I’ll tailor the definition to match the original return type precisely.
