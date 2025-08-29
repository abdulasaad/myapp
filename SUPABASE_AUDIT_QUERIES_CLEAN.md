# Supabase Structure Audit — Clean SQL (Copy/Paste)

Run each block in the Supabase SQL Editor. These are read‑only catalog queries that exclude system schemas. Paste results back so I can analyze your setup and advise on fixes.

Scope
- Focuses on non‑system schemas (excludes `pg_%` and `information_schema`).
- Covers extensions, schemas, relations, columns, constraints, indexes, RLS/policies, privileges, triggers, functions.
- Does not modify data or permissions.

---

## 1) High‑Level Overview

```sql
-- 1.1 Installed extensions and versions
select e.extname as extension, e.extversion as version, n.nspname as schema
from pg_extension e
join pg_namespace n on n.oid = e.extnamespace
order by 1;
```

```sql
-- 1.2 Non‑system schemas
select n.nspname as schema
from pg_namespace n
where n.nspname not like 'pg_%'
  and n.nspname <> 'information_schema'
order by 1;
```

```sql
-- 1.3 Tables and views per schema
select t.table_schema, t.table_name, t.table_type
from information_schema.tables t
where t.table_schema not in ('pg_catalog', 'information_schema')
order by t.table_schema, t.table_type, t.table_name;
```

```sql
-- 1.4 Materialized views with definition
select n.nspname as schema, c.relname as matview,
       pg_get_viewdef(c.oid, true) as definition
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'm'
  and n.nspname not in ('pg_catalog', 'information_schema')
order by 1, 2;
```

```sql
-- 1.5 Sequences
select sequence_schema as schema, sequence_name, data_type,
       start_value, minimum_value, maximum_value, increment, cycle_option
from information_schema.sequences
where sequence_schema not in ('pg_catalog', 'information_schema')
order by 1, 2;
```

```sql
-- 1.6 Enums and labels
select n.nspname as schema, t.typname as enum_name, e.enumlabel as value, e.enumsortorder
from pg_type t
join pg_enum e on e.enumtypid = t.oid
join pg_namespace n on n.oid = t.typnamespace
where n.nspname not in ('pg_catalog','information_schema')
order by 1, 2, 4;
```

---

## 2) Tables, Columns, and Comments

```sql
-- 2.1 Relation comments
select n.nspname as schema,
       c.relname  as relation,
       case c.relkind when 'r' then 'table'
                      when 'p' then 'partitioned table'
                      when 'v' then 'view'
                      when 'm' then 'materialized view'
                      when 'f' then 'foreign table' end as kind,
       d.description as comment
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_description d on d.objoid = c.oid and d.objsubid = 0
where c.relkind in ('r','p','v','m','f')
  and n.nspname not in ('pg_catalog','information_schema')
order by 1, 3, 2;
```

```sql
-- 2.2 Columns with defaults/identity/generated/comments
select c.table_schema,
       c.table_name,
       c.ordinal_position,
       c.column_name,
       c.data_type,
       c.is_nullable,
       c.column_default,
       c.is_identity,
       c.identity_generation,
       c.is_generated,
       c.generation_expression,
       pgd.description as column_comment
from information_schema.columns c
left join pg_catalog.pg_statio_all_tables st
       on st.schemaname = c.table_schema and st.relname = c.table_name
left join pg_catalog.pg_description pgd
       on pgd.objoid = st.relid and pgd.objsubid = c.ordinal_position
where c.table_schema not in ('pg_catalog','information_schema')
order by c.table_schema, c.table_name, c.ordinal_position;
```

---

## 3) Constraints and Indexes

```sql
-- 3.1 Primary keys and unique constraints
select n.nspname as schema,
       t.relname as table,
       con.conname as constraint_name,
       case con.contype when 'p' then 'PRIMARY KEY' when 'u' then 'UNIQUE' end as type,
       string_agg(a.attname, ', ' order by k.ordinality) as columns
from pg_constraint con
join pg_class t on con.conrelid = t.oid
join pg_namespace n on n.oid = t.relnamespace
join lateral unnest(con.conkey) with ordinality as k(attnum, ordinality) on true
join pg_attribute a on a.attrelid = t.oid and a.attnum = k.attnum
where con.contype in ('p','u')
  and n.nspname not in ('pg_catalog','information_schema')
group by 1, 2, 3, 4
order by 1, 2, 3;
```

```sql
-- 3.2 Foreign keys with actions
select n.nspname as schema,
       t.relname as table,
       con.conname as constraint_name,
       string_agg(a.attname, ', ' order by k.ordinality) as columns,
       fn.nspname as ref_schema,
       ft.relname as ref_table,
       string_agg(ra.attname, ', ' order by k.ordinality) as ref_columns,
       case con.confmatchtype when 'f' then 'FULL' when 'p' then 'PARTIAL' when 's' then 'SIMPLE' end as match,
       case con.confupdtype  when 'a' then 'NO ACTION' when 'r' then 'RESTRICT' when 'c' then 'CASCADE' when 'n' then 'SET NULL' when 'd' then 'SET DEFAULT' end as on_update,
       case con.confdeltype  when 'a' then 'NO ACTION' when 'r' then 'RESTRICT' when 'c' then 'CASCADE' when 'n' then 'SET NULL' when 'd' then 'SET DEFAULT' end as on_delete
from pg_constraint con
join pg_class t on con.conrelid = t.oid
join pg_namespace n on n.oid = t.relnamespace
join pg_class ft on con.confrelid = ft.oid
join pg_namespace fn on fn.oid = ft.relnamespace
join lateral unnest(con.conkey) with ordinality as k(attnum, ordinality) on true
join pg_attribute a on a.attrelid = t.oid and a.attnum = k.attnum
join lateral unnest(con.confkey) with ordinality as rk(attnum, ordinality) on true
join pg_attribute ra on ra.attrelid = ft.oid and ra.attnum = rk.attnum and rk.ordinality = k.ordinality
where con.contype = 'f'
  and n.nspname not in ('pg_catalog','information_schema')
order by 1, 2, 3;
```

```sql
-- 3.3 Check constraints
select n.nspname as schema,
       t.relname as table,
       con.conname as constraint_name,
       pg_get_constraintdef(con.oid, true) as definition
from pg_constraint con
join pg_class t on con.conrelid = t.oid
join pg_namespace n on n.oid = t.relnamespace
where con.contype = 'c'
  and n.nspname not in ('pg_catalog','information_schema')
order by 1, 2, 3;
```

```sql
-- 3.4 Indexes with definition
select n.nspname as schema,
       t.relname as table,
       i.relname as index,
       pg_get_indexdef(ix.indexrelid, 0, true) as definition
from pg_class t
join pg_index ix on ix.indrelid = t.oid
join pg_class i on i.oid = ix.indexrelid
join pg_namespace n on n.oid = t.relnamespace
where n.nspname not in ('pg_catalog','information_schema')
order by 1, 2, 3;
```

---

## 4) Security: RLS and Policies

```sql
-- 4.1 RLS status per table
select n.nspname as schema,
       c.relname  as table,
       c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as rls_force
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r'
  and n.nspname not in ('pg_catalog','information_schema')
order by 1, 2;
```

```sql
-- 4.2 RLS policies (name, cmd, roles, permissive, qual, with_check)
select p.schemaname as schema,
       p.tablename  as table,
       p.policyname,
       case when p.permissive then 'PERMISSIVE' else 'RESTRICTIVE' end as permissive,
       p.roles,
       p.cmd,
       p.qual,
       p.with_check
from pg_policies p
where p.schemaname not in ('pg_catalog','information_schema')
order by 1, 2, 3;
```

---

## 5) Grants and Privileges

```sql
-- 5.1 Table privileges
select table_schema as schema,
       table_name,
       grantee,
       privilege_type,
       is_grantable
from information_schema.table_privileges
where table_schema not in ('pg_catalog','information_schema')
order by 1, 2, 3, 4;
```

```sql
-- 5.2 Schema privileges via aclexplode
select n.nspname as schema,
       r.rolname  as grantee,
       a.privilege_type,
       a.is_grantable
from pg_namespace n
cross join lateral (
  select (aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner)))).*
) as a(grantee, grantor, privilege_type, is_grantable)
join pg_roles r on r.oid = a.grantee
where n.nspname not in ('pg_catalog','information_schema')
order by 1, 2, 3;
```

```sql
-- 5.3 Function privileges via aclexplode
select n.nspname as schema,
       p.proname  as function,
       r.rolname  as grantee,
       a.privilege_type,
       a.is_grantable
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
cross join lateral (
  select (aclexplode(coalesce(p.proacl, acldefault('f', p.proowner)))).*
) as a(grantee, grantor, privilege_type, is_grantable)
join pg_roles r on r.oid = a.grantee
where n.nspname not in ('pg_catalog','information_schema')
order by 1, 2, 3;
```

---

## 6) Triggers

```sql
-- 6.1 Triggers with definitions and functions
select n.nspname as schema,
       t.relname as table,
       trg.tgname as trigger,
       pg_get_triggerdef(trg.oid, true) as definition,
       pron.nspname || '.' || p.proname as function
from pg_trigger trg
join pg_class t on t.oid = trg.tgrelid
join pg_namespace n on n.oid = t.relnamespace
join pg_proc p on p.oid = trg.tgfoid
join pg_namespace pron on pron.oid = p.pronamespace
where not trg.tgisinternal
  and n.nspname not in ('pg_catalog','information_schema')
order by 1, 2, 3;
```

---

## 7) Functions and Procedures

```sql
-- 7.1 Function/procedure inventory (metadata)
select n.nspname                                  as schema,
       p.proname                                   as function,
       pg_get_function_identity_arguments(p.oid)   as args,
       pg_get_function_result(p.oid)               as returns,
       case p.prokind when 'f' then 'function' when 'p' then 'procedure' end as kind,
       p.prosecdef                                 as security_definer,
       p.provolatile                               as volatility,
       p.proparallel                               as parallel,
       p.proretset                                 as returns_set
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.prokind in ('f','p')
  and n.nspname not in ('pg_catalog','information_schema')
order by 1, 2, 3;
```

```sql
-- 7.2 Full function DDL for app schemas (can be long)
-- Uncomment schemas of interest to include body text
-- Tip: run per‑schema if output is too large
-- select n.nspname as schema, p.proname as function, pg_get_functiondef(p.oid) as ddl
-- from pg_proc p
-- join pg_namespace n on n.oid = p.pronamespace
-- where p.prokind = 'f' and n.nspname in ('public','auth','storage','realtime','cron')
-- order by 1, 2;
```

---

## 8) Storage and Auth Focus

```sql
-- 8.1 Storage schema relations
select table_schema, table_name, table_type
from information_schema.tables
where table_schema = 'storage'
order by 2;
```

```sql
-- 8.2 Storage RLS policies
select *
from pg_policies
where schemaname = 'storage'
order by tablename, policyname;
```

```sql
-- 8.3 Auth schema relations
select table_schema, table_name, table_type
from information_schema.tables
where table_schema = 'auth'
order by 2;
```

```sql
-- 8.4 Auth RLS policies
select *
from pg_policies
where schemaname = 'auth'
order by tablename, policyname;
```

---

How To Share Results
- Run each block and paste the outputs in replies, referencing the section number.
- If a block is too large, run per‑schema (use `where table_schema in ('public', ...)`).
- If anything errors, share the exact error message and the section number.
