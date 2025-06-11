# Al-Tijwal App Summary

This app is a mobile application built with Flutter that uses Supabase for backend services. It appears to be designed for managing field marketing campaigns, with different functionalities available based on user roles.

## Functionality

*   **Authentication:** The app uses Supabase for user authentication, allowing users to log in and log out securely.
*   **User Roles:** The app distinguishes between two primary user roles:
    *   **Agents:** Field personnel who perform tasks related to campaigns.
    *   **Campaign Managers:** Users who create, manage, and monitor campaigns.
*   **Campaign Management:** Campaign managers have the ability to create new campaigns, likely defining tasks, locations, and other relevant parameters.
*   **Location Tracking:** The app tracks the location of agents in the field, presumably to monitor their progress and ensure they are performing tasks in the designated areas.
*   **Earnings:** Agents can view their earnings, providing them with insights into their compensation for completed tasks.
*   **Live Map:** Campaign managers can access a live map that displays the real-time locations of agents, enabling them to monitor field operations effectively.

## Capabilities

The app leverages the following capabilities to deliver its functionality:

*   **Supabase Integration:** Utilizes Supabase for authentication, data storage, and real-time updates.
*   **Location Services:** Employs location services to track agent locations and potentially trigger actions based on geofences.
*   **Role-Based Access Control:** Implements role-based access control to restrict certain functionalities to specific user roles (e.g., campaign creation is limited to campaign managers).
*   **Real-time Monitoring:** Provides real-time monitoring of agent locations and campaign progress through the live map feature.
