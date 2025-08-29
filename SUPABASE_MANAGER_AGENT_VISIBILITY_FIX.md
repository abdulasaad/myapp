# Manager Agent Visibility — Final Fix (Copy/Paste SQL)

This script fixes “manager sees zero agents” by:
- Adding a manager-aware SELECT policy on `public.profiles` using `user_groups` membership.
- Replacing RPC `public.get_agents_in_manager_groups(manager_user_id uuid)` to use membership (not `groups.manager_id`).
- Verifying counts as the manager.

Replace <MANAGER_UUID> with: 272afd47-5e8d-4411-8369-81b03abaf9c5

---

## 0) Impersonate Manager (for tests)
```sql
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);
```
* 
| set_config                                       |
| ------------------------------------------------ |
| {"sub" : "272afd47-5e8d-4411-8369-81b03abaf9c5"} |

---

## 1) Profiles: helper + policy for manager visibility (correct syntax)
```sql
create or replace function public.manager_can_view_profile(target_user_id uuid)
returns boolean
language sql
stable
security invoker
as $$
  select exists (
    select 1
    from public.user_groups gm
    join public.user_groups ug on ug.group_id = gm.group_id
    where gm.user_id = auth.uid()      -- current manager (from JWT)
      and ug.user_id = target_user_id  -- candidate profile
  )
$$;
```
* 
Success. No rows returned

```sql
-- Allow managers (authenticated) to select profiles of users in their groups
-- This is additive to your existing policies
drop policy if exists manager_can_select_group_profiles on public.profiles;
create policy manager_can_select_group_profiles
  on public.profiles
  for select
  to authenticated
  using (
    public.manager_can_view_profile(public.profiles.id)
  );
```
* 
Success. No rows returned
```sql
-- Ensure role can execute the helper
grant execute on function public.manager_can_view_profile(uuid) to authenticated;
```
* 
Success. No rows returned

---

## 2) Replace RPC: get_agents_in_manager_groups (use membership)
-- If this fails with "cannot change return type", see the V2 fallback below.
```sql
drop function if exists public.get_agents_in_manager_groups(uuid);
create or replace function public.get_agents_in_manager_groups(manager_user_id uuid)
returns table (
  id uuid,
  full_name text,
  username text,
  email text,
  role text,
  status text,
  connection_status text,
  last_heartbeat timestamptz,
  last_location text,
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
    p.connection_status,
    p.last_heartbeat,
    p.last_location::text,
    p.last_seen,
    p.created_at,
    g.name as group_name
  from public.user_groups gm                    -- manager memberships
  join public.groups g on g.id = gm.group_id    -- manager's groups
  join public.user_groups ag on ag.group_id = g.id
  join public.profiles p on p.id = ag.user_id
  where p.role = 'agent'
    and gm.user_id = auth.uid()                 -- trust JWT for security
$$;
```
* 
ERROR:  42703: column p.last_location does not exist
LINE 30:     p.last_location::text,
             ^

---

## 2B) Fallback (only if 2) failed with return-type error)
-- Create a new RPC and switch app to call it (v2 keeps same params but new name).
```sql
create or replace function public.get_agents_in_manager_groups_v2(manager_user_id uuid)
returns table (
  id uuid,
  full_name text,
  username text,
  email text,
  role text,
  status text,
  connection_status text,
  last_heartbeat timestamptz,
  last_location text,
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
    p.connection_status,
    p.last_heartbeat,
    p.last_location::text,
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
```
* 
ERROR:  42703: column p.last_location does not exist
LINE 29:     p.last_location::text,
             ^

-- If you used v2, update the app call:
-- File: lib/screens/manager/team_members_screen.dart:56
-- .rpc('get_agents_in_manager_groups', params: {'manager_user_id': currentUser.id})
-- becomes
-- .rpc('get_agents_in_manager_groups_v2', params: {'manager_user_id': currentUser.id})

---

## 3) Sanity checks (run as manager)
```sql
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);

*  
| set_config                                       |
| ------------------------------------------------ |
| {"sub" : "272afd47-5e8d-4411-8369-81b03abaf9c5"} |

-- RPC count
select count(*) as rpc_count
from public.get_agents_in_manager_groups('272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid);
* 
| rpc_count |
| --------- |
| 0         |

-- Direct profiles (policy should allow only group members)
select count(*) as profiles_visible
from public.profiles
where role = 'agent'
  and public.manager_can_view_profile(id);

* 
| profiles_visible |
| ---------------- |
| 0                |

-- Optional: list emails
select p.id, p.email
from public.profiles p
where p.role = 'agent'
  and public.manager_can_view_profile(p.id)
order by p.email;
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

Expected: both counts = 7, and the list includes your 7 agents.
