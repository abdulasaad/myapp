# User Management System - Testing Guide

## 🛠️ Setup for Testing

### Step 1: Database Setup
Run these SQL scripts in your Supabase SQL editor in order:

1. **`manual_email_confirmation.sql`** - Confirms user.manager@test.com email
2. **`fix_status_constraint.sql`** - Fixes status constraint issues
3. **`cleanup_and_test.sql`** - Cleans up test data and adds sample groups

### Step 2: Deploy Edge Function
```bash
./deploy_edge_function.sh
```
Or manually:
```bash
supabase functions deploy create-user-admin
```

## 🧪 Testing Scenarios

### Scenario 1: Manual Email Confirmation
**Goal**: Confirm that user.manager@test.com can log in

**Steps**:
1. Run `manual_email_confirmation.sql`
2. Try logging in with user.manager@test.com
3. ✅ **Expected**: Login should work without email verification

### Scenario 2: User Status Management
**Goal**: Test activating/deactivating users

**Steps**:
1. Go to Admin Dashboard → User Management
2. Find any user and click the three-dot menu
3. Click "Deactivate" or "Activate"
4. ✅ **Expected**: Status should change between 'active' and 'offline'

### Scenario 3: Agent Creation (No Email Confirmation)
**Goal**: Create an agent account that doesn't need email verification

**Steps**:
1. Admin Dashboard → User Management → Create User
2. Fill form:
   - **Full Name**: Test Agent
   - **Email**: test.agent@example.com
   - **Role**: Agent
   - **Username**: testagent123
   - **Password**: (generate or enter)
3. Click "Create User"
4. ✅ **Expected**: 
   - User created successfully
   - Agent can log in immediately without email verification

### Scenario 4: Manager Creation (With Email Confirmation)
**Goal**: Create a manager account that requires email verification

**Steps**:
1. Admin Dashboard → User Management → Create User
2. Fill form:
   - **Full Name**: Test Manager
   - **Email**: test.manager@example.com
   - **Role**: Manager
   - **Agent Creation Limit**: 10
3. Click "Create User"
4. ✅ **Expected**: 
   - User created successfully
   - Manager needs to verify email before logging in

### Scenario 5: Search and Filtering
**Goal**: Test user search and filtering features

**Steps**:
1. Go to User Management screen
2. **Search Test**: Type user names/emails in search bar
3. **Role Filter**: Filter by Admin/Manager/Agent
4. **Status Filter**: Filter by Active/Offline
5. **Group Filter**: Filter by available groups
6. ✅ **Expected**: Results should update in real-time

### Scenario 6: User Profile Management
**Goal**: Test viewing and editing user details

**Steps**:
1. Click on any user card to view details
2. Click "Edit" in the user detail screen
3. Modify some fields (name, groups, etc.)
4. Save changes
5. ✅ **Expected**: Changes should be saved and reflected

### Scenario 7: Group Assignment
**Goal**: Test assigning users to groups

**Steps**:
1. Create or edit a user
2. In "Group Assignment" section, select multiple groups
3. Save the user
4. View user details to confirm group memberships
5. ✅ **Expected**: User should be assigned to selected groups

## 🚨 Common Issues & Solutions

### Issue: "column profiles.default_group_id does not exist"
**Solution**: Run the database fix scripts in order

### Issue: "violates check constraint status_check"
**Solution**: Run `fix_status_constraint.sql`

### Issue: Edge function not working
**Solution**: Redeploy with `supabase functions deploy create-user-admin`

### Issue: Email not confirmed
**Solution**: 
- For testing: Run `manual_email_confirmation.sql`
- For agents: Should auto-confirm
- For managers: Check email inbox or manually confirm via SQL

## 📊 Verification Queries

Check user creation:
```sql
SELECT id, full_name, email, role, status, created_at 
FROM public.profiles 
ORDER BY created_at DESC 
LIMIT 10;
```

Check email confirmation status:
```sql
SELECT u.email, u.email_confirmed_at, p.full_name, p.role
FROM auth.users u
JOIN public.profiles p ON u.id = p.id
WHERE u.email LIKE '%test%'
ORDER BY u.created_at DESC;
```

Check group assignments:
```sql
SELECT p.full_name, p.role, g.name as group_name
FROM public.profiles p
JOIN public.user_groups ug ON p.id = ug.user_id
JOIN public.groups g ON ug.group_id = g.id
ORDER BY p.full_name;
```

## ✅ Success Criteria

- [ ] user.manager@test.com can log in
- [ ] User status toggle works (active ↔ offline)
- [ ] Agents created without email confirmation
- [ ] Managers created with email confirmation requirement
- [ ] Search and filtering work smoothly
- [ ] User editing preserves data correctly
- [ ] Group assignment functions properly
- [ ] No database constraint errors
- [ ] Edge function deploys and works correctly