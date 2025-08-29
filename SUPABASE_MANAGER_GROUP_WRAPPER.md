# Manager → Group → Agents — Wrapper Function (IDs)

Context
- Your existing `public.get_manager_agent_profiles()` returns full records and currently returns 7 rows for the manager — good.
- The earlier error was from trying to change its return type to `uuid`. Avoid changing the signature to prevent breaking dependencies.

Create a non-breaking wrapper that returns only agent ids, if needed by the app.

---

## Create `get_manager_agent_ids()` wrapper (safe)

```sql
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

## Quick test (while impersonating manager)

```sql
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);
select count(*) from public.get_manager_agent_ids();
select * from public.get_manager_agent_ids() limit 50;
```
* 
| get_manager_agent_ids                |
| ------------------------------------ |
| c351d635-82a5-4efa-a636-5db3676e0cb4 |
| d7ec615c-480c-4292-8e5a-89b265778c48 |
| 6cd99aa8-b005-4958-a8ec-a1fb410686e7 |
| a34beabd-ea6c-4105-8491-105d83b85a5a |
| 263e832c-f73c-48f3-bfd2-1b567cbff0b1 |
| e73f3ea1-75e7-4c19-9ef3-fd982de5e2da |
| 40a2950d-1b87-461d-9562-2bf0be766c57 |

## Example usage in SQL (join to profiles)

```sql
select p.id, p.email
from public.profiles p
where p.id in (select * from public.get_manager_agent_ids())
order by p.email;
```
* 
Success. No rows returned
Notes
- Keep the original function as is for compatibility.
- If the app expects IDs, switch to calling `get_manager_agent_ids()`.
