import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './screens/splash_screen.dart';
import './services/connectivity_service.dart';
import './services/settings_service.dart';
import './utils/constants.dart';

final logger = Logger();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Al-Tijwal App',
      theme: ThemeData.dark().copyWith(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        cardColor: cardBackgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[800],
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
