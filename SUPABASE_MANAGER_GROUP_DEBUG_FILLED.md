# Manager → Group → Agents Debug — SQL Playbook (Filled)

Preset IDs
- Agent: 263e832c-f73c-48f3-bfd2-1b567cbff0b1 (user.agent2@test.com)
- Manager: 272afd47-5e8d-4411-8369-81b03abaf9c5 (user.a@test.com)
- Admin: c83c4a8a-b164-4d4c-acd8-7f6cd0742ac3 (abdulasaad95@gmail.com)

Use these blocks to impersonate the manager, discover group/agent mappings, inspect the function returning zero results, verify RLS permissions, and apply targeted fixes. Replace table placeholders like <agent_group_table>, <membership_table>, and <function_name>.

---

## 0) Impersonate The Manager (preset)

```sql
reset role;               -- ensure clean context
set local role authenticated;  -- Supabase API role
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);

-- Confirm perspective
select current_user as running_as_role,
       current_setting('request.jwt.claims', true) as claims,
       auth.uid() as uid,
       public.get_my_role() as app_role;
```
* 
| running_as_role | claims                                           | uid                                  | app_role |
| --------------- | ------------------------------------------------ | ------------------------------------ | -------- |
| authenticated   | {"sub" : "272afd47-5e8d-4411-8369-81b03abaf9c5"} | 272afd47-5e8d-4411-8369-81b03abaf9c5 | manager  |

---

## 0.1) Quick Presence Checks for Provided Users

```sql
-- Profiles by id/email (adjust table/columns if different)
select id, email, role from public.profiles where id in (
  '263e832c-f73c-48f3-bfd2-1b567cbff0b1', -- agent
  '272afd47-5e8d-4411-8369-81b03abaf9c5', -- manager
  'c83c4a8a-b164-4d4c-acd8-7f6cd0742ac3'  -- admin
);

select id, email, role from public.profiles where email in (
  'user.agent2@test.com','user.a@test.com','abdulasaad95@gmail.com'
);
```
* 
| id                                   | email                  | role    |
| ------------------------------------ | ---------------------- | ------- |
| 272afd47-5e8d-4411-8369-81b03abaf9c5 | user.a@test.com        | manager |
| c83c4a8a-b164-4d4c-acd8-7f6cd0742ac3 | abdulasaad95@gmail.com | admin   |
| 263e832c-f73c-48f3-bfd2-1b567cbff0b1 | user.agent2@test.com   | agent   |

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
* 
| table_schema | table_name  |
| ------------ | ----------- |
| public       | groups      |
| public       | user_groups |

```sql
-- 1B) Columns named group_id across app schemas
select table_schema, table_name, column_name, data_type
from information_schema.columns
where table_schema not in ('pg_catalog','information_schema')
  and column_name ilike 'group_id'
order by 1,2;
```
* 
| table_schema | table_name  | column_name | data_type |
| ------------ | ----------- | ----------- | --------- |
| public       | user_groups | group_id    | uuid      |

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
* 
| schema | table       | constraint_name                | definition                                                              |
| ------ | ----------- | ------------------------------ | ----------------------------------------------------------------------- |
| public | profiles    | profiles_default_group_id_fkey | FOREIGN KEY (default_group_id) REFERENCES groups(id) ON DELETE SET NULL |
| public | user_groups | user_groups_group_id_fkey      | FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE          |

```sql
-- 1D) Peek public.groups (first rows)
select * from public.groups order by 1 limit 20;
```
* 
| id                                   | name       | description | manager_id                           | created_by | created_at                    | updated_at                    |
| ------------------------------------ | ---------- | ----------- | ------------------------------------ | ---------- | ----------------------------- | ----------------------------- |
| 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | AL-Tijwal  | null        | null                                 | null       | 2025-07-10 11:36:30.737089+00 | 2025-08-08 17:53:50.974426+00 |
| c8e7add4-aad5-4fdc-9360-f7a69422722e | 1          | 1           | 38e6aae3-efab-4668-b1f1-adbc1b513800 | null       | 2025-06-26 14:45:41.695843+00 | 2025-07-09 19:42:06.270723+00 |
| edd80394-ccaa-44c1-b663-31f9c1a63af9 | Sales Team | null        | 38e6aae3-efab-4668-b1f1-adbc1b513800 | null       | 2025-06-26 21:44:39.554949+00 | 2025-07-09 20:11:53.143423+00 |

---

## 2) Identify Manager → Group Membership

```sql
-- 2A) Try direct manager column on groups
select g.*
from public.groups g
where g.manager_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid;
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
* 
Success. No rows returned

```sql
-- 2C) Sample any join table found (replace <membership_table> and user column)
-- Identify manager's groups through membership table
select gm.*
from public.<membership_table> gm
where (gm.user_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid
    or gm.profile_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid)
limit 50;
```
* 
ERROR:  42601: syntax error at or near "<"
LINE 2: from public.<membership_table> gm
                    ^

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
* 
| table_schema | table_name  |
| ------------ | ----------- |
| public       | user_groups |

```sql
-- 3B) Profiles role overview
select count(*) filter (where role = 'agent')    as agents,
       count(*) filter (where role = 'manager')  as managers,
       count(*) filter (where role = 'admin')    as admins,
       count(*)                                   as total
from public.profiles;
```
* 
| agents | managers | admins | total |
| ------ | -------- | ------ | ----- |
| 10     | 3        | 1      | 15    |

```sql
-- 3C) List agents in manager’s groups (replace table names)
select p.id as agent_id, p.email, p.role, g.id as group_id, g.name as group_name
from public.profiles p
join public.<agent_group_table> ag on ag.agent_id = p.id
join public.groups g on g.id = ag.group_id
where p.role = 'agent'
  and (
    g.manager_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid
    or exists (
         select 1
         from public.<membership_table> gm
         where gm.group_id = g.id
           and (gm.user_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid
             or gm.profile_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid)
    )
  )
order by g.id, p.email
limit 200;
```
* 
ERROR:  42601: syntax error at or near "<"
LINE 3: join public.<agent_group_table> ag on ag.agent_id = p.id
                    ^
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
-- 4D) Compare function results with ground truth (adjust table names)
select
  (select count(*) from (
     select p.id
     from public.profiles p
     join public.<agent_group_table> ag on ag.agent_id = p.id
     join public.groups g on g.id = ag.group_id
     where p.role = 'agent'
       and (g.manager_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid or exists (
             select 1 from public.<membership_table> gm
             where gm.group_id = g.id
               and (gm.user_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid or gm.profile_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid)
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
select 'profiles' as src, count(*) from public.profiles
union all
select '<agent_group_table>', count(*) from public.<agent_group_table>
union all
select '<membership_table>', count(*) from public.<membership_table>
union all
select 'groups', count(*) from public.groups;
```

---

## 6) Common Root Causes Checklist

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
  where u.id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid
) as manager_has_profile;
```

```sql
-- 6C) Inspect this manager’s memberships, assignments, and agents (fill table names)
select * from public.groups where manager_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid;
select * from public.<membership_table> where (user_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid or profile_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid) limit 50;
select * from public.<agent_group_table> where group_id in (select id from public.groups where manager_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid) limit 50;
```

---

## 7) Fix Patterns (Review Carefully; Wrap in TX)

```sql
begin;  -- rollback when testing
```

```sql
-- 7A) Function fix example (uses auth.uid() so it works via API)
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
-- 7D) Sanity check after changes (still impersonating manager)
select * from public.<function_name>() limit 50;
```

```sql
rollback;  -- change to COMMIT when satisfied
```
