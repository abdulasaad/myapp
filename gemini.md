
# Al-Tijwal - Location-Based Task Management Platform

## Project Overview

Al-Tijwal is a comprehensive, location-based task management platform designed for businesses with mobile workforces. The platform consists of a Flutter-based mobile application for agents, managers, and admins, and a powerful backend powered by Supabase. It enables organizations to create and manage location-based tasks, track agent locations in real-time, and collect evidence of task completion.

The application is designed with a hierarchical user structure:

*   **Admins:** Have full control over the system, including user management, group management, and access to all data.
*   **Managers:** Can manage specific groups of agents, create and assign tasks, and review evidence submitted by their team.
*   **Agents:** Can view and complete assigned tasks, submit evidence, and track their progress.

## Key Features

### 1. User Management and Authentication

*   **Role-Based Access Control (RBAC):** The application enforces a strict RBAC system with three roles: `admin`, `manager`, and `agent`. Each role has a distinct set of permissions and a tailored user interface.
*   **Authentication:** User authentication is handled by Supabase Auth, with support for email/password and username/password login.
*   **Session Management:** The application prevents multiple simultaneous logins from the same account, enhancing security.
*   **Group Management:** Admins can create and manage groups, assigning managers and agents to specific teams. This allows for logical separation of the workforce.

### 2. Task and Campaign Management

*   **Campaigns:** Managers and admins can create campaigns, which are collections of tasks with a specific goal and timeframe.
*   **Tasks:** Tasks are the core of the application. They can be created individually or as part of a campaign. Tasks can have the following attributes:
    *   Title and description
    *   Points awarded for completion
    *   Geofence restrictions
    *   Evidence requirements (number of photos, etc.)
    *   Start and end dates
*   **Task Templates:** Admins can create task templates to standardize common tasks.
*   **Dynamic Forms:** Managers can create tasks with dynamic forms, allowing for flexible data collection from agents. This feature supports various field types, including text, numbers, dropdowns, and more.

### 3. Location Services and Geofencing

*   **Real-time Location Tracking:** The application tracks the real-time location of agents, which is visible to managers and admins on a live map.
*   **Geofencing:** Geofences can be defined for campaigns and tasks. The application can enforce that agents are within a specific geofence to complete a task.
*   **Location History:** The application stores the location history of agents, which can be reviewed by managers and admins.

### 4. Evidence Management

*   **Evidence Submission:** Agents can submit various forms of evidence for task completion, including photos, videos, and documents.
*   **Evidence Metadata:** The application automatically captures metadata for each piece of evidence, including location, timestamp, and accuracy.
*   **Evidence Review:** Managers can review and approve or reject evidence submitted by agents.
*   **Standalone Evidence:** Agents can submit evidence that is not associated with a specific task.

### 5. Route Management

*   **Route Creation:** Managers can create routes, which are sequences of places for agents to visit.
*   **Route Assignment:** Routes can be assigned to specific agents.
*   **Visit Tracking:** The application tracks agent visits to each place on a route, including check-in and check-out times.
*   **Route Progress:** Managers can monitor the progress of agents on their assigned routes.

### 6. Reporting and Analytics

*   **Admin Dashboard:** The admin dashboard provides a high-level overview of the system, including statistics on users, tasks, and campaigns.
*   **Manager Dashboard:** The manager dashboard provides insights into the performance of their team, including task completion rates, evidence submission statistics, and agent activity.
*   **Agent Dashboard:** The agent dashboard allows agents to track their own progress, including completed tasks, earned points, and recent activity.

### 7. Offline Support

*   **Connectivity Service:** The application includes a connectivity service that monitors the device's internet connection.
*   **Offline UI:** The application provides a clear offline indicator to the user when there is no internet connection.
*   **Offline Data Queuing:** The application queues location data and other information when the device is offline and syncs it with the server when the connection is restored.

### 8. Mandatory App Updates

*   **Version Management:** The application includes a system for managing app versions and enforcing mandatory updates.
*   **In-App Updates:** The application can download and install updates automatically, ensuring that all users are on the latest version.

## Technical Architecture

### Frontend (Flutter)

*   **State Management:** The application uses a combination of `StatefulWidget` and `FutureBuilder` for managing state.
*   **Dependencies:** The application uses a number of popular Flutter packages, including:
    *   `supabase_flutter` for interacting with the Supabase backend.
    *   `geolocator` and `google_maps_flutter` for location services.
    *   `image_picker` and `file_picker` for handling file uploads.
    *   `logger` for logging.
*   **Project Structure:** The project is well-structured, with code organized into `screens`, `services`, `models`, and `widgets` directories.

### Backend (Supabase)

*   **Database:** The application uses a PostgreSQL database with Row Level Security (RLS) enabled.
*   **API:** The application uses the Supabase auto-generated REST API for all database operations.
*   **Authentication:** User authentication is handled by Supabase Auth.
*   **Storage:** File uploads are handled by Supabase Storage.
*   **Database Schema:** The database schema is well-designed and includes tables for users, groups, campaigns, tasks, evidence, and more. The schema is documented in the `supabase.md` file.

## Conclusion

Al-Tijwal is a powerful and flexible platform for managing mobile workforces. It provides a comprehensive set of features for creating and managing location-based tasks, tracking agent locations, and collecting evidence of task completion. The application is well-architected and uses modern technologies, making it a robust and scalable solution.
