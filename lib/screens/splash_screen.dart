// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:myapp/services/profile_service.dart';
import 'package:myapp/services/session_service.dart';
import 'package:myapp/services/connectivity_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../utils/constants.dart';

final logger = Logger();

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(Duration.zero);
    final session = supabase.auth.currentSession;
    if (!mounted) return;

    // Check connectivity status first
    final isOnline = ConnectivityService().isOnline;
    
    if (session != null) {
      if (isOnline) {
        try {
          // Online: Validate both Supabase Auth session AND database session
          final isValidSession = await SessionService().isSessionValid();
          
          if (isValidSession) {
            // Both sessions are valid - proceed to home
            await ProfileService.instance.loadProfile();
            await ProfileService.instance.updateUserStatus('active');
            
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
          } else {
            // Database session is invalid - force logout and go to login
            await SessionService().forceLogout();
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            }
          }
        } catch (e) {
          // Network error during session validation - should not happen since we checked isOnline
          logger.w('🌐 Unexpected network error during online session validation: $e');
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        }
      } else {
        // Offline with existing session: Go to login screen to show offline state
        logger.i('🌐 App started offline with existing session - going to login screen');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } else {
      // No Supabase Auth session - go to login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: preloader);
  }
}