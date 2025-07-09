import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import './screens/splash_screen.dart';
import './services/connectivity_service.dart';
import './services/settings_service.dart';
import './services/timezone_service.dart';
import './services/simple_notification_service.dart';
import './services/notification_manager.dart';
import './utils/constants.dart';

final logger = Logger();

// Create notification channels for background notifications
Future<void> _createNotificationChannels() async {
  try {
    final localNotifications = FlutterLocalNotificationsPlugin();
    
    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'al_tijwal_notifications',
      'AL-Tijwal Notifications',
      description: 'Notifications for campaigns, tasks, and assignments',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    
    // Create the channel
    await localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    
    // Create fallback channel
    const fallbackChannel = AndroidNotificationChannel(
      'al_tijwal_fallback',
      'AL-Tijwal Fallback',
      description: 'Fallback notification channel',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    await localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(fallbackChannel);
    
    debugPrint('✅ Notification channels created successfully');
  } catch (e) {
    debugPrint('❌ Error creating notification channels: $e');
  }
}

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');
  
  // Extract title and body from data field (to avoid Firebase auto-display)
  final title = message.data['title'] ?? message.notification?.title ?? 'AL-Tijwal';
  final body = message.data['body'] ?? message.notification?.body ?? 'You have a new notification';
  
  debugPrint('📱 Title: $title');
  debugPrint('📱 Body: $body');
  debugPrint('📱 Data: ${message.data}');
  
  try {
    // Ensure Firebase is initialized for background context
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Firebase might already be initialized, continue
      debugPrint('Firebase already initialized or error: $e');
    }
    // Initialize local notifications for background context
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    final localNotifications = FlutterLocalNotificationsPlugin();
    await localNotifications.initialize(initSettings);
    
    // Show notification immediately with enhanced configuration
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'al_tijwal_notifications',
        'AL-Tijwal Notifications',
        channelDescription: 'Notifications for campaigns, tasks, and assignments',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        // Use the custom notification icon we set up
        icon: 'notification_icon',
        // Remove largeIcon to prevent cutoff and improve appearance
        // Ensure notification shows even when app is closed
        autoCancel: true,
        ongoing: false,
        // Make notification interactive
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        // Ensure iOS notifications work when app is closed
        interruptionLevel: InterruptionLevel.active,
      ),
    );
    
    await localNotifications.show(
      message.hashCode,
      title,
      body,
      notificationDetails,
      payload: message.data.isNotEmpty ? message.data.toString() : null,
    );
    
    debugPrint('✅ Background notification displayed successfully');
  } catch (e) {
    debugPrint('❌ Error in background handler: $e');
    
    // Fallback: try a simple notification
    try {
      final localNotifications = FlutterLocalNotificationsPlugin();
      await localNotifications.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
      
      await localNotifications.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'al_tijwal_fallback',
            'AL-Tijwal Fallback',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      
      debugPrint('✅ Fallback background notification displayed');
    } catch (e2) {
      debugPrint('❌ Fallback notification also failed: $e2');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first for background messaging
  await Firebase.initializeApp();

  // Register FCM background message handler BEFORE any other Firebase initialization
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Create notification channels early for background notifications
  await _createNotificationChannels();

  await Supabase.initialize(
    
    url: 'https://jnuzpixgfskjcoqmgkxb.supabase.co',
    
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpudXpwaXhnZnNramNvcW1na3hiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkyODI4NTksImV4cCI6MjA2NDg1ODg1OX0.9H9ukV77BtyfX8Vhnlz2KqJeqPv-hxIhGeZdNsOeaPk',
  );

  // Initialize connectivity service (handle gracefully if fails)
  try {
    await ConnectivityService().initialize();
  } catch (e) {
    // If connectivity initialization fails, continue anyway
    logger.w('ConnectivityService initialization failed: $e');
  }

  // Initialize settings service (handle gracefully if fails)
  try {
    await SettingsService.instance.initialize();
  } catch (e) {
    // If settings initialization fails, continue anyway (defaults will be used)
    logger.w('SettingsService initialization failed: $e');
  }

  // Initialize timezone service (handle gracefully if fails)
  try {
    await TimezoneService.instance.initialize();
  } catch (e) {
    // If timezone initialization fails, continue anyway (default Kuwait timezone will be used)
    logger.w('TimezoneService initialization failed: $e');
  }

  // Initialize simple notification service first (always works)
  try {
    await SimpleNotificationService().initialize();
  } catch (e) {
    logger.w('SimpleNotificationService initialization failed: $e');
  }

  // Initialize NotificationManager (may fail if Firebase not configured)
  try {
    await NotificationManager().initialize();
  } catch (e) {
    logger.w('NotificationManager initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Al-Tijwal App',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3), // Modern blue
          brightness: Brightness.light,
          primary: const Color(0xFF2196F3),
          secondary: const Color(0xFF03DAC6),
          surface: Colors.white,
        ),
        primaryColor: const Color(0xFF2196F3),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        
        // Mobile-optimized app bar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2196F3),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        
        // Improved card theme for mobile
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        
        // Enhanced button themes for touch interaction
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            minimumSize: const Size(0, 48), // Minimum touch target
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        // Input decoration theme for better mobile UX
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
        
        // Improved list tile theme
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minVerticalPadding: 8,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
