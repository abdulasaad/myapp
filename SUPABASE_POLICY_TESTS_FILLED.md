# Supabase Policy Tests — Filled IDs (Agent/Manager/Admin)

Preset IDs
- Agent: 263e832c-f73c-48f3-bfd2-1b567cbff0b1 (user.agent2@test.com)
- Manager: 272afd47-5e8d-4411-8369-81b03abaf9c5 (user.a@test.com)
- Admin: c83c4a8a-b164-4d4c-acd8-7f6cd0742ac3 (abdulasaad95@gmail.com)

Notes
- Uses SET ROLE + request.jwt.claims to emulate PostgREST.
- Wrap writes in transactions and ROLLBACK.

---

## 1) Test as Agent (preset)

```sql
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','263e832c-f73c-48f3-bfd2-1b567cbff0b1')::text, true);
select current_user as running_as_role,
       current_setting('request.jwt.claims', true) as claims,
       public.get_my_role() as app_role;
```

```sql
-- Read visibility
select count(*) as evidence_visible from public.evidence;
select count(*) as tasks_visible from public.task_assignments;
select count(*) as locations_visible from public.agent_location_tracking;
```

```sql
-- Write smoke (rollback)
begin; insert into public.agent_location_tracking (agent_id, latitude, longitude, recorded_at)
values ('263e832c-f73c-48f3-bfd2-1b567cbff0b1'::uuid, 29.3759, 47.9774, now()); rollback;
```

---

## 2) Test as Manager (preset)

```sql
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','272afd47-5e8d-4411-8369-81b03abaf9c5')::text, true);
select current_user as running_as_role,
       current_setting('request.jwt.claims', true) as claims,
       public.get_my_role() as app_role;
```

```sql
-- Visibility expected: agents in manager's groups; adjust joins if needed
-- Ground truth (fill mapping tables)
-- select count(*) from (
--   select p.id
--   from public.profiles p
--   join public.<agent_group_table> ag on ag.agent_id = p.id
--   join public.groups g on g.id = ag.group_id
--   where p.role = 'agent' and g.manager_id = '272afd47-5e8d-4411-8369-81b03abaf9c5'::uuid
-- ) s;
```

```sql
-- Function under test (replace with real function name)
-- select * from public.<function_name>() limit 50;
```

---

## 3) Test as Admin (preset)

```sql
reset role; set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','c83c4a8a-b164-4d4c-acd8-7f6cd0742ac3')::text, true);
select current_user as running_as_role,
       current_setting('request.jwt.claims', true) as claims,
       public.get_my_role() as app_role;
```

```sql
-- Visibility checks
select count(*) as evidence_visible from public.evidence;
select count(*) as tasks_visible from public.task_assignments;
select count(*) as locations_visible from public.agent_location_tracking;
```
