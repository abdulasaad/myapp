-- Debug payment functionality issues
-- Run this in your Supabase SQL Editor

-- 1. Check if payments table has the new columns
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'payments' 
ORDER BY ordinal_position;

-- 2. Check current user permissions on payments table
SELECT 
    table_name,
    privilege_type
FROM information_schema.table_privileges 
WHERE table_name = 'payments'
AND grantee = 'authenticated';

-- 3. Test a simple insert to payments table (replace with actual IDs)
-- INSERT INTO payments (agent_id, amount, payment_amount, bonus_amount, paid_by, paid_at, payment_method, notes)
-- VALUES (
--     '263e832c-f73c-48f3-bfd2-1b567cbff0b1',
--     5,
--     5,
--     0,
--     '38e6aae3-efab-4668-b1f1-adbc1b513800',
--     NOW(),
--     'manual',
--     'Test payment'
-- );

-- 4. Check RLS policies on payments table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'payments';