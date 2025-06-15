# App Screen and Navigation Flow Description

## App Overview:

The application appears to be a platform for managing and executing location-based tasks, likely involving "Campaigns" composed of multiple "Tasks." It seems to cater to at least two primary user roles: "Admins" (or managers) who create and oversee campaigns/tasks, and "Agents" who perform these tasks and submit evidence.

## I. Core Authentication & General Screens:

1.  **`SplashScreen` (`lib/screens/splash_screen.dart`)**
    *   **Description:** This is the very first screen the user sees upon launching the app. Its primary role is to handle initial setup, check for existing login sessions, or display branding.
    *   **UI Elements:** Typically a logo or app name, possibly a loading indicator.
    *   **Navigation:**
        *   If a valid user session is found -> `HomeScreen`.
        *   If no user session or session expired -> `LoginScreen`.

2.  **`LoginScreen` (`lib/screens/login_screen.dart`)**
    *   **Description:** Allows existing users to sign into their accounts.
    *   **UI Elements:**
        *   App Logo/Title
        *   Email/Username input field
        *   Password input field (with show/hide password option)
        *   "Login" button
        *   "Forgot Password?" link (optional, leading to a password reset flow)
        *   "Don't have an account? Sign Up" link.
    *   **Navigation:**
        *   On successful login -> `HomeScreen`.
        *   On "Sign Up" link tap -> `SignupScreen`.

3.  **`SignupScreen` (`lib/screens/signup_screen.dart`)**
    *   **Description:** Enables new users to register for an account.
    *   **UI Elements:**
        *   App Logo/Title
        *   Full Name input field
        *   Email input field
        *   Password input field
        *   Confirm Password input field
        *   "Sign Up" button
        *   "Already have an account? Log In" link.
    *   **Navigation:**
        *   On successful registration (and possibly auto-login) -> `HomeScreen`.
        *   On "Log In" link tap -> `LoginScreen`.

4.  **`HomeScreen` (`lib/screens/home_screen.dart`)**
    *   **Description:** The central hub or dashboard after a user logs in. The content and navigation options on this screen will likely vary significantly based on the user's role (Admin vs. Agent). It might use a BottomNavigationBar or a Drawer for primary navigation sections.
    *   **UI Elements (General):**
        *   AppBar with App Title/Logo.
        *   Profile icon/menu leading to user settings, logout.
    *   **Navigation (Role-Dependent):**
        *   **Admin View:** Tabs/sections for Campaigns, Tasks, User Management, Reporting, Live Map.
        *   **Agent View:** Tabs/sections for My Tasks/Campaigns, Earnings, GPS Calibration.

5.  **`FullScreenImageViewer` (`lib/screens/full_screen_image_viewer.dart` and `lib/screens/agent/full_screen_image_viewer.dart`)**
    *   **Description:** A utility screen used to display an image in full-screen mode. This could be used for viewing evidence photos, profile pictures, etc. The agent-specific version might have slight variations if needed.
    *   **UI Elements:** The image itself, pinch-to-zoom, pan, a "Close" or "Back" button.
    *   **Navigation:** Returns to the screen from which it was opened.

## II. Admin User Flow & Screens:

Admins are responsible for creating, managing, and monitoring campaigns, tasks, and users.

1.  **`UserManagementScreen` (`lib/screens/admin/user_management_screen.dart`)**
    *   **Accessed From:** `HomeScreen` (Admin view).
    *   **Description:** Allows admins to view, add, edit, and manage user accounts, particularly agent accounts.
    *   **UI Elements:**
        *   List of users (displaying name, email, role, status).
        *   Search/filter bar for users.
        *   "Add New User" button.
        *   Actions per user (e.g., Edit, Deactivate/Activate, View Details).
    *   **Navigation:**
        *   Tapping "Add New User" or "Edit" on a user would likely open a form/dialog for user details.

2.  **Campaign Management (Admin):**
    *   **`CampaignsListScreen` (`lib/screens/campaigns/campaigns_list_screen.dart`)**
        *   **Accessed From:** `HomeScreen` (Admin view, "Campaigns" tab).
        *   **Description:** Displays a list of all created campaigns.
        *   **UI Elements:**
            *   List of campaigns (e.g., cards showing campaign title, status, date range, brief summary).
            *   "Create New Campaign" button.
            *   Filters (e.g., by status: Active, Upcoming, Completed).
            *   Search bar for campaigns.
        *   **Navigation:**
            *   Tapping a campaign -> `CampaignDetailScreen`.
            *   Tapping "Create New Campaign" -> `CreateCampaignScreen`.
    *   **`CreateCampaignScreen` (`lib/screens/campaigns/create_campaign_screen.dart`)**
        *   **Accessed From:** `CampaignsListScreen`.
        *   **Description:** A form for admins to define and create a new campaign.
        *   **UI Elements:**
            *   Campaign Title input.
            *   Campaign Description textarea.
            *   Start Date & End Date pickers.
            *   Budget input (optional).
            *   Option to define a geofence (possibly navigating to `GeofenceEditorScreen`).
            *   Assign agents/groups (optional).
            *   "Save Campaign" / "Create Campaign" button.
        *   **Navigation:**
            *   On save -> `CampaignDetailScreen` for the new campaign.
            *   To `GeofenceEditorScreen` if geofence needs to be drawn.
    *   **`CampaignDetailScreen` (`lib/screens/campaigns/campaign_detail_screen.dart`)**
        *   **Accessed From:** `CampaignsListScreen` or after creating a campaign.
        *   **Description:** Shows comprehensive details of a specific campaign, including its associated tasks, progress, and management options.
        *   **UI Elements:**
            *   Campaign Title, Description, Dates, Status.
            *   Key metrics (e.g., completion %, active agents).
            *   "Edit Campaign" button.
            *   List of tasks within this campaign (task title, status).
            *   "Add Task to Campaign" button.
            *   View/Manage assigned agents.
            *   View campaign geofence on a map (if applicable).
        *   **Navigation:**
            *   "Edit Campaign" -> `CreateCampaignScreen` (pre-filled for editing).
            *   Tapping a task -> `StandaloneTaskDetailScreen` (Admin view of the task).
            *   "Add Task to Campaign" -> `CreateEvidenceTaskScreen` (with campaign context).
    *   **`GeofenceEditorScreen` (Campaign context) (`lib/screens/campaigns/geofence_editor_screen.dart`)**
        *   **Accessed From:** `CreateCampaignScreen` or `CampaignDetailScreen` (Edit mode).
        *   **Description:** An interactive map interface for admins to draw and define a polygonal or circular geofence for a campaign.
        *   **UI Elements:**
            *   Map view.
            *   Drawing tools (polygon, circle, edit points, delete).
            *   Search for a base location on the map.
            *   "Save Geofence" / "Confirm" button.
        *   **Navigation:** Returns to the calling screen (`CreateCampaignScreen` or `CampaignDetailScreen`) with the defined geofence data.

3.  **Task Management (Admin):**
    *   **`CreateEvidenceTaskScreen` (`lib/screens/tasks/create_evidence_task_screen.dart`)**
        *   **Accessed From:** `CampaignDetailScreen` ("Add Task") or `StandaloneTasksScreen` ("Create Task").
        *   **Description:** Form for admins to create new tasks, specifically those requiring evidence submission.
        *   **UI Elements:**
            *   Task Title input.
            *   Task Description/Instructions textarea.
            *   Location input (address search or pin on map).
            *   Option to define a task-specific geofence (possibly navigating to `TaskGeofenceEditorScreen`).
            *   Points/Reward value input.
            *   Due Date/Time picker (optional).
            *   Evidence requirements (e.g., number of photos, notes required).
            *   "Save Task" / "Create Task" button.
        *   **Navigation:**
            *   On save -> `StandaloneTaskDetailScreen` for the new task or back to the list it was created from.
            *   To `TaskGeofenceEditorScreen` if a task-specific geofence is needed.
    *   **`StandaloneTasksScreen` (`lib/screens/tasks/standalone_tasks_screen.dart`)**
        *   **Accessed From:** `HomeScreen` (Admin view, "Tasks" tab, if tasks can exist outside campaigns).
        *   **Description:** Lists tasks that are not necessarily part of a campaign.
        *   **UI Elements:** Similar to `CampaignsListScreen` but for tasks (list of tasks, "Create New Task" button, filters, search).
        *   **Navigation:**
            *   Tapping a task -> `StandaloneTaskDetailScreen`.
            *   "Create New Task" -> `CreateEvidenceTaskScreen`.
    *   **`StandaloneTaskDetailScreen` (Admin View) (`lib/screens/tasks/standalone_task_detail_screen.dart`)**
        *   **Accessed From:** `StandaloneTasksScreen`, `CampaignDetailScreen` (task list).
        *   **Description:** Shows details of a specific task from an admin's perspective.
        *   **UI Elements:**
            *   Task Title, Description, Location, Status, Due Date, Reward.
            *   "Edit Task" button.
            *   List/details of agents assigned or who have completed it.
            *   View submitted evidence (possibly navigating to `FullScreenImageViewer`).
            *   Task geofence on a map (if applicable).
        *   **Navigation:**
            *   "Edit Task" -> `CreateEvidenceTaskScreen` (pre-filled).
            *   Viewing evidence might use `FullScreenImageViewer`.
    *   **`TaskGeofenceEditorScreen` (`lib/screens/tasks/task_geofence_editor_screen.dart`)**
        *   **Accessed From:** `CreateEvidenceTaskScreen` or `StandaloneTaskDetailScreen` (Edit mode).
        *   **Description:** Similar to the campaign geofence editor, but for defining a geofence for an individual task.
        *   **UI Elements & Navigation:** Same as `campaigns/GeofenceEditorScreen`.

4.  **Reporting (Admin):**
    *   **`CampaignReportScreen` (`lib/screens/reporting/campaign_report_screen.dart`)**
        *   **Accessed From:** `HomeScreen` (Admin view, "Reporting" tab) or potentially from `CampaignDetailScreen`.
        *   **Description:** Displays analytics and reports related to campaign performance, agent activity, etc.
        *   **UI Elements:**
            *   Filters (select campaign, date range, agent).
            *   Charts and graphs (e.g., task completion rates, budget tracking, agent leaderboards).
            *   Data tables.
            *   "Export Report" button (e.g., as CSV, PDF).
        *   **Navigation:** Primarily for viewing; navigation would be back or to other reporting sub-sections if they exist.

5.  **Live Map (Admin):**
    *   **`LiveMapScreen` (`lib/screens/map/live_map_screen.dart`)**
        *   **Accessed From:** `HomeScreen` (Admin view).
        *   **Description:** Provides a real-time map view, potentially showing active agent locations, ongoing task locations, or heatmaps of activity.
        *   **UI Elements:**
            *   Interactive map.
            *   Markers for agents/tasks.
            *   Filters to toggle layers (agents, tasks, geofences).
            *   Information pop-ups on tapping markers.
        *   **Navigation:** Back to `HomeScreen`.

## III. Agent User Flow & Screens:

Agents are focused on finding, understanding, and completing assigned tasks.

1.  **`AgentCampaignViewScreen` (`lib/screens/agent/agent_campaign_view_screen.dart`)**
    *   **Accessed From:** `HomeScreen` (Agent view, "Campaigns" or "Available Work" tab).
    *   **Description:** Shows agents a list of campaigns they are part of or can opt into.
    *   **UI Elements:**
        *   List of campaigns (cards with title, brief description, reward potential, possibly a progress bar if started).
        *   Filters (e.g., "New", "In Progress", "Completed").
    *   **Navigation:**
        *   Tapping a campaign -> `AgentTaskListScreen` (filtered for that campaign) or a campaign detail view for agents.

2.  **`AgentTaskListScreen` (`lib/screens/agent/agent_task_list_screen.dart`)**
    *   **Accessed From:** `HomeScreen` (Agent view, "My Tasks" tab) or `AgentCampaignViewScreen`.
    *   **Description:** Displays a list of tasks assigned to the agent, possibly grouped by campaign.
    *   **UI Elements:**
        *   List of tasks (cards with title, location hint, status - e.g., "To Do", "In Progress", "Submitted", "Approved", reward).
        *   Filters (by status, campaign).
        *   Sort options (by due date, distance).
    *   **Navigation:**
        *   Tapping a task -> `StandaloneTaskDetailScreen` (Agent view).

3.  **`StandaloneTaskDetailScreen` (Agent View) (`lib/screens/tasks/standalone_task_detail_screen.dart`)**
    *   **Accessed From:** `AgentTaskListScreen`.
    *   **Description:** Provides the agent with all necessary information to complete a task.
    *   **UI Elements:**
        *   Task Title, Full Description/Instructions.
        *   Map preview of task location (possibly static).
        *   "View Location on Map" button.
        *   "Start Task" / "Accept Task" button (if applicable).
        *   "Submit Evidence" button (enabled when appropriate).
        *   Reward amount, Due Date.
        *   Status of the task.
    *   **Navigation:**
        *   "View Location on Map" -> `TaskLocationViewerScreen`.
        *   "Submit Evidence" -> `EvidenceSubmissionScreen`.

4.  **`TaskLocationViewerScreen` (`lib/screens/agent/task_location_viewer_screen.dart`)**
    *   **Accessed From:** `StandaloneTaskDetailScreen` (Agent view).
    *   **Description:** Shows the precise location of a task on an interactive map, possibly with navigation options.
    *   **UI Elements:**
        *   Full-screen map with a marker for the task location.
        *   Agent's current location marker.
        *   "Get Directions" button (could open native map app).
        *   Information about the task geofence if applicable (e.g., visual overlay).
    *   **Navigation:** Back to `StandaloneTaskDetailScreen`.

5.  **`EvidenceSubmissionScreen` (`lib/screens/agent/evidence_submission_screen.dart`)**
    *   **Accessed From:** `StandaloneTaskDetailScreen` (Agent view).
    *   **Description:** Allows agents to capture and submit the required evidence for a task.
    *   **UI Elements:**
        *   Task Title reminder.
        *   Instructions for evidence.
        *   "Take Photo" / "Upload Photo" button (opens camera or gallery).
        *   Area to display thumbnails of selected photos (tapping a thumbnail might open `agent/FullScreenImageViewer`).
        *   Text field for notes/comments.
        *   "Submit Evidence" button.
    *   **Navigation:**
        *   On successful submission -> `AgentTaskListScreen` (with task status updated) or back to `StandaloneTaskDetailScreen`.
        *   Viewing selected photos -> `agent/FullScreenImageViewer`.

6.  **`CalibrationScreen` (`lib/screens/agent/calibration_screen.dart`)**
    *   **Accessed From:** `HomeScreen` (Agent view) or a settings menu.
    *   **Description:** Helps agents check their GPS signal strength and accuracy.
    *   **UI Elements:**
        *   Map view showing current location.
        *   Accuracy reading (e.g., "Accuracy: 10m").
        *   Signal strength indicator (e.g., "Signal: Good (4/5)").
        *   Tips for improving GPS signal.
        *   "Refresh" button.
    *   **Navigation:** Back to the previous screen.

7.  **`EarningsScreen` (`lib/screens/agent/earnings_screen.dart`)**
    *   **Accessed From:** `HomeScreen` (Agent view, "Earnings" tab or profile).
    *   **Description:** Shows the agent their earnings from completed and approved tasks.
    *   **UI Elements:**
        *   Total earnings summary.
        *   List of completed tasks/campaigns with individual earnings.
        *   Date filters for earnings period.
        *   Withdrawal history/options (if applicable).
    *   **Navigation:** Back to `HomeScreen`.
