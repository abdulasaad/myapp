// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../services/profile_service.dart';
import '../services/session_service.dart';
import '../services/connectivity_service.dart';
import '../services/background_notification_manager.dart';
import '../widgets/session_conflict_dialog.dart';
import '../widgets/offline_widget.dart';
import '../utils/constants.dart';
import './modern_home_screen.dart';

final logger = Logger();

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    try {
      // Set initial state
      _isOnline = ConnectivityService().isOnline;
      
      // Listen to connectivity changes
      ConnectivityService().connectivityStream.listen((isOnline) {
        if (mounted) {
          setState(() {
            _isOnline = isOnline;
          });
          
          // Only show "Back online" snackbar when connectivity is restored
          if (isOnline) {
            OnlineSnackBar.show(context);
          }
          // Don't show offline snackbar - the persistent banner handles this
        }
      });
    } catch (e) {
      logger.w('Failed to initialize connectivity listener in login screen: $e');
      // Default to offline if connectivity service is not available
      _isOnline = false;
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  Future<void> _signIn() async {
    // Check if user is offline
    if (!_isOnline) {
      context.showSnackBar(
        AppLocalizations.of(context)!.noInternetMessage,
        isError: true,
      );
      return;
    }

    // Validate the form first
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final identifier = _identifierController.text.trim();
      final password = _passwordController.text.trim();
      AuthResponse? authResponse;
      String? potentialErrorMessage;

      // --- LOGIN ATTEMPTS ---
      // First, try to sign in assuming the identifier is a username.
      if (!identifier.contains('@')) {
        try {
          authResponse = await supabase.auth.signInWithPassword(
            email: '$identifier@agent.local',
            password: password,
          );
        } on AuthException catch (e) {
          potentialErrorMessage = e.message;
        }
      }
      
      // If the username login was skipped or failed, try as a direct email.
      if (authResponse == null) {
        try {
          authResponse = await supabase.auth.signInWithPassword(
            email: identifier,
            password: password,
          );
        } on AuthException catch (e) {
           potentialErrorMessage = e.message;
        }
      }

      // --- NULL-SAFETY CHECK ---
      final user = authResponse?.user;
      if (user == null) {
        if (mounted) {
          context.showSnackBar(
            potentialErrorMessage ?? AppLocalizations.of(context)!.invalidCredentials,
            isError: true,
          );
        }
        return;
      }
      
      // --- SESSION MANAGEMENT (Check for existing sessions) ---
      
      // 1. Check if user already has an active session
      final hasActiveSession = await SessionService().hasActiveSession(user.id);
      
      if (hasActiveSession) {
        // Show dialog asking user what to do
        if (!mounted) return;
        final shouldLogoutOther = await SessionConflictDialog.show(context);
        
        if (shouldLogoutOther != true) {
          // User cancelled, stay on login screen
          return;
        }
        
        // User chose to logout other device
        await SessionService().invalidateAllUserSessions(user.id);
      }

      // 2. Create a new active session for the current login
      await SessionService().createNewSession(user.id);

      // Note: You should store 'sessionId' on the client (e.g., secure storage)
      // to validate it on subsequent requests to protected routes.

      // --- SUCCESS PATH ---
      await ProfileService.instance.loadProfile();
      
      // Initialize background notification management (fully automatic)
      try {
        await BackgroundNotificationManager().initialize();
        debugPrint('✅ Background notification management started after login');
      } catch (e) {
        debugPrint('⚠️ Background notification management failed after login: $e');
      }
      
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.loginSuccessful);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ModernHomeScreen()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) context.showSnackBar(e.message, isError: true);
    } catch (e) {
      if (mounted) context.showSnackBar('${AppLocalizations.of(context)!.unexpectedError}: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  void _openFacebook() async {
    const webUrl = 'https://www.facebook.com/Altijwal/';
    
    try {
      final uri = Uri.parse(webUrl);
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.couldNotOpenFacebook, isError: true);
      }
    }
  }

  void _openInstagram() async {
    const webUrl = 'https://www.instagram.com/al.tijwal/';
    
    try {
      final uri = Uri.parse(webUrl);
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.couldNotOpenInstagram, isError: true);
      }
    }
  }

  void _openWhatsApp() async {
    const url = 'https://wa.me/message/7LSSON3LJAS3C1';
    
    try {
      final uri = Uri.parse(url);
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.couldNotOpenWhatsApp, isError: true);
      }
    }
  }

  void _openWebsite() async {
    const url = 'https://www.al-tijwal.com';
    try {
      final uri = Uri.parse(url);
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.couldNotOpenWebsite, isError: true);
      }
    }
  }


  Widget _buildImageSocialIcon(String imagePath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            imagePath,
            width: 35,
            height: 35,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to black circle if image fails
              return Container(
                width: 35,
                height: 35,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Offline banner
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              color: Colors.orange[700],
              child: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.noInternetConnection,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          // Main content
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo Section
                      Container(
                        margin: const EdgeInsets.only(top: 40, bottom: 50),
                        child: Column(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.asset(
                                  'icons/logo1.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback to icon if image fails to load
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.business_center,
                                        size: 60,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            Text(
                              AppLocalizations.of(context)!.loginTitle,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context)!.loginSubtitle,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Login Form
                      TextFormField(
                        controller: _identifierController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.usernameOrEmail,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        keyboardType: TextInputType.text,
                        validator: (value) => (value == null || value.isEmpty) ? AppLocalizations.of(context)!.requiredField : null,
                      ),
                      formSpacer,
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.password,
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: (value) => (value == null || value.isEmpty) ? AppLocalizations.of(context)!.requiredField : null,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              AppLocalizations.of(context)!.login,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      ),
                      
                      // Website and Social Media Section
                      const SizedBox(height: 60),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Website link with chain icon
                          GestureDetector(
                            onTap: _openWebsite,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.link,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'www.al-tijwal.com',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 30),
                          // Social media icons
                          _buildImageSocialIcon('assets/images/facebook.png', _openFacebook),
                          const SizedBox(width: 15),
                          _buildImageSocialIcon('assets/images/whatsapp.png', _openWhatsApp),
                          const SizedBox(width: 15),
                          _buildImageSocialIcon('assets/images/instagram.png', _openInstagram),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
