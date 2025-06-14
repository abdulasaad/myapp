import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/profile_service.dart';
import './home_screen.dart';
import './signup_screen.dart';
import '../utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController(); // Renamed for username OR email
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  // bool _isAgentLogin = true; // No longer needed

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final identifier = _identifierController.text.trim();
      final password = _passwordController.text.trim();
      AuthResponse? authResponse;
      String? potentialErrorMessage;

      try {
        // Attempt 1: Try as agent (username@agent.local)
        // Only attempt if it doesn't look like a full email already
        if (!identifier.contains('@')) {
          try {
            final agentEmail = '$identifier@agent.local';
            authResponse = await supabase.auth.signInWithPassword(
              email: agentEmail,
              password: password,
            );
          } on AuthException catch (e) {
            // Common errors: "Invalid login credentials", "Email not confirmed"
            // If it's not "Invalid login credentials", it might be a real issue for an agent account.
            if (e.message.toLowerCase().contains('invalid login credentials')) {
              potentialErrorMessage = e.message; // Store for later if second attempt also fails
            } else {
              // It's a different error, probably specific to this attempt as agent
              if (mounted) context.showSnackBar(e.message, isError: true);
              setState(() => _isLoading = false);
              return;
            }
          }
        }

        // Attempt 2: If agent login didn't succeed (or wasn't tried because input contained '@'), try as direct email
        if (authResponse == null && identifier.contains('@')) {
           try {
            authResponse = await supabase.auth.signInWithPassword(
              email: identifier, // Use identifier directly as email
              password: password,
            );
          } on AuthException catch (e) {
             potentialErrorMessage = e.message; // Overwrite or store
          }
        } else if (authResponse == null && !identifier.contains('@')) {
          // This case means agent login was tried and failed with "Invalid login credentials"
          // and the input wasn't an email, so there's no second attempt to make with the identifier as email.
          // We can directly show the potentialErrorMessage from the agent attempt.
          if (potentialErrorMessage != null && mounted) {
            context.showSnackBar(potentialErrorMessage, isError: true);
          } else if (mounted) {
            // Fallback generic message if somehow potentialErrorMessage is null
            context.showSnackBar('Invalid username or email.', isError: true);
          }
          setState(() => _isLoading = false);
          return;
        }


        if (authResponse?.user == null) {
          if (mounted) context.showSnackBar(potentialErrorMessage ?? 'Invalid credentials. Please check username/email and password.', isError: true);
          setState(() => _isLoading = false);
          return;
        }
        
        // Load the user profile to get the role
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
        if (mounted) context.showSnackBar('An unexpected error occurred.', isError: true);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    // Forgot password should ideally always use the actual email.
    // If _isAgentLogin is true, we might need to ask for their agent username
    // and then construct the agent.local email, or guide them differently.
    // For simplicity now, we'll assume they need to enter the email they registered with (or synthetic one).
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      context.showSnackBar('Please enter your username or email to reset password.', isError: true);
      return;
    }
    
    String emailForReset;
    // Heuristic: if it contains '@', assume it's an email, otherwise assume it's an agent username.
    if (identifier.contains('@')) {
      emailForReset = identifier;
    } else {
      // Assume it's an agent username, construct synthetic email
      emailForReset = '$identifier@agent.local';
    }

    setState(() => _isLoading = true);
    try {
      await supabase.auth.resetPasswordForEmail(emailForReset);
      if (mounted) {
        context.showSnackBar('Password reset link sent to $emailForReset.');
      }
    } on AuthException catch (e) {
      if (mounted) context.showSnackBar(e.message, isError: true);
    } catch (e) {
      if (mounted) context.showSnackBar('An unexpected error occurred: $e', isError: true); // Added $e for more info
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                // Removed ChoiceChip Row for selecting role
                TextFormField(
                  controller: _identifierController, // Use the new controller
                  decoration: const InputDecoration(labelText: 'Username or Email'),
                  keyboardType: TextInputType.text, // General text input
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required field';
                    // Basic validation, more specific checks happen in _signIn
                    return null; 
                  },
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
                  onPressed: () => Navigator.of(context).push(
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
