# Manager → Group → Agents — Follow-Up SQL (Based on your outputs)

Findings So Far
- Mapping table: public.user_groups (has group_id; user column name unknown).
- Foreign keys: user_groups.group_id → groups.id; profiles.default_group_id → groups.id.
- Groups.manager_id does NOT include the test manager (so any function relying only on groups.manager_id will return zero).

Goal
- Identify the user column in public.user_groups, verify the manager’s memberships there, and compute a ground-truth list of agents in the manager’s groups. Then compare to your function and check RLS.

Preset IDs
- Manager UUID: 272afd47-5e8d-4411-8369-81b03abaf9c5
- Agent UUID (example): 263e832c-f73c-48f3-bfd2-1b567cbff0b1

---

## A) Introspect user_groups Structure

```sql
-- A1) Column list for public.user_groups
select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'user_groups'
order by ordinal_position;
```
* 
| column_name | data_type                | is_nullable | column_default    |
| ----------- | ------------------------ | ----------- | ----------------- |
| id          | uuid                     | NO          | gen_random_uuid() |
| user_id     | uuid                     | NO          | null              |
| group_id    | uuid                     | NO          | null              |
| created_at  | timestamp with time zone | YES         | now()             |

```sql
-- A2) Constraints and FKs for public.user_groups (shows which column links to profiles)
select con.conname as constraint_name,
       case con.contype when 'p' then 'PRIMARY KEY'
                        when 'u' then 'UNIQUE'
                        when 'f' then 'FOREIGN KEY'
                        when 'c' then 'CHECK' end as type,
       n.nspname as table_schema,
       t.relname as table_name,
       string_agg(a.attname, ', ' order by k.ordinality) as columns,
       rn.nspname as ref_schema,
       rt.relname as ref_table,
       string_agg(ra.attname, ', ' order by rk.ordinality) as ref_columns,
       pg_get_constraintdef(con.oid, true) as definition
from pg_constraint con
join pg_class t on t.oid = con.conrelid
join pg_namespace n on n.oid = t.relnamespace
left join lateral unnest(con.conkey) with ordinality as k(attnum, ordinality) on true
left join pg_attribute a on a.attrelid = t.oid and a.attnum = k.attnum
left join pg_class rt on rt.oid = con.confrelid
left join pg_namespace rn on rn.oid = rt.relnamespace
left join lateral unnest(con.confkey) with ordinality as rk(attnum, ordinality) on true
left join pg_attribute ra on ra.attrelid = rt.oid and ra.attnum = rk.attnum
where n.nspname = 'public' and t.relname = 'user_groups'
group by con.conname, con.contype, n.nspname, t.relname, rn.nspname, rt.relname, con.oid
order by 1;
```
* 
| constraint_name                  | type        | table_schema | table_name  | columns           | ref_schema | ref_table | ref_columns | definition                                                      |
| -------------------------------- | ----------- | ------------ | ----------- | ----------------- | ---------- | --------- | ----------- | --------------------------------------------------------------- |
| user_groups_group_id_fkey        | FOREIGN KEY | public       | user_groups | group_id          | public     | groups    | id          | FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE  |
| user_groups_pkey                 | PRIMARY KEY | public       | user_groups | id                | null       | null      | null        | PRIMARY KEY (id)                                                |
| user_groups_user_id_fkey         | FOREIGN KEY | public       | user_groups | user_id           | public     | profiles  | id          | FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE |
| user_groups_user_id_group_id_key | UNIQUE      | public       | user_groups | user_id, group_id | null       | null      | null        | UNIQUE (user_id, group_id)                                      |

```sql
-- A3) Sample rows to see shape (limit)
select * from public.user_groups order by 1 desc limit 50;
```
* 
| id                                   | user_id                              | group_id                             | created_at                    |
| ------------------------------------ | ------------------------------------ | ------------------------------------ | ----------------------------- |
| eda9c4d4-3e4f-4767-9c26-831f1d4e6338 | c351d635-82a5-4efa-a636-5db3676e0cb4 | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | 2025-07-10 11:36:30.862821+00 |
| c1d1fc0f-cf76-48e8-b23c-23c5142b0644 | 94423254-7322-4e23-a314-4b690ea9ab44 | edd80394-ccaa-44c1-b663-31f9c1a63af9 | 2025-07-09 18:21:36.495271+00 |
| b21ef83c-6e50-425c-94c0-9376a2b6b320 | e73f3ea1-75e7-4c19-9ef3-fd982de5e2da | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | 2025-08-08 17:53:42.909834+00 |
| 98b5e20b-7d7b-4cc7-b94c-257f84f29269 | 6cd99aa8-b005-4958-a8ec-a1fb410686e7 | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | 2025-07-10 16:16:16.712685+00 |
| 8cce726c-7098-42b4-95f2-2a2568420741 | a34beabd-ea6c-4105-8491-105d83b85a5a | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | 2025-07-12 15:21:43.180244+00 |
| 7feb6c6a-6586-4e3e-916a-107afeb53680 | 38e6aae3-efab-4668-b1f1-adbc1b513800 | edd80394-ccaa-44c1-b663-31f9c1a63af9 | 2025-07-09 20:11:53.48856+00  |
| 627d85bc-c8a8-423e-a081-3d5d05202351 | 272afd47-5e8d-4411-8369-81b03abaf9c5 | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | 2025-07-10 11:58:48.381559+00 |
| 5e1feb59-fe53-4e23-b503-0b944d59d710 | f33e02d4-4e3a-48f3-8788-49b9a079c721 | c8e7add4-aad5-4fdc-9360-f7a69422722e | 2025-07-09 19:42:06.828093+00 |
| 4502eed2-8baa-4690-b958-c9eb8817b638 | d7ec615c-480c-4292-8e5a-89b265778c48 | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | 2025-07-10 11:36:30.862821+00 |
| 3dfe104c-4675-4735-9208-57d7cb5f09b9 | b5b6a078-8c4a-4961-83a6-5d727668b27c | edd80394-ccaa-44c1-b663-31f9c1a63af9 | 2025-06-27 00:54:21.980023+00 |
| 2e4b7065-74f3-471e-aa7c-74dc7f695593 | 263e832c-f73c-48f3-bfd2-1b567cbff0b1 | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | 2025-07-16 14:37:04.882523+00 |
| 16c910b8-b640-41db-b6d5-cfb12f084a3c | 40a2950d-1b87-461d-9562-2bf0be766c57 | 66edfbfc-fbf0-4d86-aa77-3f8b0189cdd9 | 2025-08-15 09:59:03.378221+00 |

---

## B) Check Manager Membership in user_groups

```sql
-- B1) Try common user column names to find manager memberships (run; some may error if column absent)
-- Variant 1: user_id
select * from public.user_groups where user_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid limit 50;
-- Variant 2: profile_id
select * from public.user_groups where profile_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid limit 50;
-- Variant 3: member_id
select * from public.user_groups where member_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid limit 50;
-- Variant 4: user_uuid
select * from public.user_groups where user_uuid = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid limit 50;
-- Variant 5: uid
select * from public.user_groups where uid = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid limit 50;
```
* 
ERROR:  42703: column "profile_id" does not exist
LINE 3: select * from public.user_groups where profile_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid limit 50;
                                               ^

```sql
-- B2) If there is a role column, inspect its values (rename to actual user column discovered in A2/A3)
select role, count(*)
from public.user_groups
group by 1
order by 2 desc;
```
* 
ERROR:  42703: column "role" does not exist
LINE 1: select role, count(*)
               ^

---

## C) Ground Truth: Agents in Manager’s Groups (Fill user column name)

```sql
-- C1) Replace <ug_user_col> with the actual user column from A2/A3
select p.id as agent_id, p.email, g.id as group_id, g.name as group_name
from public.profiles p
join public.user_groups ag on ag.group_id = g.id  -- uses group_id
join public.groups g on g.id = ag.group_id
where p.role = 'agent'
  and exists (
    select 1 from public.user_groups gm
    where gm.group_id = g.id
      and gm.<ug_user_col> = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid
      and (gm.role is null or gm.role in ('manager','owner')) -- adjust if role exists
  )
order by g.id, p.email
limit 200;
```
* 
ERROR:  42601: syntax error at or near "<"
LINE 9:       and gm.<ug_user_col> = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid
                     ^

---

## D) Function Discovery Referencing user_groups

```sql
-- D1) Candidate functions that reference user_groups
select n.nspname as schema, p.proname as function, p.oid
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public','auth')
  and pg_get_functiondef(p.oid) ilike any (array['%user_groups%','%groups%','%profiles%'])
order by 1,2;
```
* 
ERROR:  42809: "array_agg" is an aggregate function

```sql
-- D2) Show DDL for a picked function (replace OID)
select pg_get_functiondef(<FUNCTION_OID>) as ddl;
```
* 
ERROR:  42601: syntax error at or near "<"
LINE 1: select pg_get_functiondef(<FUNCTION_OID>) as ddl limit 100;
                                  ^

---

## E) RLS Checks (user_groups + groups + profiles)

```sql
-- E1) RLS status
select n.nspname as schema, c.relname as table, c.relrowsecurity as rls_enabled, c.relforcerowsecurity as rls_force
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname in ('user_groups','groups','profiles')
order by 2;
```
* 
| schema | table       | rls_enabled | rls_force |
| ------ | ----------- | ----------- | --------- |
| public | groups      | true        | false     |
| public | profiles    | true        | false     |
| public | user_groups | true        | false     |

```sql
-- E2) Policies
select * from pg_policies where schemaname='public' and tablename in ('user_groups','groups','profiles') order by tablename, policyname;
```
* 
| schemaname | tablename   | policyname                                            | permissive | roles           | cmd    | qual                                                                                               | with_check                                                             |
| ---------- | ----------- | ----------------------------------------------------- | ---------- | --------------- | ------ | -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| public     | groups      | Admins and managers can manage groups                 | PERMISSIVE | {public}        | ALL    | (get_user_role_secure() = ANY (ARRAY['admin'::text, 'manager'::text]))                             | (get_user_role_secure() = ANY (ARRAY['admin'::text, 'manager'::text])) |
| public     | groups      | All authenticated can view groups                     | PERMISSIVE | {public}        | SELECT | (auth.role() = 'authenticated'::text)                                                              | null                                                                   |
| public     | groups      | Allow all authenticated to view groups                | PERMISSIVE | {authenticated} | SELECT | true                                                                                               | null                                                                   |
| public     | profiles    | Simple insert                                         | PERMISSIVE | {authenticated} | INSERT | null                                                                                               | (auth.uid() = id)                                                      |
| public     | profiles    | Simple read access                                    | PERMISSIVE | {authenticated} | SELECT | true                                                                                               | null                                                                   |
| public     | profiles    | Simple update own                                     | PERMISSIVE | {authenticated} | UPDATE | (auth.uid() = id)                                                                                  | (auth.uid() = id)                                                      |
| public     | profiles    | Users can delete own profile or admins can delete any | PERMISSIVE | {public}        | DELETE | ((auth.uid() = id) OR is_user_admin())                                                             | null                                                                   |
| public     | user_groups | Allow all authenticated to manage user groups         | PERMISSIVE | {authenticated} | ALL    | true                                                                                               | true                                                                   |
| public     | user_groups | Allow all authenticated to view user groups           | PERMISSIVE | {authenticated} | SELECT | true                                                                                               | null                                                                   |
| public     | user_groups | Only admins and managers can manage user groups       | PERMISSIVE | {public}        | ALL    | (get_user_role_secure() = ANY (ARRAY['admin'::text, 'manager'::text]))                             | (get_user_role_secure() = ANY (ARRAY['admin'::text, 'manager'::text])) |
| public     | user_groups | Users can view their own group memberships            | PERMISSIVE | {public}        | SELECT | ((user_id = auth.uid()) OR (get_user_role_secure() = ANY (ARRAY['admin'::text, 'manager'::text]))) | null                                                                   |
| public     | user_groups | enable_all_for_authenticated_users                    | PERMISSIVE | {public}        | ALL    | (auth.role() = 'authenticated'::text)                                                              | null                                                                   |

```sql
-- E3) Can-I-read counts as manager (rerun while impersonating manager)
select 'profiles' src, count(*) from public.profiles
union all
select 'user_groups', count(*) from public.user_groups
union all
select 'groups', count(*) from public.groups;
```
* 
| src         | count |
| ----------- | ----- |
| profiles    | 15    |
| user_groups | 12    |
| groups      | 3     |

---

## F) Fix Pattern (Replace function to use membership)

```sql
-- F1) Example: create/replace function to return agent ids visible to current manager via user_groups
-- Replace <ug_user_col> with the discovered column name
create or replace function public.get_manager_agent_ids()
returns setof uuid
language sql
security invoker
stable
as $$
  select p.id
  from public.profiles p
  join public.user_groups ag on ag.group_id = g.id
  join public.groups g on g.id = ag.group_id
  where p.role = 'agent'
    and exists (
      select 1
      from public.user_groups gm
      where gm.group_id = g.id
        and gm.<ug_user_col> = auth.uid()
        and (gm.role is null or gm.role in ('manager','owner'))
    )
$$;
```
* 
ERROR:  42601: syntax error at or near "<"
LINE 16:         and gm.<ug_user_col> = auth.uid()
                        ^
```sql
-- F2) RLS policy example to allow manager to read needed rows (if RLS blocks user_groups)
-- Adjust conditions to your schema/columns
create policy if not exists user_groups_manager_can_read
  on public.user_groups
  for select
  to authenticated
  using (
    exists (
      select 1 from public.user_groups gm
      where gm.group_id = user_groups.group_id
        and gm.<ug_user_col> = auth.uid()
        and (gm.role is null or gm.role in ('manager','owner'))
    )
  );
```
* 
ERROR:  42601: syntax error at or near "not"
LINE 1: create policy if not exists user_groups_manager_can_read
                         ^
Notes
- First run A1–A3 to discover the exact user column on user_groups.
- If B1 queries error, that’s normal—only the correct variant will return rows.
- If D1 finds the function that returns zero, paste its DDL and I’ll propose a precise rewrite.
