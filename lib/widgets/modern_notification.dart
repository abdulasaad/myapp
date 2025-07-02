// lib/widgets/modern_notification.dart

import 'package:flutter/material.dart';
import '../utils/constants.dart';

enum NotificationType {
  success,
  error,
  warning,
  info,
}

class ModernNotification {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
    String? subtitle,
    VoidCallback? onTap,
  }) {
    // Remove any existing notification
    hide();

    final overlay = Overlay.of(context);
    _currentEntry = OverlayEntry(
      builder: (context) => _ModernNotificationWidget(
        message: message,
        type: type,
        subtitle: subtitle,
        onTap: onTap,
        onDismiss: hide,
      ),
    );

    overlay.insert(_currentEntry!);

    // Auto-hide after duration
    Future.delayed(duration, () {
      hide();
    });
  }

  static void hide() {
    _currentEntry?.remove();
    _currentEntry = null;
  }

  // Convenience methods
  static void success(
    BuildContext context, {
    required String message,
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: NotificationType.success,
      duration: duration,
    );
  }

  static void error(
    BuildContext context, {
    required String message,
    String? subtitle,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: NotificationType.error,
      duration: duration,
    );
  }

  static void warning(
    BuildContext context, {
    required String message,
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: NotificationType.warning,
      duration: duration,
    );
  }

  static void info(
    BuildContext context, {
    required String message,
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: NotificationType.info,
      duration: duration,
    );
  }
}

class _ModernNotificationWidget extends StatefulWidget {
  final String message;
  final String? subtitle;
  final NotificationType type;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const _ModernNotificationWidget({
    required this.message,
    this.subtitle,
    required this.type,
    this.onTap,
    required this.onDismiss,
  });

  @override
  State<_ModernNotificationWidget> createState() => _ModernNotificationWidgetState();
}

class _ModernNotificationWidgetState extends State<_ModernNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.info:
        return primaryColor;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top,
                    left: 16,
                    right: 16,
                  ),
                  child: GestureDetector(
                    onTap: widget.onTap,
                    onVerticalDragUpdate: (details) {
                      // Allow swipe up to dismiss
                      if (details.delta.dy < -5) {
                        _dismiss();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getBackgroundColor(),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Icon(
                              _getIcon(),
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.message,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (widget.subtitle != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.subtitle!,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _dismiss,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}