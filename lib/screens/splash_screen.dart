// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:myapp/services/profile_service.dart';
import 'package:myapp/services/session_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../utils/constants.dart';

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

    if (session != null) {
      // Validate both Supabase Auth session AND database session
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