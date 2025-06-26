import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- SUPABASE CLIENT ---
// Global access to the Supabase client
final supabase = Supabase.instance.client;

// --- COLORS AND THEMES ---
const primaryColor = Color(0xFF2196F3); // Modern blue
const secondaryColor = Color(0xFF03DAC6); // Teal accent
const backgroundColor = Color(0xFFF8F9FA); // Light gray background
const cardBackgroundColor = Colors.white;
const surfaceColor = Colors.white;

// Additional modern colors
const successColor = Color(0xFF4CAF50);
const warningColor = Color(0xFFFF9800);
const errorColor = Color(0xFFf44336);
const textPrimaryColor = Color(0xFF212121);
const textSecondaryColor = Color(0xFF757575);

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
