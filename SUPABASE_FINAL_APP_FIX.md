# Manager Agents Show Zero — Final App-Facing Fix (Copy/Paste SQL)

This ensures the RPC used by the app returns the 7 agents your manager should see and that policies allow direct profile reads when used.

Manager UUID (pre-filled): 272afd47-5e8d-4411-8369-81b03abaf9c5

---

## 1) Quick verification of both RPCs (manager session)
```sql
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);

-- App RPC
select count(*) as rpc_v1_count
from public.get_agents_in_manager_groups('272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid);

-- Known-good RPC
select count(*) as profiles_rpc_count
from public.get_manager_agent_profiles();
```
* 
| profiles_rpc_count |
| ------------------ |
| 7                  |

Expected: profiles_rpc_count = 7. If rpc_v1_count != 7, proceed to 2).

---

## 2) Force-replace the app RPC to use membership
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
  from public.user_groups gm                     -- manager memberships
  join public.groups g on g.id = gm.group_id     -- manager's groups
  join public.user_groups ag on ag.group_id = g.id
  join public.profiles p on p.id = ag.user_id
  where p.role = 'agent'
    and gm.user_id = auth.uid()                  -- rely on JWT for security
$$;

-- Ensure execution permissions for API role
grant execute on function public.get_agents_in_manager_groups(uuid) to authenticated;
```
ERROR:  42703: column p.last_location does not exist
LINE 30:     p.last_location::text,
             ^

Re-test step 1: rpc_v1_count should now be 7.

If you see "cannot change return type" here, the existing function has a different shape. Use v2 below and switch app to call it.

---

## 2B) Create v2 RPC (if 2) failed) and grant execute
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

grant execute on function public.get_agents_in_manager_groups_v2(uuid) to authenticated;
```
* 
ERROR:  42703: column p.last_location does not exist
LINE 29:     p.last_location::text,
             ^

Now update the app to call v2 instead of v1 (one line change):
- File: lib/screens/manager/team_members_screen.dart:56
- Change: `.rpc('get_agents_in_manager_groups', params: {'manager_user_id': currentUser.id})`
- To: `.rpc('get_agents_in_manager_groups_v2', params: {'manager_user_id': currentUser.id})`

---

## 3) Profiles policy helper (fixes direct profiles reads elsewhere)
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
    where gm.user_id = auth.uid()
      and ug.user_id = target_user_id
  )
$$;

drop policy if exists manager_can_select_group_profiles on public.profiles;
create policy manager_can_select_group_profiles
  on public.profiles
  for select
  to authenticated
  using (
    public.manager_can_view_profile(public.profiles.id)
  );

grant execute on function public.manager_can_view_profile(uuid) to authenticated;
```
* 
Success. No rows returned

---

## 4) Final verification (manager session)
```sql
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);

-- RPC used by app (v1 or v2, depending on what you applied)
select count(*) as rpc_count
from public.get_agents_in_manager_groups('272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid);
-- or
select count(*) as rpc_v2_count
from public.get_agents_in_manager_groups_v2('272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid);

-- Direct profiles (should match 7 through the policy)
select count(*) as profiles_visible
from public.profiles
where role = 'agent'
  and public.manager_can_view_profile(id);
```
* 
ERROR:  42883: function public.get_agents_in_manager_groups_v2(uuid) does not exist
LINE 9: from public.get_agents_in_manager_groups_v2('272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid);
             ^
HINT:  No function matches the given name and argument types. You might need to add explicit type casts.

If any step errors, paste the exact error and I will adjust to your current function signature.
