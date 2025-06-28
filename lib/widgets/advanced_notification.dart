// lib/widgets/advanced_notification.dart

import 'package:flutter/material.dart';
import '../utils/constants.dart';

enum NotificationType {
  success,
  error,
  warning,
  info,
}

class AdvancedNotification {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;
  static bool _isDismissing = false;

  static void show(
    BuildContext context, {
    required String message,
    required NotificationType type,
    String? title,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
    IconData? customIcon,
  }) {
    // If currently dismissing, queue the notification
    if (_isDismissing) {
      // Don't use context in async callback - just return early
      // The caller should retry or handle this case
      return;
    }

    // Hide current notification with animation if showing
    if (_isShowing) {
      _hideWithAnimation();
      // Don't use context in async callback - just return early
      // The caller should retry or handle this case
      return;
    }

    _showNotification(context,
      message: message,
      type: type,
      title: title,
      duration: duration,
      onTap: onTap,
      customIcon: customIcon,
    );
  }

  static void _showNotification(
    BuildContext context, {
    required String message,
    required NotificationType type,
    String? title,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
    IconData? customIcon,
  }) {
    _isShowing = true;
    _isDismissing = false;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => _NotificationWidget(
        message: message,
        type: type,
        title: title,
        onTap: onTap,
        customIcon: customIcon,
        onDismiss: _handleDismiss,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    // Auto-hide after duration
    Future.delayed(duration, () {
      if (_isShowing && !_isDismissing) {
        hide();
      }
    });
  }

  static void _hideWithAnimation() {
    _isDismissing = true;
    // The animation will be handled by the widget itself
  }

  static void _handleDismiss() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    _isShowing = false;
    _isDismissing = false;
  }

  static void hide() {
    if (_isShowing && _overlayEntry != null && !_isDismissing) {
      _hideWithAnimation();
      // Delay the actual removal to allow animation to complete
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleDismiss();
      });
    }
  }
}

class _NotificationWidget extends StatefulWidget {
  final String message;
  final NotificationType type;
  final String? title;
  final VoidCallback? onTap;
  final IconData? customIcon;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.message,
    required this.type,
    this.title,
    this.onTap,
    this.customIcon,
    required this.onDismiss,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      reverseDuration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Slide animation - from top to position
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2), // Start further up for better effect
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeInBack, // Smooth slide out
    ));

    // Fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    ));

    // Scale animation for a subtle zoom effect
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      reverseCurve: Curves.easeIn,
    ));

    // Start entrance animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    // Play exit animation then dismiss
    await _animationController.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _getNotificationConfig();
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: widget.onTap ?? _dismiss,
                onPanUpdate: (details) {
                  // Allow swipe up to dismiss
                  if (details.delta.dy < -10) {
                    _dismiss();
                  }
                },
                child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: config.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: -5,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          config.primaryColor,
                          config.secondaryColor,
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Icon with animated container
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                widget.customIcon ?? config.icon,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.title != null) ...[
                                    Text(
                                      widget.title!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  Text(
                                    widget.message,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            // Dismiss button
                            GestureDetector(
                              onTap: _dismiss,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ), // Close GestureDetector
              ), // Close Material  
            ), // Close ScaleTransition
          ), // Close FadeTransition
        ), // Close SlideTransition
      ), // Close Positioned
    );
  }

  _NotificationConfig _getNotificationConfig() {
    switch (widget.type) {
      case NotificationType.success:
        return _NotificationConfig(
          primaryColor: successColor,
          secondaryColor: successLightColor,
          icon: Icons.check_circle_rounded,
        );
      case NotificationType.error:
        return _NotificationConfig(
          primaryColor: errorColor,
          secondaryColor: errorLightColor,
          icon: Icons.error_rounded,
        );
      case NotificationType.warning:
        return _NotificationConfig(
          primaryColor: warningColor,
          secondaryColor: warningLightColor,
          icon: Icons.warning_rounded,
        );
      case NotificationType.info:
        return _NotificationConfig(
          primaryColor: primaryColor,
          secondaryColor: primaryLightColor,
          icon: Icons.info_rounded,
        );
    }
  }
}

class _NotificationConfig {
  final Color primaryColor;
  final Color secondaryColor;
  final IconData icon;

  _NotificationConfig({
    required this.primaryColor,
    required this.secondaryColor,
    required this.icon,
  });
}