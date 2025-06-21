# Profile Status Constraint Investigation

The error occurs when logging out and trying to set status to 'offline'. Let's check what status values are allowed.

## Check the status constraint on profiles table
```sql
SELECT 
    constraint_name,
    check_clause
FROM information_schema.check_constraints 
WHERE constraint_name = 'status_check';
```

## Check current constraint definition
```sql
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conname = 'status_check';
```

## Check all constraints on profiles table
```sql
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'profiles'::regclass;
```

## Check current status values in profiles table
```sql
SELECT DISTINCT status 
FROM profiles 
ORDER BY status;
```

---

## ✅ Solution Found

The constraint only allows: `['active', 'suspended', 'deleted']`
But the app tries to use: `'offline'`, `'away'`, `'inactive'`

### Option 1: Update Database Constraint (Recommended)
```sql
-- Drop the existing constraint
ALTER TABLE profiles DROP CONSTRAINT status_check;

-- Add new constraint with all needed status values
ALTER TABLE profiles ADD CONSTRAINT status_check 
CHECK (status IN ('active', 'suspended', 'deleted', 'away', 'offline'));
```

### Option 2: Change App Code to Use Allowed Values
Update these files to use allowed status values:

**In home_screen.dart:**
```dart
// Line 45: Change 'active' to 'active' (already correct)
ProfileService.instance.updateUserStatus('active');

// Line 47: Change 'away' to 'suspended'
ProfileService.instance.updateUserStatus('suspended');

// Line 59: Change 'offline' to 'suspended'
await ProfileService.instance.updateUserStatus('suspended');
```

### Recommendation: Use Option 1
Option 1 is better because it maintains the app's intended behavior and status semantics.