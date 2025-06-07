import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- SUPABASE CLIENT ---
// Global access to the Supabase client
final supabase = Supabase.instance.client;

// --- COLORS AND THEMES ---
const primaryColor = Colors.teal;
const backgroundColor = Color.fromRGBO(24, 24, 32, 1);
const cardBackgroundColor = Color.fromRGBO(36, 36, 48, 1);

// --- UI WIDGETS ---
const formSpacer = SizedBox(height: 16);
const formSpacerHorizontal = SizedBox(width: 16);
const preloader = Center(child: CircularProgressIndicator(color: primaryColor));

// --- HELPERS ---
extension ScaffoldMessengerHelper on BuildContext {
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(this).colorScheme.error : Colors.green[400],
      ),
    );
  }
}
