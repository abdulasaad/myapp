import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/advanced_notification.dart';

// --- SUPABASE CLIENT ---
// Global access to the Supabase client
final supabase = Supabase.instance.client;

// --- COLORS AND THEMES ---
const primaryColor = Color(0xFF2196F3); // Modern blue
const primaryLightColor = Color(0xFF64B5F6); // Lighter blue for gradients
const primaryDarkColor = Color(0xFF1976D2); // Darker blue for gradients
const secondaryColor = Color(0xFF03DAC6); // Teal accent
const backgroundColor = Color(0xFFF8F9FA); // Light gray background
const cardBackgroundColor = Colors.white;
const surfaceColor = Colors.white;

// Enhanced color palette
const successColor = Color(0xFF4CAF50);
const successLightColor = Color(0xFF81C784);
const warningColor = Color(0xFFFF9800);
const warningLightColor = Color(0xFFFFB74D);
const errorColor = Color(0xFFf44336);
const errorLightColor = Color(0xFFE57373);
const textPrimaryColor = Color(0xFF212121);
const textSecondaryColor = Color(0xFF757575);

// New accent colors for variety
const purpleAccent = Color(0xFF9C27B0);
const purpleLightAccent = Color(0xFFBA68C8);
const orangeAccent = Color(0xFFF57C00);
const orangeLightAccent = Color(0xFFFFB74D);
const indigoAccent = Color(0xFF3F51B5);
const indigoLightAccent = Color(0xFF7986CB);

// Shadow colors for elevation
const shadowColor = Color(0x1A000000);
const lightShadowColor = Color(0x0D000000);

// --- UI WIDGETS ---
const formSpacer = SizedBox(height: 16);
const formSpacerHorizontal = SizedBox(width: 16);
const preloader = Center(child: CircularProgressIndicator(color: primaryColor));

// --- HELPERS ---
extension ScaffoldMessengerHelper on BuildContext {
  void showSnackBar(String message, {bool isError = false}) {
    // Use advanced notification system
    if (isError) {
      showErrorNotification(message);
    } else {
      showSuccessNotification(message);
    }
  }
}

// Advanced notification helper extension
extension AdvancedNotificationHelper on BuildContext {
  void showAdvancedNotification(
    String message, {
    String? title,
    bool isError = false,
    bool isWarning = false,
    bool isInfo = false,
    Duration? duration,
    VoidCallback? onTap,
    IconData? customIcon,
  }) {
    // Determine notification type
    late NotificationType type;
    if (isError) {
      type = NotificationType.error;
    } else if (isWarning) {
      type = NotificationType.warning;
    } else if (isInfo) {
      type = NotificationType.info;
    } else {
      type = NotificationType.success;
    }

    AdvancedNotification.show(
      this,
      message: message,
      type: type,
      title: title,
      duration: duration ?? const Duration(seconds: 4),
      onTap: onTap,
      customIcon: customIcon,
    );
  }

  void showSuccessNotification(String message, {String? title, Duration? duration}) {
    showAdvancedNotification(message, title: title, duration: duration);
  }

  void showErrorNotification(String message, {String? title, Duration? duration}) {
    showAdvancedNotification(message, title: title, isError: true, duration: duration);
  }

  void showWarningNotification(String message, {String? title, Duration? duration}) {
    showAdvancedNotification(message, title: title, isWarning: true, duration: duration);
  }

  void showInfoNotification(String message, {String? title, Duration? duration}) {
    showAdvancedNotification(message, title: title, isInfo: true, duration: duration);
  }
}
