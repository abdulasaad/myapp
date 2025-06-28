# Supabase Configuration Documentation

## Project Information
- **Project Name**: Al-Tijwal
- **Database**: PostgreSQL with Row Level Security (RLS)
- **Backend**: Supabase (Backend-as-a-Service)

## Database Schema

### Tables Overview

#### 1. `profiles` Table
Extended user information with roles and group assignments.

**Columns:**
- `id` (UUID, Primary Key) - References auth.users
- `full_name` (TEXT)
- `role` (TEXT) - Values: 'admin', 'manager', 'agent'
- `status` (TEXT) - Values: 'active', 'inactive', 'offline'
- `created_at` (TIMESTAMP WITH TIME ZONE)
- `updated_at` (TIMESTAMP WITH TIME ZONE, DEFAULT: now())

#### 2. `groups` Table
User organization with manager assignments.

**Columns:**
- `id` (UUID, Primary Key)
- `name` (TEXT)
- `description` (TEXT)
- `manager_id` (UUID) - References profiles(id)
- `created_at` (TIMESTAMP WITH TIME ZONE)
- `updated_at` (TIMESTAMP WITH TIME ZONE, DEFAULT: now())

#### 3. `user_groups` Table
Many-to-many relationship between users and groups.

**Columns:**
- `id` (UUID, Primary Key)
- `user_id` (UUID) - References profiles(id)
- `group_id` (UUID) - References groups(id)
- `created_at` (TIMESTAMP WITH TIME ZONE)

#### 4. `campaigns` Table
Location-based work campaigns.

**Columns:**
- `id` (UUID, Primary Key)
- `created_at` (TIMESTAMP WITH TIME ZONE)
- `created_by` (UUID) - References profiles(id)
- `name` (TEXT)
- `description` (TEXT)
- `start_date` (DATE)
- `end_date` (DATE)
- `status` (TEXT)
- `package_type` (TEXT)
- `reset_status_daily` (BOOLEAN)
- `assigned_manager_id` (UUID) - References profiles(id) ON DELETE SET NULL **Added: 2025-06-27**

#### 5. `tasks` Table
Individual work items with evidence requirements.

**Columns:**
- `id` (UUID, Primary Key)
- `title` (TEXT)
- `description` (TEXT)
- `points` (INTEGER)
- `campaign_id` (UUID) - References campaigns(id)
- `status` (TEXT)
- `location_name` (TEXT)
- `start_date` (TIMESTAMP WITH TIME ZONE)
- `end_date` (TIMESTAMP WITH TIME ZONE)
- `required_evidence_count` (INTEGER)
- `enforce_geofence` (BOOLEAN)
- `created_by` (UUID) - References profiles(id)
- `reset_status_daily` (BOOLEAN)
- `template_id` (UUID)
- `custom_fields` (JSONB)
- `template_version` (INTEGER)
- `assigned_manager_id` (UUID) - References profiles(id) ON DELETE SET NULL **Added: 2025-06-27**
- `created_at` (TIMESTAMP WITH TIME ZONE)

**Note**: Geofence data is stored at the campaign level, not task level.

#### 6. `task_assignments` Table
Links between agents and tasks.

**Columns:**
- `id` (UUID, Primary Key)
- `task_id` (UUID) - References tasks(id)
- `agent_id` (UUID) - References profiles(id)
- `status` (TEXT) - Values: 'assigned', 'in_progress', 'completed', 'pending'
- `assigned_at` (TIMESTAMP WITH TIME ZONE)
- `completed_at` (TIMESTAMP WITH TIME ZONE)
- `created_at` (TIMESTAMP WITH TIME ZONE)
- `updated_at` (TIMESTAMP WITH TIME ZONE, DEFAULT: now())

#### 7. `evidence` Table
Evidence submissions with metadata.

**Columns:**
- `id` (UUID, Primary Key)
- `title` (TEXT, NOT NULL)
- `description` (TEXT) - **Added: 2025-06-26**
- `file_url` (TEXT, NOT NULL)
- `mime_type` (TEXT)
- `file_size` (INTEGER)
- `status` (TEXT) - Values: 'pending', 'approved', 'rejected'
- `priority` (TEXT) - Values: 'normal', 'urgent'
- `latitude` (DOUBLE PRECISION)
- `longitude` (DOUBLE PRECISION)
- `accuracy` (DOUBLE PRECISION)
- `captured_at` (TIMESTAMP WITH TIME ZONE)
- `rejection_reason` (TEXT)
- `reviewed_at` (TIMESTAMP WITH TIME ZONE)
- `reviewed_by` (UUID) - References profiles(id)
- `task_assignment_id` (UUID, NOT NULL) - References task_assignments(id)
- `uploader_id` (UUID, NOT NULL) - References profiles(id)
- `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL)
- `updated_at` (TIMESTAMP WITH TIME ZONE)

#### 8. `active_agents` Table
Real-time agent tracking.

**Columns:**
- `id` (UUID, Primary Key)
- `agent_id` (UUID) - References profiles(id)
- `latitude` (DOUBLE PRECISION)
- `longitude` (DOUBLE PRECISION)
- `accuracy` (DOUBLE PRECISION)
- `last_seen` (TIMESTAMP WITH TIME ZONE)
- `is_active` (BOOLEAN)
- `created_at` (TIMESTAMP WITH TIME ZONE)
- `updated_at` (TIMESTAMP WITH TIME ZONE, DEFAULT: now())

#### 9. `geofences` Table
Geofence areas for campaigns and tasks.

**Columns:**
- `id` (UUID, Primary Key)
- `campaign_id` (UUID) - References campaigns(id)
- `task_id` (UUID) - References tasks(id)
- `name` (TEXT)
- `area` (GEOGRAPHY/GEOMETRY - PostGIS type)
- `area_text` (TEXT) - Text representation of area
- `color` (TEXT)
- `created_at` (TIMESTAMP WITH TIME ZONE)

## Foreign Key Relationships

### Current Relationships (as of 2025-06-26)

1. **task_assignments → profiles**
   ```sql
   ALTER TABLE task_assignments
   ADD CONSTRAINT fk_task_assignments_agent_id
   FOREIGN KEY (agent_id) REFERENCES profiles(id);
   ```

2. **task_assignments → tasks**
   ```sql
   ALTER TABLE task_assignments
   ADD CONSTRAINT fk_task_assignments_task_id
   FOREIGN KEY (task_id) REFERENCES tasks(id);
   ```

3. **tasks → campaigns**
   ```sql
   ALTER TABLE tasks
   ADD CONSTRAINT fk_tasks_campaign_id
   FOREIGN KEY (campaign_id) REFERENCES campaigns(id);
   ```

4. **groups → profiles (manager)**
   ```sql
   ALTER TABLE groups
   ADD CONSTRAINT fk_groups_manager_id
   FOREIGN KEY (manager_id) REFERENCES profiles(id);
   ```

5. **user_groups → profiles**
   ```sql
   ALTER TABLE user_groups
   ADD CONSTRAINT fk_user_groups_user_id
   FOREIGN KEY (user_id) REFERENCES profiles(id);
   ```

6. **user_groups → groups**
   ```sql
   ALTER TABLE user_groups
   ADD CONSTRAINT fk_user_groups_group_id
   FOREIGN KEY (group_id) REFERENCES groups(id);
   ```

7. **evidence → profiles (reviewer)**
   ```sql
   ALTER TABLE evidence
   ADD CONSTRAINT fk_evidence_reviewed_by
   FOREIGN KEY (reviewed_by) REFERENCES profiles(id);
   ```

8. **active_agents → profiles**
   ```sql
   ALTER TABLE active_agents
   ADD CONSTRAINT fk_active_agents_agent_id
   FOREIGN KEY (agent_id) REFERENCES profiles(id);
   ```

## Row Level Security (RLS) Policies

### Authentication & Authorization
- **Role-based access control**: admin, manager, agent
- **Database-level permissions** enforced through RLS policies
- **Group-based access** for managers and agents

### Policy Examples
```sql
-- Example: Agents can only see their own task assignments
CREATE POLICY "agents_own_assignments" ON task_assignments
FOR SELECT USING (agent_id = auth.uid());

-- Example: Managers can see assignments for their group members
CREATE POLICY "managers_group_assignments" ON task_assignments
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM user_groups ug
    JOIN groups g ON ug.group_id = g.id
    WHERE ug.user_id = agent_id
    AND g.manager_id = auth.uid()
  )
);
```

#### 10. `task_templates` Table
Task templates for creating standardized tasks.

**Columns:**
- `id` (UUID, Primary Key)
- `name` (TEXT)
- `category_id` (UUID) - References template_categories(id)
- `description` (TEXT)
- `default_points` (INTEGER)
- `requires_geofence` (BOOLEAN)
- `default_evidence_count` (INTEGER)
- `template_config` (JSONB)
- `evidence_types` (JSONB)
- `custom_instructions` (TEXT)
- `estimated_duration` (INTEGER)
- `difficulty_level` (TEXT)
- `task_type` (TEXT) - **Added: 2025-06-26** - Values: 'simpleEvidence', 'survey', 'dataCollection', 'inspection', 'delivery', 'monitoring', 'maintenance'
- `is_active` (BOOLEAN)
- `created_by` (UUID) - References profiles(id)
- `created_at` (TIMESTAMP WITH TIME ZONE)
- `updated_at` (TIMESTAMP WITH TIME ZONE)

#### 11. `task_dynamic_fields` Table
**Added: 2025-06-26** - Dynamic form fields created by managers for specific tasks.

**Columns:**
- `id` (UUID, Primary Key)
- `task_id` (UUID) - References tasks(id) ON DELETE CASCADE
- `field_name` (TEXT, NOT NULL)
- `field_type` (TEXT, NOT NULL) - Values: 'text', 'number', 'email', 'phone', 'select', 'multiselect', 'textarea', 'date', 'time', 'checkbox', 'radio'
- `field_label` (TEXT, NOT NULL)
- `placeholder_text` (TEXT)
- `is_required` (BOOLEAN, DEFAULT: false)
- `field_options` (TEXT[]) - For select/multiselect/radio options
- `validation_rules` (JSONB, DEFAULT: '{}')
- `help_text` (TEXT)
- `sort_order` (INTEGER, DEFAULT: 0)
- `created_at` (TIMESTAMP WITH TIME ZONE, DEFAULT: CURRENT_TIMESTAMP)
- `created_by` (UUID) - References profiles(id)

**Unique Constraint:** `UNIQUE(task_id, field_name)`

#### 12. `sessions` Table
**Added: 2025-06-27** - Device session management to prevent multiple simultaneous logins.

**Columns:**
- `id` (UUID, Primary Key)
- `user_id` (UUID, NOT NULL) - References auth.users(id) ON DELETE CASCADE
- `is_active` (BOOLEAN, NOT NULL, DEFAULT: true)
- `created_at` (TIMESTAMP WITH TIME ZONE, DEFAULT: now())
- `updated_at` (TIMESTAMP WITH TIME ZONE, DEFAULT: now())

**Indexes:**
- `idx_sessions_user_id` ON user_id
- `idx_sessions_active` ON is_active
- `idx_sessions_user_active` ON (user_id, is_active)

**RLS Policies:**
- Users can only view/manage their own sessions
- Automatic cleanup of inactive sessions after 30 days

#### 13. `password_reset_logs` Table
**Added: 2025-06-28** - Audit log for password reset operations performed by managers.

**Columns:**
- `id` (UUID, Primary Key, DEFAULT: gen_random_uuid())
- `user_id` (UUID, NOT NULL) - References auth.users(id) ON DELETE CASCADE
- `reset_by` (UUID) - References auth.users(id) ON DELETE SET NULL  
- `reset_at` (TIMESTAMP WITH TIME ZONE, DEFAULT: NOW())
- `created_at` (TIMESTAMP WITH TIME ZONE, DEFAULT: NOW())

**RLS Policies:**
- Managers and admins can view password reset logs
- Insert permissions for password reset function

## Recent Schema Changes

### 2025-06-26
1. **Added `description` column to evidence table**
   ```sql
   ALTER TABLE evidence ADD COLUMN description TEXT;
   ```

2. **Fixed foreign key relationship between task_assignments and profiles**
   ```sql
   ALTER TABLE task_assignments
   ADD CONSTRAINT fk_task_assignments_agent_id
   FOREIGN KEY (agent_id) REFERENCES profiles(id);
   ```

3. **Added missing foreign key from evidence to task_assignments**
   ```sql
   ALTER TABLE evidence
   ADD COLUMN task_assignment_id UUID REFERENCES task_assignments(id);
   ```

4. **Updated evidence query structure in Flutter code**
   - Fixed join syntax to use explicit foreign key references
   - Added null safety checks for task assignment data
   - Corrected EvidenceListItem constructor parameter order

5. **Added `task_type` column to task_templates table**
   ```sql
   ALTER TABLE task_templates ADD COLUMN task_type TEXT DEFAULT 'simpleEvidence';
   ```

6. **Created `task_dynamic_fields` table for dynamic form fields**
   ```sql
   CREATE TABLE task_dynamic_fields (
       id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
       task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
       field_name TEXT NOT NULL,
       field_type TEXT NOT NULL,
       field_label TEXT NOT NULL,
       placeholder_text TEXT,
       is_required BOOLEAN DEFAULT false,
       field_options TEXT[],
       validation_rules JSONB DEFAULT '{}',
       help_text TEXT,
       sort_order INTEGER DEFAULT 0,
       created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
       created_by UUID REFERENCES profiles(id),
       UNIQUE(task_id, field_name)
   );
   ```

7. **Implemented RLS policies for dynamic fields**
   - Managers can create/manage dynamic fields for their tasks
   - Agents can read dynamic fields for assigned tasks (including pending status)

8. **Added dynamic form field builder system**
   - Managers can create custom form fields when creating survey/data collection tasks
   - Support for 11 field types with validation and options
   - Form submissions stored in both `custom_fields` (JSON) and `evidence` table (audit trail)

### 2025-06-27
1. **Implemented comprehensive group isolation system**
   - Managers can only see campaigns/tasks created by users in their shared groups
   - Live map filtering: Managers only see agents within their groups
   - User management: Group-based filtering for agent assignment
   - Applied to campaigns list, standalone tasks, and agent assignment screens

2. **Enhanced session management for device security**
   - Added `sessions` table with proper RLS policies and indexing
   - Implemented periodic session validation (60-second intervals)
   - Session conflict dialog for multiple device login attempts
   - Automatic logout when session becomes invalid on another device
   - Session cleanup function for old inactive sessions

3. **Updated session handling in application**
   - Added session validation to ModernHomeScreen with automatic logout
   - Enhanced login screen with session conflict detection
   - Proper session cleanup on app dispose

4. **Added manager assignment functionality**
   ```sql
   ALTER TABLE tasks 
   ADD COLUMN assigned_manager_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
   
   ALTER TABLE campaigns
   ADD COLUMN assigned_manager_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
   
   CREATE INDEX idx_tasks_assigned_manager ON tasks(assigned_manager_id);
   CREATE INDEX idx_campaigns_assigned_manager ON campaigns(assigned_manager_id);
   ```
   - Admin users can now assign specific managers to tasks and campaigns
   - Admin-created tasks without assigned managers are not visible to agents
   - Manager assignment dropdown added to task and campaign creation screens
   - Database columns and indexes added for performance
   - Updated Task model to include `createdAt` property for proper sorting
   - Enhanced manager task/campaign fetching logic to include assigned items
   - Fixed all database queries to select `created_at` field

### 2025-06-28
1. **Implemented direct password reset system for managers**
   ```sql
   -- Created password reset logs table
   CREATE TABLE IF NOT EXISTS password_reset_logs (
       id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
       user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
       reset_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
       reset_at TIMESTAMPTZ DEFAULT NOW(),
       created_at TIMESTAMPTZ DEFAULT NOW()
   );

   -- Added RLS policies for password reset logs
   CREATE POLICY "Managers and admins can view password reset logs" 
   ON password_reset_logs FOR SELECT 
   USING (
       EXISTS (
           SELECT 1 FROM profiles 
           WHERE id = auth.uid() 
           AND role IN ('manager', 'admin')
       )
   );

   CREATE POLICY "Allow password reset logging" 
   ON password_reset_logs FOR INSERT 
   WITH CHECK (true);

   -- Created password reset function with group-based permissions
   CREATE OR REPLACE FUNCTION reset_user_password_direct(
       target_user_id UUID,
       new_password TEXT
   )
   RETURNS JSON
   LANGUAGE plpgsql
   SECURITY DEFINER
   AS $$
   -- Function validates manager permissions and resets passwords directly
   $$;
   ```

2. **Enhanced Team Members management screen**
   - Managers can view all agents within their groups with status indicators
   - Added search and filtering capabilities for team members
   - Real-time agent status display with active task counts
   - Group membership visibility for each team member

3. **Direct password reset with manual entry**
   - Managers can reset passwords for agents in their groups only
   - Manual password entry with strength validation requirements
   - Real-time password validation (8+ chars, uppercase, lowercase, numbers)
   - Password confirmation field with match validation
   - Immediate password change in Supabase Auth system
   - Copy-to-clipboard functionality for easy password sharing

4. **UI improvements for password reset dialog**
   - Fixed keyboard overlap issues with scrollable dialog
   - Professional password entry interface with show/hide toggles
   - Clear password requirements display
   - Success dialog with secure password sharing instructions
   - Audit logging for all password reset operations

5. **Security enhancements**
   - Group-based permission validation at database level
   - Role verification (only managers/admins can reset passwords)
   - Target user validation (can only reset agent passwords)
   - Comprehensive audit trail for password reset operations
   - Bcrypt password hashing in database function

## Key Features

### 1. Geofencing
- **Campaign-level**: Location boundaries for entire campaigns
- **Task-level**: Specific geofence validation for individual tasks
- **Evidence validation**: Location verification against task geofences

### 2. Evidence Management
- **Photo capture** with metadata (location, timestamp)
- **Multi-format support**: Images, PDFs, videos, documents
- **Review workflow**: Pending → Approved/Rejected
- **Location verification**: Distance calculation from task center

### 3. Real-time Features
- **Agent tracking**: Live location monitoring for admins/managers
- **Status updates**: Real-time task and evidence status changes
- **Dashboard metrics**: Live performance and system health data

### 4. User Management
- **Hierarchical structure**: Admin → Manager → Agent
- **Group-based organization**: Managers oversee specific agent groups
- **Role-based UI**: Different interfaces per user role

### 5. Dynamic Form Builder (Added: 2025-06-26)
- **Template System**: 8 task types including survey, data collection, inspection
- **Custom Field Creation**: Managers can create dynamic form fields for tasks
- **Field Types**: Support for 11 field types (text, number, email, phone, select, multiselect, textarea, date, time, checkbox, radio)
- **Validation**: Built-in validation rules and required field enforcement
- **Form Responses**: Comprehensive form submission management and viewing
- **Data Export**: Form response viewing with export capabilities (planned)

### 6. Group Isolation System (Added: 2025-06-27)
- **Manager Segregation**: Managers only see content from users in their shared groups
- **Campaign Filtering**: Group-based campaign and task visibility
- **Agent Assignment**: Filtered agent lists based on group membership
- **Live Map Filtering**: Real-time agent tracking respects group boundaries
- **User Management**: Group-aware user creation and assignment

### 7. Device Session Management (Added: 2025-06-27)
- **Single Device Login**: Prevents multiple simultaneous logins per account
- **Session Validation**: Periodic 60-second session checks
- **Automatic Logout**: Forced logout when logged in from another device
- **Conflict Resolution**: User choice dialog for handling multiple login attempts
- **Session Cleanup**: Automatic removal of old inactive sessions

### 8. Password Reset Management (Added: 2025-06-28)
- **Manager-Controlled Resets**: Managers can reset passwords for agents in their groups
- **Direct Password Change**: Immediate password updates in Supabase Auth system
- **Manual Password Entry**: Managers manually enter new passwords with validation
- **Security Validation**: Role-based permissions and group isolation enforcement
- **Audit Trail**: Complete logging of all password reset operations
- **Professional UI**: Clean password entry dialog with requirements display

## API Integration

### Supabase Client Configuration
```dart
// Global client accessible via supabase constant in lib/utils/constants.dart
final supabase = Supabase.instance.client;
```

### Key Query Patterns

#### Evidence with Related Data
```dart
final evidenceQuery = supabase
    .from('evidence')
    .select('''
      *,
      task_assignments!inner(
        tasks!inner(
          id, title, campaign_id,
          campaigns(name)
        ),
        profiles!inner(id, full_name)
      )
    ''');
```

#### Manager Dashboard Stats
```dart
final taskStats = await supabase
    .from('tasks')
    .select('id, status, created_at');

final agentStats = await supabase
    .from('profiles')
    .select('status, role')
    .eq('role', 'agent');
```

## Storage Configuration

### File Storage
- **Bucket**: Evidence files (images, documents)
- **Public access**: Controlled via RLS policies
- **File size limits**: Configured per file type
- **Supported formats**: Images (JPEG, PNG), PDFs, Videos, Documents

## Environment Variables
```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
```

## Development Notes

### Error Handling Patterns
- **Try-catch blocks** around all database operations
- **Fallback values** for missing data
- **User-friendly error messages** with retry options
- **Debug logging** for development troubleshooting

### Performance Considerations
- **Indexed foreign keys** for efficient joins
- **Pagination** for large data sets
- **Selective queries** to minimize data transfer
- **Connection pooling** via Supabase client

---

**Last Updated**: 2025-06-28  
**Maintained By**: Claude Code Assistant  
**Version**: 1.2