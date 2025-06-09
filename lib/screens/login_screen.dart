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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

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
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      context.showSnackBar('Please enter your email to reset password.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.auth.resetPasswordForEmail(email);
      if (mounted) {
        context.showSnackBar('Password reset link sent to your email.');
      }
    } on AuthException catch (e) {
      if (mounted) context.showSnackBar(e.message, isError: true);
    } catch (e) {
      if (mounted) context.showSnackBar('An unexpected error occurred.', isError: true);
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
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
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
