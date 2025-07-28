import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// The application name
  ///
  /// In en, this message translates to:
  /// **'Al-Tijwal'**
  String get appName;

  /// Title on the login screen
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get loginTitle;

  /// Subtitle on the login screen
  ///
  /// In en, this message translates to:
  /// **'Sign in to your Al-Tijwal account'**
  String get loginSubtitle;

  /// Sign up button text
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// Full name input field label
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// Email input field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Username or email input field label
  ///
  /// In en, this message translates to:
  /// **'Username or Email'**
  String get usernameOrEmail;

  /// Password input field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Login button text
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Required field checkbox label
  ///
  /// In en, this message translates to:
  /// **'Required Field'**
  String get requiredField;

  /// Password validation message
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// No internet connection message
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network settings and try again.'**
  String get noInternetConnection;

  /// Detailed offline error message
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network and try again.'**
  String get noInternetMessage;

  /// Login error message for invalid credentials
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials. Please check username/email and password.'**
  String get invalidCredentials;

  /// Login success message
  ///
  /// In en, this message translates to:
  /// **'Login successful!'**
  String get loginSuccessful;

  /// Unexpected error message
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get unexpectedError;

  /// Sign up success message
  ///
  /// In en, this message translates to:
  /// **'Sign up successful! Please check your email to confirm.'**
  String get signUpSuccessful;

  /// Facebook link error message
  ///
  /// In en, this message translates to:
  /// **'Could not open Facebook'**
  String get couldNotOpenFacebook;

  /// Instagram link error message
  ///
  /// In en, this message translates to:
  /// **'Could not open Instagram'**
  String get couldNotOpenInstagram;

  /// WhatsApp link error message
  ///
  /// In en, this message translates to:
  /// **'Could not open WhatsApp'**
  String get couldNotOpenWhatsApp;

  /// Website link error message
  ///
  /// In en, this message translates to:
  /// **'Could not open website'**
  String get couldNotOpenWebsite;

  /// Loading text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Button text to retry an operation
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Profile loading error message
  ///
  /// In en, this message translates to:
  /// **'Error loading user profile'**
  String get errorLoadingProfile;

  /// Dashboard navigation label
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// Campaigns suffix
  ///
  /// In en, this message translates to:
  /// **'campaigns'**
  String get campaigns;

  /// Tasks navigation label
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// Profile navigation label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Home navigation label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// My tasks screen title
  ///
  /// In en, this message translates to:
  /// **'My Tasks'**
  String get myTasks;

  /// You're offline message
  ///
  /// In en, this message translates to:
  /// **'You\'re Offline'**
  String get youreOffline;

  /// Offline status detailed message
  ///
  /// In en, this message translates to:
  /// **'Please check your internet connection to load the dashboard.'**
  String get offlineMessage;

  /// Error loading dashboard message
  ///
  /// In en, this message translates to:
  /// **'Error loading dashboard'**
  String get errorLoadingDashboard;

  /// Generic retry message
  ///
  /// In en, this message translates to:
  /// **'Please try again later'**
  String get pleaseTryAgainLater;

  /// Create new button text
  ///
  /// In en, this message translates to:
  /// **'Create New'**
  String get createNew;

  /// Create task type selection title
  ///
  /// In en, this message translates to:
  /// **'Choose Task Type'**
  String get chooseTaskType;

  /// Campaign label
  ///
  /// In en, this message translates to:
  /// **'Campaign'**
  String get campaign;

  /// Create campaign description
  ///
  /// In en, this message translates to:
  /// **'Create a new campaign with tasks'**
  String get createCampaignDesc;

  /// Task label
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get task;

  /// Create task description
  ///
  /// In en, this message translates to:
  /// **'Create a standalone task'**
  String get createTaskDesc;

  /// Route noun
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// Create route description
  ///
  /// In en, this message translates to:
  /// **'Create a new route'**
  String get createRouteDesc;

  /// Template task label
  ///
  /// In en, this message translates to:
  /// **'Template Task'**
  String get templateTask;

  /// Create template task description
  ///
  /// In en, this message translates to:
  /// **'Create from existing template'**
  String get createTemplateDesc;

  /// Custom task option
  ///
  /// In en, this message translates to:
  /// **'Custom Task'**
  String get customTask;

  /// Create custom task description
  ///
  /// In en, this message translates to:
  /// **'Create evidence-based task'**
  String get createCustomDesc;

  /// Permission required status
  ///
  /// In en, this message translates to:
  /// **'Permission required'**
  String get permissionRequired;

  /// Active status
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// Disabled status
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// Error prefix
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Permission denied status
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get permissionDenied;

  /// Error occurred status
  ///
  /// In en, this message translates to:
  /// **'Error occurred'**
  String get errorOccurred;

  /// On route status
  ///
  /// In en, this message translates to:
  /// **'On Route'**
  String get onRoute;

  /// Working tasks status
  ///
  /// In en, this message translates to:
  /// **'Working Tasks'**
  String get workingTasks;

  /// In campaign status
  ///
  /// In en, this message translates to:
  /// **'In Campaign'**
  String get inCampaign;

  /// Status when geofence has available capacity
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// Agent dashboard title
  ///
  /// In en, this message translates to:
  /// **'Agent Dashboard'**
  String get agentDashboard;

  /// Location service label
  ///
  /// In en, this message translates to:
  /// **'Location Service'**
  String get locationService;

  /// Routes label
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get routes;

  /// None assigned status
  ///
  /// In en, this message translates to:
  /// **'None assigned'**
  String get noneAssigned;

  /// None active status
  ///
  /// In en, this message translates to:
  /// **'None active'**
  String get noneActive;

  /// No active campaigns status
  ///
  /// In en, this message translates to:
  /// **'No active campaigns'**
  String get noActiveCampaigns;

  /// Places label (lowercase for inline use)
  ///
  /// In en, this message translates to:
  /// **'places'**
  String get places;

  /// Evidence label
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get evidence;

  /// Completion rate label
  ///
  /// In en, this message translates to:
  /// **'Completion Rate'**
  String get completionRate;

  /// Peak hour label
  ///
  /// In en, this message translates to:
  /// **'Peak Hour'**
  String get peakHour;

  /// Average duration label
  ///
  /// In en, this message translates to:
  /// **'Avg Duration'**
  String get avgDuration;

  /// Week total label
  ///
  /// In en, this message translates to:
  /// **'Week Total'**
  String get weekTotal;

  /// Month total label
  ///
  /// In en, this message translates to:
  /// **'Month Total'**
  String get monthTotal;

  /// Unique locations label
  ///
  /// In en, this message translates to:
  /// **'Unique Locations'**
  String get uniqueLocations;

  /// Visit analytics action
  ///
  /// In en, this message translates to:
  /// **'Visit Analytics'**
  String get visitAnalytics;

  /// Visits today label
  ///
  /// In en, this message translates to:
  /// **'Visits today'**
  String get visitsToday;

  /// Active tasks label
  ///
  /// In en, this message translates to:
  /// **'Active Tasks'**
  String get activeTasks;

  /// Tasks in progress label
  ///
  /// In en, this message translates to:
  /// **'Tasks in progress'**
  String get tasksInProgress;

  /// Total points label
  ///
  /// In en, this message translates to:
  /// **'Total Points'**
  String get totalPoints;

  /// Points earned label
  ///
  /// In en, this message translates to:
  /// **'Points Earned:'**
  String get pointsEarned;

  /// Active campaigns label
  ///
  /// In en, this message translates to:
  /// **'Active Campaigns'**
  String get activeCampaigns;

  /// Campaigns running label
  ///
  /// In en, this message translates to:
  /// **'Campaigns running'**
  String get campaignsRunning;

  /// Section title for active routes
  ///
  /// In en, this message translates to:
  /// **'Active Routes'**
  String get activeRoutes;

  /// Routes assigned label
  ///
  /// In en, this message translates to:
  /// **'Routes assigned'**
  String get routesAssigned;

  /// Quick actions label
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// Suggest button label
  ///
  /// In en, this message translates to:
  /// **'Suggest'**
  String get suggest;

  /// Map tab title
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Enable button label
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// Sign out button label
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Settings button text
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Notifications label
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Help and support label
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// About label
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Create options description
  ///
  /// In en, this message translates to:
  /// **'Choose what you\'d like to create'**
  String get chooseWhatToCreate;

  /// Welcome back greeting
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// Agent label
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agent;

  /// Offline feature limitation message
  ///
  /// In en, this message translates to:
  /// **'You\'re offline - Some features may not be available'**
  String get offlineFeatureMessage;

  /// Status checking text
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get checking;

  /// Permission request status
  ///
  /// In en, this message translates to:
  /// **'Requesting permission...'**
  String get requestingPermission;

  /// Service starting status
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get starting;

  /// Location enabled success message
  ///
  /// In en, this message translates to:
  /// **'Location service enabled successfully!'**
  String get locationEnabledSuccess;

  /// Location permission denied message
  ///
  /// In en, this message translates to:
  /// **'Location permission denied. Please enable it in device settings.'**
  String get locationPermissionDeniedMessage;

  /// Failed to enable location error
  ///
  /// In en, this message translates to:
  /// **'Failed to enable location service'**
  String get failedToEnableLocation;

  /// Today's activity section title
  ///
  /// In en, this message translates to:
  /// **'Today\'s Activity'**
  String get todaysActivity;

  /// Places to visit today suffix
  ///
  /// In en, this message translates to:
  /// **'to visit today'**
  String get toVisitToday;

  /// Completed today suffix
  ///
  /// In en, this message translates to:
  /// **'completed today'**
  String get completedToday;

  /// Active campaign label
  ///
  /// In en, this message translates to:
  /// **'active campaign'**
  String get activeCampaign;

  /// Route assignment suffix
  ///
  /// In en, this message translates to:
  /// **'route'**
  String get routesAssignedSuffix;

  /// Assigned label
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assigned;

  /// Description label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// Optional field indicator
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// Address label
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// Location marker title
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// Place name field label
  ///
  /// In en, this message translates to:
  /// **'Place Name'**
  String get placeName;

  /// Placeholder for place name input
  ///
  /// In en, this message translates to:
  /// **'Enter place name'**
  String get enterPlaceName;

  /// Place description hint
  ///
  /// In en, this message translates to:
  /// **'Describe this place...'**
  String get describePlaceHint;

  /// Address field hint
  ///
  /// In en, this message translates to:
  /// **'Enter the address'**
  String get enterAddress;

  /// No location selected message
  ///
  /// In en, this message translates to:
  /// **'No location selected'**
  String get noLocationSelected;

  /// Button text to change location
  ///
  /// In en, this message translates to:
  /// **'Change Location'**
  String get changeLocation;

  /// Button text to select location
  ///
  /// In en, this message translates to:
  /// **'Select Location on Map'**
  String get selectLocationOnMap;

  /// Geofence radius label
  ///
  /// In en, this message translates to:
  /// **'Geofence Radius'**
  String get geofenceRadius;

  /// Meters unit
  ///
  /// In en, this message translates to:
  /// **'meters'**
  String get meters;

  /// Submit suggestion button text
  ///
  /// In en, this message translates to:
  /// **'Submit Suggestion'**
  String get submitSuggestion;

  /// Dialog title for suggesting new place
  ///
  /// In en, this message translates to:
  /// **'Suggest New Place'**
  String get suggestNewPlace;

  /// Required fields validation message
  ///
  /// In en, this message translates to:
  /// **'Please fill required fields (Name)'**
  String get fillRequiredFields;

  /// Authentication error message
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get authenticationRequired;

  /// Success message for place suggestion
  ///
  /// In en, this message translates to:
  /// **'Place suggestion submitted! Waiting for manager approval.'**
  String get placeSuggestionSubmitted;

  /// Failed to submit suggestion error
  ///
  /// In en, this message translates to:
  /// **'Failed to submit place suggestion'**
  String get failedToSubmitSuggestion;

  /// Group management label
  ///
  /// In en, this message translates to:
  /// **'Group Management'**
  String get groupManagement;

  /// Group management description
  ///
  /// In en, this message translates to:
  /// **'Manage client groups and team members'**
  String get manageGroupsDesc;

  /// Settings description
  ///
  /// In en, this message translates to:
  /// **'App preferences and configuration'**
  String get settingsDesc;

  /// Notifications enabled status
  ///
  /// In en, this message translates to:
  /// **'Notifications enabled'**
  String get notificationsEnabled;

  /// Setting up notifications status
  ///
  /// In en, this message translates to:
  /// **'Setting up notifications...'**
  String get settingUpNotifications;

  /// Help and support description
  ///
  /// In en, this message translates to:
  /// **'Get help and contact support'**
  String get helpSupportDesc;

  /// Help support coming soon message
  ///
  /// In en, this message translates to:
  /// **'Help & Support coming soon'**
  String get helpSupportComingSoon;

  /// About description
  ///
  /// In en, this message translates to:
  /// **'App version and information'**
  String get aboutDesc;

  /// About coming soon message
  ///
  /// In en, this message translates to:
  /// **'About information coming soon'**
  String get aboutComingSoon;

  /// Sign out description
  ///
  /// In en, this message translates to:
  /// **'Sign out of your account'**
  String get signOutDesc;

  /// Sign out confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out of your account?'**
  String get signOutConfirmation;

  /// Failed sign out error
  ///
  /// In en, this message translates to:
  /// **'Failed to sign out properly'**
  String get failedToSignOut;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get anErrorOccurred;

  /// Language label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Select language title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Arabic language option
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// Language change success message
  ///
  /// In en, this message translates to:
  /// **'Language changed successfully'**
  String get languageChanged;

  /// Restart required message for language change
  ///
  /// In en, this message translates to:
  /// **'Please restart the app to apply language changes'**
  String get restartRequired;

  /// Language option description
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language'**
  String get languageDesc;

  /// Confirm delete title
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDelete;

  /// Delete campaign confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This action cannot be undone.'**
  String confirmDeleteCampaign(String name);

  /// Campaign deletion success message
  ///
  /// In en, this message translates to:
  /// **'Campaign \"{name}\" deleted successfully.'**
  String campaignDeleted(String name);

  /// Campaign deletion error message
  ///
  /// In en, this message translates to:
  /// **'Error deleting campaign: {error}'**
  String errorDeletingCampaign(String error);

  /// Empty state title for managers with no campaigns
  ///
  /// In en, this message translates to:
  /// **'No Campaigns Yet'**
  String get noCampaignsYet;

  /// Empty state description for managers with no campaigns
  ///
  /// In en, this message translates to:
  /// **'Create your first campaign to get started with managing tasks and agents'**
  String get createFirstCampaign;

  /// Empty state title for agents with no assigned campaigns
  ///
  /// In en, this message translates to:
  /// **'No Campaigns Assigned'**
  String get noCampaignsAssigned;

  /// Empty state description for agents with no assigned campaigns
  ///
  /// In en, this message translates to:
  /// **'You will see assigned campaigns here when available'**
  String get viewAssignedCampaigns;

  /// Edit campaign title
  ///
  /// In en, this message translates to:
  /// **'Edit Campaign'**
  String get editCampaign;

  /// Delete campaign tooltip
  ///
  /// In en, this message translates to:
  /// **'Delete Campaign'**
  String get deleteCampaign;

  /// Status when agent is inside geofence
  ///
  /// In en, this message translates to:
  /// **'Inside geofence'**
  String get insideGeofence;

  /// Status when agent is outside geofence
  ///
  /// In en, this message translates to:
  /// **'Outside geofence'**
  String get outsideGeofence;

  /// View task location tooltip
  ///
  /// In en, this message translates to:
  /// **'View Task Location'**
  String get viewTaskLocation;

  /// Campaign end date prefix
  ///
  /// In en, this message translates to:
  /// **'Ends:'**
  String get ends;

  /// Agent campaigns screen title
  ///
  /// In en, this message translates to:
  /// **'My Campaigns'**
  String get myCampaigns;

  /// Network error message for campaigns loading
  ///
  /// In en, this message translates to:
  /// **'Unable to load campaigns. Please check your connection and try again.'**
  String get unableToLoadCampaigns;

  /// Generic error message for campaigns loading
  ///
  /// In en, this message translates to:
  /// **'Error loading campaigns'**
  String get errorLoadingCampaigns;

  /// Add new task dialog title
  ///
  /// In en, this message translates to:
  /// **'Add New Task'**
  String get addNewTask;

  /// Task title input label
  ///
  /// In en, this message translates to:
  /// **'Task Title'**
  String get taskTitle;

  /// Assign agent dialog title
  ///
  /// In en, this message translates to:
  /// **'Assign an Agent'**
  String get assignAnAgent;

  /// Assigned agents metric
  ///
  /// In en, this message translates to:
  /// **'Assigned Agents'**
  String get assignedAgents;

  /// Assign agent button label
  ///
  /// In en, this message translates to:
  /// **'Assign Agent'**
  String get assignAgent;

  /// Empty state message when no tasks exist
  ///
  /// In en, this message translates to:
  /// **'No tasks created yet.'**
  String get noTasksCreated;

  /// Empty state message when no agents are assigned
  ///
  /// In en, this message translates to:
  /// **'No agents assigned yet.'**
  String get noAgentsAssigned;

  /// Edit task button
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get editTask;

  /// Delete task text
  ///
  /// In en, this message translates to:
  /// **'Delete Task'**
  String get deleteTask;

  /// Button text to manage geofences
  ///
  /// In en, this message translates to:
  /// **'Manage Geofences'**
  String get manageGeofences;

  /// Agent removal confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Confirm Removal'**
  String get confirmRemoval;

  /// Agent removal confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {name} from this campaign?'**
  String removeAgentConfirmation(String name);

  /// Pay agent dialog title
  ///
  /// In en, this message translates to:
  /// **'Pay {name}'**
  String payAgent(String name);

  /// Payment amount input label
  ///
  /// In en, this message translates to:
  /// **'Amount Paid'**
  String get amountPaid;

  /// Outstanding balance label
  ///
  /// In en, this message translates to:
  /// **'Outstanding Balance'**
  String get outstandingBalance;

  /// Loading earnings status message
  ///
  /// In en, this message translates to:
  /// **'Loading earnings...'**
  String get loadingEarnings;

  /// Task addition success message
  ///
  /// In en, this message translates to:
  /// **'Task added and assigned to all campaign agents!'**
  String get taskAddedSuccess;

  /// Task addition failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to add task: {error}'**
  String taskAddFailed(String error);

  /// Agent assignment success message
  ///
  /// In en, this message translates to:
  /// **'Agent assigned to campaign. All tasks have been assigned.'**
  String get agentAssignedSuccess;

  /// Agent assignment failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to assign agent: {error}'**
  String agentAssignFailed(String error);

  /// Task update success message
  ///
  /// In en, this message translates to:
  /// **'Task updated successfully!'**
  String get taskUpdatedSuccess;

  /// Task update failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to update task: {error}'**
  String taskUpdateFailed(String error);

  /// Task deletion success message
  ///
  /// In en, this message translates to:
  /// **'Task deleted successfully!'**
  String get taskDeletedSuccess;

  /// Task deletion failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to delete task: {error}'**
  String taskDeleteFailed(String error);

  /// Agent removal success message
  ///
  /// In en, this message translates to:
  /// **'Agent removed successfully.'**
  String get agentRemovedSuccess;

  /// Agent removal failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to remove agent: {error}'**
  String agentRemoveFailed(String error);

  /// Payment recording success message
  ///
  /// In en, this message translates to:
  /// **'Payment recorded successfully!'**
  String get paymentRecordedSuccess;

  /// Payment recording failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to record payment: {error}'**
  String paymentRecordFailed(String error);

  /// Payment amount input label
  ///
  /// In en, this message translates to:
  /// **'Payment Amount'**
  String get paymentAmount;

  /// Pay button label
  ///
  /// In en, this message translates to:
  /// **'PAY'**
  String get pay;

  /// Number validation error message
  ///
  /// In en, this message translates to:
  /// **'Must be a number'**
  String get mustBeNumber;

  /// Upload evidence dialog title and button text
  ///
  /// In en, this message translates to:
  /// **'Upload Evidence'**
  String get uploadEvidence;

  /// Evidence name field label
  ///
  /// In en, this message translates to:
  /// **'Evidence Name'**
  String get evidenceName;

  /// Evidence name input placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter evidence name'**
  String get enterEvidenceName;

  /// Evidence name validation message
  ///
  /// In en, this message translates to:
  /// **'Evidence name is required'**
  String get evidenceNameRequired;

  /// Button text to select a file
  ///
  /// In en, this message translates to:
  /// **'Select File'**
  String get selectFile;

  /// Change file button text
  ///
  /// In en, this message translates to:
  /// **'Change File'**
  String get changeFile;

  /// Upload button text
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// Take photo option
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// Take photo description
  ///
  /// In en, this message translates to:
  /// **'Capture with camera'**
  String get captureWithCamera;

  /// Choose image option
  ///
  /// In en, this message translates to:
  /// **'Choose Image'**
  String get chooseImage;

  /// Choose image description
  ///
  /// In en, this message translates to:
  /// **'Select from gallery'**
  String get selectFromGallery;

  /// Record video option
  ///
  /// In en, this message translates to:
  /// **'Record Video'**
  String get recordVideo;

  /// Record video description
  ///
  /// In en, this message translates to:
  /// **'Capture video'**
  String get captureVideo;

  /// Choose video option
  ///
  /// In en, this message translates to:
  /// **'Choose Video'**
  String get chooseVideo;

  /// Choose video description
  ///
  /// In en, this message translates to:
  /// **'Select from gallery'**
  String get selectVideoFromGallery;

  /// Choose document option
  ///
  /// In en, this message translates to:
  /// **'Choose Document'**
  String get chooseDocument;

  /// Document types description
  ///
  /// In en, this message translates to:
  /// **'PDF, Word, Excel, etc.'**
  String get documentTypes;

  /// Any file option
  ///
  /// In en, this message translates to:
  /// **'Any File'**
  String get anyFile;

  /// Any file description
  ///
  /// In en, this message translates to:
  /// **'Browse all files'**
  String get browseAllFiles;

  /// Image file type display
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// PDF label
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get pdf;

  /// Video label
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// Document label
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get document;

  /// Generic file type display
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// Approved status
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// Rejected status
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// Pending review status
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get pendingReview;

  /// Delete confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get confirmDeletion;

  /// Delete evidence confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?'**
  String confirmDeleteEvidence(String title);

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Evidence deletion success message
  ///
  /// In en, this message translates to:
  /// **'Evidence deleted successfully.'**
  String get evidenceDeletedSuccess;

  /// Evidence deletion failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to delete evidence: {error}'**
  String evidenceDeleteFailed(String error);

  /// Task status reverted message
  ///
  /// In en, this message translates to:
  /// **'Task status reverted to pending.'**
  String get taskStatusReverted;

  /// Confirm completion dialog title
  ///
  /// In en, this message translates to:
  /// **'Confirm Completion'**
  String get confirmCompletion;

  /// Task completion confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to mark this task as done? This cannot be undone.'**
  String get confirmMarkTaskDone;

  /// Confirm button text
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Task completion success message
  ///
  /// In en, this message translates to:
  /// **'Task marked as completed!'**
  String get taskCompletedSuccess;

  /// Error message when upload fails
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String uploadFailed(String error);

  /// Checking location status
  ///
  /// In en, this message translates to:
  /// **'Checking Location...'**
  String get checkingLocation;

  /// Geofence validation failed message
  ///
  /// In en, this message translates to:
  /// **'You must be within the task location area to upload evidence. Please move to the designated location and try again.'**
  String get geofenceValidationFailed;

  /// Location verified success message
  ///
  /// In en, this message translates to:
  /// **'Location Verified!'**
  String get locationVerified;

  /// File size limit error message
  ///
  /// In en, this message translates to:
  /// **'File too large. Maximum size is 50MB.'**
  String get fileTooLarge;

  /// Evidence upload success message
  ///
  /// In en, this message translates to:
  /// **'Evidence uploaded successfully.'**
  String get evidenceUploadedSuccess;

  /// File URL dialog title
  ///
  /// In en, this message translates to:
  /// **'File URL'**
  String get fileUrl;

  /// Close button text
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Open button text
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// File open error message
  ///
  /// In en, this message translates to:
  /// **'Could not open file: {error}'**
  String couldNotOpenFile(String error);

  /// Document file viewer info
  ///
  /// In en, this message translates to:
  /// **'This file can be viewed in your device\'s document viewer.'**
  String get fileViewerInfo;

  /// Video file player info
  ///
  /// In en, this message translates to:
  /// **'This video can be played in your device\'s video player.'**
  String get videoPlayerInfo;

  /// Generic file app info
  ///
  /// In en, this message translates to:
  /// **'This file can be opened with a compatible app on your device.'**
  String get compatibleAppInfo;

  /// Rejection reason field label
  ///
  /// In en, this message translates to:
  /// **'Rejection Reason'**
  String get rejectionReason;

  /// Approve evidence dialog title
  ///
  /// In en, this message translates to:
  /// **'Approve Evidence'**
  String get approveEvidence;

  /// Approve evidence confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to approve \"{title}\"?'**
  String confirmApproveEvidence(String title);

  /// Approve button text
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// Evidence approval success message
  ///
  /// In en, this message translates to:
  /// **'Evidence approved successfully'**
  String get evidenceApprovedSuccess;

  /// Evidence approval failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to approve evidence: {error}'**
  String evidenceApproveFailed(String error);

  /// Reject evidence dialog title
  ///
  /// In en, this message translates to:
  /// **'Reject Evidence'**
  String get rejectEvidence;

  /// Reject evidence confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reject \"{title}\"?'**
  String confirmRejectEvidence(String title);

  /// Rejection reason input label
  ///
  /// In en, this message translates to:
  /// **'Rejection Reason'**
  String get rejectionReasonLabel;

  /// Rejection reason input hint
  ///
  /// In en, this message translates to:
  /// **'Explain why this evidence is being rejected'**
  String get rejectionReasonHint;

  /// Rejection reason validation message
  ///
  /// In en, this message translates to:
  /// **'Please provide a reason for rejection'**
  String get rejectionReasonRequired;

  /// Reject button text
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// Evidence rejection success message
  ///
  /// In en, this message translates to:
  /// **'Evidence rejected'**
  String get evidenceRejectedSuccess;

  /// Evidence rejection failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to reject evidence: {error}'**
  String evidenceRejectFailed(String error);

  /// Empty state message when no evidence exists
  ///
  /// In en, this message translates to:
  /// **'No evidence submitted yet.'**
  String get noEvidenceSubmitted;

  /// Progress label showing current vs total time
  ///
  /// In en, this message translates to:
  /// **'Progress: {current} / {total}'**
  String progressLabel(String current, String total);

  /// Completed status label
  ///
  /// In en, this message translates to:
  /// **'Status: Completed'**
  String get statusCompleted;

  /// Manager status debug label
  ///
  /// In en, this message translates to:
  /// **'Is Manager: {isManager}'**
  String isManager(bool isManager);

  /// View evidence tooltip
  ///
  /// In en, this message translates to:
  /// **'View Evidence'**
  String get viewEvidence;

  /// Delete evidence tooltip
  ///
  /// In en, this message translates to:
  /// **'Delete Evidence'**
  String get deleteEvidence;

  /// Mark task as done button text
  ///
  /// In en, this message translates to:
  /// **'Mark as Done'**
  String get markAsDone;

  /// Assignment pending title
  ///
  /// In en, this message translates to:
  /// **'Assignment Pending'**
  String get assignmentPending;

  /// Assignment pending dialog message
  ///
  /// In en, this message translates to:
  /// **'Your assignment to this task is currently pending approval from a manager. You cannot access task details or submit evidence until it is approved.\n\nPlease check back later or contact your manager.'**
  String get assignmentPendingMessage;

  /// Go back button
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// Task assignment loading error message
  ///
  /// In en, this message translates to:
  /// **'Error loading task assignment: {error}'**
  String errorLoadingTaskAssignment(String error);

  /// No description available message
  ///
  /// In en, this message translates to:
  /// **'No description.'**
  String get noDescription;

  /// No location name available message
  ///
  /// In en, this message translates to:
  /// **'No location name'**
  String get noLocationName;

  /// Current campaign section
  ///
  /// In en, this message translates to:
  /// **'Current Campaign'**
  String get currentCampaign;

  /// Start guided task button
  ///
  /// In en, this message translates to:
  /// **'Start Guided Task'**
  String get startGuidedTask;

  /// Quick upload button
  ///
  /// In en, this message translates to:
  /// **'Quick Upload'**
  String get quickUpload;

  /// Mark done button
  ///
  /// In en, this message translates to:
  /// **'Mark Done'**
  String get markDone;

  /// In progress status
  ///
  /// In en, this message translates to:
  /// **'IN PROGRESS'**
  String get inProgress;

  /// Awaiting manager approval text
  ///
  /// In en, this message translates to:
  /// **'Awaiting Manager Approval'**
  String get awaitingManagerApproval;

  /// Evidence required dialog message
  ///
  /// In en, this message translates to:
  /// **'This task requires {requiredEvidence} evidence file(s) but only {uploadedEvidence} uploaded.\\n\\nPlease upload the required evidence before marking the task as complete.'**
  String evidenceRequiredMessage(int requiredEvidence, int uploadedEvidence);

  /// Confirm completion message
  ///
  /// In en, this message translates to:
  /// **'You have uploaded {uploaded}/{required} required evidence files.\n\nAre you sure you want to mark this task as complete?'**
  String confirmCompletionMessage(int uploaded, int required);

  /// Task assignment pending message
  ///
  /// In en, this message translates to:
  /// **'This task assignment is pending approval from your manager. You cannot start work until it is approved.'**
  String get taskAssignmentPending;

  /// Checking location for geofence
  ///
  /// In en, this message translates to:
  /// **'Checking location for geofence validation...'**
  String get checkingLocationGeofence;

  /// Location verified uploading message
  ///
  /// In en, this message translates to:
  /// **'Location verified! Uploading evidence...'**
  String get locationVerifiedUploading;

  /// Upload more evidence message
  ///
  /// In en, this message translates to:
  /// **'Upload {count} more evidence file(s) to complete this task'**
  String uploadMoreEvidence(int count);

  /// Task marked completed message
  ///
  /// In en, this message translates to:
  /// **'Task marked as completed!'**
  String get taskMarkedCompleted;

  /// Failed to update task message
  ///
  /// In en, this message translates to:
  /// **'Failed to update task: {error}'**
  String failedToUpdateTask(String error);

  /// No tasks available title
  ///
  /// In en, this message translates to:
  /// **'No Tasks Available'**
  String get noTasksAvailable;

  /// No tasks assigned message
  ///
  /// In en, this message translates to:
  /// **'There are no tasks assigned to you in this campaign yet. Check back later or contact your manager.'**
  String get noTasksAssignedMessage;

  /// Loading tasks message
  ///
  /// In en, this message translates to:
  /// **'Loading tasks...'**
  String get loadingTasks;

  /// Try again button
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// Unable to load tasks message
  ///
  /// In en, this message translates to:
  /// **'Unable to load tasks'**
  String get unableToLoadTasks;

  /// Please check connection message
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again'**
  String get pleaseCheckConnection;

  /// Account not assigned to group title
  ///
  /// In en, this message translates to:
  /// **'Account Not Assigned to Group'**
  String get accountNotAssignedToGroup;

  /// Account not assigned message
  ///
  /// In en, this message translates to:
  /// **'This account has not been set to a group. Contact the system administrator.'**
  String get accountNotAssignedMessage;

  /// Tasks will appear message
  ///
  /// In en, this message translates to:
  /// **'Tasks will appear once you are assigned to a group'**
  String get tasksWillAppear;

  /// No tasks found message
  ///
  /// In en, this message translates to:
  /// **'No tasks found.\nStandalone tasks will appear here when created.'**
  String get noTasksFound;

  /// Request assignment button
  ///
  /// In en, this message translates to:
  /// **'Request Assignment'**
  String get requestAssignment;

  /// View location button
  ///
  /// In en, this message translates to:
  /// **'View Location'**
  String get viewLocation;

  /// Submit evidence button
  ///
  /// In en, this message translates to:
  /// **'Submit Evidence'**
  String get submitEvidence;

  /// Request task assignment dialog title
  ///
  /// In en, this message translates to:
  /// **'Request Task Assignment'**
  String get requestTaskAssignment;

  /// Request assignment message
  ///
  /// In en, this message translates to:
  /// **'Do you want to request assignment to \"{title}\"? This will notify the manager.'**
  String requestAssignmentMessage(String title);

  /// Request button
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get request;

  /// Task assignment requested message
  ///
  /// In en, this message translates to:
  /// **'Task assignment requested successfully!'**
  String get taskAssignmentRequested;

  /// Failed to request assignment message
  ///
  /// In en, this message translates to:
  /// **'Failed to request assignment: {error}'**
  String failedToRequestAssignment(String error);

  /// Assignment request pending message
  ///
  /// In en, this message translates to:
  /// **'Your assignment request for this task is currently pending approval from a manager. You cannot start work until it is approved.\n\nPlease check back later or contact your manager for more information.'**
  String get assignmentRequestPending;

  /// Assignment pending approval title
  ///
  /// In en, this message translates to:
  /// **'Assignment request pending approval'**
  String get assignmentPendingApproval;

  /// Cannot start until approved message
  ///
  /// In en, this message translates to:
  /// **'You cannot start work on this task until your assignment request is approved by a manager.'**
  String get cannotStartUntilApproved;

  /// Overview step label
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// Location verification step label
  ///
  /// In en, this message translates to:
  /// **'Location Verification'**
  String get locationVerification;

  /// Evidence upload section title
  ///
  /// In en, this message translates to:
  /// **'Evidence Upload'**
  String get evidenceUpload;

  /// Complete button
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// Task overview section title
  ///
  /// In en, this message translates to:
  /// **'Task Overview'**
  String get taskOverview;

  /// Points label
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// Location check required label
  ///
  /// In en, this message translates to:
  /// **'Location Check Required'**
  String get locationCheckRequired;

  /// Must be within area description
  ///
  /// In en, this message translates to:
  /// **'You must be within the specified area'**
  String get mustBeWithinArea;

  /// Evidence required label
  ///
  /// In en, this message translates to:
  /// **'Evidence Required'**
  String get evidenceRequired;

  /// Upload photos or files description
  ///
  /// In en, this message translates to:
  /// **'Upload photos or files as proof of completion'**
  String get uploadPhotosOrFiles;

  /// Start task button
  ///
  /// In en, this message translates to:
  /// **'Start Task'**
  String get startTask;

  /// Within required area message
  ///
  /// In en, this message translates to:
  /// **'You are within the required task area. You can now proceed to upload evidence.'**
  String get withinRequiredArea;

  /// Move to designated area button
  ///
  /// In en, this message translates to:
  /// **'Move to Designated Area'**
  String get moveToDesignatedArea;

  /// View map button
  ///
  /// In en, this message translates to:
  /// **'View Map'**
  String get viewMap;

  /// Check location button
  ///
  /// In en, this message translates to:
  /// **'Check Location'**
  String get checkLocation;

  /// Continue to evidence button
  ///
  /// In en, this message translates to:
  /// **'Continue to Evidence'**
  String get continueToEvidence;

  /// Verify location first button
  ///
  /// In en, this message translates to:
  /// **'Verify Location First'**
  String get verifyLocationFirst;

  /// Evidence uploaded success message
  ///
  /// In en, this message translates to:
  /// **'Evidence Uploaded!'**
  String get evidenceUploaded;

  /// Successfully uploaded evidence message
  ///
  /// In en, this message translates to:
  /// **'You have successfully uploaded evidence for this task. You can add more evidence or proceed to complete the task.'**
  String get successfullyUploadedEvidence;

  /// Upload evidence description
  ///
  /// In en, this message translates to:
  /// **'Upload photos, documents, or other files as evidence that you have completed this task.'**
  String get uploadEvidenceDesc;

  /// Add more evidence button
  ///
  /// In en, this message translates to:
  /// **'Add More Evidence'**
  String get addMoreEvidence;

  /// Upload evidence first button
  ///
  /// In en, this message translates to:
  /// **'Upload Evidence First'**
  String get uploadEvidenceFirst;

  /// Task completed status
  ///
  /// In en, this message translates to:
  /// **'Task Completed'**
  String get taskCompleted;

  /// Congratulations completed message
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You have successfully completed \"{title}\". Your evidence has been submitted for review.'**
  String congratulationsCompleted(String title);

  /// Return to tasks button
  ///
  /// In en, this message translates to:
  /// **'Return to Tasks'**
  String get returnToTasks;

  /// Visit status - not started
  ///
  /// In en, this message translates to:
  /// **'Visit has not started yet'**
  String get visitNotStartedYet;

  /// Visit status - checked in
  ///
  /// In en, this message translates to:
  /// **'Currently at the location'**
  String get currentlyAtLocation;

  /// Visit status - completed
  ///
  /// In en, this message translates to:
  /// **'Visit completed successfully'**
  String get visitCompletedSuccessfully;

  /// Visit status - skipped
  ///
  /// In en, this message translates to:
  /// **'Visit was skipped'**
  String get visitWasSkipped;

  /// Unknown status fallback
  ///
  /// In en, this message translates to:
  /// **'Unknown status'**
  String get unknownStatus;

  /// Check in button
  ///
  /// In en, this message translates to:
  /// **'Check In'**
  String get checkIn;

  /// Check out button
  ///
  /// In en, this message translates to:
  /// **'Check Out'**
  String get checkOut;

  /// Duration label
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// Coordinates label
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get coordinates;

  /// Error getting location message
  ///
  /// In en, this message translates to:
  /// **'Error getting location'**
  String get errorGettingLocation;

  /// Selected coordinates label
  ///
  /// In en, this message translates to:
  /// **'Selected Coordinates:'**
  String get selectedCoordinates;

  /// Map interaction instructions
  ///
  /// In en, this message translates to:
  /// **'Tap on the map to select a location. Drag the marker to fine-tune. Adjust the geofence radius as needed.'**
  String get mapInstructions;

  /// Start marker title
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// End marker title
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// Seven days preset button
  ///
  /// In en, this message translates to:
  /// **'7 Days'**
  String get sevenDays;

  /// Thirty days preset button
  ///
  /// In en, this message translates to:
  /// **'30 Days'**
  String get thirtyDays;

  /// Ninety days preset button
  ///
  /// In en, this message translates to:
  /// **'90 Days'**
  String get ninetyDays;

  /// Total entries statistics label
  ///
  /// In en, this message translates to:
  /// **'Total Entries'**
  String get totalEntries;

  /// Average accuracy statistics label
  ///
  /// In en, this message translates to:
  /// **'Avg Accuracy'**
  String get avgAccuracy;

  /// Average speed statistics label
  ///
  /// In en, this message translates to:
  /// **'Avg Speed'**
  String get avgSpeed;

  /// Period statistics label
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// Shows number of selected days
  ///
  /// In en, this message translates to:
  /// **'{count} days selected'**
  String daysSelected(int count);

  /// Select days label
  ///
  /// In en, this message translates to:
  /// **'Select Days'**
  String get selectDays;

  /// Select start time label
  ///
  /// In en, this message translates to:
  /// **'Select Start Time'**
  String get selectStartTime;

  /// Select end time label
  ///
  /// In en, this message translates to:
  /// **'Select End Time'**
  String get selectEndTime;

  /// History tab title
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// Select agent dropdown label
  ///
  /// In en, this message translates to:
  /// **'Select Agent'**
  String get selectAgent;

  /// Please select agent message
  ///
  /// In en, this message translates to:
  /// **'Please select an agent to view location history'**
  String get pleaseSelectAgentForLocationHistory;

  /// No location history found message
  ///
  /// In en, this message translates to:
  /// **'No location history found for the selected period'**
  String get noLocationHistoryFound;

  /// Agent movement track title
  ///
  /// In en, this message translates to:
  /// **'Agent Movement Track'**
  String get agentMovementTrack;

  /// Total locations label
  ///
  /// In en, this message translates to:
  /// **'Total Locations'**
  String get totalLocations;

  /// Time period label
  ///
  /// In en, this message translates to:
  /// **'Time Period'**
  String get timePeriod;

  /// Start time label
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get startTime;

  /// End time label
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get endTime;

  /// Tap to view complete route message
  ///
  /// In en, this message translates to:
  /// **'Tap to view complete route on map'**
  String get tapToViewCompleteRoute;

  /// Location statistics title
  ///
  /// In en, this message translates to:
  /// **'Location Statistics'**
  String get locationStatistics;

  /// No location data to display message
  ///
  /// In en, this message translates to:
  /// **'No location data to display on map'**
  String get noLocationDataToDisplay;

  /// Place visit details title
  ///
  /// In en, this message translates to:
  /// **'Place Visit Details'**
  String get placeVisitDetails;

  /// Place information section title
  ///
  /// In en, this message translates to:
  /// **'Place Information'**
  String get placeInformation;

  /// Visit status section title
  ///
  /// In en, this message translates to:
  /// **'Visit Status'**
  String get visitStatus;

  /// Visit timing section title
  ///
  /// In en, this message translates to:
  /// **'Visit Timing'**
  String get visitTiming;

  /// Not yet placeholder
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get notYet;

  /// Route information section title
  ///
  /// In en, this message translates to:
  /// **'Route Information'**
  String get routeInformation;

  /// Unknown route placeholder
  ///
  /// In en, this message translates to:
  /// **'Unknown Route'**
  String get unknownRoute;

  /// Visit notes section title
  ///
  /// In en, this message translates to:
  /// **'Visit Notes'**
  String get visitNotes;

  /// Tap to move location instruction
  ///
  /// In en, this message translates to:
  /// **'Tap to move location'**
  String get tapToMoveLocation;

  /// Location permission required message
  ///
  /// In en, this message translates to:
  /// **'Location permission is required'**
  String get locationPermissionRequired;

  /// Please select location on map message
  ///
  /// In en, this message translates to:
  /// **'Please select a location on the map'**
  String get pleaseSelectLocationOnMap;

  /// Select location title
  ///
  /// In en, this message translates to:
  /// **'Select Location'**
  String get selectLocation;

  /// Assignment pending dialog title
  ///
  /// In en, this message translates to:
  /// **'Assignment Pending'**
  String get assignmentPendingTitle;

  /// Assignment pending dialog description
  ///
  /// In en, this message translates to:
  /// **'Your assignment to this task is currently pending approval from a manager. You cannot start work until it is approved.\n\nPlease check back later or contact your manager.'**
  String get assignmentPendingDesc;

  /// Not within task location error message
  ///
  /// In en, this message translates to:
  /// **'You are not within the task location area. Please move closer to continue.'**
  String get notWithinTaskLocation;

  /// Error checking location message
  ///
  /// In en, this message translates to:
  /// **'Error checking location: {error}'**
  String errorCheckingLocation(String error);

  /// Completed status
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// Requested status
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requested;

  /// OK button text
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Mark all notifications as read button text
  ///
  /// In en, this message translates to:
  /// **'Mark All Read'**
  String get markAllRead;

  /// All filter option
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Unread filter option for notifications
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// Read filter option for notifications
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// Just now time text
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Minutes ago text
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String minutesAgo(int minutes);

  /// Hours ago text
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String hoursAgo(int hours);

  /// Days ago text
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String daysAgo(int days);

  /// Campaign notification type display name
  ///
  /// In en, this message translates to:
  /// **'Campaign'**
  String get campaignType;

  /// Task notification type display name
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskType;

  /// Route notification type display name
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get routeType;

  /// Place notification type display name
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get placeType;

  /// Completion notification type display name
  ///
  /// In en, this message translates to:
  /// **'Completion'**
  String get completionType;

  /// Evidence notification type display name
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get evidenceType;

  /// General notification type display name
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalType;

  /// Error message when notifications fail to load
  ///
  /// In en, this message translates to:
  /// **'Error loading notifications'**
  String get errorLoadingNotifications;

  /// Empty state message when no notifications exist
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// Empty state message for filtered notifications
  ///
  /// In en, this message translates to:
  /// **'No {filter} notifications'**
  String noFilterNotifications(String filter);

  /// Empty state description for notifications
  ///
  /// In en, this message translates to:
  /// **'You\'ll see notifications here when there are updates'**
  String get notificationsUpdatesMessage;

  /// Success message when marking notifications as read
  ///
  /// In en, this message translates to:
  /// **'Marked {count} notifications as read'**
  String markedNotificationsRead(int count);

  /// Button text for suggesting a new place
  ///
  /// In en, this message translates to:
  /// **'Suggest Place'**
  String get suggestPlace;

  /// Title for agent routes dashboard
  ///
  /// In en, this message translates to:
  /// **'My Routes'**
  String get myRoutes;

  /// Label for current active visit
  ///
  /// In en, this message translates to:
  /// **'Currently Visiting'**
  String get currentlyVisiting;

  /// Add evidence button text
  ///
  /// In en, this message translates to:
  /// **'Add Evidence'**
  String get addEvidence;

  /// Status label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// Empty state title for no active routes
  ///
  /// In en, this message translates to:
  /// **'No Active Routes'**
  String get noActiveRoutes;

  /// Empty state message for routes
  ///
  /// In en, this message translates to:
  /// **'Your manager will assign routes for you to visit.'**
  String get routesWillBeAssigned;

  /// Coming soon message for checkout
  ///
  /// In en, this message translates to:
  /// **'Check-out functionality - Coming soon!'**
  String get checkoutComingSoon;

  /// Coming soon message for evidence upload
  ///
  /// In en, this message translates to:
  /// **'Evidence upload - Coming soon!'**
  String get evidenceUploadComingSoon;

  /// Required place name field label
  ///
  /// In en, this message translates to:
  /// **'Place Name *'**
  String get placeNameRequired;

  /// Placeholder for description input
  ///
  /// In en, this message translates to:
  /// **'Brief description of the place'**
  String get briefDescription;

  /// Placeholder for address input
  ///
  /// In en, this message translates to:
  /// **'Street address or landmark'**
  String get streetAddressOrLandmark;

  /// Required location field label
  ///
  /// In en, this message translates to:
  /// **'Location *'**
  String get locationRequired;

  /// Label for selected location
  ///
  /// In en, this message translates to:
  /// **'Selected Location:'**
  String get selectedLocation;

  /// Radius label
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get radius;

  /// Validation message for required fields
  ///
  /// In en, this message translates to:
  /// **'Please fill required fields'**
  String get pleaseFillRequiredFields;

  /// Error message for suggestion submission
  ///
  /// In en, this message translates to:
  /// **'Error submitting suggestion'**
  String get errorSubmittingSuggestion;

  /// Error message when form fails to load
  ///
  /// In en, this message translates to:
  /// **'Error loading form'**
  String get errorLoadingForm;

  /// Empty state title for no form fields
  ///
  /// In en, this message translates to:
  /// **'No Form Fields'**
  String get noFormFields;

  /// Empty state message for no custom fields
  ///
  /// In en, this message translates to:
  /// **'This template has no custom fields configured.'**
  String get noCustomFieldsConfigured;

  /// Required field indicator
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// Placeholder for email input
  ///
  /// In en, this message translates to:
  /// **'Enter email address'**
  String get enterEmailAddress;

  /// Placeholder for phone input
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get enterPhoneNumber;

  /// Placeholder for dropdown selection
  ///
  /// In en, this message translates to:
  /// **'Select an option'**
  String get selectAnOption;

  /// Date picker placeholder
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// Placeholder for time picker
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get selectTime;

  /// Signature field label
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get signature;

  /// Instruction for signature field
  ///
  /// In en, this message translates to:
  /// **'Please sign below to confirm completion'**
  String get pleaseSignToConfirm;

  /// Clear signature button text
  ///
  /// In en, this message translates to:
  /// **'Clear Signature'**
  String get clearSignature;

  /// Loading text while submitting
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get submitting;

  /// Submit form button text
  ///
  /// In en, this message translates to:
  /// **'Submit Form'**
  String get submitForm;

  /// Field validation suffix
  ///
  /// In en, this message translates to:
  /// **'is required'**
  String get isRequired;

  /// Email validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get pleaseEnterValidEmail;

  /// Phone validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get pleaseEnterValidPhone;

  /// Number validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get pleaseEnterValidNumber;

  /// Minimum length validation prefix
  ///
  /// In en, this message translates to:
  /// **'must be at least'**
  String get mustBeAtLeast;

  /// Character count unit
  ///
  /// In en, this message translates to:
  /// **'characters'**
  String get characters;

  /// Maximum length validation prefix
  ///
  /// In en, this message translates to:
  /// **'must be no more than'**
  String get mustBeNoMoreThan;

  /// Signature validation message
  ///
  /// In en, this message translates to:
  /// **'Signature is required'**
  String get signatureRequired;

  /// Form submission success message
  ///
  /// In en, this message translates to:
  /// **'Form submitted successfully!'**
  String get formSubmittedSuccessfully;

  /// Form submission error message
  ///
  /// In en, this message translates to:
  /// **'Failed to submit form'**
  String get failedToSubmitForm;

  /// Form data label
  ///
  /// In en, this message translates to:
  /// **'Form Data'**
  String get formData;

  /// Evidence upload description
  ///
  /// In en, this message translates to:
  /// **'Upload supporting evidence for this task (optional)'**
  String get uploadSupportingEvidence;

  /// Status message for uploaded file
  ///
  /// In en, this message translates to:
  /// **'File uploaded'**
  String get fileUploaded;

  /// Success message when evidence is uploaded
  ///
  /// In en, this message translates to:
  /// **'Evidence uploaded successfully!'**
  String get evidenceUploadedSuccessfully;

  /// Evidence upload error message
  ///
  /// In en, this message translates to:
  /// **'Failed to upload evidence'**
  String get failedToUploadEvidence;

  /// Title for submission history screen
  ///
  /// In en, this message translates to:
  /// **'My Submissions'**
  String get mySubmissions;

  /// Type filter label
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// Forms filter option
  ///
  /// In en, this message translates to:
  /// **'Forms'**
  String get forms;

  /// Pending status
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get pending;

  /// Loading text for submissions
  ///
  /// In en, this message translates to:
  /// **'Loading submissions...'**
  String get loadingSubmissions;

  /// Additional fields indicator
  ///
  /// In en, this message translates to:
  /// **'more fields'**
  String get moreFields;

  /// Form type label
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get form;

  /// Empty state title for no submissions
  ///
  /// In en, this message translates to:
  /// **'No Submissions Yet'**
  String get noSubmissionsYet;

  /// Empty state message for submissions
  ///
  /// In en, this message translates to:
  /// **'Your form submissions and evidence uploads will appear here.'**
  String get submissionsWillAppearHere;

  /// User management action
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get userManagement;

  /// Evidence review action
  ///
  /// In en, this message translates to:
  /// **'Evidence Review'**
  String get evidenceReview;

  /// Admin dashboard screen title
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// Search placeholder for user management
  ///
  /// In en, this message translates to:
  /// **'Search by name, email, or username...'**
  String get searchByName;

  /// All users filter option
  ///
  /// In en, this message translates to:
  /// **'All Users'**
  String get allUsers;

  /// Managers only filter option
  ///
  /// In en, this message translates to:
  /// **'Managers Only'**
  String get managersOnly;

  /// Agents only filter option
  ///
  /// In en, this message translates to:
  /// **'Agents Only'**
  String get agentsOnly;

  /// Empty state title when no users found
  ///
  /// In en, this message translates to:
  /// **'No Users Found'**
  String get noUsersFound;

  /// Empty state message when no users match filters
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search or filters'**
  String get tryAdjustingFilters;

  /// Empty state message when no users exist
  ///
  /// In en, this message translates to:
  /// **'Get started by creating your first user'**
  String get createFirstUser;

  /// Create user button text
  ///
  /// In en, this message translates to:
  /// **'Create User'**
  String get createUser;

  /// View details menu option
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// Activate user action
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activate;

  /// Deactivate user action
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivate;

  /// Search placeholder for groups
  ///
  /// In en, this message translates to:
  /// **'Search groups...'**
  String get searchGroups;

  /// Empty state when no groups exist
  ///
  /// In en, this message translates to:
  /// **'No groups found'**
  String get noGroupsFound;

  /// Empty state when no groups match search
  ///
  /// In en, this message translates to:
  /// **'No groups match your search'**
  String get noGroupsMatch;

  /// Empty state message for first group
  ///
  /// In en, this message translates to:
  /// **'Create your first group to get started'**
  String get createFirstGroup;

  /// Create group button text
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroup;

  /// Delete group action
  ///
  /// In en, this message translates to:
  /// **'Delete Group'**
  String get deleteGroup;

  /// Group deletion confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This action cannot be undone.'**
  String confirmDeleteGroup(String name);

  /// Group deletion success message
  ///
  /// In en, this message translates to:
  /// **'Group \"{name}\" deleted successfully'**
  String groupDeleted(String name);

  /// Group deletion error message
  ///
  /// In en, this message translates to:
  /// **'Failed to delete group'**
  String get failedToDeleteGroup;

  /// Good morning greeting
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get goodMorning;

  /// Good afternoon greeting
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get goodAfternoon;

  /// Good evening greeting
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get goodEvening;

  /// System administrator role
  ///
  /// In en, this message translates to:
  /// **'System Administrator'**
  String get systemAdministrator;

  /// Monitor platform description
  ///
  /// In en, this message translates to:
  /// **'Monitor and manage the platform'**
  String get monitorPlatform;

  /// System overview section title
  ///
  /// In en, this message translates to:
  /// **'System Overview'**
  String get systemOverview;

  /// Total managers metric
  ///
  /// In en, this message translates to:
  /// **'Total Managers'**
  String get totalManagers;

  /// Total agents metric
  ///
  /// In en, this message translates to:
  /// **'Total Agents'**
  String get totalAgents;

  /// Active users metric
  ///
  /// In en, this message translates to:
  /// **'Active Users'**
  String get activeUsers;

  /// Total campaigns metric
  ///
  /// In en, this message translates to:
  /// **'Total Campaigns'**
  String get totalCampaigns;

  /// Total tasks metric
  ///
  /// In en, this message translates to:
  /// **'Total Tasks'**
  String get totalTasks;

  /// New this month metric
  ///
  /// In en, this message translates to:
  /// **'New This Month'**
  String get newThisMonth;

  /// Edit action button
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// User label
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// Confirmation question prefix
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to'**
  String get areYouSure;

  /// Warning about irreversible action
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone'**
  String get cannotBeUndone;

  /// Generic error loading data message
  ///
  /// In en, this message translates to:
  /// **'Error loading data'**
  String get errorLoadingData;

  /// Empty state when no evidence exists
  ///
  /// In en, this message translates to:
  /// **'No evidence found'**
  String get noEvidenceFound;

  /// Empty state for managers with no evidence from group members
  ///
  /// In en, this message translates to:
  /// **'No evidence from members in your groups'**
  String get noEvidenceFromMembers;

  /// Empty state when no evidence has been uploaded
  ///
  /// In en, this message translates to:
  /// **'No evidence uploaded yet'**
  String get noEvidenceUploaded;

  /// Info message for managers about evidence filtering
  ///
  /// In en, this message translates to:
  /// **'Showing evidence from all members in your groups'**
  String get showingEvidenceFromMembers;

  /// Error message when refreshing groups fails
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh groups'**
  String get failedToRefreshGroups;

  /// Error message when groups fail to load
  ///
  /// In en, this message translates to:
  /// **'Error loading groups'**
  String get errorLoadingGroups;

  /// Created date prefix for groups
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String createdDate(String date);

  /// Placeholder when no description is provided
  ///
  /// In en, this message translates to:
  /// **'No description provided'**
  String get noDescriptionProvided;

  /// Instruction text for viewing group members
  ///
  /// In en, this message translates to:
  /// **'Tap to view members'**
  String get tapToViewMembers;

  /// Today label
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Yesterday date indicator
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get yesterday;

  /// Days ago date indicator
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgoCount(int count);

  /// Team members label
  ///
  /// In en, this message translates to:
  /// **'Team Members'**
  String get teamMembers;

  /// Search team members placeholder
  ///
  /// In en, this message translates to:
  /// **'Search team members...'**
  String get searchTeamMembers;

  /// Filter option for all members
  ///
  /// In en, this message translates to:
  /// **'All Members'**
  String get allMembers;

  /// Filter option for online members
  ///
  /// In en, this message translates to:
  /// **'Online (Active/Away)'**
  String get onlineActiveAway;

  /// Offline status
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// Error message when team members fail to load
  ///
  /// In en, this message translates to:
  /// **'Unable to load team members'**
  String get unableToLoadTeamMembers;

  /// Empty state when no members found
  ///
  /// In en, this message translates to:
  /// **'No members found'**
  String get noMembersFound;

  /// Empty state when no online members
  ///
  /// In en, this message translates to:
  /// **'No online members'**
  String get noOnlineMembers;

  /// Empty state when no offline members
  ///
  /// In en, this message translates to:
  /// **'No offline members'**
  String get noOfflineMembers;

  /// Empty state when no team members found
  ///
  /// In en, this message translates to:
  /// **'No team members found'**
  String get noTeamMembersFound;

  /// Search results indicator
  ///
  /// In en, this message translates to:
  /// **'Search: \"{query}\"'**
  String searchResults(String query);

  /// Clear all filters button
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// Online status suffix
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get online;

  /// Edit name menu option
  ///
  /// In en, this message translates to:
  /// **'Edit Name'**
  String get editName;

  /// Reset password menu option
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// Edit agent name button
  ///
  /// In en, this message translates to:
  /// **'Edit Agent Name'**
  String get editAgentName;

  /// Away status
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get away;

  /// Earnings screen title
  ///
  /// In en, this message translates to:
  /// **'My Earnings'**
  String get myEarnings;

  /// Error message when earnings fail to load
  ///
  /// In en, this message translates to:
  /// **'Error fetching earnings: {error}'**
  String errorFetchingEarnings(String error);

  /// Empty state for earnings
  ///
  /// In en, this message translates to:
  /// **'No earnings data found.'**
  String get noEarningsDataFound;

  /// Total earnings label
  ///
  /// In en, this message translates to:
  /// **'Total Earned'**
  String get totalEarned;

  /// Total earnings for campaign
  ///
  /// In en, this message translates to:
  /// **'Total for Campaign:'**
  String get totalForCampaign;

  /// Amount already paid
  ///
  /// In en, this message translates to:
  /// **'Already Paid:'**
  String get alreadyPaid;

  /// Outstanding balance for campaign
  ///
  /// In en, this message translates to:
  /// **'Balance for Campaign:'**
  String get balanceForCampaign;

  /// Points paid label
  ///
  /// In en, this message translates to:
  /// **'Points Paid'**
  String get pointsPaid;

  /// Task not started status
  ///
  /// In en, this message translates to:
  /// **'Not Started'**
  String get notStarted;

  /// In area ready to start status
  ///
  /// In en, this message translates to:
  /// **'In Area - Ready to Start'**
  String get inAreaReadyToStart;

  /// Outside area status
  ///
  /// In en, this message translates to:
  /// **'Outside Area'**
  String get outsideArea;

  /// Location check failed status
  ///
  /// In en, this message translates to:
  /// **'Location Check Failed'**
  String get locationCheckFailed;

  /// Task active status
  ///
  /// In en, this message translates to:
  /// **'Task Active'**
  String get taskActive;

  /// Task started message for geofence stay
  ///
  /// In en, this message translates to:
  /// **'Task started! Stay in the area for {minutes} minutes.'**
  String taskStartedStayInArea(int minutes);

  /// Left geofence area warning
  ///
  /// In en, this message translates to:
  /// **'You left the designated area. Task paused.'**
  String get youLeftDesignatedArea;

  /// Returned to geofence area
  ///
  /// In en, this message translates to:
  /// **'Welcome back! Task resumed.'**
  String get welcomeBackTaskResumed;

  /// Task paused status
  ///
  /// In en, this message translates to:
  /// **'Paused - Outside Area'**
  String get pausedOutsideArea;

  /// Early completion dialog title
  ///
  /// In en, this message translates to:
  /// **'Early Completion'**
  String get earlyCompletion;

  /// Early completion confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to complete this task early?'**
  String get earlyCompletionConfirm;

  /// Geofence stay task title
  ///
  /// In en, this message translates to:
  /// **'Geofence Stay Task'**
  String get geofenceStayTask;

  /// Geofence stay task instruction
  ///
  /// In en, this message translates to:
  /// **'Stay in the designated area for the required duration.'**
  String get stayInDesignatedArea;

  /// Required stay duration
  ///
  /// In en, this message translates to:
  /// **'Required Stay: {minutes} minutes'**
  String requiredStay(int minutes);

  /// Location status label
  ///
  /// In en, this message translates to:
  /// **'Location Status'**
  String get locationStatus;

  /// Inside designated area status
  ///
  /// In en, this message translates to:
  /// **'Inside designated area'**
  String get insideDesignatedArea;

  /// Outside designated area status
  ///
  /// In en, this message translates to:
  /// **'Outside designated area'**
  String get outsideDesignatedArea;

  /// Time progress label
  ///
  /// In en, this message translates to:
  /// **'Time Progress'**
  String get timeProgress;

  /// Task start time
  ///
  /// In en, this message translates to:
  /// **'Started: {time}'**
  String started(String time);

  /// Expected completion time
  ///
  /// In en, this message translates to:
  /// **'Expected completion: {time}'**
  String expectedCompletion(String time);

  /// Progress label
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// Complete early button
  ///
  /// In en, this message translates to:
  /// **'Complete Early'**
  String get completeEarly;

  /// Route details screen title
  ///
  /// In en, this message translates to:
  /// **'Route Details'**
  String get routeDetails;

  /// Select start date button text
  ///
  /// In en, this message translates to:
  /// **'Select Start Date'**
  String get selectStartDate;

  /// Select end date button text
  ///
  /// In en, this message translates to:
  /// **'Select End Date'**
  String get selectEndDate;

  /// No places added message
  ///
  /// In en, this message translates to:
  /// **'No places added'**
  String get noPlacesAdded;

  /// Add places to create route message
  ///
  /// In en, this message translates to:
  /// **'Add places to create your route'**
  String get addPlacesToCreateYourRoute;

  /// Visits label
  ///
  /// In en, this message translates to:
  /// **'visits'**
  String get visits;

  /// Loading places message
  ///
  /// In en, this message translates to:
  /// **'Loading places...'**
  String get loadingPlaces;

  /// No approved places available message
  ///
  /// In en, this message translates to:
  /// **'No approved places available. Ask agents to suggest places.'**
  String get noApprovedPlacesAvailableAskAgentsToSuggestPlaces;

  /// Times to visit label
  ///
  /// In en, this message translates to:
  /// **'times to visit'**
  String get timesToVisit;

  /// Agent visit requirement message
  ///
  /// In en, this message translates to:
  /// **'Agent must visit {times} times with a {cooldown}-hour cooldown'**
  String agentMustVisitTimesWithCooldown(int times, int cooldown);

  /// Visit frequency validation message
  ///
  /// In en, this message translates to:
  /// **'Visit frequency must be between 1 and 10'**
  String get visitFrequencyMustBeBetween1And10;

  /// Route place validation message
  ///
  /// In en, this message translates to:
  /// **'Please add at least one place to the route'**
  String get pleaseAddAtLeastOnePlaceToTheRoute;

  /// Route creation success message
  ///
  /// In en, this message translates to:
  /// **'Route created successfully'**
  String get routeCreatedSuccessfully;

  /// Route creation error message
  ///
  /// In en, this message translates to:
  /// **'Error creating route'**
  String get errorCreatingRoute;

  /// Inactive status
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No pending suggestions message
  ///
  /// In en, this message translates to:
  /// **'No pending suggestions'**
  String get noPendingSuggestions;

  /// Agent suggestions empty state message
  ///
  /// In en, this message translates to:
  /// **'Agent suggestions will appear here'**
  String get agentSuggestionsWillAppearHere;

  /// No inactive places message
  ///
  /// In en, this message translates to:
  /// **'No inactive places'**
  String get noInactivePlaces;

  /// Deactivated places empty state message
  ///
  /// In en, this message translates to:
  /// **'Deactivated places will appear here'**
  String get deactivatedPlacesWillAppearHere;

  /// Places empty state message
  ///
  /// In en, this message translates to:
  /// **'Places will appear here once added'**
  String get placesWillAppearHereOnceAdded;

  /// Suggested by label
  ///
  /// In en, this message translates to:
  /// **'Suggested by'**
  String get suggestedBy;

  /// Inactive place warning message
  ///
  /// In en, this message translates to:
  /// **'This place is inactive and hidden from new routes'**
  String get thisPlaceIsInactiveAndHiddenFromNewRoutes;

  /// Reactivate button text
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get reactivate;

  /// Suggestion label
  ///
  /// In en, this message translates to:
  /// **'Suggestion'**
  String get suggestion;

  /// Reject confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reject'**
  String get areYouSureYouWantToReject;

  /// Rejection reason hint
  ///
  /// In en, this message translates to:
  /// **'Explain why this place was rejected'**
  String get explainWhyThisPlaceWasRejected;

  /// New place title
  ///
  /// In en, this message translates to:
  /// **'New Place'**
  String get newPlace;

  /// Place name validation message
  ///
  /// In en, this message translates to:
  /// **'Place name is required'**
  String get placeNameIsRequired;

  /// Place description hint
  ///
  /// In en, this message translates to:
  /// **'Brief description of the place'**
  String get briefDescriptionOfThePlace;

  /// Physical address label
  ///
  /// In en, this message translates to:
  /// **'Physical address'**
  String get physicalAddress;

  /// Location selected message
  ///
  /// In en, this message translates to:
  /// **'Location selected'**
  String get locationSelected;

  /// Manager place approval info
  ///
  /// In en, this message translates to:
  /// **'Manager-created places are automatically approved and ready for use'**
  String get managerCreatedPlacesAreAutomaticallyApprovedAndReadyForUse;

  /// Cannot remove place title
  ///
  /// In en, this message translates to:
  /// **'Cannot remove place'**
  String get cannotRemovePlace;

  /// Cannot delete place message
  ///
  /// In en, this message translates to:
  /// **'The place cannot be deleted because it has historical data or is currently in use'**
  String
      get thePlaceCannotBeDeletedBecauseItHasHistoricalDataOrIsCurrentlyInUse;

  /// Used in routes label
  ///
  /// In en, this message translates to:
  /// **'Used in routes'**
  String get usedInRoutes;

  /// Has historical records label
  ///
  /// In en, this message translates to:
  /// **'Has historical visit records'**
  String get hasHistoricalVisitRecords;

  /// Remove from routes instruction
  ///
  /// In en, this message translates to:
  /// **'Remove this place from all routes first'**
  String get removeThisPlaceFromAllRoutesFirst;

  /// Mark inactive suggestion
  ///
  /// In en, this message translates to:
  /// **'Mark the place as inactive to hide it from new routes while preserving history'**
  String get markThePlaceAsInactiveToHideItFromNewRoutesWhilePreservingHistory;

  /// Go to button text
  ///
  /// In en, this message translates to:
  /// **'Go to'**
  String get goTo;

  /// Permanent remove confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently remove'**
  String get areYouSureYouWantToPermanentlyRemove;

  /// Safe delete message
  ///
  /// In en, this message translates to:
  /// **'This place is not used in any routes or visits and can be safely deleted'**
  String get thisPlaceIsNotUsedInAnyRoutesOrVisitsAndCanBeSafelyDeleted;

  /// Permanent delete warning
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. The place will be permanently deleted from the system'**
  String
      get thisActionCannotBeUndoneThePlaceWillBePermanentlyDeletedFromTheSystem;

  /// Deactivate confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to deactivate'**
  String get areYouSureYouWantToDeactivate;

  /// Deactivate explanation
  ///
  /// In en, this message translates to:
  /// **'The place will be hidden from new routes but all historical data will be preserved. You can reactivate it later'**
  String
      get thePlaceWillBeHiddenFromNewRoutesButAllHistoricalDataWillBePreservedYouCanReactivateItLater;

  /// Edit location button text
  ///
  /// In en, this message translates to:
  /// **'Edit Location'**
  String get editLocation;

  /// No groups found message
  ///
  /// In en, this message translates to:
  /// **'No groups found for this manager'**
  String get noGroupsFoundForThisManager;

  /// No available places message
  ///
  /// In en, this message translates to:
  /// **'No available places to add to this route'**
  String get noAvailablePlacesToAddToThisRoute;

  /// Error loading places message
  ///
  /// In en, this message translates to:
  /// **'Error loading available places'**
  String get errorLoadingAvailablePlaces;

  /// Place added success message
  ///
  /// In en, this message translates to:
  /// **'Place added to route successfully'**
  String get placeAddedToRouteSuccessfully;

  /// Error adding place message
  ///
  /// In en, this message translates to:
  /// **'Error adding place to route'**
  String get errorAddingPlaceToRoute;

  /// Created by label
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get createdBy;

  /// Evidence required format
  ///
  /// In en, this message translates to:
  /// **'{current}/{required} evidence required'**
  String evidenceRequiredFormat(String current, String required);

  /// Evidence files format
  ///
  /// In en, this message translates to:
  /// **'{count} evidence file(s)'**
  String evidenceFilesFormat(String count);

  /// Evidence count requirement text
  ///
  /// In en, this message translates to:
  /// **'{count} evidence required'**
  String evidenceRequiredCount(String count);

  /// Empty state for route places
  ///
  /// In en, this message translates to:
  /// **'No places found in this route'**
  String get noPlacesFound;

  /// Places to visit section
  ///
  /// In en, this message translates to:
  /// **'Places to Visit'**
  String get placesToVisit;

  /// Time spent label
  ///
  /// In en, this message translates to:
  /// **'Time Spent'**
  String get timeSpent;

  /// Route progress section
  ///
  /// In en, this message translates to:
  /// **'Route Progress'**
  String get routeProgress;

  /// Cooldown period active
  ///
  /// In en, this message translates to:
  /// **'Cooldown active'**
  String get cooldownActive;

  /// Next visit availability
  ///
  /// In en, this message translates to:
  /// **'Next visit available in {hours} hours'**
  String nextVisitAvailable(int hours);

  /// Currently active visit message
  ///
  /// In en, this message translates to:
  /// **'Currently Active - See top card for actions'**
  String get currentlyActiveSeeTop;

  /// All visits completed message
  ///
  /// In en, this message translates to:
  /// **'All {count} visits completed'**
  String allVisitsCompleted(int count);

  /// Complete previous places instruction
  ///
  /// In en, this message translates to:
  /// **'Complete previous places first'**
  String get completePreviousPlacesFirst;

  /// Waiting status
  ///
  /// In en, this message translates to:
  /// **'Waiting...'**
  String get waiting;

  /// Visit count display
  ///
  /// In en, this message translates to:
  /// **'Visit {current}/{total}'**
  String visitCount(int current, int total);

  /// Not visited status
  ///
  /// In en, this message translates to:
  /// **'Not visited'**
  String get notVisited;

  /// Error loading route details
  ///
  /// In en, this message translates to:
  /// **'Error loading route details'**
  String get errorLoadingRouteDetails;

  /// Not authenticated status
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get notAuthenticated;

  /// Already checked in status
  ///
  /// In en, this message translates to:
  /// **'Already checked in'**
  String get alreadyCheckedIn;

  /// All visits completed status
  ///
  /// In en, this message translates to:
  /// **'All visits completed'**
  String get allVisitsCompletedStatus;

  /// Error checking availability
  ///
  /// In en, this message translates to:
  /// **'Error checking availability'**
  String get errorCheckingAvailability;

  /// Notes label with content
  ///
  /// In en, this message translates to:
  /// **'Notes: {notes}'**
  String notes(String notes);

  /// Zone label with number
  ///
  /// In en, this message translates to:
  /// **'Zone {number}'**
  String zone(int number);

  /// No location set title
  ///
  /// In en, this message translates to:
  /// **'No Location Set'**
  String get noLocationSet;

  /// Task has location name but no geofence
  ///
  /// In en, this message translates to:
  /// **'This task has a location name but no geofence area defined. You can submit evidence from any location.'**
  String get taskHasLocationNameButNoGeofence;

  /// Manager has not set location
  ///
  /// In en, this message translates to:
  /// **'The manager has not set a specific location or geofence for this task. You can submit evidence from any location.'**
  String get managerNotSetLocation;

  /// Geofence areas title
  ///
  /// In en, this message translates to:
  /// **'Geofence Areas'**
  String get geofenceAreas;

  /// Default name for unnamed campaign
  ///
  /// In en, this message translates to:
  /// **'Unnamed Campaign'**
  String get unnamedCampaign;

  /// Default name for unnamed task
  ///
  /// In en, this message translates to:
  /// **'Unnamed Task'**
  String get unnamedTask;

  /// Work areas title
  ///
  /// In en, this message translates to:
  /// **'Work Areas'**
  String get workAreas;

  /// No zones available title
  ///
  /// In en, this message translates to:
  /// **'No Zones Available'**
  String get noZonesAvailable;

  /// Not assigned to zones message
  ///
  /// In en, this message translates to:
  /// **'You are not assigned to any campaigns or tasks with geofenced zones.'**
  String get notAssignedToZones;

  /// Task zone label
  ///
  /// In en, this message translates to:
  /// **'Task Zone'**
  String get taskZone;

  /// Campaign zone label
  ///
  /// In en, this message translates to:
  /// **'Campaign Zone'**
  String get campaignZone;

  /// Background services label
  ///
  /// In en, this message translates to:
  /// **'Background Services'**
  String get backgroundServices;

  /// Location tracking active status
  ///
  /// In en, this message translates to:
  /// **'Location tracking and status active'**
  String get locationTrackingActive;

  /// Services stopped status
  ///
  /// In en, this message translates to:
  /// **'Services are stopped'**
  String get servicesAreStopped;

  /// Same as yesterday label
  ///
  /// In en, this message translates to:
  /// **'Same as yesterday'**
  String get sameAsYesterday;

  /// Create campaign button and title
  ///
  /// In en, this message translates to:
  /// **'Create Campaign'**
  String get createCampaign;

  /// New campaign title
  ///
  /// In en, this message translates to:
  /// **'New Campaign'**
  String get newCampaign;

  /// Edit campaign subtitle
  ///
  /// In en, this message translates to:
  /// **'Update campaign details'**
  String get updateCampaignDetails;

  /// Create campaign subtitle
  ///
  /// In en, this message translates to:
  /// **'Create a new campaign for your team'**
  String get createNewCampaignForTeam;

  /// Campaign name field label
  ///
  /// In en, this message translates to:
  /// **'Campaign Name'**
  String get campaignName;

  /// Campaign name validation message
  ///
  /// In en, this message translates to:
  /// **'Campaign name is required'**
  String get campaignNameRequired;

  /// Manager assignment field label
  ///
  /// In en, this message translates to:
  /// **'Assign to Manager'**
  String get assignToManager;

  /// Manager assignment field hint
  ///
  /// In en, this message translates to:
  /// **'Select a manager to oversee this campaign'**
  String get selectManagerToOversee;

  /// No manager option
  ///
  /// In en, this message translates to:
  /// **'No specific manager'**
  String get noSpecificManager;

  /// Manager assignment information
  ///
  /// In en, this message translates to:
  /// **'This campaign will be assigned to the selected manager. Only they and their agents will be able to see and work on this campaign.'**
  String get campaignAssignmentInfo;

  /// Start date field label
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// End date field label
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// Update campaign button text
  ///
  /// In en, this message translates to:
  /// **'Update Campaign'**
  String get updateCampaign;

  /// Date validation message
  ///
  /// In en, this message translates to:
  /// **'Please select both start and end dates.'**
  String get pleaseSelectBothStartEndDates;

  /// Date range validation message
  ///
  /// In en, this message translates to:
  /// **'End date cannot be before the start date.'**
  String get endDateCannotBeforeStartDate;

  /// Campaign update success message
  ///
  /// In en, this message translates to:
  /// **'Campaign updated successfully!'**
  String get campaignUpdatedSuccessfully;

  /// Campaign creation success message
  ///
  /// In en, this message translates to:
  /// **'Campaign created successfully!'**
  String get campaignCreatedSuccessfully;

  /// Campaign creation error message
  ///
  /// In en, this message translates to:
  /// **'Failed to create campaign. Please try again.'**
  String get failedToCreateCampaign;

  /// New evidence task title
  ///
  /// In en, this message translates to:
  /// **'New Evidence Task'**
  String get newEvidenceTask;

  /// Edit evidence task title
  ///
  /// In en, this message translates to:
  /// **'Edit Evidence Task'**
  String get editEvidenceTask;

  /// Core information section title
  ///
  /// In en, this message translates to:
  /// **'Core Information'**
  String get coreInformation;

  /// Task name field label
  ///
  /// In en, this message translates to:
  /// **'Task Name'**
  String get taskName;

  /// Location name field label
  ///
  /// In en, this message translates to:
  /// **'Location Name'**
  String get locationName;

  /// Start date and time field label
  ///
  /// In en, this message translates to:
  /// **'Start Date/Time'**
  String get startDateTime;

  /// End date and time field label
  ///
  /// In en, this message translates to:
  /// **'End Date/Time'**
  String get endDateTime;

  /// Rules and completion section title
  ///
  /// In en, this message translates to:
  /// **'Rules & Completion'**
  String get rulesCompletion;

  /// Evidence count field label
  ///
  /// In en, this message translates to:
  /// **'Required Evidence Count'**
  String get requiredEvidenceCount;

  /// Number validation message
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get invalidNumber;

  /// Task points toggle label
  ///
  /// In en, this message translates to:
  /// **'Enable Task Points'**
  String get enableTaskPoints;

  /// Points field label
  ///
  /// In en, this message translates to:
  /// **'Points Awarded'**
  String get pointsAwarded;

  /// Points field hint
  ///
  /// In en, this message translates to:
  /// **'e.g., 10, 50, 100'**
  String get pointsAwardedHint;

  /// Positive number validation message
  ///
  /// In en, this message translates to:
  /// **'Must be a positive number'**
  String get mustBePositiveNumber;

  /// Geofence enforcement toggle label
  ///
  /// In en, this message translates to:
  /// **'Enforce Geofence for Upload'**
  String get enforceGeofenceForUpload;

  /// Geofence enforcement description active
  ///
  /// In en, this message translates to:
  /// **'Agent must be inside the zone to upload'**
  String get agentMustBeInsideZone;

  /// Geofence enforcement description inactive
  ///
  /// In en, this message translates to:
  /// **'Uploads allowed from anywhere'**
  String get uploadsAllowedAnywhere;

  /// Manager assignment section title
  ///
  /// In en, this message translates to:
  /// **'Manager Assignment'**
  String get managerAssignment;

  /// Task manager assignment information
  ///
  /// In en, this message translates to:
  /// **'This task will be assigned to the selected manager. Only they and their agents will be able to see and work on this task.'**
  String get taskAssignmentInfo;

  /// Geofencing section title
  ///
  /// In en, this message translates to:
  /// **'Geofencing'**
  String get geofencing;

  /// Geofence editor button text
  ///
  /// In en, this message translates to:
  /// **'Define Geofence Zone'**
  String get defineGeofenceZone;

  /// Save task before geofence message
  ///
  /// In en, this message translates to:
  /// **'Must save task before adding geofence'**
  String get mustSaveTaskBeforeGeofence;

  /// Save changes button text
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// Save and continue button text
  ///
  /// In en, this message translates to:
  /// **'Save & Continue'**
  String get saveContinue;

  /// Task creation success message
  ///
  /// In en, this message translates to:
  /// **'Task created successfully.'**
  String get taskCreatedSuccessfully;

  /// Task edit success message
  ///
  /// In en, this message translates to:
  /// **'Task details saved.'**
  String get taskDetailsSaved;

  /// Task save error message prefix
  ///
  /// In en, this message translates to:
  /// **'Failed to save task'**
  String get failedToSaveTask;

  /// Create from template title
  ///
  /// In en, this message translates to:
  /// **'Create from {templateName}'**
  String createFromTemplate(String templateName);

  /// Template loading error message
  ///
  /// In en, this message translates to:
  /// **'Error loading template details'**
  String get errorLoadingTemplateDetails;

  /// Task details section title
  ///
  /// In en, this message translates to:
  /// **'Task Details'**
  String get taskDetails;

  /// Task title field label with required indicator
  ///
  /// In en, this message translates to:
  /// **'Task Title *'**
  String get taskTitleRequired;

  /// Task title field hint
  ///
  /// In en, this message translates to:
  /// **'Enter a descriptive title for this task'**
  String get enterDescriptiveTitle;

  /// Task title validation message
  ///
  /// In en, this message translates to:
  /// **'Task title is required'**
  String get taskTitleIsRequired;

  /// Task description field hint
  ///
  /// In en, this message translates to:
  /// **'Optional: Add more details about this task'**
  String get addMoreDetailsOptional;

  /// Location name field hint
  ///
  /// In en, this message translates to:
  /// **'Optional: Name of the location (e.g., Main Hospital)'**
  String get locationNameOptional;

  /// Configuration section title
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get configuration;

  /// Points validation message
  ///
  /// In en, this message translates to:
  /// **'Points required'**
  String get pointsRequired;

  /// Positive validation message
  ///
  /// In en, this message translates to:
  /// **'Must be positive'**
  String get mustBePositive;

  /// Evidence files field label
  ///
  /// In en, this message translates to:
  /// **'Evidence Files'**
  String get evidenceFiles;

  /// Evidence count validation message
  ///
  /// In en, this message translates to:
  /// **'Evidence count required'**
  String get evidenceCountRequired;

  /// Minimum value validation message
  ///
  /// In en, this message translates to:
  /// **'Must be at least 1'**
  String get mustBeAtLeastOne;

  /// Location verification toggle label
  ///
  /// In en, this message translates to:
  /// **'Require Location Verification'**
  String get requireLocationVerification;

  /// Location verification description
  ///
  /// In en, this message translates to:
  /// **'Agent must be at the correct location to submit evidence'**
  String get agentMustBeAtCorrectLocation;

  /// Geofence configured status
  ///
  /// In en, this message translates to:
  /// **'Geofence configured ({pointCount} points)'**
  String geofenceConfigured(int pointCount);

  /// Geofence not configured status
  ///
  /// In en, this message translates to:
  /// **'Geofence not set'**
  String get geofenceNotSet;

  /// Set geofence button text
  ///
  /// In en, this message translates to:
  /// **'Set Geofence'**
  String get setGeofence;

  /// Geofence area description
  ///
  /// In en, this message translates to:
  /// **'Define the area where agents must be located to complete this task.'**
  String get defineAreaForAgents;

  /// Additional information section title
  ///
  /// In en, this message translates to:
  /// **'Additional Information'**
  String get additionalInformation;

  /// Template additional info description
  ///
  /// In en, this message translates to:
  /// **'This template requires additional information to be collected from agents.'**
  String get templateRequiresAdditionalInfo;

  /// Custom form fields section title
  ///
  /// In en, this message translates to:
  /// **'Custom Form Fields'**
  String get customFormFields;

  /// Add field button
  ///
  /// In en, this message translates to:
  /// **'Add Field'**
  String get addField;

  /// Custom fields creation info
  ///
  /// In en, this message translates to:
  /// **'Create custom fields that agents will fill out when completing this task'**
  String get createCustomFieldsInfo;

  /// No custom fields empty state
  ///
  /// In en, this message translates to:
  /// **'No custom fields yet'**
  String get noCustomFieldsYet;

  /// Add field instruction
  ///
  /// In en, this message translates to:
  /// **'Click \"Add Field\" to create form fields'**
  String get clickAddFieldToCreate;

  /// Edit field dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Field'**
  String get editField;

  /// Add custom field dialog title
  ///
  /// In en, this message translates to:
  /// **'Add Custom Field'**
  String get addCustomField;

  /// Field label input label
  ///
  /// In en, this message translates to:
  /// **'Field Label*'**
  String get fieldLabelRequired;

  /// Field label input hint
  ///
  /// In en, this message translates to:
  /// **'e.g., Customer Name, Satisfaction Level'**
  String get fieldLabelHint;

  /// Field type dropdown label
  ///
  /// In en, this message translates to:
  /// **'Field Type'**
  String get fieldType;

  /// Placeholder text input label
  ///
  /// In en, this message translates to:
  /// **'Placeholder Text (Optional)'**
  String get placeholderTextOptional;

  /// Placeholder text input hint
  ///
  /// In en, this message translates to:
  /// **'Hint text shown in the field'**
  String get hintTextShownInField;

  /// Field options input label
  ///
  /// In en, this message translates to:
  /// **'Options (comma separated)*'**
  String get optionsCommaSeparated;

  /// Field options input hint
  ///
  /// In en, this message translates to:
  /// **'Option 1, Option 2, Option 3'**
  String get optionsHint;

  /// Required field checkbox description
  ///
  /// In en, this message translates to:
  /// **'Agent must fill this field'**
  String get agentMustFillField;

  /// Field label validation message
  ///
  /// In en, this message translates to:
  /// **'Field label is required'**
  String get fieldLabelIsRequired;

  /// Field options validation message
  ///
  /// In en, this message translates to:
  /// **'Options are required for this field type'**
  String get optionsRequiredForFieldType;

  /// Update button
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// Add button text
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Creating task loading text
  ///
  /// In en, this message translates to:
  /// **'Creating Task...'**
  String get creatingTask;

  /// Create task button text
  ///
  /// In en, this message translates to:
  /// **'Create Task'**
  String get createTask;

  /// Validation errors dialog title
  ///
  /// In en, this message translates to:
  /// **'Validation Errors'**
  String get validationErrors;

  /// Set up geofence dialog title
  ///
  /// In en, this message translates to:
  /// **'Set Up Geofence'**
  String get setUpGeofence;

  /// Geofence setup dialog message
  ///
  /// In en, this message translates to:
  /// **'This task requires a location boundary. Would you like to set up the geofence now?'**
  String get taskRequiresLocationBoundary;

  /// Skip button text
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Set up now button text
  ///
  /// In en, this message translates to:
  /// **'Set Up Now'**
  String get setUpNow;

  /// Set geofence screen title
  ///
  /// In en, this message translates to:
  /// **'Set Geofence - {taskTitle}'**
  String setGeofenceTaskTitle(String taskTitle);

  /// Clear points tooltip
  ///
  /// In en, this message translates to:
  /// **'Clear all points'**
  String get clearAllPoints;

  /// Map interaction instruction
  ///
  /// In en, this message translates to:
  /// **'Tap on the map to add points. You need at least 3 points to create a geofence.'**
  String get tapMapToAddPoints;

  /// Points added status
  ///
  /// In en, this message translates to:
  /// **'{pointCount} points added'**
  String pointsAdded(int pointCount);

  /// Ready to save button text
  ///
  /// In en, this message translates to:
  /// **'Ready to Save'**
  String get readyToSave;

  /// Save geofence button text
  ///
  /// In en, this message translates to:
  /// **'Save Geofence'**
  String get saveGeofence;

  /// Minimum points validation message
  ///
  /// In en, this message translates to:
  /// **'Please add at least 3 points to create a geofence'**
  String get addAtLeastThreePoints;

  /// Campaign report screen title
  ///
  /// In en, this message translates to:
  /// **'Campaign Report'**
  String get campaignReport;

  /// Campaign progress section title
  ///
  /// In en, this message translates to:
  /// **'Campaign Progress'**
  String get campaignProgress;

  /// Tasks completed label
  ///
  /// In en, this message translates to:
  /// **'Tasks Completed'**
  String get tasksCompleted;

  /// Total points earned metric
  ///
  /// In en, this message translates to:
  /// **'Total Points Earned'**
  String get totalPointsEarned;

  /// No report data message
  ///
  /// In en, this message translates to:
  /// **'No report data available.'**
  String get noReportDataAvailable;

  /// Recent visits tab title
  ///
  /// In en, this message translates to:
  /// **'Recent Visits'**
  String get recentVisits;

  /// Total visits metric
  ///
  /// In en, this message translates to:
  /// **'Total Visits'**
  String get totalVisits;

  /// Active now status
  ///
  /// In en, this message translates to:
  /// **'Active Now'**
  String get activeNow;

  /// Total hours metric
  ///
  /// In en, this message translates to:
  /// **'Total Hours'**
  String get totalHours;

  /// Quick stats section title
  ///
  /// In en, this message translates to:
  /// **'Quick Stats'**
  String get quickStats;

  /// Average visit duration text
  ///
  /// In en, this message translates to:
  /// **'Average visit duration: {duration} minutes'**
  String averageVisitDuration(int duration);

  /// Active route assignments text
  ///
  /// In en, this message translates to:
  /// **'Active route assignments: {count}'**
  String activeRouteAssignments(int count);

  /// No recent visits message
  ///
  /// In en, this message translates to:
  /// **'No recent visits found'**
  String get noRecentVisitsFound;

  /// Checked in status
  ///
  /// In en, this message translates to:
  /// **'Checked In'**
  String get checkedIn;

  /// Unknown place fallback text
  ///
  /// In en, this message translates to:
  /// **'Unknown Place'**
  String get unknownPlace;

  /// Unknown text
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No active route assignments message
  ///
  /// In en, this message translates to:
  /// **'No active route assignments'**
  String get noActiveRouteAssignments;

  /// Assignment details coming soon message
  ///
  /// In en, this message translates to:
  /// **'Assignment details - Coming soon!'**
  String get assignmentDetails;

  /// Management overview section title
  ///
  /// In en, this message translates to:
  /// **'Management Overview'**
  String get managementOverview;

  /// Route management section title
  ///
  /// In en, this message translates to:
  /// **'Route Management'**
  String get routeManagement;

  /// Create and manage routes description
  ///
  /// In en, this message translates to:
  /// **'Create & manage routes'**
  String get createManageRoutes;

  /// Place management section title
  ///
  /// In en, this message translates to:
  /// **'Place Management'**
  String get placeManagement;

  /// Approve agent suggestions description
  ///
  /// In en, this message translates to:
  /// **'Approve agent suggestions'**
  String get approveAgentSuggestions;

  /// Live map section title
  ///
  /// In en, this message translates to:
  /// **'Live Map'**
  String get liveMap;

  /// Track agents in real-time description
  ///
  /// In en, this message translates to:
  /// **'Track agents in real-time'**
  String get trackAgentsRealTime;

  /// Manage tasks action
  ///
  /// In en, this message translates to:
  /// **'Manage Tasks'**
  String get manageTasks;

  /// Review evidence action
  ///
  /// In en, this message translates to:
  /// **'Review Evidence'**
  String get reviewEvidence;

  /// Routes and places action
  ///
  /// In en, this message translates to:
  /// **'Routes & Places'**
  String get routesPlaces;

  /// Calendar action
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// Location history action
  ///
  /// In en, this message translates to:
  /// **'Location History'**
  String get locationHistory;

  /// Send notification action
  ///
  /// In en, this message translates to:
  /// **'Send Notification'**
  String get sendNotification;

  /// Message users description
  ///
  /// In en, this message translates to:
  /// **'Message users'**
  String get messageUsers;

  /// Loading dashboard message
  ///
  /// In en, this message translates to:
  /// **'Loading dashboard...'**
  String get loadingDashboard;

  /// Welcome text
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// Manager dashboard title
  ///
  /// In en, this message translates to:
  /// **'Manager Dashboard'**
  String get managerDashboard;

  /// System tasks action
  ///
  /// In en, this message translates to:
  /// **'System Tasks'**
  String get systemTasks;

  /// Templates action
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templates;

  /// Manager performance section title
  ///
  /// In en, this message translates to:
  /// **'Manager Performance'**
  String get managerPerformance;

  /// Label for touring tasks count
  ///
  /// In en, this message translates to:
  /// **'Touring Tasks'**
  String get touringTasks;

  /// Touring tasks progress section title
  ///
  /// In en, this message translates to:
  /// **'Touring Tasks Progress'**
  String get touringTasksProgress;

  /// Message when agent has no touring tasks
  ///
  /// In en, this message translates to:
  /// **'No Touring Tasks Assigned'**
  String get noTouringTasksAssigned;

  /// Description when agent has no touring tasks
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any touring tasks assigned yet. Check back later or contact your manager.'**
  String get noTouringTasksDescription;

  /// Refresh button text
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Work zone label
  ///
  /// In en, this message translates to:
  /// **'Work Zone'**
  String get workZone;

  /// Movement timeout label
  ///
  /// In en, this message translates to:
  /// **'Movement Timeout'**
  String get movementTimeout;

  /// Task requirements section title
  ///
  /// In en, this message translates to:
  /// **'Task Requirements'**
  String get taskRequirements;

  /// Requirement to spend time in work zone
  ///
  /// In en, this message translates to:
  /// **'Spend {duration} inside the work zone'**
  String spendTimeInWorkZone(String duration);

  /// Requirement to keep moving
  ///
  /// In en, this message translates to:
  /// **'Keep moving (timer pauses after {timeout} of inactivity)'**
  String keepMovingTimer(String timeout);

  /// Movement threshold information
  ///
  /// In en, this message translates to:
  /// **'Movement threshold: {threshold}m'**
  String movementThreshold(String threshold);

  /// Status when location is active
  ///
  /// In en, this message translates to:
  /// **'Location Active'**
  String get locationActive;

  /// Status when location is unknown
  ///
  /// In en, this message translates to:
  /// **'Location Unknown'**
  String get locationUnknown;

  /// Status when agent is moving
  ///
  /// In en, this message translates to:
  /// **'Moving'**
  String get moving;

  /// Status when agent is not moving
  ///
  /// In en, this message translates to:
  /// **'Not Moving'**
  String get notMoving;

  /// Timer paused message with reason
  ///
  /// In en, this message translates to:
  /// **'Timer Paused: {reason}'**
  String timerPaused(String reason);

  /// Required time label
  ///
  /// In en, this message translates to:
  /// **'Required Time'**
  String get requiredTime;

  /// Online now metric
  ///
  /// In en, this message translates to:
  /// **'Online Now'**
  String get onlineNow;

  /// Top performers metric
  ///
  /// In en, this message translates to:
  /// **'Top Performers'**
  String get topPerformers;

  /// Top performing managers section title
  ///
  /// In en, this message translates to:
  /// **'Top Performing Managers'**
  String get topPerformingManagers;

  /// System performance section title
  ///
  /// In en, this message translates to:
  /// **'System Performance'**
  String get systemPerformance;

  /// Weekly tasks metric
  ///
  /// In en, this message translates to:
  /// **'Weekly Tasks'**
  String get weeklyTasks;

  /// Completed this week description
  ///
  /// In en, this message translates to:
  /// **'Completed this week'**
  String get completedThisWeek;

  /// Monthly tasks metric
  ///
  /// In en, this message translates to:
  /// **'Monthly Tasks'**
  String get monthlyTasks;

  /// Completed this month description
  ///
  /// In en, this message translates to:
  /// **'Completed this month'**
  String get completedThisMonth;

  /// Approval rate metric
  ///
  /// In en, this message translates to:
  /// **'Approval Rate'**
  String get approvalRate;

  /// Evidence quality description
  ///
  /// In en, this message translates to:
  /// **'Evidence quality'**
  String get evidenceQuality;

  /// System health metric
  ///
  /// In en, this message translates to:
  /// **'System Health'**
  String get systemHealth;

  /// Overall status description
  ///
  /// In en, this message translates to:
  /// **'Overall status'**
  String get overallStatus;

  /// Recent system activity section title
  ///
  /// In en, this message translates to:
  /// **'Recent System Activity'**
  String get recentSystemActivity;

  /// No recent activity message
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get noRecentActivity;

  /// Loading with ellipsis
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadingEllipsis;

  /// Error loading route data message
  ///
  /// In en, this message translates to:
  /// **'Error loading route data'**
  String get errorLoadingRouteData;

  /// Dialog title when user's account is active on another device
  ///
  /// In en, this message translates to:
  /// **'Another Device Active'**
  String get anotherDeviceActive;

  /// Message explaining account is logged in on another device
  ///
  /// In en, this message translates to:
  /// **'Your account is currently logged in on another device.'**
  String get accountLoggedInElsewhere;

  /// Instruction for logging out from other device
  ///
  /// In en, this message translates to:
  /// **'To continue logging in on this device, you need to logout from the other device first.'**
  String get logoutOtherDeviceInstruction;

  /// Button text to logout from other device
  ///
  /// In en, this message translates to:
  /// **'Logout Other Device'**
  String get logoutOtherDevice;

  /// GPS status message for no signal
  ///
  /// In en, this message translates to:
  /// **'No GPS signal (1 bar)'**
  String get noGpsSignalOnebar;

  /// GPS status message for excellent signal
  ///
  /// In en, this message translates to:
  /// **'Excellent GPS ({accuracy}m) - 5 bars'**
  String excellentGpsFiveBars(String accuracy);

  /// GPS status message for good signal
  ///
  /// In en, this message translates to:
  /// **'Good GPS ({accuracy}m) - 4 bars'**
  String goodGpsFourBars(String accuracy);

  /// GPS status message for fair signal
  ///
  /// In en, this message translates to:
  /// **'Fair GPS ({accuracy}m) - 3 bars'**
  String fairGpsThreeBars(String accuracy);

  /// GPS status message for poor signal
  ///
  /// In en, this message translates to:
  /// **'Poor GPS ({accuracy}m) - 2 bars'**
  String poorGpsTwoBars(String accuracy);

  /// GPS status message for very poor signal
  ///
  /// In en, this message translates to:
  /// **'Very poor GPS ({accuracy}m) - 1 bar'**
  String veryPoorGpsOnebar(String accuracy);

  /// Status message when downloading app update
  ///
  /// In en, this message translates to:
  /// **'Downloading update...'**
  String get downloadingUpdate;

  /// Status message when download is complete
  ///
  /// In en, this message translates to:
  /// **'Download complete. Ready to install.'**
  String get downloadCompleteReadyToInstall;

  /// Status message when installing update
  ///
  /// In en, this message translates to:
  /// **'Installing update...'**
  String get installingUpdate;

  /// Installation guidance message
  ///
  /// In en, this message translates to:
  /// **'Installation started. If you see a security scan dialog, tap \"Install without scanning\" to proceed quickly.'**
  String get installationStartedSecurityDialog;

  /// Error message when update download fails
  ///
  /// In en, this message translates to:
  /// **'Failed to download update. Please try again.'**
  String get failedToDownloadUpdate;

  /// Generic update error message
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String updateError(String error);

  /// Update dialog title
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailable;

  /// Label for current version
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get current;

  /// Label for new version
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newVersion;

  /// Section title for release notes
  ///
  /// In en, this message translates to:
  /// **'What\'s New'**
  String get whatsNew;

  /// Download size information
  ///
  /// In en, this message translates to:
  /// **'Download size: {size} MB'**
  String downloadSize(String size);

  /// Button text when update is in progress
  ///
  /// In en, this message translates to:
  /// **'Updating...'**
  String get updating;

  /// Button text to start update
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// Label for required title field
  ///
  /// In en, this message translates to:
  /// **'Title *'**
  String get titleRequired;

  /// Hint text for evidence title field
  ///
  /// In en, this message translates to:
  /// **'Enter a title for this evidence'**
  String get enterTitleForEvidence;

  /// Validation message for required title
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleIsRequired;

  /// Validation message for minimum title length
  ///
  /// In en, this message translates to:
  /// **'Title must be at least 3 characters'**
  String get titleMinLength;

  /// Hint text for optional description field
  ///
  /// In en, this message translates to:
  /// **'Optional description or notes'**
  String get optionalDescriptionOrNotes;

  /// Upload progress message
  ///
  /// In en, this message translates to:
  /// **'Uploading... {progress}%'**
  String uploadingProgress(int progress);

  /// Error message for oversized files
  ///
  /// In en, this message translates to:
  /// **'File too large. Maximum size is 50MB.'**
  String get fileTooLargeMaxSize;

  /// Error message when file selection fails
  ///
  /// In en, this message translates to:
  /// **'Error selecting file: {error}'**
  String errorSelectingFile(String error);

  /// Error message when file has no data
  ///
  /// In en, this message translates to:
  /// **'File has no data'**
  String get fileHasNoData;

  /// Place noun
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get place;

  /// Evidence number label
  ///
  /// In en, this message translates to:
  /// **'Evidence {number}'**
  String evidenceNumber(String number);

  /// Message showing evidence requirements
  ///
  /// In en, this message translates to:
  /// **'Evidence Required: {remaining} more needed ({current}/{total})'**
  String evidenceRequiredProgress(
      String remaining, String current, String total);

  /// Message showing evidence completion
  ///
  /// In en, this message translates to:
  /// **'Evidence Complete: {current}/{total} submitted'**
  String evidenceComplete(String current, String total);

  /// Evidence title required field label
  ///
  /// In en, this message translates to:
  /// **'Evidence Title (Required)'**
  String get evidenceTitleRequired;

  /// Hint text for evidence notes field
  ///
  /// In en, this message translates to:
  /// **'Optional notes about this evidence'**
  String get optionalNotesAboutEvidence;

  /// Instructions label
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructions;

  /// Button text to select evidence file
  ///
  /// In en, this message translates to:
  /// **'Select Evidence File'**
  String get selectEvidenceFile;

  /// Button text to take photo or video
  ///
  /// In en, this message translates to:
  /// **'Take Photo/Video'**
  String get takePhotoVideo;

  /// OR separator text
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// Button text to upload file
  ///
  /// In en, this message translates to:
  /// **'Upload File'**
  String get uploadFile;

  /// Uploading evidence loading message
  ///
  /// In en, this message translates to:
  /// **'Uploading evidence...'**
  String get uploadingEvidence;

  /// Status message for submitted form
  ///
  /// In en, this message translates to:
  /// **'Form submitted'**
  String get formSubmitted;

  /// Status message for available form data
  ///
  /// In en, this message translates to:
  /// **'Form data available'**
  String get formDataAvailable;

  /// Default title for form submissions
  ///
  /// In en, this message translates to:
  /// **'Form Submission'**
  String get formSubmission;

  /// Default title for evidence files
  ///
  /// In en, this message translates to:
  /// **'Evidence File'**
  String get evidenceFile;

  /// Message when no data is available
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// Title for previous submissions section with count
  ///
  /// In en, this message translates to:
  /// **'Previous Submissions ({count})'**
  String previousSubmissionsCount(int count);

  /// Link text to view all submissions
  ///
  /// In en, this message translates to:
  /// **'View All Submissions'**
  String get viewAllSubmissions;

  /// Uppercase label for form submission
  ///
  /// In en, this message translates to:
  /// **'FORM SUBMISSION'**
  String get formSubmissionUppercase;

  /// Uppercase label for evidence upload
  ///
  /// In en, this message translates to:
  /// **'EVIDENCE UPLOAD'**
  String get evidenceUploadUppercase;

  /// Remove button
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// From preposition
  ///
  /// In en, this message translates to:
  /// **'from'**
  String get from;

  /// Confirmation message for removal
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove'**
  String get areYouSureYouWantToRemove;

  /// From this route phrase
  ///
  /// In en, this message translates to:
  /// **'from this route'**
  String get fromThisRoute;

  /// Success message for place removal
  ///
  /// In en, this message translates to:
  /// **'Place removed from route successfully'**
  String get placeRemovedFromRouteSuccessfully;

  /// Error message for place removal
  ///
  /// In en, this message translates to:
  /// **'Error removing place from route'**
  String get errorRemovingPlaceFromRoute;

  /// Cannot delete route dialog title
  ///
  /// In en, this message translates to:
  /// **'Cannot Delete Route'**
  String get cannotDeleteRoute;

  /// Cannot delete route explanation
  ///
  /// In en, this message translates to:
  /// **'The route \"{routeName}\" cannot be deleted because it has historical data or active assignments'**
  String theRouteCannotBeDeletedBecauseItHasHistoricalDataOrActiveAssignments(
      String routeName);

  /// Assigned to agents count
  ///
  /// In en, this message translates to:
  /// **'Assigned to {count} agents'**
  String assignedToAgents(String count);

  /// Visit records explanation
  ///
  /// In en, this message translates to:
  /// **'Has {count} visit records. This historical data cannot be deleted to maintain audit trail'**
  String hasVisitRecordsThisHistoricalDataCannotBeDeletedToMaintainAuditTrail(
      String count);

  /// What you can do section header
  ///
  /// In en, this message translates to:
  /// **'What you can do:'**
  String get whatYouCanDo;

  /// Remove agent assignments instruction
  ///
  /// In en, this message translates to:
  /// **'Remove agent assignments first'**
  String get removeAgentAssignmentsFirst;

  /// Archive route instruction
  ///
  /// In en, this message translates to:
  /// **'Archive the route instead of deleting to preserve historical data'**
  String get archiveTheRouteInsteadOfDeletingToPreserveHistoricalData;

  /// Archive button text
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// Route deletion success message
  ///
  /// In en, this message translates to:
  /// **'Route deleted successfully'**
  String get routeDeletedSuccessfully;

  /// Route deletion error message
  ///
  /// In en, this message translates to:
  /// **'Error deleting route'**
  String get errorDeletingRoute;

  /// Archive confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to archive'**
  String get areYouSureYouWantToArchive;

  /// Archive route explanation
  ///
  /// In en, this message translates to:
  /// **'The route will be moved to archived status. All historical data will be preserved and it will no longer be available for new assignments.'**
  String
      get theRouteWillBeMovedToArchivedStatusAllHistoricalDataWillBePreservedAndItWillNoLongerBeAvailableForNewAssignments;

  /// Route archive success message
  ///
  /// In en, this message translates to:
  /// **'Route archived successfully'**
  String get routeArchivedSuccessfully;

  /// Route archive error message
  ///
  /// In en, this message translates to:
  /// **'Error archiving route'**
  String get errorArchivingRoute;

  /// File URL not available error
  ///
  /// In en, this message translates to:
  /// **'File URL not available'**
  String get fileUrlNotAvailable;

  /// Route name field label
  ///
  /// In en, this message translates to:
  /// **'Route Name'**
  String get routeName;

  /// Route name field hint
  ///
  /// In en, this message translates to:
  /// **'Enter route name'**
  String get enterRouteName;

  /// Route name validation message
  ///
  /// In en, this message translates to:
  /// **'Route name is required'**
  String get routeNameIsRequired;

  /// Route description field hint
  ///
  /// In en, this message translates to:
  /// **'Brief description of the route'**
  String get briefDescriptionOfTheRoute;

  /// Estimated duration field label
  ///
  /// In en, this message translates to:
  /// **'Estimated Duration'**
  String get estimatedDuration;

  /// Hours label
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// Minutes label
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// Schedule section header
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// All places added message
  ///
  /// In en, this message translates to:
  /// **'All available places have been added to the route'**
  String get allAvailablePlacesHaveBeenAddedToTheRoute;

  /// Required evidence field label
  ///
  /// In en, this message translates to:
  /// **'Required Evidence'**
  String get requiredEvidence;

  /// Visit frequency field label
  ///
  /// In en, this message translates to:
  /// **'Visit Frequency'**
  String get visitFrequency;

  /// Edit mode active status
  ///
  /// In en, this message translates to:
  /// **'Edit mode active'**
  String get editModeActive;

  /// Map editing instruction
  ///
  /// In en, this message translates to:
  /// **'Tap on the map or drag the marker to change the location'**
  String get tapOnTheMapOrDragTheMarkerToChangeTheLocation;

  /// Geofence label
  ///
  /// In en, this message translates to:
  /// **'Geofence'**
  String get geofence;

  /// No visits yet message
  ///
  /// In en, this message translates to:
  /// **'No visits yet'**
  String get noVisitsYet;

  /// Create button text
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Details section header
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// Created label
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get created;

  /// Statistics section header
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No agents assigned message
  ///
  /// In en, this message translates to:
  /// **'No agents assigned yet'**
  String get noAgentsAssignedYet;

  /// Assign agents instruction
  ///
  /// In en, this message translates to:
  /// **'Tap \'Assign to Agents\' to get started'**
  String get tapAssignToAgentsToGetStarted;

  /// Agent hasn't started message
  ///
  /// In en, this message translates to:
  /// **'Agent hasn\'t started visiting places'**
  String get agentHasntStartedVisitingPlaces;

  /// Progress details section header
  ///
  /// In en, this message translates to:
  /// **'Progress Details'**
  String get progressDetails;

  /// No places in route message
  ///
  /// In en, this message translates to:
  /// **'No places in this route'**
  String get noPlacesInThisRoute;

  /// Activate confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to activate'**
  String get areYouSureYouWantToActivate;

  /// Activation explanation
  ///
  /// In en, this message translates to:
  /// **'Once activated, it will be available for agent assignment'**
  String get onceActivatedItWillBeAvailableForAgentAssignment;

  /// Route activation success message
  ///
  /// In en, this message translates to:
  /// **'Route activated successfully'**
  String get routeActivatedSuccessfully;

  /// Route activation error message
  ///
  /// In en, this message translates to:
  /// **'Error activating route'**
  String get errorActivatingRoute;

  /// Permanent deletion confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete'**
  String get areYouSureYouWantToPermanentlyDelete;

  /// Safe deletion explanation
  ///
  /// In en, this message translates to:
  /// **'This route has no assignments or visit history and can be safely deleted'**
  String get thisRouteHasNoAssignmentsOrVisitHistoryAndCanBeSafelyDeleted;

  /// Permanent deletion warning
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. The route and all its places will be permanently deleted'**
  String
      get thisActionCannotBeUndoneTheRouteAndAllItsPlacesWillBePermanentlyDeleted;

  /// Delete permanently button text
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get deletePermanently;

  /// No agents in groups message
  ///
  /// In en, this message translates to:
  /// **'No agents found in your groups'**
  String get noAgentsFoundInYourGroups;

  /// No agents available message
  ///
  /// In en, this message translates to:
  /// **'No agents available for assignment'**
  String get noAgentsAvailableForAssignment;

  /// Error loading agents message
  ///
  /// In en, this message translates to:
  /// **'Error loading agents'**
  String get errorLoadingAgents;

  /// Assign button text
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get assign;

  /// To preposition
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get to;

  /// Agents plural noun
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get agents;

  /// Currently assigned section header
  ///
  /// In en, this message translates to:
  /// **'Currently Assigned'**
  String get currentlyAssigned;

  /// More agents section header
  ///
  /// In en, this message translates to:
  /// **'More Agents'**
  String get moreAgents;

  /// All agents assigned message
  ///
  /// In en, this message translates to:
  /// **'All agents are already assigned'**
  String get allAgentsAreAlreadyAssigned;

  /// No additional agents message
  ///
  /// In en, this message translates to:
  /// **'No additional agents available'**
  String get noAdditionalAgentsAvailable;

  /// Assign to button text
  ///
  /// In en, this message translates to:
  /// **'Assign to'**
  String get assignTo;

  /// All selected agents already assigned message
  ///
  /// In en, this message translates to:
  /// **'All selected agents are already assigned to this route'**
  String get allSelectedAgentsAreAlreadyAssignedToThisRoute;

  /// New route assigned notification title
  ///
  /// In en, this message translates to:
  /// **'New Route Assigned'**
  String get newRouteAssigned;

  /// Route assignment notification message
  ///
  /// In en, this message translates to:
  /// **'You have been assigned to route'**
  String get youHaveBeenAssignedToRoute;

  /// New agents text
  ///
  /// In en, this message translates to:
  /// **'new agents'**
  String get newAgents;

  /// Already assigned text
  ///
  /// In en, this message translates to:
  /// **'were already assigned'**
  String get wereAlreadyAssigned;

  /// Route assignment success message
  ///
  /// In en, this message translates to:
  /// **'Route assigned to {count} agents successfully'**
  String routeAssignedToAgentsSuccessfully(String count);

  /// Route assignment error message
  ///
  /// In en, this message translates to:
  /// **'Error assigning route'**
  String get errorAssigningRoute;

  /// Please select a file message
  ///
  /// In en, this message translates to:
  /// **'Please select a file'**
  String get pleaseSelectFile;

  /// Task status updated message
  ///
  /// In en, this message translates to:
  /// **'Task status updated!'**
  String get taskStatusUpdated;

  /// Failed to update status message
  ///
  /// In en, this message translates to:
  /// **'Failed to update status.'**
  String get failedToUpdateStatus;

  /// Error uploading evidence message
  ///
  /// In en, this message translates to:
  /// **'Error uploading evidence'**
  String get errorUploadingEvidence;

  /// No tasks assigned message
  ///
  /// In en, this message translates to:
  /// **'You have not been assigned any tasks for this campaign.'**
  String get noTasksAssigned;

  /// Uploading evidence with progress
  ///
  /// In en, this message translates to:
  /// **'Uploading evidence... {progress}%'**
  String uploadingEvidenceProgress(int progress);

  /// Zone count format
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String zoneCountFormat(String current, String total);

  /// Task has location name but no geofence message
  ///
  /// In en, this message translates to:
  /// **'This task has a location name but no geofence area defined. You can submit evidence from any location.'**
  String get taskHasLocationNameNoGeofence;

  /// No location set description
  ///
  /// In en, this message translates to:
  /// **'The manager has not set a specific location or geofence for this task. You can submit evidence from any location.'**
  String get noLocationSetDescription;

  /// Points count format
  ///
  /// In en, this message translates to:
  /// **'{count} points'**
  String pointsCount(String count);

  /// Assignment pending description
  ///
  /// In en, this message translates to:
  /// **'Your assignment to this task is pending approval.\nYou cannot access task details until it is approved.'**
  String get assignmentPendingDescription;

  /// Template not found title
  ///
  /// In en, this message translates to:
  /// **'Template not found'**
  String get templateNotFound;

  /// Template not found description
  ///
  /// In en, this message translates to:
  /// **'This task template could not be loaded.'**
  String get templateNotFoundDescription;

  /// Location verification requirement text
  ///
  /// In en, this message translates to:
  /// **'Location Verification Required'**
  String get locationVerificationRequired;

  /// Task assignment pending approval message
  ///
  /// In en, this message translates to:
  /// **'This task assignment is pending approval from your manager. You cannot start work until it is approved.'**
  String get taskAssignmentPendingApproval;

  /// Upload more evidence format
  ///
  /// In en, this message translates to:
  /// **'Upload {count} more evidence file(s) to complete this task'**
  String uploadMoreEvidenceFormat(String count);

  /// No tasks assigned description
  ///
  /// In en, this message translates to:
  /// **'There are no tasks assigned to you in this campaign yet. Check back later or contact your manager.'**
  String get noTasksAssignedDescription;

  /// Active visit title
  ///
  /// In en, this message translates to:
  /// **'ACTIVE VISIT'**
  String get activeVisit;

  /// Points format
  ///
  /// In en, this message translates to:
  /// **'{points} points'**
  String pointsFormat(String points);

  /// Points abbreviation format
  ///
  /// In en, this message translates to:
  /// **'{points} pts'**
  String ptsFormat(String points);

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Al-Tijwal'**
  String get appTitle;

  /// Sign up success message
  ///
  /// In en, this message translates to:
  /// **'Sign up successful! Please check your email to confirm.'**
  String get signUpSuccessMessage;

  /// Stop services dialog title
  ///
  /// In en, this message translates to:
  /// **'Stop Services?'**
  String get stopServicesQuestion;

  /// Stop services warning message
  ///
  /// In en, this message translates to:
  /// **'This will stop location tracking and status updates. Your manager will not be able to see your location or online status.\n\nAre you sure you want to stop all services?'**
  String get stopServicesWarning;

  /// Stop services button
  ///
  /// In en, this message translates to:
  /// **'Stop Services'**
  String get stopServices;

  /// Background services stopped message
  ///
  /// In en, this message translates to:
  /// **'Background services stopped'**
  String get backgroundServicesStopped;

  /// Services disabled title
  ///
  /// In en, this message translates to:
  /// **'Services Disabled'**
  String get servicesDisabled;

  /// Services active message
  ///
  /// In en, this message translates to:
  /// **'Location tracking and status updates are now active'**
  String get servicesActiveMessage;

  /// Services started title
  ///
  /// In en, this message translates to:
  /// **'Services Started'**
  String get servicesStarted;

  /// Failed to start services message
  ///
  /// In en, this message translates to:
  /// **'Failed to start services. Please check permissions.'**
  String get failedToStartServices;

  /// Service error title
  ///
  /// In en, this message translates to:
  /// **'Service Error'**
  String get serviceError;

  /// Unable to toggle services message
  ///
  /// In en, this message translates to:
  /// **'Unable to toggle services'**
  String get unableToToggleServices;

  /// Service details title
  ///
  /// In en, this message translates to:
  /// **'Service Details'**
  String get serviceDetails;

  /// Location tracking label
  ///
  /// In en, this message translates to:
  /// **'Location Tracking'**
  String get locationTracking;

  /// Online status label
  ///
  /// In en, this message translates to:
  /// **'Online Status'**
  String get onlineStatus;

  /// Broadcasting status
  ///
  /// In en, this message translates to:
  /// **'Broadcasting'**
  String get broadcasting;

  /// Heartbeat label
  ///
  /// In en, this message translates to:
  /// **'Heartbeat'**
  String get heartbeat;

  /// Every 30 seconds
  ///
  /// In en, this message translates to:
  /// **'Every 30s'**
  String get every30s;

  /// Stopped status
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get stopped;

  /// Back online message
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get backOnline;

  /// Error loading user profile message
  ///
  /// In en, this message translates to:
  /// **'Error loading user profile'**
  String get errorLoadingUserProfile;

  /// Delete field dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Field'**
  String get deleteField;

  /// Confirm delete field message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{fieldName}\"?'**
  String confirmDeleteField(String fieldName);

  /// Add task button
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get addTask;

  /// Done button
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// New zone label
  ///
  /// In en, this message translates to:
  /// **'New Zone'**
  String get newZone;

  /// Rename zone dialog title
  ///
  /// In en, this message translates to:
  /// **'Rename Zone'**
  String get renameZone;

  /// Zone name field label
  ///
  /// In en, this message translates to:
  /// **'Zone Name'**
  String get zoneName;

  /// Pick a color dialog title
  ///
  /// In en, this message translates to:
  /// **'Pick a color'**
  String get pickAColor;

  /// All team members online message
  ///
  /// In en, this message translates to:
  /// **'All team members are currently online.\nGreat job keeping the team active!'**
  String get allTeamMembersOnline;

  /// No team members assigned message
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any team members assigned to your groups yet.\nContact your administrator to add agents to your groups.'**
  String get noTeamMembersAssigned;

  /// Update name button
  ///
  /// In en, this message translates to:
  /// **'Update Name'**
  String get updateName;

  /// Enter new password hint
  ///
  /// In en, this message translates to:
  /// **'Enter new password'**
  String get enterNewPassword;

  /// Edit name for agent message
  ///
  /// In en, this message translates to:
  /// **'Edit name for @{username}'**
  String editNameForAgent(String username);

  /// Enter agent full name hint
  ///
  /// In en, this message translates to:
  /// **'Enter agent full name'**
  String get enterAgentFullName;

  /// New password label
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// Enter new password for user message
  ///
  /// In en, this message translates to:
  /// **'Enter new password for {fullName}'**
  String enterNewPasswordFor(String fullName);

  /// Create first route message
  ///
  /// In en, this message translates to:
  /// **'Create your first route to get started'**
  String get createFirstRoute;

  /// Create new task title
  ///
  /// In en, this message translates to:
  /// **'Create New Task'**
  String get createNewTask;

  /// Choose from professional templates description
  ///
  /// In en, this message translates to:
  /// **'Choose from professional task templates by category'**
  String get chooseFromProfessionalTemplates;

  /// Create custom task description
  ///
  /// In en, this message translates to:
  /// **'Create a custom task with specific requirements'**
  String get createCustomTaskDescription;

  /// Create first task to get started message
  ///
  /// In en, this message translates to:
  /// **'Create your first task to get started with task management'**
  String get createFirstTaskToGetStarted;

  /// Create template button
  ///
  /// In en, this message translates to:
  /// **'Create Template'**
  String get createTemplate;

  /// Select category text
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get selectCategory;

  /// Create new template title
  ///
  /// In en, this message translates to:
  /// **'Create New Template'**
  String get createNewTemplate;

  /// Back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Next button
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Error loading categories message
  ///
  /// In en, this message translates to:
  /// **'Error loading categories'**
  String get errorLoadingCategories;

  /// Template created successfully message
  ///
  /// In en, this message translates to:
  /// **'Template created successfully!'**
  String get templateCreatedSuccessfully;

  /// Error creating template message
  ///
  /// In en, this message translates to:
  /// **'Error creating template'**
  String get errorCreatingTemplate;

  /// Basic information section title
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get basicInformation;

  /// Tell us about template subtitle
  ///
  /// In en, this message translates to:
  /// **'Tell us about your template'**
  String get tellUsAboutTemplate;

  /// Template name required field
  ///
  /// In en, this message translates to:
  /// **'Template Name *'**
  String get templateNameRequired;

  /// Template name hint text
  ///
  /// In en, this message translates to:
  /// **'e.g., Hospital Equipment Check'**
  String get templateNameHint;

  /// Description required field
  ///
  /// In en, this message translates to:
  /// **'Description *'**
  String get descriptionRequired;

  /// Describe agent task hint
  ///
  /// In en, this message translates to:
  /// **'Describe what agents need to do...'**
  String get describeAgentTask;

  /// Category required field
  ///
  /// In en, this message translates to:
  /// **'Category *'**
  String get categoryRequired;

  /// Configure agent requirements subtitle
  ///
  /// In en, this message translates to:
  /// **'Configure what agents need to provide'**
  String get configureAgentRequirements;

  /// Difficulty level label
  ///
  /// In en, this message translates to:
  /// **'Difficulty Level'**
  String get difficultyLevel;

  /// Estimated duration minutes label
  ///
  /// In en, this message translates to:
  /// **'Estimated Duration (minutes)'**
  String get estimatedDurationMinutes;

  /// Reward points label
  ///
  /// In en, this message translates to:
  /// **'Reward Points'**
  String get rewardPoints;

  /// Requires geofence label
  ///
  /// In en, this message translates to:
  /// **'Requires Geofence'**
  String get requiresGeofence;

  /// Task must be completed at location subtitle
  ///
  /// In en, this message translates to:
  /// **'Task must be completed at specific location'**
  String get taskMustBeCompletedAtLocation;

  /// Custom instructions optional label
  ///
  /// In en, this message translates to:
  /// **'Custom Instructions (Optional)'**
  String get customInstructionsOptional;

  /// Additional instructions hint
  ///
  /// In en, this message translates to:
  /// **'Additional instructions for agents...'**
  String get additionalInstructionsForAgents;

  /// Review and create section title
  ///
  /// In en, this message translates to:
  /// **'Review & Create'**
  String get reviewAndCreate;

  /// Verify template before creating subtitle
  ///
  /// In en, this message translates to:
  /// **'Verify your template before creating'**
  String get verifyTemplateBeforeCreating;

  /// Template name label
  ///
  /// In en, this message translates to:
  /// **'Template Name'**
  String get templateName;

  /// Not selected text
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get notSelected;

  /// Difficulty label
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficulty;

  /// Minutes format
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String minutesFormat(String minutes);

  /// Reward label
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get reward;

  /// Geofence required label
  ///
  /// In en, this message translates to:
  /// **'Geofence Required'**
  String get geofenceRequired;

  /// Yes text
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No text
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Photo label
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// Audio label
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// Step x of y format
  ///
  /// In en, this message translates to:
  /// **'Step {x} of {y}'**
  String stepXOfY(int x, int y);

  /// Basic info step title
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get basicInfo;

  /// Requirements step title
  ///
  /// In en, this message translates to:
  /// **'Requirements'**
  String get requirements;

  /// Task management title
  ///
  /// In en, this message translates to:
  /// **'Task Management'**
  String get taskManagement;

  /// Error loading tasks message
  ///
  /// In en, this message translates to:
  /// **'Error loading tasks'**
  String get errorLoadingTasks;

  /// No tasks yet message
  ///
  /// In en, this message translates to:
  /// **'No Tasks Yet'**
  String get noTasksYet;

  /// Confirm delete task message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this task? This action cannot be undone.'**
  String get confirmDeleteTaskMessage;

  /// New task button
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get newTask;

  /// Task deleted successfully message
  ///
  /// In en, this message translates to:
  /// **'Task deleted successfully'**
  String get taskDeletedSuccessfully;

  /// Failed to delete task message
  ///
  /// In en, this message translates to:
  /// **'Failed to delete task'**
  String get failedToDeleteTask;

  /// From template option
  ///
  /// In en, this message translates to:
  /// **'From Template'**
  String get fromTemplate;

  /// Manage places tooltip
  ///
  /// In en, this message translates to:
  /// **'Manage Places'**
  String get managePlaces;

  /// No draft routes message
  ///
  /// In en, this message translates to:
  /// **'No draft routes'**
  String get noDraftRoutes;

  /// No routes found message
  ///
  /// In en, this message translates to:
  /// **'No routes found'**
  String get noRoutesFound;

  /// Route order label
  ///
  /// In en, this message translates to:
  /// **'Route Order:'**
  String get routeOrder;

  /// Created by format
  ///
  /// In en, this message translates to:
  /// **'Created by: {name}'**
  String createdByFormat(String name);

  /// More places format
  ///
  /// In en, this message translates to:
  /// **'... (+{count} more)'**
  String morePlacesFormat(int count);

  /// Category label
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// Minutes short form
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutesShort;

  /// Points short form
  ///
  /// In en, this message translates to:
  /// **'pts'**
  String get pointsShort;

  /// New task assigned notification title
  ///
  /// In en, this message translates to:
  /// **'New Task Assigned'**
  String get newTaskAssigned;

  /// Campaign assignment title
  ///
  /// In en, this message translates to:
  /// **'Campaign Assignment'**
  String get campaignAssignment;

  /// Title label
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// Points prefix
  ///
  /// In en, this message translates to:
  /// **'Pts '**
  String get pointsPrefix;

  /// Confirm payment button
  ///
  /// In en, this message translates to:
  /// **'Confirm Payment'**
  String get confirmPayment;

  /// Remove agent tooltip
  ///
  /// In en, this message translates to:
  /// **'Remove Agent'**
  String get removeAgent;

  /// Task progress section title
  ///
  /// In en, this message translates to:
  /// **'Task Progress'**
  String get taskProgress;

  /// Uploaded files section title
  ///
  /// In en, this message translates to:
  /// **'Uploaded Files'**
  String get uploadedFiles;

  /// Outstanding balance label
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get outstanding;

  /// Untitled evidence label
  ///
  /// In en, this message translates to:
  /// **'Untitled Evidence'**
  String get untitledEvidence;

  /// View button
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// Download button
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// Unknown file label
  ///
  /// In en, this message translates to:
  /// **'Unknown file'**
  String get unknownFile;

  /// Unknown task label
  ///
  /// In en, this message translates to:
  /// **'Unknown Task'**
  String get unknownTask;

  /// Title for campaign day selection dialog
  ///
  /// In en, this message translates to:
  /// **'Select Campaign Days'**
  String get selectCampaignDays;

  /// Label for campaign days field
  ///
  /// In en, this message translates to:
  /// **'Campaign Days'**
  String get campaignDays;

  /// Error message when no campaign days are selected
  ///
  /// In en, this message translates to:
  /// **'Please select campaign days'**
  String get pleaseSelectCampaignDays;

  /// Title for task day selection dialog
  ///
  /// In en, this message translates to:
  /// **'Select Task Days'**
  String get selectTaskDays;

  /// Label for task days field
  ///
  /// In en, this message translates to:
  /// **'Task Days'**
  String get taskDays;

  /// Error message when no task days are selected
  ///
  /// In en, this message translates to:
  /// **'Please select task days'**
  String get pleaseSelectTaskDays;

  /// Title for history day selection dialog
  ///
  /// In en, this message translates to:
  /// **'Select History Days'**
  String get selectHistoryDays;

  /// Select geofence screen title
  ///
  /// In en, this message translates to:
  /// **'Select Geofence'**
  String get selectGeofence;

  /// Instructions for selecting a geofence
  ///
  /// In en, this message translates to:
  /// **'Choose a work area to start tracking your location and progress'**
  String get selectGeofenceInstructions;

  /// Message when agent has no geofence assignment
  ///
  /// In en, this message translates to:
  /// **'No Current Assignment'**
  String get noCurrentAssignment;

  /// Instructions to select geofence
  ///
  /// In en, this message translates to:
  /// **'Select a geofence below to start working'**
  String get selectGeofenceToStart;

  /// Label for current geofence assignment
  ///
  /// In en, this message translates to:
  /// **'Current Assignment'**
  String get currentAssignment;

  /// Status when agent is inside assigned geofence
  ///
  /// In en, this message translates to:
  /// **'Currently inside'**
  String get currentlyInside;

  /// Section title for available geofences
  ///
  /// In en, this message translates to:
  /// **'Available Geofences'**
  String get availableGeofences;

  /// Error message when geofences fail to load
  ///
  /// In en, this message translates to:
  /// **'Error loading geofences'**
  String get errorLoadingGeofences;

  /// Message when no geofences exist for selection
  ///
  /// In en, this message translates to:
  /// **'No geofences available'**
  String get noGeofencesAvailable;

  /// Instructions when no geofences are available
  ///
  /// In en, this message translates to:
  /// **'Contact your manager to create geofences for this campaign'**
  String get contactManagerForGeofences;

  /// Error message when geofence capacity is full
  ///
  /// In en, this message translates to:
  /// **'Geofence is full'**
  String get geofenceIsFull;

  /// Success message when assigned to geofence
  ///
  /// In en, this message translates to:
  /// **'Assigned to geofence'**
  String get assignedToGeofence;

  /// Error message when geofence assignment fails
  ///
  /// In en, this message translates to:
  /// **'Assignment failed'**
  String get assignmentFailed;

  /// Cancel geofence assignment button text
  ///
  /// In en, this message translates to:
  /// **'Cancel Assignment'**
  String get cancelAssignment;

  /// Confirmation dialog for canceling assignment
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel your current geofence assignment?'**
  String get cancelAssignmentConfirmation;

  /// Success message when assignment is cancelled
  ///
  /// In en, this message translates to:
  /// **'Assignment cancelled successfully'**
  String get assignmentCancelled;

  /// Error message when cancellation fails
  ///
  /// In en, this message translates to:
  /// **'Cancellation Failed'**
  String get cancellationFailed;

  /// Geofence tracking screen title
  ///
  /// In en, this message translates to:
  /// **'Geofence Tracking'**
  String get geofenceTracking;

  /// Button text to select geofence zone
  ///
  /// In en, this message translates to:
  /// **'Select Zone'**
  String get selectZone;

  /// Geofence zones section title
  ///
  /// In en, this message translates to:
  /// **'Geofence Zones'**
  String get geofenceZones;

  /// Message when no geofences exist
  ///
  /// In en, this message translates to:
  /// **'No geofences created yet'**
  String get noGeofencesCreated;

  /// Helper text for creating first geofence
  ///
  /// In en, this message translates to:
  /// **'Create your first geofence to get started'**
  String get createFirstGeofence;

  /// Notification when entering geofence
  ///
  /// In en, this message translates to:
  /// **'Entered geofence'**
  String get enteredGeofence;

  /// Notification when leaving geofence
  ///
  /// In en, this message translates to:
  /// **'Left geofence'**
  String get leftGeofence;

  /// Warning message to return to geofence
  ///
  /// In en, this message translates to:
  /// **'Return to your assigned area'**
  String get returnToAssignedArea;

  /// Status when tracking is active
  ///
  /// In en, this message translates to:
  /// **'Tracking active'**
  String get trackingActive;

  /// Status when tracking is stopped
  ///
  /// In en, this message translates to:
  /// **'Tracking stopped'**
  String get trackingStopped;

  /// Button to start location tracking
  ///
  /// In en, this message translates to:
  /// **'Start Tracking'**
  String get startTracking;

  /// Button to stop location tracking
  ///
  /// In en, this message translates to:
  /// **'Stop Tracking'**
  String get stopTracking;

  /// Button to complete geofence assignment
  ///
  /// In en, this message translates to:
  /// **'Complete Assignment'**
  String get completeAssignment;

  /// Success message for completed assignment
  ///
  /// In en, this message translates to:
  /// **'Assignment completed successfully'**
  String get assignmentCompletedSuccessfully;

  /// Error message when assignment completion fails
  ///
  /// In en, this message translates to:
  /// **'Failed to complete assignment'**
  String get failedToCompleteAssignment;

  /// GPS accuracy label
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get accuracy;

  /// Time spent inside geofence label
  ///
  /// In en, this message translates to:
  /// **'Time Inside'**
  String get timeInside;

  /// Message when no geofence assignment exists
  ///
  /// In en, this message translates to:
  /// **'No Active Assignment'**
  String get noActiveAssignment;

  /// Instructions for starting geofence tracking
  ///
  /// In en, this message translates to:
  /// **'Select a geofence to start tracking'**
  String get selectGeofenceToStartTracking;

  /// Button to change current geofence assignment
  ///
  /// In en, this message translates to:
  /// **'Change Geofence'**
  String get changeGeofence;

  /// Label showing current geofence assignment
  ///
  /// In en, this message translates to:
  /// **'Currently assigned to'**
  String get currentlyAssignedTo;

  /// Label showing available capacity slots
  ///
  /// In en, this message translates to:
  /// **'Available slots'**
  String get availableSlots;

  /// Status when geofence is at full capacity
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get full;

  /// Geofences section title
  ///
  /// In en, this message translates to:
  /// **'Geofences'**
  String get geofences;

  /// Work zone label with name
  ///
  /// In en, this message translates to:
  /// **'Work Zone: {name}'**
  String workZoneLabel(String name);

  /// Task not available yet title
  ///
  /// In en, this message translates to:
  /// **'Task Not Available Yet'**
  String get taskNotAvailableYet;

  /// Task start date message
  ///
  /// In en, this message translates to:
  /// **'This task will be available starting {date}'**
  String taskStartsOn(DateTime date);

  /// Task expired title
  ///
  /// In en, this message translates to:
  /// **'Task Expired'**
  String get taskExpired;

  /// Task end date message
  ///
  /// In en, this message translates to:
  /// **'This task ended on {date}'**
  String taskEndedOn(DateTime date);

  /// Title for background services required message
  ///
  /// In en, this message translates to:
  /// **'Background Services Required'**
  String get backgroundServicesRequired;

  /// Enable background services message
  ///
  /// In en, this message translates to:
  /// **'Please enable background services to start this task. Background location tracking is required for touring tasks.'**
  String get enableBackgroundServicesMessage;

  /// Enable background services title
  ///
  /// In en, this message translates to:
  /// **'Enable Background Services'**
  String get enableBackgroundServices;

  /// Instructions for enabling background services
  ///
  /// In en, this message translates to:
  /// **'To enable background services:\n\n1. Go to phone Settings\n2. Find Al-Tijwal app\n3. Enable \'Allow background activity\'\n4. Enable \'Location\' permissions\n5. Restart the app'**
  String get backgroundServicesInstructions;

  /// Task unavailable button text
  ///
  /// In en, this message translates to:
  /// **'Task Unavailable'**
  String get taskUnavailable;

  /// Indicator showing an active task is running
  ///
  /// In en, this message translates to:
  /// **'Active Task Running'**
  String get activeTaskRunning;

  /// Message when task is completed for the day
  ///
  /// In en, this message translates to:
  /// **'Task completed today. Available again tomorrow.'**
  String get taskCompletedToday;

  /// Number of tasks available
  ///
  /// In en, this message translates to:
  /// **'{count} tasks available'**
  String tasksAvailable(Object count);

  /// Message for tasks not yet available
  ///
  /// In en, this message translates to:
  /// **'Available on the scheduled day'**
  String get waitForTaskDay;

  /// Button text for future tasks
  ///
  /// In en, this message translates to:
  /// **'Available on scheduled day'**
  String get availableOnDay;

  /// Number of tasks completed
  ///
  /// In en, this message translates to:
  /// **'{count} completed'**
  String tasksCompletedCount(Object count);

  /// Message when no touring tasks are assigned for a specific day
  ///
  /// In en, this message translates to:
  /// **'No touring tasks for this day'**
  String get noTouringTasksForDay;

  /// Label for remaining points to be paid
  ///
  /// In en, this message translates to:
  /// **'Remaining Points'**
  String get remainingPoints;

  /// Section title for campaign tasks
  ///
  /// In en, this message translates to:
  /// **'Campaign Tasks'**
  String get campaignTasks;

  /// Message when agent has no completed campaign tasks
  ///
  /// In en, this message translates to:
  /// **'No completed campaign tasks'**
  String get noCompletedCampaignTasks;

  /// Message when agent has no completed standalone tasks
  ///
  /// In en, this message translates to:
  /// **'No completed standalone tasks'**
  String get noCompletedStandaloneTasks;

  /// Label showing when a task was completed
  ///
  /// In en, this message translates to:
  /// **'Completed on'**
  String get completedOn;

  /// Title for agents earnings management screen
  ///
  /// In en, this message translates to:
  /// **'Agents Earnings Management'**
  String get agentsEarningsManagement;

  /// Placeholder text for agent search field
  ///
  /// In en, this message translates to:
  /// **'Search agents...'**
  String get searchAgents;

  /// Message when no agents are found
  ///
  /// In en, this message translates to:
  /// **'No Agents Found'**
  String get noAgentsFound;

  /// Description when no agents are found
  ///
  /// In en, this message translates to:
  /// **'No agents are registered in the system yet.'**
  String get noAgentsFoundDesc;

  /// Message when no agents match the search query
  ///
  /// In en, this message translates to:
  /// **'No Agents Match Search'**
  String get noAgentsMatchSearch;

  /// Suggestion when no agents match search
  ///
  /// In en, this message translates to:
  /// **'Try a different search term or clear the search.'**
  String get tryDifferentSearch;

  /// Label for completed tasks count
  ///
  /// In en, this message translates to:
  /// **'Completed Tasks'**
  String get completedTasks;

  /// Subtitle for agent earnings management feature
  ///
  /// In en, this message translates to:
  /// **'Manage agent earnings and payments'**
  String get manageAgentEarnings;

  /// Section title for daily participation records
  ///
  /// In en, this message translates to:
  /// **'Daily Participation'**
  String get dailyParticipation;

  /// Label for hours worked in daily participation
  ///
  /// In en, this message translates to:
  /// **'Hours Worked'**
  String get hoursWorked;

  /// Message when no daily participation records exist
  ///
  /// In en, this message translates to:
  /// **'No daily participation records found'**
  String get noDailyParticipation;

  /// Title for editing touring task screen
  ///
  /// In en, this message translates to:
  /// **'Edit Touring Task'**
  String get editTouringTask;

  /// Title for creating touring task screen
  ///
  /// In en, this message translates to:
  /// **'Create Touring Task'**
  String get createTouringTask;

  /// Button text for updating touring task
  ///
  /// In en, this message translates to:
  /// **'Update Touring Task'**
  String get updateTouringTask;

  /// Success message when touring task is updated
  ///
  /// In en, this message translates to:
  /// **'Touring task updated successfully'**
  String get touringTaskUpdatedSuccessfully;

  /// Success message when touring task is created
  ///
  /// In en, this message translates to:
  /// **'Touring task created successfully'**
  String get touringTaskCreatedSuccessfully;

  /// Error message when touring task update fails
  ///
  /// In en, this message translates to:
  /// **'Failed to update touring task'**
  String get failedToUpdateTouringTask;

  /// Error message when touring task creation fails
  ///
  /// In en, this message translates to:
  /// **'Failed to create touring task'**
  String get failedToCreateTouringTask;

  /// Description for background services required message
  ///
  /// In en, this message translates to:
  /// **'Background services must be enabled to view and participate in campaigns. Please enable them from the Dashboard.'**
  String get backgroundServicesRequiredDescription;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
