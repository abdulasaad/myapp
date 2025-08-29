# Manager Agents — Error‑Free RPC Fix (Copy/Paste SQL)

Purpose
- Fix the app RPC to return agents via group membership without referencing missing columns (e.g., p.last_location).
- Keep it simple: only fields that exist on public.profiles plus group_name.

Uses manager UUID: 272afd47-5e8d-4411-8369-81b03abaf9c5

---

## 1) Create safe v2 RPC (no missing columns)
```sql
create or replace function public.get_agents_in_manager_groups_v2(manager_user_id uuid)
returns table (
  id uuid,
  full_name text,
  username text,
  email text,
  role text,
  status text,
  last_seen timestamptz,
  created_at timestamptz,
  group_name text
)
language sql
security invoker
stable
as $$
  select
    p.id,
    p.full_name,
    p.username,
    p.email,
    p.role,
    p.status,
    p.last_seen,
    p.created_at,
    g.name as group_name
  from public.user_groups gm
  join public.groups g on g.id = gm.group_id
  join public.user_groups ag on ag.group_id = g.id
  join public.profiles p on p.id = ag.user_id
  where p.role = 'agent'
    and gm.user_id = auth.uid()
$$;

grant execute on function public.get_agents_in_manager_groups_v2(uuid) to authenticated;
```
* 
ERROR:  42703: column p.last_seen does not exist
LINE 24:     p.last_seen,
             ^

---

## 2) Verify v2 returns 7 for the manager
```sql
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);

select count(*) as rpc_v2_count
from public.get_agents_in_manager_groups_v2('272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid);

-- Optional list
select id, email, group_name
from public.get_agents_in_manager_groups_v2('272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid)
order by email;
```
* 
ERROR:  42883: function public.get_agents_in_manager_groups_v2(uuid) does not exist
LINE 5: from public.get_agents_in_manager_groups_v2('272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid);
             ^


Expected: rpc_v2_count = 7 (matches your earlier list).

---

## 3) Choose how to wire the app
- Option A (preferred): Update RPC call to use v2
  - File: lib/screens/manager/team_members_screen.dart:56
    - `.rpc('get_agents_in_manager_groups', ...)` → `.rpc('get_agents_in_manager_groups_v2', ...)`
  - File: lib/screens/map/live_map_screen.dart:358
    - `.rpc('get_agents_in_manager_groups', ...)` → `.rpc('get_agents_in_manager_groups_v2', ...)`

- Option B (no code change): Replace v1 with safe shape
  - Note: This removes unused columns like last_location to avoid errors.
```sql
-- Remove old v1 and recreate it with the safe v2 shape
drop function if exists public.get_agents_in_manager_groups(uuid);
create or replace function public.get_agents_in_manager_groups(manager_user_id uuid)
returns table (
  id uuid,
  full_name text,
  username text,
  email text,
  role text,
  status text,
  last_seen timestamptz,
  created_at timestamptz,
  group_name text
)
language sql
security invoker
stable
as $$
  select
    p.id,
    p.full_name,
    p.username,
    p.email,
    p.role,
    p.status,
    p.last_seen,
    p.created_at,
    g.name as group_name
  from public.user_groups gm
  join public.groups g on g.id = gm.group_id
  join public.user_groups ag on ag.group_id = g.id
  join public.profiles p on p.id = ag.user_id
  where p.role = 'agent'
    and gm.user_id = auth.uid()
$$;

grant execute on function public.get_agents_in_manager_groups(uuid) to authenticated;
```
* 
ERROR:  42703: column p.last_seen does not exist
LINE 25:     p.last_seen,
             ^
             
---

## 4) Final sanity (manager session)
```sql
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);

-- If you updated the app to v2
select count(*) as rpc_v2_count
from public.get_agents_in_manager_groups_v2('272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid);

-- If you kept v1
select count(*) as rpc_v1_count
from public.get_agents_in_manager_groups('272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid);
```
* 
ERROR:  42883: function public.get_agents_in_manager_groups_v2(uuid) does not exist
LINE 6: from public.get_agents_in_manager_groups_v2('272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid);
             ^
             
If any step errors, paste the exact error and I’ll adjust immediately.
