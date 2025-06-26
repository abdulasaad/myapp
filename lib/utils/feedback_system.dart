// lib/utils/feedback_system.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FeedbackSystem {
  static final FeedbackSystem _instance = FeedbackSystem._internal();
  factory FeedbackSystem() => _instance;
  FeedbackSystem._internal();

  /// Show success feedback with haptic response
  static void showSuccess(BuildContext context, String message, {
    Duration? duration,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    HapticFeedback.lightImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: onAction != null && actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  /// Show error feedback with stronger haptic response
  static void showError(BuildContext context, String message, {
    Duration? duration,
    VoidCallback? onRetry,
  }) {
    HapticFeedback.mediumImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: duration ?? const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show warning feedback
  static void showWarning(BuildContext context, String message, {
    Duration? duration,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    HapticFeedback.selectionClick();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange[600],
        duration: duration ?? const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: onAction != null && actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  /// Show info feedback
  static void showInfo(BuildContext context, String message, {
    Duration? duration,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue[600],
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Show loading feedback
  static void showLoading(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.grey[700],
        duration: const Duration(seconds: 30), // Long duration for loading
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Enhanced form validation with visual feedback
class ValidationHelper {
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  static String? validateMinLength(String? value, int minLength, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    if (value.trim().length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    
    return null;
  }

  static String? validateNumber(String? value, String fieldName, {
    int? min,
    int? max,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    final number = int.tryParse(value.trim());
    if (number == null) {
      return '$fieldName must be a valid number';
    }
    
    if (min != null && number < min) {
      return '$fieldName must be at least $min';
    }
    
    if (max != null && number > max) {
      return '$fieldName must be at most $max';
    }
    
    return null;
  }

  static String? validatePoints(String? value) {
    return validateNumber(value, 'Points', min: 1, max: 1000);
  }
}

/// Visual loading states and animations
class LoadingStates {
  static Widget buildLoadingCard() {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildErrorCard(String message, VoidCallback? onRetry) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(icon, size: 40, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Connection state indicator
class ConnectionIndicator extends StatefulWidget {
  final Widget child;
  
  const ConnectionIndicator({super.key, required this.child});

  @override
  State<ConnectionIndicator> createState() => _ConnectionIndicatorState();
}

class _ConnectionIndicatorState extends State<ConnectionIndicator> {
  bool _isOnline = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_isOnline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.red[600],
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'No internet connection',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Progress indicators with percentage
class ProgressIndicators {
  static Widget buildTaskProgress(double progress, {String? label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: progress == 1.0 ? Colors.green : Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress == 1.0 ? Colors.green : Colors.blue,
          ),
          minHeight: 8,
        ),
      ],
    );
  }

  static Widget buildCircularProgress(double progress, {
    String? centerText,
    Color? color,
    double size = 80,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? (progress == 1.0 ? Colors.green : Colors.blue),
            ),
            strokeWidth: 6,
          ),
          if (centerText != null)
            Text(
              centerText,
              style: TextStyle(
                fontSize: size * 0.2,
                fontWeight: FontWeight.bold,
                color: color ?? (progress == 1.0 ? Colors.green : Colors.blue),
              ),
            ),
        ],
      ),
    );
  }
}

/// Input helpers with real-time validation
class SmartTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextEditingController? controller;
  final VoidCallback? onChanged;
  final TextInputType? keyboardType;
  final bool required;
  final int? maxLines;
  final List<String>? suggestions;

  const SmartTextField({
    super.key,
    this.label,
    this.hint,
    this.validator,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.required = false,
    this.maxLines = 1,
    this.suggestions,
  });

  @override
  State<SmartTextField> createState() => _SmartTextFieldState();
}

class _SmartTextFieldState extends State<SmartTextField> {
  String? _errorText;
  bool _showSuggestions = false;

  void _validateInput(String value) {
    if (widget.validator != null) {
      setState(() {
        _errorText = widget.validator!(value);
      });
    }
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          maxLines: widget.maxLines,
          onChanged: _validateInput,
          onTap: () {
            if (widget.suggestions?.isNotEmpty ?? false) {
              setState(() => _showSuggestions = true);
            }
          },
          decoration: InputDecoration(
            labelText: widget.required ? '${widget.label} *' : widget.label,
            hintText: widget.hint,
            errorText: _errorText,
            prefixIcon: _errorText != null
                ? const Icon(Icons.error, color: Colors.red)
                : _errorText == null && widget.controller?.text.isNotEmpty == true
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
            suffixIcon: widget.suggestions?.isNotEmpty == true
                ? IconButton(
                    icon: Icon(_showSuggestions ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                    onPressed: () => setState(() => _showSuggestions = !_showSuggestions),
                  )
                : null,
          ),
        ),
        if (_showSuggestions && (widget.suggestions?.isNotEmpty ?? false))
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: widget.suggestions!.take(5).map((suggestion) {
                return ListTile(
                  dense: true,
                  title: Text(suggestion),
                  onTap: () {
                    widget.controller?.text = suggestion;
                    setState(() => _showSuggestions = false);
                    _validateInput(suggestion);
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}