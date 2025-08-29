# Manager Agents — Minimal RPC Fix (No Missing Columns)

Purpose
- Create an RPC that only selects columns guaranteed on `public.profiles`: `id, full_name, username, email, role, status, created_at` plus `group_name`.
- Avoids errors like “column p.last_seen does not exist”.

Manager UUID: 272afd47-5e8d-4411-8369-81b03abaf9c5

---

## 1) Create minimal v2 RPC (safe schema)
```sql
create or replace function public.get_agents_in_manager_groups_v2(manager_user_id uuid)
returns table (
  id uuid,
  full_name text,
  username text,
  email text,
  role text,
  status text,
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
Success. No rows returned

---

## 2) Optional: replace v1 with minimal shape (no app code change)
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
* Success. No rows returned ( after this sql now i can see 7 agent from the manager account)
---

## 3) Verify (manager session)
```sql
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);

-- If using v2
select count(*) as rpc_v2_count
from public.get_agents_in_manager_groups_v2('272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid);

-- If replaced v1
select count(*) as rpc_v1_count
from public.get_agents_in_manager_groups('272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid);

-- Optional list
select id, email, group_name
from public.get_agents_in_manager_groups_v2('272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid)
order by email;
```
* 
| id                                   | email                   | group_name |
| ------------------------------------ | ----------------------- | ---------- |
| d7ec615c-480c-4292-8e5a-89b265778c48 | abseealaseel@gmail.com  | AL-Tijwal  |
| c351d635-82a5-4efa-a636-5db3676e0cb4 | dhyabmstfy34@gmail.com  | AL-Tijwal  |
| e73f3ea1-75e7-4c19-9ef3-fd982de5e2da | fadelkhaled41@gmail.com | AL-Tijwal  |
| 6cd99aa8-b005-4958-a8ec-a1fb410686e7 | gafar6760@gmail.com     | AL-Tijwal  |
| a34beabd-ea6c-4105-8491-105d83b85a5a | iraqi900iraqi@gmail.com | AL-Tijwal  |
| 40a2950d-1b87-461d-9562-2bf0be766c57 | kadmmhmdkadm2@gmail.com | AL-Tijwal  |
| 263e832c-f73c-48f3-bfd2-1b567cbff0b1 | user.agent2@test.com    | AL-Tijwal  |
Expected: count = 7.
