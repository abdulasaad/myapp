# Route Management System - Al-Tijwal

## Overview

The Route Management System in Al-Tijwal is a comprehensive location-based task management platform that allows managers to create routes with multiple places and assign them to agents for completion. The system tracks real-time progress, manages check-ins/check-outs, and provides detailed analytics.

## Route Lifecycle

### Route Statuses
- **`draft`** - Route is being created/edited, not yet available to agents
- **`active`** - Route is live and can be assigned to agents
- **`completed`** - All assigned agents have completed their route assignments
- **`archived`** - Route is archived for historical purposes, no longer active

### Route Assignment Statuses
- **`assigned`** - Route has been assigned to an agent but not started
- **`in_progress`** - Agent has started working on the route (first check-in completed)
- **`completed`** - Agent has completed all places in the route
- **`cancelled`** - Assignment was cancelled by manager

### Place Visit Statuses
- **`pending`** - Place visit has not started yet
- **`checked_in`** - Agent has checked into the place
- **`completed`** - Agent has checked out and completed the place visit
- **`skipped`** - Place visit was skipped (if allowed)

## Status Flow Diagram

```
Route Creation:
draft → [manager activates] → active → [all agents complete] → completed → [manager archives] → archived

Route Assignment:
assigned → [first check-in] → in_progress → [all places completed] → completed

Place Visit:
pending → [agent checks in] → checked_in → [agent checks out] → completed
```

## Manager Features

### ✅ Implemented Features

#### Route Management
- **Create Routes**: Define route name, description, estimated duration, and schedule
- **Add Places to Routes**: Select from approved places and set visit order
- **Configure Place Details**: Set estimated duration, required evidence count, and special instructions
- **Reorder Places**: Drag-and-drop interface for place ordering
- **Activate Routes**: Change status from draft to active
- **Delete Routes**: 
  - Smart deletion with usage checking
  - Archive routes with historical data instead of deletion
  - Permanent deletion for unused routes
- **Route Status Management**: View and manage route statuses

#### Place Management
- **Approve/Reject Agent Suggestions**: Review places suggested by agents
- **Create Places**: Add new places with map-based location picker
- **Geofence Configuration**: Set location boundaries (10-500m radius)
- **Place Status Management**: Active/inactive place management
- **Smart Place Deletion**: 
  - Usage detection (routes, historical visits)
  - Deactivation option for places with historical data
  - Comprehensive usage reports before deletion

#### Route Assignment
- **Assign to Agents**: Select multiple agents from manager's groups
- **Agent Selection**: View agents by name from managed groups
- **Assignment Tracking**: Monitor assignment status and progress

#### Analytics & Monitoring
- **Route Visit Analytics**: Comprehensive analytics with three tabs:
  - Overview: Summary statistics and metrics
  - Recent Visits: Latest check-in/check-out activities
  - Active Routes: Currently running routes
- **Real-time Progress**: Track route completion percentages
- **Visit History**: Detailed check-in/check-out logs with duration tracking
- **Route Details**: Complete route information with place lists and statistics

#### Place Location Management
- **Map-based Location Picker**: Google Maps integration for precise place positioning
- **Geofence Visualization**: Visual radius selection and preview
- **Coordinate Display**: Precise latitude/longitude coordinates
- **Address Support**: Optional address field for places

### ❌ Not Implemented Features

#### Route Management
- **Edit Routes**: Route editing functionality was removed (delete and recreate instead)
- **Route Templates**: Pre-defined route templates for common patterns
- **Bulk Route Operations**: Mass route management actions
- **Route Scheduling**: Advanced scheduling with recurring routes
- **Route Categories**: Categorization and tagging system

#### Advanced Assignment Features
- **Assignment Rules**: Automatic assignment based on agent skills/location
- **Load Balancing**: Distribute routes evenly among agents
- **Agent Availability**: Check agent calendar/availability before assignment
- **Assignment Notifications**: Push notifications for new assignments

#### Analytics Enhancements
- **Performance Metrics**: Agent performance comparison and KPIs
- **Route Optimization**: Suggest optimal route order based on traffic/distance
- **Predictive Analytics**: Estimated completion times based on historical data
- **Export Functionality**: Export analytics data to CSV/PDF
- **Custom Reports**: Configurable reporting with date ranges and filters

#### Integration Features
- **External Calendar Sync**: Integrate with Google Calendar/Outlook
- **GPS Tracking**: Real-time agent location tracking during routes
- **Weather Integration**: Weather-based route recommendations
- **Traffic Integration**: Real-time traffic updates for route optimization

## Agent Features

### ✅ Implemented Features

#### Route Discovery
- **My Routes Dashboard**: View all assigned routes with status indicators
- **Route Details**: Complete route information with place list
- **Progress Tracking**: Visual progress bars and completion percentages
- **Next Place Indicator**: Automatic detection of next place to visit

#### Check-in/Check-out System
- **Place Check-in**: Start visit at a location
- **Place Check-out**: Complete visit and submit evidence
- **Active Visit Management**: One active visit at a time enforcement
- **Visit Duration Tracking**: Automatic time tracking for visits
- **Real-time Status Updates**: Immediate status synchronization

#### Route Progress
- **Automatic Route Start**: Route assignment marked as "in_progress" on first check-in
- **Automatic Route Completion**: Route assignment completed when all places are visited
- **Completion Celebrations**: Success messages and notifications
- **Progress Visualization**: Clear indicators of completed vs pending places

#### Evidence Submission
- **Photo Evidence**: Camera integration for evidence capture
- **Evidence Requirements**: Configurable evidence count per place
- **Visit Instructions**: Display special instructions for each place

### ❌ Not Implemented Features

#### Navigation & Location
- **GPS Navigation**: Turn-by-turn directions to places
- **Geofence Validation**: Enforce location-based check-ins
- **Offline Maps**: Cached maps for offline operation
- **Location Accuracy**: Precise GPS validation before check-in

#### Enhanced Check-in Experience
- **QR Code Check-in**: Quick check-in using QR codes at locations
- **Voice Notes**: Audio evidence and notes
- **Signature Capture**: Digital signatures for verification
- **Barcode Scanning**: Product/asset identification at places

#### Productivity Features
- **Route Optimization**: Suggest optimal place visit order
- **Time Estimates**: Dynamic time estimates based on traffic
- **Break Management**: Schedule and track breaks during routes
- **Multiple Route Handling**: Work on multiple routes simultaneously

#### Communication
- **Manager Chat**: Direct communication with route managers
- **Issue Reporting**: Report problems or obstacles at places
- **Help System**: In-app help and guidance
- **Emergency Features**: Emergency contact and alerts

#### Offline Capabilities
- **Offline Route Storage**: Download routes for offline use
- **Offline Check-ins**: Queue check-ins when connectivity is poor
- **Data Synchronization**: Automatic sync when connection is restored

## Database Schema

### Core Tables

#### `routes`
- Route definitions with status, dates, and metadata
- Links to creators and assigned managers

#### `route_places`
- Junction table linking routes to places
- Contains visit order, duration estimates, and instructions

#### `route_assignments`
- Links agents to routes with assignment tracking
- Contains status, timestamps, and completion data

#### `place_visits`
- Individual place visit records
- Check-in/check-out times, evidence, and visit status

#### `places`
- Location definitions with coordinates and geofence data
- Approval status and creation metadata

### Key Relationships
```
routes (1) → (many) route_places → (1) places
routes (1) → (many) route_assignments → (1) profiles (agents)
route_assignments (1) → (many) place_visits
```

## Technical Implementation

### Frontend (Flutter)
- **Manager Screens**: Route management, analytics, place management
- **Agent Screens**: Route dashboard, check-in/check-out interfaces
- **Shared Components**: Maps integration, image handling, form widgets

### Backend (Supabase)
- **PostgreSQL Database**: Relational data with foreign key constraints
- **Row Level Security (RLS)**: Role-based access control
- **Real-time Subscriptions**: Live data updates
- **File Storage**: Evidence photos and documents

### Key Features
- **Automatic Status Management**: Smart status transitions
- **Data Integrity**: Comprehensive constraint checking
- **Audit Trails**: Complete history preservation
- **Real-time Updates**: Live progress tracking

## Security & Permissions

### Role-based Access
- **Admins**: Full system access
- **Managers**: Group-specific route and agent management
- **Agents**: Personal route and visit management

### Data Protection
- **Group Isolation**: Managers only see their group's data
- **Agent Privacy**: Personal visit data protection
- **Audit Logging**: Complete activity tracking
- **Secure Evidence**: Encrypted photo storage

## Performance Considerations

### Implemented Optimizations
- **Lazy Loading**: Progressive data loading
- **Caching**: Local data caching for performance
- **Pagination**: Large dataset handling
- **Image Compression**: Optimized evidence photos

### Scalability Features
- **Database Indexing**: Optimized query performance
- **Connection Pooling**: Efficient database connections
- **File CDN**: Distributed evidence storage
- **Real-time Efficiency**: Optimized live updates

## Future Roadmap

### Short-term Enhancements
1. **GPS Geofence Validation**: Enforce location-based check-ins
2. **Enhanced Analytics**: Performance metrics and KPIs
3. **Route Optimization**: AI-powered route planning
4. **Mobile Notifications**: Push notifications for assignments

### Medium-term Features
1. **Offline Capability**: Full offline route execution
2. **Advanced Reporting**: Custom reports and dashboards
3. **Integration APIs**: Third-party system integration
4. **Mobile App Improvements**: Enhanced UI/UX

### Long-term Vision
1. **AI Route Planning**: Machine learning optimization
2. **IoT Integration**: Smart device connectivity
3. **Predictive Analytics**: Forecasting and planning
4. **Enterprise Features**: Multi-tenant architecture

---

## Getting Started

### For Managers
1. Create places using the map-based location picker
2. Build routes by adding approved places
3. Assign routes to agents in your groups
4. Monitor progress through the analytics dashboard

### For Agents
1. Check your route assignments in "My Routes"
2. Start routes by checking into the first place
3. Complete visits by checking out and submitting evidence
4. Track your progress and celebrate completions!

---

*Last Updated: July 2025*
*Version: 1.0*