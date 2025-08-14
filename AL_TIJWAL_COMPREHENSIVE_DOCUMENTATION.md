# AL-Tijwal: Comprehensive Application Documentation

## Table of Contents
1. [Application Overview](#application-overview)
2. [Technical Architecture](#technical-architecture)
3. [User Roles & Permissions](#user-roles--permissions)
4. [Core Features](#core-features)
5. [Data Models](#data-models)
6. [Database Schema](#database-schema)
7. [Screen Architecture](#screen-architecture)
8. [Services & Components](#services--components)
9. [Navigation Flows](#navigation-flows)
10. [Location & Geofencing](#location--geofencing)
11. [Template System](#template-system)
12. [Notification System](#notification-system)
13. [Multi-Language Support](#multi-language-support)
14. [Security & Authentication](#security--authentication)
15. [Development Environment](#development-environment)
16. [API Integration](#api-integration)
17. [Testing Strategy](#testing-strategy)
18. [Deployment Configuration](#deployment-configuration)

---

## Application Overview

**AL-Tijwal** is a comprehensive Flutter mobile application designed for location-based task management and field operations. The application serves as a sophisticated platform for campaign management, evidence collection, and real-time agent tracking in field operations.

### Key Characteristics
- **Application Name**: AL-Tijwal Agent
- **Description**: Location-Based Task Management
- **Version**: 1.3.1+20
- **Platform**: Cross-platform Flutter (Android/iOS)
- **Backend**: Supabase (PostgreSQL with Row Level Security)
- **Real-time Features**: Live location tracking, instant notifications
- **Internationalization**: Arabic and English support

### Primary Use Cases
1. **Field Operations Management**: Coordinate agents in field-based campaigns
2. **Evidence Collection**: Systematic photo and data collection with GPS verification
3. **Real-time Monitoring**: Live tracking of agent activities and locations
4. **Campaign Analytics**: Comprehensive reporting and performance metrics
5. **Route-based Tasks**: Sequential location visits with evidence requirements

---

## Technical Architecture

### Frontend Architecture
- **Framework**: Flutter 3.x
- **Language**: Dart (SDK >=2.19.0 <3.0.0)
- **UI Pattern**: Material Design 3 with custom theming
- **State Management**: Provider pattern for complex state
- **Navigation**: Material page routes with role-based navigation

### Backend Architecture
- **BaaS Provider**: Supabase
- **Database**: PostgreSQL with Row Level Security (RLS)
- **Authentication**: Supabase Auth with email/password
- **Real-time**: Supabase Realtime for live updates
- **File Storage**: Supabase Storage for evidence photos
- **Edge Functions**: TypeScript functions for complex operations

### External Integrations
- **Firebase**: Cloud Messaging for push notifications
- **Google Maps**: Location services and mapping
- **Geolocator**: Precise GPS positioning
- **Image Picker**: Camera integration for evidence collection

### Development Tools
- **IDE**: VS Code with Flutter extensions
- **Version Control**: Git
- **Testing**: Flutter Test framework with Mockito
- **CI/CD**: GitHub Actions
- **Debugging**: Flutter DevTools

---

## User Roles & Permissions

### Role Hierarchy

#### 1. Admin (Highest Privileges)
**Capabilities:**
- Complete system administration
- User management (create, edit, delete users)
- Group management and organization
- Campaign creation and full lifecycle management
- Template system administration
- System settings configuration
- Evidence review and approval
- Real-time agent monitoring
- Advanced analytics and reporting
- Database export capabilities

**Access Restrictions:** None - full system access

#### 2. Manager (Campaign & Team Management)
**Capabilities:**
- Team member management within assigned groups
- Campaign creation and management for their groups
- Task assignment and tracking
- Route planning and management
- Place/location database management
- Team performance analytics
- Evidence review for assigned campaigns
- Agent earnings management

**Access Restrictions:**
- Cannot modify system settings
- Cannot access other managers' groups
- Cannot delete system-wide data

#### 3. Agent (Field Operations)
**Capabilities:**
- View assigned campaigns and tasks
- Submit evidence with photos and GPS data
- Execute route-based touring tasks
- Track personal earnings and performance
- Receive push notifications for assignments
- Access GPS calibration tools
- View submission history

**Access Restrictions:**
- Read-only access to campaigns and tasks
- Cannot create or modify campaigns
- Cannot access other agents' data
- Cannot view system administration screens

#### 4. Client (View-Only)
**Capabilities:**
- View campaign progress and results
- Access to assigned campaign dashboards
- View evidence submissions (if authorized)
- Basic campaign analytics

**Access Restrictions:**
- No creation or modification capabilities
- Limited to specifically assigned campaigns
- Cannot access agent or management tools

### Permission Matrix

| Feature | Admin | Manager | Agent | Client |
|---------|-------|---------|-------|--------|
| Create Campaigns | ✅ | ✅ | ❌ | ❌ |
| Assign Tasks | ✅ | ✅ | ❌ | ❌ |
| Submit Evidence | ✅ | ✅ | ✅ | ❌ |
| View Analytics | ✅ | ✅ | Limited | Limited |
| User Management | ✅ | Limited | ❌ | ❌ |
| System Settings | ✅ | ❌ | ❌ | ❌ |
| Real-time Tracking | ✅ | ✅ | Self-only | ❌ |

---

## Core Features

### 1. Campaign Management System
**Description:** Comprehensive campaign lifecycle management from creation to completion.

**Components:**
- Campaign creation wizard (3-step process)
- Campaign status tracking (draft, active, completed, archived)
- Multi-package campaign support
- Client assignment and manager delegation
- Campaign geofence configuration
- Start/end date management with timezone support

**Key Screens:**
- `CampaignsListScreen`: Role-based campaign directory
- `CampaignDetailScreen`: Full campaign management interface
- `CreateCampaignScreen`: Direct campaign creation
- `CampaignWizardStep1-3Screen`: Guided campaign setup

### 2. Location-Based Task System
**Description:** GPS-enabled task management with geofence enforcement and evidence collection.

**Task Types:**
- **Evidence Collection Tasks**: Photo capture with GPS verification
- **Touring Tasks**: Sequential route visits with evidence requirements
- **Stay Tasks**: Time-based location presence verification
- **Data Collection Tasks**: Form-based information gathering

**Geofencing Features:**
- Campaign-level boundary enforcement
- Task-specific location restrictions
- Real-time geofence entry/exit detection
- GPS accuracy validation

### 3. Evidence Management
**Description:** Systematic photo and data collection with metadata preservation.

**Evidence Features:**
- GPS coordinate embedding
- Timestamp verification
- Image compression and optimization
- Multi-photo submissions per task
- Evidence review and approval workflow
- Metadata export capabilities

**Evidence Types:**
- Photo evidence with GPS coordinates
- Form responses with validation
- Signature capture
- File attachments

### 4. Real-Time Agent Tracking
**Description:** Live monitoring of field agents with location history and performance metrics.

**Tracking Capabilities:**
- Live GPS position updates
- Location history with timestamps
- Geofence entry/exit notifications
- Agent status monitoring (active, idle, offline)
- Route progress tracking
- Performance analytics

### 5. Template System
**Description:** Reusable task templates for standardized operations.

**Template Features:**
- Custom field definitions
- Template categories and organization  
- Version control for templates
- Template preview and validation
- Bulk task creation from templates
- Template sharing across campaigns

### 6. Route Management
**Description:** Sequential location visit planning and execution.

**Route Features:**
- Multi-location route planning
- Turn-by-turn navigation integration
- Route optimization algorithms
- Evidence requirements per location
- Route completion tracking
- Route analytics and reporting

### 7. Earnings System
**Description:** Agent compensation tracking and payment management.

**Earnings Features:**
- Task-based payment calculation
- Campaign completion bonuses
- Real-time earnings tracking
- Payment history and reporting
- Performance-based incentives

---

## Data Models

### Core Entities

#### 1. AppUser Model
```dart
class AppUser {
  final String id;                    // UUID primary key
  final String fullName;              // User display name
  final String? username;             // Optional username
  final String? email;                // Email address
  final String role;                  // User role (admin/manager/agent/client)
  final String? status;               // Account status (active/inactive)
  final int? agentCreationLimit;      // Max agents a manager can create
  final String? defaultGroupId;       // Default group assignment
  final String? createdBy;            // Creator user ID
  final DateTime createdAt;           // Creation timestamp
  final DateTime? updatedAt;          // Last update timestamp
}
```

#### 2. Campaign Model
```dart
class Campaign {
  final String id;                    // UUID primary key
  final DateTime createdAt;           // Creation timestamp
  final String name;                  // Campaign name
  final String? description;          // Campaign description
  final DateTime startDate;           // Campaign start date
  final DateTime endDate;             // Campaign end date
  final String status;                // Campaign status
  final String packageType;           // Campaign package type
  final String? clientId;             // Assigned client ID
  final String? assignedManagerId;    // Assigned manager ID
}
```

#### 3. Task Model
```dart
class Task {
  final String id;                    // UUID primary key
  final String? campaignId;           // Parent campaign (nullable for standalone)
  final String title;                 // Task title
  final String? description;          // Task description
  final int points;                   // Points awarded for completion
  final String status;                // Task status
  final DateTime createdAt;           // Creation timestamp
  final String? locationName;         // Location description
  final DateTime? startDate;          // Task start date
  final DateTime? endDate;            // Task end date
  final int? requiredEvidenceCount;   // Required evidence items
  final bool? enforceGeofence;        // Geofence enforcement flag
  final String? templateId;           // Template reference
  final Map<String, dynamic>? customFields; // Template custom fields
  final int? templateVersion;         // Template version
}
```

#### 4. Group Model
```dart
class Group {
  final String id;                    // UUID primary key
  final String name;                  // Group name
  final String? description;          // Group description
  final String? createdBy;            // Creator user ID
  final DateTime createdAt;           // Creation timestamp
  final DateTime updatedAt;           // Last update timestamp
}
```

### Specialized Models

#### 1. ActiveAgent Model
- Real-time agent status tracking
- GPS coordinates and timestamp
- Status indicators (active/idle/offline)
- Session management

#### 2. TaskAssignment Model
- Agent-task relationship mapping
- Assignment status tracking
- Completion tracking
- Performance metrics

#### 3. LocationHistory Model
- Historical GPS data storage
- Timestamp and accuracy information
- User activity correlation
- Geofence interaction logs

#### 4. CampaignGeofence Model
- Geographic boundary definitions
- Polygon coordinate storage
- Geofence rule configuration
- Campaign association

#### 5. TouringTask Model
- Route-based task definitions
- Sequential location requirements
- Route optimization data
- Progress tracking

---

## Database Schema

### Core Tables

#### profiles
```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  full_name TEXT NOT NULL,
  username TEXT UNIQUE,
  email TEXT,
  role TEXT NOT NULL DEFAULT 'agent',
  status TEXT DEFAULT 'active',
  agent_creation_limit INTEGER,
  default_group_id UUID REFERENCES groups(id),
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### campaigns
```sql
CREATE TABLE campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  end_date TIMESTAMP WITH TIME ZONE NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft',
  package_type TEXT NOT NULL,
  client_id UUID REFERENCES profiles(id),
  assigned_manager_id UUID REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### tasks  
```sql
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID REFERENCES campaigns(id),
  title TEXT NOT NULL,
  description TEXT,
  points INTEGER DEFAULT 0,
  status TEXT DEFAULT 'pending',
  location_name TEXT,
  start_date TIMESTAMP WITH TIME ZONE,
  end_date TIMESTAMP WITH TIME ZONE,
  required_evidence_count INTEGER,
  enforce_geofence BOOLEAN DEFAULT false,
  template_id UUID REFERENCES task_templates(id),
  custom_fields JSONB,
  template_version INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### groups
```sql
CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Relationship Tables

#### user_groups (Many-to-Many)
```sql
CREATE TABLE user_groups (
  user_id UUID REFERENCES profiles(id),
  group_id UUID REFERENCES groups(id),
  role TEXT DEFAULT 'member',
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (user_id, group_id)
);
```

#### task_assignments
```sql
CREATE TABLE task_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID REFERENCES tasks(id),
  agent_id UUID REFERENCES profiles(id),
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status TEXT DEFAULT 'assigned',
  completed_at TIMESTAMP WITH TIME ZONE,
  evidence_count INTEGER DEFAULT 0
);
```

### Row Level Security (RLS) Policies

The database implements comprehensive RLS policies to ensure data security:

- **Profile Access**: Users can only access their own profile and profiles in their managed groups
- **Campaign Access**: Role-based access with manager group restrictions
- **Task Access**: Agents see only assigned tasks, managers see group tasks
- **Evidence Access**: Restricted to task assignees and campaign managers
- **Location Data**: Personal location data privacy with management oversight

---

## Screen Architecture

### Authentication Flow
```
SplashScreen (Session Validation)
    ↓
LoginScreen/SignupScreen (Authentication)
    ↓
ModernHomeScreen (Role-based Hub)
```

### Admin Screens (`/lib/screens/admin/`)

#### Core Administration
- **AdminDashboardScreen**: System-wide statistics and oversight
- **EnhancedManagerDashboardScreen**: Manager-specific dashboard with team metrics

#### User Management Screens
- **UserManagementScreen**: Complete user directory with CRUD operations
- **CreateEditUserScreen**: User creation and modification forms
- **UserDetailScreen**: Individual user profile and activity history
- **GroupManagementScreen**: Team organization and hierarchy management
- **CreateEditGroupScreen**: Group creation and member assignment
- **GroupDetailScreen**: Group analytics and member management

#### Evidence & Task Management
- **EvidenceListScreen**: Evidence review queue with filtering
- **EvidenceDetailScreen**: Detailed evidence inspection and approval
- **SimpleEvidenceReviewScreen**: Streamlined evidence review workflow
- **TaskDataExportScreen**: Data export and reporting tools

#### System Configuration
- **SettingsScreen**: Application configuration and preferences
- **TemplateSetupScreen**: Task template system administration
- **GPSSettingsScreen**: Location service configuration
- **AgentsEarningsManagementScreen**: Payment and earnings oversight

### Agent Screens (`/lib/screens/agent/`)

#### Campaign & Task Execution
- **AgentCampaignViewScreen**: Campaign overview for field agents
- **AgentTaskListScreen**: Available tasks with priority sorting
- **TaskLocationViewerScreen**: Task details with GPS navigation
- **EvidenceSubmissionScreen**: Photo capture and data submission
- **DataCollectionTaskScreen**: Form-based data collection interface

#### Specialized Task Types
- **AgentTouringTaskListScreen**: Route-based task management
- **TouringTaskExecutionScreen**: Active route navigation and evidence collection
- **GeofenceStayTaskScreen**: Location-based presence verification
- **GeofenceTrackingScreen**: Real-time geofence monitoring

#### Agent Tools & Management
- **AgentRouteDashboardScreen**: Personal route management
- **AgentGeofenceMapScreen**: Geofence visualization and navigation
- **EarningsScreen**: Personal earnings tracking and payment history
- **NotificationsScreen**: Message center and system alerts
- **AppHealthScreen**: System diagnostics and GPS calibration

### Campaign Management Screens (`/lib/screens/campaigns/`)

#### Campaign Lifecycle
- **CampaignsListScreen**: Role-based campaign directory
- **CampaignDetailScreen**: Complete campaign management interface
- **CreateCampaignScreen**: Direct campaign creation form

#### Campaign Creation Wizard
- **CampaignWizardStep1Screen**: Basic campaign information
- **CampaignWizardStep2Screen**: Task configuration and templates
- **CampaignWizardStep3Screen**: Agent assignment and review

#### Geographic Management
- **CampaignGeofenceManagementScreen**: Boundary configuration
- **GeofenceEditorScreen**: Interactive geofence drawing tool
- **AgentCampaignProgressScreen**: Agent-specific progress tracking

### Manager Screens (`/lib/screens/manager/`)

#### Route & Location Management
- **RouteManagementScreen**: Route directory and planning
- **CreateRouteScreen**: Route creation with location sequencing
- **RouteDetailScreen**: Route configuration and optimization
- **RouteEvidenceScreen**: Route completion verification
- **PlaceManagementScreen**: Location database management
- **MapLocationPickerScreen**: Geographic point selection

#### Team Management
- **TeamMembersScreen**: Team overview and performance metrics
- **RouteVisitAnalyticsScreen**: Route completion analytics

### Task & Template Screens (`/lib/screens/tasks/`)

#### Task Management
- **StandaloneTasksScreen**: Independent task management
- **CreateEvidenceTaskScreen**: Evidence collection task setup
- **CreateTouringTaskScreen**: Route-based task creation
- **StandaloneTaskDetailScreen**: Individual task configuration

#### Template System
- **TemplateCategoriesScreen**: Template organization and categorization
- **TemplateGridScreen**: Template selection interface
- **TemplatePreviewScreen**: Template preview and validation
- **CreateTaskFromTemplateScreen**: Template instantiation
- **TaskGeofenceEditorScreen**: Task-specific geofence configuration

### Reporting & Analytics Screens

#### Analytics
- **CampaignReportScreen**: Campaign performance analytics
- **LocationHistoryScreen**: GPS tracking history and analysis

#### Real-time Monitoring
- **LiveMapScreen**: Real-time agent tracking and geofence monitoring

### Client Screens (`/lib/screens/client/`)
- **ClientDashboardScreen**: High-level campaign overview
- **ClientCampaignsListScreen**: Campaign portfolio view

---

## Services & Components

### Core Services (`/lib/services/`)

#### 1. Location Services
**LocationService**
- GPS tracking and positioning
- Geofence entry/exit detection
- Location accuracy validation
- Background location updates
- Battery optimization strategies

**SmartLocationManager**
- Intelligent location sampling
- Power-efficient tracking algorithms
- Location data filtering and validation

**BackgroundLocationService**
- Persistent location tracking
- Service lifecycle management
- Location data queuing and upload

**OfflineLocationQueue**
- Local storage of location data when offline
- Automatic synchronization when connected
- Data integrity validation

#### 2. User & Profile Management
**ProfileService**
- User profile management and caching
- Role-based permission checking
- User status tracking and updates

**UserManagementService**
- User CRUD operations
- Group assignment management
- User validation and authentication

**GroupService**
- Group creation and management
- Member assignment and removal
- Group-based permission enforcement

#### 3. Notification Systems
**NotificationManager**
- Firebase Cloud Messaging integration
- Local notification scheduling
- Notification channel management
- Push notification token management

**SimpleNotificationService**
- Basic notification display
- Fallback notification system
- Notification history tracking

**BackgroundNotificationManager**
- Background notification handling
- Notification queue management
- Notification delivery optimization

#### 4. Task & Campaign Services
**TaskAssignmentService**
- Task-agent assignment management
- Assignment status tracking
- Completion validation

**CampaignGeofenceService**
- Campaign boundary management
- Geofence rule enforcement
- Real-time boundary checking

**TouringTaskService**
- Route-based task management
- Sequential location validation
- Route progress tracking

**TouringTaskMovementService**
- Agent movement tracking during routes
- Movement pattern analysis
- Route optimization suggestions

#### 5. Template & Configuration Services
**TemplateService**
- Task template management
- Template version control
- Custom field configuration

**SettingsService**
- Application configuration management
- User preference storage
- System setting synchronization

**SmartDefaultsService**
- Intelligent default value suggestions
- User behavior learning
- Preference prediction

#### 6. Data & Synchronization Services
**ConnectivityService**
- Network connectivity monitoring
- Offline/online state management
- Data synchronization triggers

**SessionService**
- User session management
- Session timeout handling
- Multi-device session coordination

**UpdateService**
- Application update checking
- Automatic update downloading
- Update notification management

#### 7. Specialized Services
**GeofenceLocationTracker**
- Specialized geofence monitoring
- High-accuracy boundary detection
- Geofence event logging

**LocationHistoryService**
- Historical location data management
- Location analytics and reporting
- Data retention policies

**TimezoneService**
- Multi-timezone support
- Time zone conversion utilities
- Localized time display

**LanguageService**
- Multi-language support
- Language switching functionality
- Localization management

**UserStatusService**
- Real-time user status tracking
- Activity monitoring
- Presence indicators

**PersistentServiceManager**
- Background service coordination
- Service lifecycle management
- Cross-service communication

### Widget Components (`/lib/widgets/`)

#### Notification Widgets
- **ModernNotification**: Contemporary notification display system
- **AdvancedNotification**: Feature-rich notification component

#### Form & Input Components
- **CustomFieldEditor**: Dynamic form field generation
- **MonthDayPicker**: Specialized date selection widget
- **TaskSubmissionPreview**: Evidence preview component

#### Status & Monitoring Components
- **GPSStatusIndicator**: Real-time GPS status display
- **OfflineWidget**: Offline mode indicator
- **ServiceControlWidget**: Service management interface

#### Dialog Components
- **LanguageSelectionDialog**: Multi-language selection
- **SessionConflictDialog**: Session management dialog
- **UpdateDialog**: Application update notification
- **RouteEvidenceUploadDialog**: Route evidence submission
- **StandaloneUploadDialog**: Independent evidence upload

---

## Navigation Flows

### Role-Based Navigation Architecture

#### Universal Entry Point
```
SplashScreen
├── Session Valid → ModernHomeScreen (Role-based)
└── Session Invalid → LoginScreen → ModernHomeScreen
```

#### Admin Navigation Flow
```
ModernHomeScreen (Admin)
├── Tab 1: AdminDashboardScreen
│   ├── UserManagementScreen
│   │   ├── CreateEditUserScreen
│   │   └── UserDetailScreen
│   ├── GroupManagementScreen
│   │   ├── CreateEditGroupScreen
│   │   └── GroupDetailScreen
│   └── EvidenceListScreen
│       └── EvidenceDetailScreen
├── Tab 2: CampaignsListScreen
│   ├── CampaignDetailScreen
│   │   ├── CampaignGeofenceManagementScreen
│   │   └── Task Creation Flows
│   └── CreateCampaignScreen
├── Tab 3: Task Management Screens
└── Tab 4: Profile & Settings
```

#### Manager Navigation Flow
```
ModernHomeScreen (Manager)
├── Tab 1: EnhancedManagerDashboardScreen
│   ├── TeamMembersScreen
│   └── RouteManagementScreen
│       ├── CreateRouteScreen
│       ├── RouteDetailScreen
│       └── RouteEvidenceScreen
├── Tab 2: CampaignsListScreen (Group-filtered)
├── Tab 3: PlaceManagementScreen
└── Tab 4: Profile Management
```

#### Agent Navigation Flow
```
ModernHomeScreen (Agent)
├── Tab 1: Personal Dashboard
│   ├── EarningsScreen
│   └── AgentSubmissionHistoryScreen
├── Tab 2: AgentCampaignViewScreen
│   └── AgentTaskListScreen
│       ├── TaskLocationViewerScreen
│       ├── EvidenceSubmissionScreen
│       └── DataCollectionTaskScreen
├── Tab 3: TouringTaskExecution
│   ├── AgentTouringTaskListScreen
│   └── TouringTaskExecutionScreen
└── Tab 4: Agent Tools
    ├── NotificationsScreen
    └── AppHealthScreen
```

#### Client Navigation Flow
```
ModernHomeScreen (Client)
├── Tab 1: ClientDashboardScreen
├── Tab 2: ClientCampaignsListScreen
└── Tab 3: Limited Analytics
```

### Task Execution Flows

#### Standard Evidence Task Flow
```
AgentTaskListScreen
├── TaskLocationViewerScreen
│   ├── GPS Validation
│   └── Geofence Check
├── EvidenceSubmissionScreen
│   ├── Photo Capture
│   ├── GPS Embedding
│   └── Data Validation
└── Task Completion Confirmation
```

#### Touring Task Flow
```
AgentTouringTaskListScreen
├── TouringTaskExecutionScreen
│   ├── Route Navigation
│   ├── Sequential Location Visits
│   ├── Evidence Collection per Location
│   └── Route Progress Tracking
└── Route Completion Verification
```

#### Template-Based Task Creation Flow
```
TemplateGridScreen
├── TemplatePreviewScreen
├── CreateTaskFromTemplateScreen
│   ├── Custom Field Configuration
│   ├── Location Assignment
│   └── Agent Assignment
└── Task Publishing
```

### Campaign Management Flows

#### Campaign Creation Wizard Flow
```
CampaignWizardStep1Screen (Basic Info)
├── CampaignWizardStep2Screen (Task Configuration)
│   ├── Template Selection
│   └── Task Customization
├── CampaignWizardStep3Screen (Assignment & Review)
│   ├── Agent Assignment
│   ├── Geofence Configuration
│   └── Campaign Validation
└── Campaign Publishing
```

#### Geofence Management Flow
```
CampaignDetailScreen
├── CampaignGeofenceManagementScreen
│   ├── GeofenceEditorScreen
│   │   ├── Interactive Map Drawing
│   │   ├── Polygon Validation
│   │   └── Boundary Testing
│   └── Geofence Rule Configuration
└── Real-time Monitoring (LiveMapScreen)
```

---

## Location & Geofencing

### GPS & Location Architecture

#### Location Service Hierarchy
```
LocationService (Primary)
├── SmartLocationManager (Intelligence Layer)
├── BackgroundLocationService (Persistence)
├── GeofenceLocationTracker (Specialized Monitoring)
└── OfflineLocationQueue (Offline Handling)
```

#### Location Accuracy Levels
1. **High Accuracy**: <5m accuracy for critical tasks
2. **Balanced**: 10-50m accuracy for general tracking  
3. **Low Power**: 100m+ accuracy for background monitoring
4. **Passive**: GPS-free location from network/WiFi

#### Location Data Structure
```dart
class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final double heading;
  final double speed;
  final DateTime timestamp;
  final String source; // GPS, Network, Passive
}
```

### Geofencing System

#### Geofence Types
1. **Campaign Geofences**: Broad area boundaries for entire campaigns
2. **Task Geofences**: Specific location boundaries for individual tasks
3. **Route Geofences**: Sequential boundaries for touring tasks
4. **Stay Geofences**: Time-based presence validation areas

#### Geofence Validation Process
```
1. GPS Position Acquisition
2. Accuracy Validation (min 20m accuracy)
3. Boundary Check (Point-in-Polygon algorithm)
4. Entry/Exit Event Generation
5. Database Logging
6. Real-time Notification
```

#### Geofence Data Model
```dart
class Geofence {
  final String id;
  final String name;
  final List<LatLng> polygon;
  final double minimumAccuracy;
  final int dwellTime; // Required stay time
  final GeofenceType type;
  final bool enforceEntry;
  final bool enforceExit;
}
```

### Real-Time Location Tracking

#### Tracking Modes
1. **Active Tracking**: Continuous high-frequency updates during tasks
2. **Background Tracking**: Power-efficient periodic updates
3. **Route Tracking**: Enhanced tracking during touring tasks
4. **Geofence Monitoring**: Boundary-focused tracking

#### Location History Management
- **Storage**: Local SQLite + Supabase sync
- **Retention**: 30-day rolling window
- **Privacy**: Encrypted storage with user consent
- **Analytics**: Movement pattern analysis

#### Power Optimization Strategies
- **Adaptive Sampling**: Frequency based on movement and activity
- **Geofence-based Updates**: Increased frequency near boundaries
- **Battery Monitoring**: Reduced tracking on low battery
- **Network-based Positioning**: WiFi/cellular when GPS unavailable

---

## Template System

### Template Architecture

The template system provides reusable task configurations with custom fields and validation rules.

#### Template Components
1. **Template Categories**: Organizational structure for templates
2. **Template Fields**: Custom form fields with validation
3. **Template Versions**: Version control for template evolution
4. **Template Instances**: Task instances created from templates

#### Template Data Models

**TaskTemplate**
```dart
class TaskTemplate {
  final String id;
  final String name;
  final String description;
  final String categoryId;
  final List<TemplateField> fields;
  final int version;
  final bool isActive;
  final Map<String, dynamic> defaultValues;
  final List<ValidationRule> validationRules;
}
```

**TemplateField**
```dart
class TemplateField {
  final String id;
  final String name;
  final FieldType type; // text, number, photo, signature, etc.
  final bool required;
  final Map<String, dynamic> validation;
  final dynamic defaultValue;
  final List<String>? options; // For dropdown/radio fields
}
```

#### Field Types Supported
1. **Text Input**: Single/multi-line text fields
2. **Number Input**: Integer/decimal number fields
3. **Photo Upload**: Image capture with GPS metadata
4. **Signature**: Digital signature capture
5. **Dropdown**: Single selection from predefined options
6. **Radio**: Single selection with radio buttons
7. **Checkbox**: Multiple selection options
8. **Date/Time**: Date and time pickers
9. **Location**: GPS coordinate capture
10. **Barcode/QR**: Barcode scanning input

#### Template Validation Rules
- **Required Field Validation**: Ensures mandatory fields are completed
- **Format Validation**: Email, phone, URL format checking
- **Range Validation**: Min/max values for numbers and dates
- **Custom Validation**: JavaScript expressions for complex rules
- **Cross-field Validation**: Dependencies between multiple fields

#### Template Lifecycle
```
Template Creation → Testing → Publishing → Versioning → Archiving
```

---

## Notification System

### Multi-Channel Notification Architecture

#### Notification Channels
1. **Firebase Cloud Messaging (FCM)**: System-wide push notifications
2. **Supabase Realtime**: In-app real-time updates
3. **Local Notifications**: Scheduled and triggered local alerts
4. **In-App Notifications**: UI-integrated notification system

#### Notification Types

**System Notifications**
- New task assignments
- Campaign status updates
- Evidence approval/rejection
- System maintenance alerts

**Task Notifications**
- Task deadline reminders
- Geofence entry/exit alerts
- Route start/completion notifications
- Evidence submission confirmations

**Real-time Updates**
- Live agent location updates
- Campaign progress updates
- Team member status changes
- Evidence submission notifications

#### Notification Data Flow
```
Event Trigger → Supabase Edge Function → FCM → Device → Local Display
                     ↓
              Realtime Channel → In-App Update
```

#### Notification Management Features
- **Channel Configuration**: User-controlled notification preferences
- **Delivery Optimization**: Intelligent timing and batching
- **Offline Handling**: Notification queuing for offline devices
- **Rich Notifications**: Images, actions, and deep links
- **Analytics**: Delivery and engagement tracking

### Notification Services

#### NotificationManager
- FCM token management
- Message delivery coordination
- Channel creation and management
- Background message handling

#### SimpleNotificationService
- Basic notification display
- Fallback notification system
- Local notification scheduling

#### BackgroundNotificationManager
- Background notification processing
- Notification queue management
- Service lifecycle coordination

---

## Multi-Language Support

### Internationalization Architecture

#### Supported Languages
1. **English (en)**: Primary language and fallback
2. **Arabic (ar)**: Right-to-left (RTL) support with cultural adaptations

#### Localization Structure
```
lib/l10n/
├── app_en.arb (English translations)
├── app_ar.arb (Arabic translations)
├── app_localizations.dart (Generated base class)
├── app_localizations_en.dart (English implementation)
└── app_localizations_ar.dart (Arabic implementation)
```

#### Language Management Service

**LanguageService**
- Language detection and selection
- Locale switching functionality
- Preference persistence
- RTL layout support

**Key Features:**
- **Automatic Detection**: Device language detection
- **Manual Override**: User language selection
- **Persistent Preferences**: Language selection storage
- **Dynamic Switching**: Runtime language changes
- **Fallback Support**: English fallback for missing translations

#### RTL Support Implementation
- **Layout Direction**: Automatic RTL layout for Arabic
- **Text Alignment**: Culture-appropriate text alignment
- **Icon Mirroring**: Directional icon adjustments
- **Date/Time Formatting**: Localized date and time display
- **Number Formatting**: Regional number format support

#### Translation Management
- **Placeholders**: Dynamic content insertion
- **Pluralization**: Proper plural form handling
- **Gender Support**: Gender-specific translations where needed
- **Context-aware Translations**: Situation-specific text

---

## Security & Authentication

### Authentication System

#### Supabase Authentication
- **Email/Password**: Primary authentication method
- **Session Management**: JWT token-based sessions
- **Password Reset**: Secure password recovery flow
- **Account Verification**: Email verification requirement

#### Session Security
- **Token Refresh**: Automatic token renewal
- **Session Timeout**: Configurable session expiration
- **Multi-device Support**: Session management across devices
- **Logout Security**: Secure session termination

### Authorization & Permissions

#### Row Level Security (RLS)
The database implements comprehensive RLS policies:

**Profile Security**
- Users access only their own profiles
- Managers access profiles in managed groups
- Admins have system-wide access

**Campaign Security**
- Role-based campaign access
- Client-specific campaign visibility
- Manager group-based restrictions

**Location Data Privacy**
- Personal location data protection
- Role-based location access
- Historical data retention policies

#### API Security
- **Request Authentication**: All API calls require valid JWT
- **Rate Limiting**: Protection against abuse
- **Input Validation**: Comprehensive input sanitization
- **SQL Injection Protection**: Parameterized queries
- **XSS Prevention**: Output encoding and validation

### Data Privacy & Compliance

#### Personal Data Protection
- **Data Minimization**: Collection of only necessary data
- **Purpose Limitation**: Data used only for stated purposes
- **Storage Limitation**: Automatic data retention policies
- **User Rights**: Data access, correction, and deletion rights

#### Location Privacy
- **Consent Management**: Explicit location tracking consent
- **Data Encryption**: Encrypted location data storage
- **Access Logging**: Location data access audit trails
- **Anonymization**: Location data anonymization for analytics

#### Evidence Security
- **Photo Encryption**: Encrypted image storage
- **Metadata Protection**: GPS metadata security
- **Access Control**: Role-based evidence access
- **Audit Trails**: Evidence access and modification logs

---

## Development Environment

### Development Setup

#### Prerequisites
- **Flutter SDK**: 3.x or higher
- **Dart SDK**: 2.19.0 or higher  
- **Android Studio/VS Code**: With Flutter extensions
- **Docker**: For local Supabase development
- **Git**: Version control

#### Local Development Commands

**Flutter Development**
```bash
flutter run              # Run on connected device
flutter build apk        # Build Android APK
flutter build ios        # Build iOS app
flutter test             # Run unit tests
flutter analyze          # Static code analysis
dart format .            # Code formatting
flutter clean            # Clean build cache
flutter pub get          # Install dependencies
```

**Supabase Development**
```bash
supabase start           # Start local Supabase
supabase stop            # Stop local Supabase
supabase db reset        # Reset local database
supabase gen types dart  # Generate Dart types
supabase db diff -f name # Create migration
```

#### Development Configuration

**Environment Files**
- Production: Supabase cloud instance
- Development: Local Supabase with Docker
- Testing: Isolated test database

**API Configuration**
```dart
// Production
url: 'https://jnuzpixgfskjcoqmgkxb.supabase.co'
anonKey: 'production_key'

// Development  
url: 'http://localhost:54321'
anonKey: 'local_development_key'
```

### Testing Strategy

#### Test Categories
1. **Unit Tests**: Individual function and class testing
2. **Widget Tests**: UI component testing
3. **Integration Tests**: End-to-end workflow testing
4. **Performance Tests**: Location service performance
5. **Security Tests**: Authentication and authorization

#### Test Structure
```
test/
├── basic_app_test.dart
├── models/
│   └── simple_campaign_test.dart
├── services/
├── screens/
├── test_helpers.dart
└── widget_test.dart
```

#### Testing Tools
- **flutter_test**: Flutter testing framework
- **mockito**: Mock object generation
- **integration_test**: End-to-end testing
- **build_runner**: Code generation for tests

### Code Quality & Standards

#### Code Analysis
- **flutter_lints**: Dart and Flutter linting rules
- **Custom Rules**: Project-specific linting
- **Analysis Options**: Configured in `analysis_options.yaml`

#### Development Rules
1. **No Breaking Changes**: Existing functionality preservation
2. **Universal Implementation**: All user roles supported
3. **Non-destructive Updates**: Additive feature development
4. **Comprehensive Testing**: All roles tested after changes

---

## API Integration

### Supabase Integration

#### Database Operations
- **CRUD Operations**: Create, Read, Update, Delete via Supabase client
- **Real-time Subscriptions**: Live data updates
- **RPC Functions**: Custom database functions
- **Batch Operations**: Efficient bulk data operations

#### Authentication API
```dart
// Sign in
await supabase.auth.signInWithPassword(
  email: email,
  password: password,
);

// Sign out
await supabase.auth.signOut();

// Get current user
final user = supabase.auth.currentUser;
```

#### Database Queries
```dart
// Select with filters
final response = await supabase
    .from('campaigns')
    .select()
    .eq('status', 'active')
    .order('created_at');

// Insert data
await supabase
    .from('tasks')
    .insert(taskData);

// Real-time subscription
supabase
    .from('active_agents')
    .stream(primaryKey: ['id'])
    .listen((data) {
      // Handle real-time updates
    });
```

#### Storage Operations
```dart
// Upload file
await supabase.storage
    .from('evidence')
    .upload(fileName, fileBytes);

// Download file
final response = await supabase.storage
    .from('evidence')
    .download(fileName);
```

### External API Integrations

#### Google Maps Integration
- **Map Display**: Interactive map components
- **Geocoding**: Address to coordinate conversion
- **Reverse Geocoding**: Coordinate to address conversion
- **Directions**: Navigation route calculation

#### Firebase Cloud Messaging
- **Push Notifications**: Cross-platform notification delivery
- **Topic Subscriptions**: Group-based notification targeting
- **Background Handling**: Notification processing when app closed

#### Device Hardware Integration
- **GPS/Location**: High-accuracy positioning
- **Camera**: Photo capture for evidence
- **File System**: Local data storage and caching
- **Network**: Connectivity status monitoring

---

## Testing Strategy

### Test Architecture

#### Test Levels
1. **Unit Tests**: Core business logic validation
2. **Widget Tests**: UI component behavior verification  
3. **Integration Tests**: End-to-end user workflow testing
4. **Performance Tests**: Location service and database performance
5. **Security Tests**: Authentication and data access validation

#### Test Categories by Component

**Model Tests**
- Data serialization/deserialization
- Validation rule enforcement
- Model relationship integrity

**Service Tests**
- Location service accuracy and reliability
- Notification delivery verification
- Database operation correctness
- API integration functionality

**Screen Tests**
- Role-based navigation verification
- Form validation and submission
- Error handling and user feedback
- Responsive design behavior

**Integration Tests**
- Complete user workflows
- Cross-service communication
- Real-time data synchronization
- Offline/online transition handling

#### Test Data Management
- **Mock Data**: Realistic test data generation
- **Test Fixtures**: Predefined test scenarios
- **Database Seeding**: Consistent test database states
- **User Simulation**: Role-based test user creation

### Continuous Integration

#### Automated Testing Pipeline
```yaml
# Example GitHub Actions workflow
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter build apk --debug
```

#### Test Coverage Requirements
- **Unit Tests**: >80% code coverage
- **Critical Paths**: 100% coverage for authentication and payments
- **Location Services**: Comprehensive GPS and geofencing testing
- **Cross-platform Testing**: Android and iOS validation

---

## Deployment Configuration

### Build Configuration

#### Android Configuration
```gradle
// build.gradle.kts
android {
    compileSdk = 34
    minSdk = 21
    targetSdk = 34
    
    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles("proguard-rules.pro")
            signingConfig = signingConfigs.getByName("release")
        }
    }
    
    signingConfigs {
        create("release") {
            keyAlias = "altijwal-release"
            keyPassword = System.getenv("KEY_PASSWORD")
            storeFile = file("altijwal-release.keystore")
            storePassword = System.getenv("STORE_PASSWORD")
        }
    }
}
```

#### iOS Configuration
```xml
<!-- Info.plist -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to verify task completion locations.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>  
<string>This app needs location access to track field agent activities.</string>
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to capture evidence photos.</string>
```

### Environment Management

#### Production Environment
- **Backend**: Supabase cloud production instance
- **Notifications**: Firebase Cloud Messaging production
- **Analytics**: Production analytics tracking
- **Error Reporting**: Crash reporting and monitoring

#### Staging Environment
- **Backend**: Supabase staging instance
- **Testing**: QA testing environment
- **Feature Flags**: Beta feature testing
- **Performance Monitoring**: Load testing environment

#### Development Environment
- **Backend**: Local Supabase Docker instance
- **Hot Reload**: Development productivity features
- **Debug Tools**: Flutter DevTools integration
- **Mock Services**: Service mocking for offline development

### Release Management

#### Version Management
- **Semantic Versioning**: MAJOR.MINOR.PATCH format
- **Build Numbers**: Incremental build identification
- **Release Notes**: Automated changelog generation
- **Feature Flags**: Gradual feature rollout

#### Deployment Pipeline
```
Code Commit → Automated Tests → Build Generation → QA Testing → Production Release
```

#### Release Channels
- **Internal Testing**: Developer builds
- **Alpha Testing**: Limited internal testing
- **Beta Testing**: External user testing
- **Production Release**: General availability

---

## Performance Optimization

### Location Service Optimization

#### Battery Optimization Strategies
- **Adaptive Sampling**: Dynamic location update frequency
- **Geofence-based Triggering**: Reduced background tracking
- **Power-aware Modes**: Battery level-based tracking adjustment
- **Smart Positioning**: WiFi/cellular fallback when GPS unavailable

#### Location Accuracy Optimization
- **Multi-source Fusion**: GPS + Network + Passive location
- **Kalman Filtering**: Location data smoothing and prediction
- **Accuracy Validation**: Minimum accuracy requirements
- **Historical Analysis**: Movement pattern learning

### Database Performance

#### Query Optimization
- **Indexed Queries**: Optimized database indexes
- **Query Batching**: Bulk operations for efficiency
- **Connection Pooling**: Database connection optimization
- **Caching Strategy**: Intelligent data caching

#### Real-time Performance
- **Selective Subscriptions**: Targeted real-time updates
- **Data Filtering**: Server-side data filtering
- **Update Batching**: Grouped real-time updates
- **Connection Management**: Efficient WebSocket handling

### Mobile App Performance

#### Memory Management
- **Image Optimization**: Automatic image compression
- **Cache Management**: Intelligent cache cleanup
- **Memory Leak Prevention**: Proper stream and controller disposal
- **Background Process Management**: Service lifecycle optimization

#### UI Performance
- **Lazy Loading**: On-demand screen and data loading
- **Image Caching**: Efficient image caching and loading
- **Animation Optimization**: Smooth 60fps animations
- **State Management**: Efficient state update patterns

---

## Conclusion

AL-Tijwal represents a comprehensive, enterprise-grade mobile application for location-based task management and field operations. With its sophisticated architecture, robust security model, and user-centric design, the application serves as a complete solution for organizations requiring precise field operation coordination, evidence collection, and real-time monitoring capabilities.

The application's modular architecture, extensive feature set, and cross-platform compatibility make it suitable for various industries including market research, field services, compliance monitoring, and logistics operations. Its emphasis on location accuracy, data security, and user experience positions it as a leader in the field operation management space.

This documentation serves as a comprehensive reference for developers, system administrators, and stakeholders involved in the AL-Tijwal ecosystem, providing detailed insights into every aspect of the application's architecture, functionality, and operational characteristics.