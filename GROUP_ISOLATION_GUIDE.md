# 🔒 Group-Based Isolation System

## 📋 **Overview**

This system ensures that **each manager only sees and manages users within their assigned groups**, creating complete isolation between different manager domains.

## 🎯 **Key Isolation Rules**

### **Admins** 👑
- ✅ Can see **ALL** users, campaigns, tasks, and evidence
- ✅ Can manage **ALL** groups and assignments
- ✅ No restrictions

### **Managers** 👨‍💼
- ✅ Can only see users in **shared groups**
- ✅ Can only see campaigns/tasks involving **their group's agents**
- ✅ Can only assign tasks to **agents in their groups**
- ✅ Can only view evidence from **their group's agents**
- ❌ **Cannot see** users/data from other groups

### **Agents** 👷‍♂️
- ✅ Can see their **own profile and assignments**
- ✅ Can view tasks **assigned to them**
- ✅ Can submit evidence for **their tasks**
- ❌ Cannot see other agents or management data

## 🛠️ **Implementation Steps**

### Step 1: Apply Database Policies
```sql
-- Run this in Supabase SQL Editor
-- File: group_isolation_policies.sql
```
This creates comprehensive RLS policies for all tables.

### Step 2: Test the Setup
```sql
-- Run this to verify isolation works
-- File: test_group_isolation.sql
```

### Step 3: Assign Test Users to Groups
```sql
-- Create realistic test scenario
-- File: assign_test_users.sql
```

### Step 4: Deploy Updated Code
The UserManagementService has been updated to respect group boundaries.

## 📊 **How It Works**

### **Database Level (RLS Policies)**
- **profiles**: Managers only see users in shared groups
- **campaigns**: Managers only see campaigns involving their groups
- **tasks**: Managers only see tasks assigned to their group's agents
- **task_assignments**: Managers can only assign to their group's agents
- **evidence**: Managers only see evidence from their group's agents

### **Application Level**
- **User Management**: Automatically filtered by group membership
- **Group Selection**: Managers only see their own groups
- **Assignment Screens**: Only show available agents from manager's groups

## 🧪 **Testing Scenarios**

### Scenario 1: Manager Isolation
1. **Create Manager A** → Assign to "Sales Team"
2. **Create Manager B** → Assign to "Support Team"  
3. **Create Agents** → Some in Sales, some in Support
4. **Test**: Manager A should only see Sales agents, Manager B should only see Support agents

### Scenario 2: Cross-Group Visibility
1. **Create Manager C** → Assign to both "Sales Team" AND "Marketing Team"
2. **Test**: Manager C should see agents from both teams

### Scenario 3: Admin Override
1. **Login as Admin**
2. **Test**: Should see ALL users regardless of groups

## 📈 **Example Test Setup**

```sql
-- 1. Create groups
Sales Team, Support Team, Marketing Team

-- 2. Assign users
user.manager@test.com → Sales Team
Agent 1, Agent 2 → Sales Team  
Agent 3, Agent 4 → Support Team

-- 3. Expected Result
user.manager@test.com sees: Agent 1, Agent 2 (only Sales Team)
Admin sees: ALL agents
```

## 🔍 **Verification Queries**

### Check Manager's Visible Users
```sql
-- Replace MANAGER_EMAIL with actual email
SELECT p.full_name, p.role, string_agg(g.name, ', ') as groups
FROM public.profiles p
JOIN public.user_groups ug ON p.id = ug.user_id
JOIN public.groups g ON ug.group_id = g.id
WHERE EXISTS (
  SELECT 1 FROM public.profiles manager
  JOIN public.user_groups mug ON manager.id = mug.user_id
  WHERE manager.email = 'MANAGER_EMAIL'
    AND mug.group_id = ug.group_id
)
GROUP BY p.id, p.full_name, p.role;
```

### Check Group Assignments
```sql
SELECT 
    p.full_name,
    p.role,
    g.name as group_name
FROM public.profiles p
JOIN public.user_groups ug ON p.id = ug.user_id
JOIN public.groups g ON ug.group_id = g.id
ORDER BY g.name, p.role;
```

## 🚀 **Quick Start**

1. **Run SQL scripts** (in order):
   - `group_isolation_policies.sql`
   - `assign_test_users.sql`

2. **Hot restart your Flutter app**

3. **Test isolation**:
   - Login as admin → Should see all users
   - Login as manager → Should only see group members
   - Create new users → Should be filtered appropriately

## ⚠️ **Important Notes**

- **Groups are mandatory**: Users without group assignments won't be visible to managers
- **Multiple groups**: Users can belong to multiple groups
- **Manager assignment**: Managers must be assigned to groups to see any users
- **RLS enforcement**: Database automatically enforces these rules
- **Performance**: Policies are optimized with proper indexes

## ✅ **Success Criteria**

- [ ] Manager A cannot see users from Manager B's groups
- [ ] Managers can only assign tasks to their group's agents
- [ ] Campaign/task visibility is group-restricted
- [ ] Evidence viewing is group-restricted
- [ ] Admin maintains full system access
- [ ] User management interface respects boundaries

The system now provides **complete data isolation** while maintaining operational flexibility for admins and appropriate access for managers within their domains.