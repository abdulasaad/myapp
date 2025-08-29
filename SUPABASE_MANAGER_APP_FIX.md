# Manager Sees Zero in App — Root Cause and Fix (Profiles RLS)

Root Cause
- The app fetches agents via direct `from('profiles')` queries (multiple usages in `lib/screens/...`). With RLS on `public.profiles`, managers likely lack a SELECT policy to view other users’ profiles, so app queries return 0. Our RPCs return 7 because they compute membership explicitly.

Plan
1) Confirm the direct profiles query returns 0 for the manager session.
2) Add a permissive SELECT policy on `public.profiles` that allows managers to read profiles of users in their groups via `user_groups` membership.
3) Re‑test the same app‑style query; it should return 7 without code changes.

---

## 1) Verify current app‑style query (manager impersonation)

```sql
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);

-- This mimics the app code: supabase.from('profiles').select(...).eq('role','agent')
select count(*) as app_profiles_count
from public.profiles
where role = 'agent';
```
* 
| app_profiles_count |
| ------------------ |
| 10                 |

---

## 2) Add manager SELECT policy on `public.profiles` (membership‑based)

```sql
-- Safe to run multiple times
create or replace function public.manager_can_view_profile(target_user_id uuid)
returns boolean
language sql
stable
security invoker
as $$
  exists (
    select 1
    from public.user_groups gm
    join public.user_groups ug on ug.group_id = gm.group_id
    where gm.user_id = auth.uid()      -- current manager
      and ug.user_id = target_user_id  -- candidate profile
  )
$$;
```
* 
ERROR:  42601: syntax error at or near "exists"
LINE 7:   exists (
          ^

```sql
-- Permissive policy: managers can SELECT profiles of users in their groups
-- Keeps existing self/admin policies intact (OR‑ed by RLS)
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
ERROR:  42883: function public.manager_can_view_profile(uuid) does not exist
HINT:  No function matches the given name and argument types. You might need to add explicit type casts.

```sql
-- Optional: ensure role can execute the helper and schema is usable
grant usage on schema public to authenticated;
grant execute on function public.manager_can_view_profile(uuid) to authenticated;
```
* 
ERROR:  42883: function public.manager_can_view_profile(uuid) does not exist

---

## 3) Re‑test app‑style query (should match 7)

```sql
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);

select count(*) as app_profiles_count_after
from public.profiles
where role = 'agent';

-- Optionally list emails to verify
select p.id, p.email
from public.profiles p
where p.role = 'agent'
  and public.manager_can_view_profile(p.id)
order by p.email;
```
* 
ERROR:  42883: function public.manager_can_view_profile(uuid) does not exist
LINE 12:   and public.manager_can_view_profile(p.id)
               ^
               
Notes
- This policy fixes all existing places where the app queries `profiles` directly.
- Keep RPCs (`get_manager_agent_profiles`, `get_manager_agent_ids`) as complementary endpoints.
- If you prefer a single policy function, we can inline the EXISTS join inside the policy and drop the helper.
