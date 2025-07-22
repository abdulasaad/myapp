# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️ CRITICAL DEVELOPMENT RULES - READ FIRST
**BEFORE ANY CHANGES: Always read and follow DEVELOPMENT_RULES.md**

Key principles:
1. **NO BREAKING CHANGES** - Existing functions must continue working
2. **UNIVERSAL IMPLEMENTATION** - New features work for ALL user roles (Admin, Manager, Agent, Client)
3. **NON-DESTRUCTIVE** - Add features without modifying core existing logic
4. **COMPREHENSIVE TESTING** - Test all user roles after changes

## Development Commands

### Flutter Development
- **Build**: `flutter build apk` (Android) or `flutter build ios` (iOS)
- **Run**: `flutter run` (with device connected)
- **Hot reload**: `r` while `flutter run` is active
- **Test**: `flutter test`
- **Analyze**: `flutter analyze`
- **Format**: `dart format .`
- **Clean**: `flutter clean` then `flutter pub get`

### Dependencies
- **Install**: `flutter pub get`
- **Upgrade**: `flutter pub upgrade`

### Supabase Development
- **Start local**: `supabase start` (requires Docker)
- **Stop local**: `supabase stop`
- **Database reset**: `supabase db reset`
- **Generate types**: `supabase gen types dart --local > lib/database.dart`
- **Migration**: `supabase db diff -f new_migration_name`

## Project Architecture

### Core Structure
This is a Flutter mobile application called **Al-Tijwal** - a location-based task management platform with campaign and evidence submission capabilities. The app serves two primary user roles:

1. **Admins/Managers**: Create and manage campaigns, tasks, and user groups
2. **Agents**: Complete location-based tasks and submit evidence

### Key Components

#### Authentication & Backend
- **Supabase**: Backend-as-a-Service for authentication, database, and storage
- **Global client**: Accessible via `supabase` constant in `lib/utils/constants.dart`
- **Database**: PostgreSQL with Row Level Security (RLS) policies
- **User management**: Role-based access (admin, manager, agent) with group assignments

#### Data Models (`lib/models/`)
- **AppUser**: User profiles with roles and group assignments
- **Campaign**: Location-based campaigns containing multiple tasks
- **Task**: Individual work items with geofences and evidence requirements
- **Group**: User organization for managers and agents
- **ActiveAgent**: Real-time agent tracking
- **TaskAssignment**: Links between agents and tasks

#### Screen Architecture (`lib/screens/`)
The app follows a role-based navigation pattern:

**Shared Screens:**
- Authentication flow: `SplashScreen` → `LoginScreen`/`SignupScreen` → `HomeScreen`
- `FullScreenImageViewer`: Evidence photo viewing

**Admin/Manager Flow:**
- Campaign management: `CampaignsListScreen` → `CampaignDetailScreen`
- Task creation: `CreateEvidenceTaskScreen` with geofence support
- User management: `GroupManagementScreen`
- Analytics: `CampaignReportScreen`
- Live tracking: `LiveMapScreen`

**Agent Flow:**
- Task discovery: `AgentCampaignViewScreen` → `AgentTaskListScreen`
- Task execution: `TaskLocationViewerScreen` → `EvidenceSubmissionScreen`
- Tools: `CalibrationScreen` (GPS), `EarningsScreen`

#### Services (`lib/services/`)
- **LocationService**: GPS tracking and geofence validation
- **ProfileService**: User profile management

#### Key Features
- **Geofencing**: Campaign and task-level location boundaries
- **Evidence Collection**: Photo capture with metadata
- **Real-time Tracking**: Agent location monitoring for admins
- **Role-based Permissions**: Database-level access control
- **Group Management**: Hierarchical user organization

### Database Schema
- **profiles**: Extended user information with roles and group assignments
- **groups**: User organization with manager assignments
- **user_groups**: Many-to-many user-group relationships
- **campaigns**: Location-based work campaigns
- **tasks**: Individual work items with evidence requirements

### Important Patterns
- All screens extend `StatefulWidget` for state management
- Navigation uses `Navigator.push/pop` with MaterialPageRoute
- Error handling via `ScaffoldMessengerHelper` extension in constants
- Consistent theming with dark mode and teal primary color
- Location permissions handled in `LocationService`
- Image handling via `image_picker` package with proper permissions

# important-instruction-reminders
**CRITICAL: Always follow DEVELOPMENT_RULES.md - No breaking changes, universal implementation for all user roles**
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.

      
      IMPORTANT: this context may or may not be relevant to your tasks. You should not respond to this context or otherwise consider it in your response unless it is highly relevant to your task. Most of the time, it is not relevant.