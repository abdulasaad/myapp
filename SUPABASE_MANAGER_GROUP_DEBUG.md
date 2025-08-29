# Manager → Group → Agents Debug — SQL Playbook

Use these blocks to impersonate a manager, discover group/agent mappings, locate the function causing zero results, verify RLS permissions, and apply targeted fixes. Replace placeholders like <MANAGER_UUID> as noted. All discovery blocks are read‑only unless explicitly marked.

---

## 0) Impersonate The Manager

```sql
reset role;               -- ensure clean context
set local role authenticated;  -- Supabase API role
select set_config('request.jwt.claims', json_build_object('sub','<MANAGER_UUID>')::text, true);

-- Confirm perspective
select current_user as running_as_role,
       current_setting('request.jwt.claims', true) as claims,
       auth.uid() as uid,
       public.get_my_role() as app_role;
```

---

## 1) Discover Group‑Related Tables and Columns

```sql
-- 1A) Tables with "group" (name) in non‑system schemas
select table_schema, table_name
from information_schema.tables
where table_schema not in ('pg_catalog','information_schema')
  and table_name ilike '%group%'
order by 1,2;
```

```sql
-- 1B) Columns named group_id across app schemas
select table_schema, table_name, column_name, data_type
from information_schema.columns
where table_schema not in ('pg_catalog','information_schema')
  and column_name ilike 'group_id'
order by 1,2;
```

```sql
-- 1C) Foreign keys pointing at public.groups (if present)
select n.nspname as schema,
       t.relname as table,
       con.conname as constraint_name,
       pg_get_constraintdef(con.oid, true) as definition
from pg_constraint con
join pg_class t on con.conrelid = t.oid
join pg_namespace n on n.oid = t.relnamespace
where con.contype = 'f'
  and pg_get_constraintdef(con.oid, true) ilike '% groups(%'
order by 1,2;
```

```sql
-- 1D) Peek public.groups (first rows)
select * from public.groups order by 1 limit 20;
```

---

## 2) Identify Manager → Group Membership

```sql
-- 2A) Try direct manager column on groups
select g.*
from public.groups g
where g.manager_id = auth.uid();
```

```sql
-- 2B) If membership is via a join table (search candidates)
select table_schema, table_name
from information_schema.columns
where table_schema = 'public'
  and column_name in ('user_id','profile_id')
  and table_name ilike '%group%'
order by 2;
```

```sql
-- 2C) Sample any join table found (replace <membership_table> and user column)
-- Identify manager's groups through membership table
select gm.*
from public.<membership_table> gm
where (gm.user_id = auth.uid() or gm.profile_id = auth.uid())
limit 50;
```

---

## 3) Identify Agents Assigned To These Groups

```sql
-- 3A) Candidate mapping tables that link agents/users to groups
select table_schema, table_name
from information_schema.columns
where table_schema = 'public'
  and column_name = 'group_id'
  and table_name ilike any (array['%agent%','%assign%','%member%','%user%'])
order by 2;
```

```sql
-- 3B) Profiles table role overview (if exists)
select count(*) filter (where role = 'agent')    as agents,
       count(*) filter (where role = 'manager')  as managers,
       count(*) filter (where role = 'admin')    as admins,
       count(*)                                   as total
from public.profiles;
```

```sql
-- 3C) List agents in manager’s groups (try direct groups.manager_id path)
select p.id as agent_id, p.email, p.role, g.id as group_id, g.name as group_name
from public.profiles p
join public.<agent_group_table> ag on ag.agent_id = p.id   -- replace if different column
join public.groups g on g.id = ag.group_id
where p.role = 'agent'
  and (g.manager_id = auth.uid()  -- direct ownership path
       or exists (
            select 1
            from public.<membership_table> gm
            where gm.group_id = g.id
              and (gm.user_id = auth.uid() or gm.profile_id = auth.uid())
       )
  )
order by g.id, p.email
limit 200;
```

---

## 4) Locate The Function Returning Zero Agents

```sql
-- 4A) Functions likely involved
select n.nspname as schema, p.proname as function, p.oid
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public','auth','realtime','storage')
  and (p.proname ilike any (array['%agent%','%group%','%manager%'])
       or pg_get_functiondef(p.oid) ilike any (array['%group%','%manager%','%agent%']))
order by 1,2;
```

```sql
-- 4B) Show definition of the suspected function (replace <FUNCTION_OID>)
select pg_get_functiondef(<FUNCTION_OID>) as ddl;
```

```sql
-- 4C) If you know the name
-- select pg_get_functiondef(('public.<function_name>'::regproc)) as ddl;
```

```sql
-- 4D) Compare function results with ground truth join (replace function)
-- Expected: counts should match 3C's result when impersonating the manager
select
  (select count(*) from (
     -- ground truth from 3C (adjust table names)
     select p.id
     from public.profiles p
     join public.<agent_group_table> ag on ag.agent_id = p.id
     join public.groups g on g.id = ag.group_id
     where p.role = 'agent'
       and (g.manager_id = auth.uid() or exists (
             select 1 from public.<membership_table> gm
             where gm.group_id = g.id
               and (gm.user_id = auth.uid() or gm.profile_id = auth.uid())
           ))
  ) s) as expected_agents,
  (select count(*) from public.<function_name>() ) as function_agents;  -- adapt signature if different
```

---

## 5) RLS Policies On Membership/Assignment Tables

```sql
-- 5A) RLS status summaries
with t as (
  select unnest(array['profiles','groups','<agent_group_table>','<membership_table>']) as rel
)
select c.relname as table,
       c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as rls_force
from pg_class c
join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
where c.relname in (select rel from t)
order by 1;
```

```sql
-- 5B) Policies for those tables
select *
from pg_policies
where schemaname = 'public'
  and tablename in ('profiles','groups','<agent_group_table>','<membership_table>')
order by tablename, policyname;
```

```sql
-- 5C) Quick can‑I‑read checks (expect rows when impersonating manager)
select 'profiles' as src, count(*)
from public.profiles
union all
select '<agent_group_table>', count(*)
from public.<agent_group_table>
union all
select '<membership_table>', count(*)
from public.<membership_table>
union all
select 'groups', count(*)
from public.groups;
```

---

## 6) Common Root Causes Checklist (Read‑Only Diagnostics)

```sql
-- 6A) Check for NULL manager_id or mismatched types
select count(*) filter (where manager_id is null) as groups_without_manager,
       pg_typeof(manager_id) as manager_id_type
from public.groups;
```

```sql
-- 6B) Ensure IDs line up between auth.users and profiles (if applicable)
select exists(
  select 1
  from auth.users u
  join public.profiles p on p.id = u.id
  where u.id = auth.uid()
) as manager_has_profile;
```

```sql
-- 6C) Inspect a specific manager’s memberships, assignments, and agents (replace UUIDs)
select * from public.groups where manager_id = '<MANAGER_UUID>'::uuid;
select * from public.<membership_table> where (user_id = '<MANAGER_UUID>'::uuid or profile_id = '<MANAGER_UUID>'::uuid) limit 50;
select * from public.<agent_group_table> where group_id in (select id from public.groups where manager_id = '<MANAGER_UUID>'::uuid) limit 50;
```

---

## 7) Fix Patterns (Apply One That Matches Your Schema)

-- Note: The following are write operations. Review before running.
-- Wrap in a transaction to test and ROLLBACK if needed.

```sql
begin;
```

```sql
-- 7A) Function fix example: ensure it uses auth.uid() and correct joins
-- Replace <function_name>, tables, and columns accordingly
create or replace function public.<function_name>()
returns setof uuid
language sql
security invoker
stable
as $$
  select p.id
  from public.profiles p
  join public.<agent_group_table> ag on ag.agent_id = p.id
  join public.groups g on g.id = ag.group_id
  where p.role = 'agent'
    and (
      g.manager_id = auth.uid() or exists (
        select 1
        from public.<membership_table> gm
        where gm.group_id = g.id
          and (gm.user_id = auth.uid() or gm.profile_id = auth.uid())
      )
    )
$$;
```

```sql
-- 7B) RLS policy to allow managers to read agent group assignments
-- Replace <agent_group_table> and membership columns
drop policy if exists manager_can_read_agent_groups on public.<agent_group_table>;
create policy manager_can_read_agent_groups
  on public.<agent_group_table>
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.groups g
      where g.id = <agent_group_table>.group_id
        and (
          g.manager_id = auth.uid() or exists (
            select 1
            from public.<membership_table> gm
            where gm.group_id = g.id
              and (gm.user_id = auth.uid() or gm.profile_id = auth.uid())
          )
        )
    )
  );
```

```sql
-- 7C) (Optional) View to debug who a manager can see
create or replace view public.manager_agents_v as
select auth.uid() as manager_uid,
       g.id as group_id,
       g.name as group_name,
       p.id as agent_id,
       p.email
from public.profiles p
join public.<agent_group_table> ag on ag.agent_id = p.id
join public.groups g on g.id = ag.group_id
where p.role = 'agent';
```

```sql
-- 7D) Sanity check after changes (impersonating manager from section 0)
select * from public.<function_name>() limit 50;
select * from public.manager_agents_v limit 50;
```

```sql
rollback;  -- change to COMMIT when satisfied
```

---

Notes
- Replace <agent_group_table> with the real assignment table discovered in section 1/3 (e.g., public.agent_group_assignments).
- Replace <membership_table> if managers relate to groups via a membership table (e.g., public.group_members with role = 'manager'). If not present, rely on groups.manager_id.
- If RLS still blocks reads, capture errors from section 5C and share them; we’ll refine the policies.
