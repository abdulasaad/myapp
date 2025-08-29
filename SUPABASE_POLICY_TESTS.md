# Supabase Policy Tests — Copy/Paste SQL

Use these blocks to simulate requests from different roles/users and verify RLS behavior on key tables. Paste outputs under each block (start with `*`) like before.

Notes:
- Uses `SET ROLE` + `set_config('request.jwt.claims', ...)` to emulate PostgREST.
- Replace placeholder UUIDs with real IDs from `public.profiles`.
- Wrap write tests in a transaction and ROLLBACK to avoid changes.

---

## 0) Pick Example Users

```sql
-- List some users by role to pick test IDs
select id, email, role, full_name
from public.profiles
order by role, full_name
limit 20;
```

---

## 1) Test as Agent

```sql
-- 1A) Assume authenticated agent (replace <AGENT_UUID>)
reset role; -- ensure clean
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','<AGENT_UUID>')::text, true);

-- Confirm perspective
select current_user as running_as_role,
       current_setting('request.jwt.claims', true) as claims,
       public.get_my_role() as app_role;
```

```sql
-- 1B) Read visibility smoke tests (RLS filters apply)
select count(*) as evidence_visible
from public.evidence; -- should only include rows related to this agent

select count(*) as tasks_visible
from public.task_assignments; -- ditto

select count(*) as locations_visible
from public.agent_location_tracking; -- ditto
```

```sql
-- 1C) Write tests (no persistence)
begin;
-- Insert allowed? Example for agent_location_tracking
insert into public.agent_location_tracking (agent_id, latitude, longitude, recorded_at)
values (auth.uid(), 29.3759, 47.9774, now());
-- If policy blocks, this will error. If OK, 1 row inserted.
rollback;
```

---

## 2) Test as Manager

```sql
-- 2A) Assume authenticated manager (replace <MANAGER_UUID>)
reset role;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','<MANAGER_UUID>')::text, true);

select current_user as running_as_role,
       current_setting('request.jwt.claims', true) as claims,
       public.get_my_role() as app_role;
```

```sql
-- 2B) Read visibility: manager should see managed agents’ data
select count(*) as evidence_visible
from public.evidence;

select count(*) as tasks_visible
from public.task_assignments;

select count(*) as locations_visible
from public.agent_location_tracking;
```

```sql
-- 2C) Write check (example: forbid manager direct insert to agent locations?)
begin;
insert into public.agent_location_tracking (agent_id, latitude, longitude, recorded_at)
values ('00000000-0000-0000-0000-000000000000', 0, 0, now()); -- expect policy to reject
rollback;
```

---

## 3) Test as Admin

```sql
-- 3A) Assume authenticated admin (replace <ADMIN_UUID>)
reset role;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','<ADMIN_UUID>')::text, true);

select current_user as running_as_role,
       current_setting('request.jwt.claims', true) as claims,
       public.get_my_role() as app_role;
```

```sql
-- 3B) Read visibility: admin should see most data per policies
select count(*) as evidence_visible from public.evidence;
select count(*) as tasks_visible from public.task_assignments;
select count(*) as locations_visible from public.agent_location_tracking;
```

```sql
-- 3C) Admin write checks (ensure with_check permits intended writes)
begin;
update public.tasks set updated_at = now() where false; -- harmless, should be permitted/blocked per policy
rollback;
```

---

## 4) Targeted Table Diagnostics

```sql
-- Evidence: who can see what (role-aware; uses current claims)
select
  (select count(*) from public.evidence) as total_visible,
  (select count(*) from public.evidence where created_by = auth.uid()) as mine_visible;
```

```sql
-- Task assignments: perspective snapshot
select
  (select count(*) from public.task_assignments) as total_visible,
  (select count(*) from public.task_assignments where agent_id = auth.uid()) as mine_visible;
```

```sql
-- Agent geofences: ensure manager/admin/self access pattern aligns with policy text
select
  (select count(*) from public.agent_geofence_assignments) as total_visible,
  (select count(*) from public.agent_geofence_assignments where agent_id = auth.uid()) as mine_visible;
```

---

## 5) Sanity: RLS & Policies on Key Tables

```sql
-- Quick view of RLS + policies for a few tables (adjust list)
with tables as (
  select unnest(array['evidence','task_assignments','agent_location_tracking','agent_geofence_assignments']) as t
)
select c.relname as table,
       c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as rls_force,
       p.policyname,
       p.cmd,
       p.permissive,
       p.qual,
       p.with_check
from pg_class c
join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
left join pg_policies p on p.schemaname = 'public' and p.tablename = c.relname
where c.relname in (select t from tables)
order by 1, 5, 4;
```

---

Tips
- If a read/write unexpectedly fails: capture the exact error and which block produced it.
- If counts don’t match expectations per role, we’ll inspect the matching policy’s `qual`/`with_check` and adjust.
