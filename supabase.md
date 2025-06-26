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

**Last Updated**: 2025-06-26  
**Maintained By**: Claude Code Assistant  
**Version**: 1.0