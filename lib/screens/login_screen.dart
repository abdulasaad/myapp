// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import '../services/profile_service.dart';
import '../services/session_service.dart';
import '../widgets/session_conflict_dialog.dart';
import '../utils/constants.dart';
import './home_screen.dart';
import './signup_screen.dart';

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

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
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
            potentialErrorMessage ?? 'Invalid credentials. Please check username/email and password.',
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
      
      if (mounted) {
        context.showSnackBar('Login successful!');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) context.showSnackBar(e.message, isError: true);
    } catch (e) {
      if (mounted) context.showSnackBar('An unexpected error occurred: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      context.showSnackBar('Please enter your username or email to reset password.', isError: true);
      return;
    }
    
    // Determine the correct email for the password reset request
    String emailForReset = identifier.contains('@') ? identifier : '$identifier@agent.local';

    setState(() => _isLoading = true);
    try {
      await supabase.auth.resetPasswordForEmail(emailForReset);
      if (mounted) {
        context.showSnackBar('Password reset link sent to $emailForReset.');
      }
    } on AuthException catch (e) {
      if (mounted) context.showSnackBar(e.message, isError: true);
    } catch (e) {
      if (mounted) context.showSnackBar('An unexpected error occurred: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Al-Tijwal - Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _identifierController,
                  decoration: const InputDecoration(labelText: 'Username or Email'),
                  keyboardType: TextInputType.text,
                  validator: (value) => (value == null || value.isEmpty) ? 'Required field' : null,
                ),
                formSpacer,
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) => (value == null || value.isEmpty) ? 'Required field' : null,
                ),
                formSpacer,
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _forgotPassword,
                    child: const Text('Forgot Password?'),
                  ),
                ),
                formSpacer,
                ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Login'),
                ),
                formSpacer,
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SignUpScreen()),
                  ),
                  child: const Text('Don\'t have an account? Sign Up'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
