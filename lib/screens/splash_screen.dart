// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:myapp/services/profile_service.dart';
import 'package:myapp/services/session_service.dart';
import 'package:myapp/services/connectivity_service.dart';
import 'package:myapp/services/update_service.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:myapp/services/background_notification_manager.dart';
import 'package:myapp/widgets/update_dialog.dart';
import 'modern_home_screen.dart';
import 'login_screen.dart';
import '../utils/constants.dart';

final logger = Logger();

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final UpdateService _updateService = UpdateService();
  
  @override
  void initState() {
    super.initState();
    _redirect();
  }
  
  Future<void> _checkForUpdate() async {
    try {
      final appVersion = await _updateService.checkForUpdate();
      
      if (appVersion != null && mounted) {
        // Show mandatory update dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => UpdateDialog(appVersion: appVersion),
        );
      }
    } catch (e) {
      logger.e('Error checking for update: $e');
      // Continue with normal flow if update check fails
    }
  }

  Future<void> _redirect() async {
    // Small delay to show splash screen briefly before transition
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // Clean up any APKs from previous installation
    _updateService.cleanupAfterInstallation();
    
    // Check for app updates first
    await _checkForUpdate();
    
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
            
            // Initialize background notification management (fully automatic)
            try {
              await BackgroundNotificationManager().initialize();
              debugPrint('✅ Background notification management started');
            } catch (e) {
              debugPrint('⚠️ Background notification management failed: $e');
            }
            
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const ModernHomeScreen()),
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
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // Gradient background that complements the blue and orange logo
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A), // Deep blue
              Color(0xFF2563EB), // Medium blue
              Color(0xFF3B82F6), // Lighter blue
              Color(0xFF60A5FA), // Even lighter blue
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
          // Gradient borders effect
          boxShadow: [
            BoxShadow(
              color: Color(0xFF1E40AF),
              blurRadius: 20,
              spreadRadius: 2,
              offset: Offset(0, 0),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Animated background particles
            ...List.generate(20, (index) => _buildFloatingParticle(index)),
            
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with elevated effect
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        // Multiple shadows for depth
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                          offset: const Offset(0, 15),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.1),
                          blurRadius: 15,
                          spreadRadius: -5,
                          offset: const Offset(0, -5),
                        ),
                        BoxShadow(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.4),
                          blurRadius: 25,
                          spreadRadius: 0,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Image.asset(
                          'icons/logo2.png',
                          width: 160,
                          height: 160,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // App name with elegant typography
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Text(
                      'AL-Tijwal Agent',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Tagline
                  Text(
                    'Location-Based Task Management',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 1,
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Loading indicator with custom styling
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Gradient border overlay for the entire screen
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    width: 0,
                    color: Colors.transparent,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFEA580C).withValues(alpha: 0.3),
                      Colors.transparent,
                      Colors.transparent,
                      const Color(0xFF2563EB).withValues(alpha: 0.3),
                    ],
                    stops: const [0.0, 0.1, 0.9, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFloatingParticle(int index) {
    return AnimatedPositioned(
      duration: Duration(seconds: 3 + (index % 3)),
      left: (index * 47.0) % MediaQuery.of(context).size.width,
      top: (index * 83.0) % MediaQuery.of(context).size.height,
      child: Container(
        width: 4 + (index % 3) * 2,
        height: 4 + (index % 3) * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1 + (index % 3) * 0.1),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.2),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}