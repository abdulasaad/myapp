import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../utils/constants.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final authResponse = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {'full_name': _fullNameController.text.trim()},
        );

        // Check if user is created and needs email confirmation
        if (authResponse.user != null) {
          if (mounted) {
            context.showSnackBar(
              AppLocalizations.of(context)!.signUpSuccessMessage,
            );
            // This is important: you might want to redirect to login
            // or show a message, instead of directly to home.
            // For now, we redirect to login screen after signup.
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          }
        }
      } on AuthException catch (e) {
        if (mounted) {
          context.showSnackBar(e.message, isError: true);
        }
      } catch (e) {
        if (mounted) {
          context.showSnackBar(AppLocalizations.of(context)!.unexpectedError, isError: true);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.signUp)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.fullName),
                  validator:
                      (value) =>
                          (value == null || value.isEmpty)
                              ? AppLocalizations.of(context)!.requiredField
                              : null,
                ),
                formSpacer,
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.email),
                  keyboardType: TextInputType.emailAddress,
                  validator:
                      (value) =>
                          (value == null || value.isEmpty)
                              ? AppLocalizations.of(context)!.requiredField
                              : null,
                ),
                formSpacer,
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.password),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return AppLocalizations.of(context)!.requiredField;
                    if (value.length < 6) {
                      return AppLocalizations.of(context)!.passwordMinLength;
                    }
                    return null;
                  },
                ),
                formSpacer,
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(AppLocalizations.of(context)!.signUp),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
