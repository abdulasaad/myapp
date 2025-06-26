// lib/utils/responsive.dart

import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double mobile = 480;
  static const double tablet = 768;
  static const double desktop = 1024;
}

class ResponsiveHelper {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobile;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveBreakpoints.mobile &&
        MediaQuery.of(context).size.width < ResponsiveBreakpoints.desktop;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveBreakpoints.desktop;
  }

  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 16);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 32);
    } else {
      return const EdgeInsets.symmetric(horizontal: 64);
    }
  }

  static int getCrossAxisCount(BuildContext context, double itemWidth) {
    final screenWidth = getScreenWidth(context);
    final padding = getScreenPadding(context).horizontal;
    final availableWidth = screenWidth - padding;
    final count = (availableWidth / itemWidth).floor();
    return count > 0 ? count : 1;
  }

  static double getCardMaxWidth(BuildContext context) {
    if (isMobile(context)) {
      return double.infinity;
    } else if (isTablet(context)) {
      return 600;
    } else {
      return 800;
    }
  }
}

class MobileOptimizations {
  // Optimized touch targets for mobile
  static const double minTouchTarget = 48.0;
  static const double preferredTouchTarget = 56.0;
  
  // Spacing for mobile layouts
  static const double smallSpacing = 8.0;
  static const double mediumSpacing = 16.0;
  static const double largeSpacing = 24.0;
  static const double extraLargeSpacing = 32.0;
  
  // Border radius for mobile-friendly UI
  static const double smallRadius = 8.0;
  static const double mediumRadius = 12.0;
  static const double largeRadius = 16.0;
  
  // Text sizes optimized for mobile screens
  static const double smallText = 12.0;
  static const double bodyText = 14.0;
  static const double titleText = 16.0;
  static const double headingText = 18.0;
  static const double largeHeadingText = 24.0;
  
  // Safe area for notched devices
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
    );
  }
  
  // Keyboard aware padding
  static EdgeInsets getKeyboardAwarePadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      bottom: mediaQuery.viewInsets.bottom,
    );
  }
}

// Widget extensions for responsive design
extension ResponsiveWidget on Widget {
  Widget paddingResponsive(BuildContext context) {
    return Padding(
      padding: ResponsiveHelper.getScreenPadding(context),
      child: this,
    );
  }
  
  Widget maxWidthResponsive(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: ResponsiveHelper.getCardMaxWidth(context),
      ),
      child: this,
    );
  }
  
  Widget centerResponsive(BuildContext context) {
    return Center(
      child: maxWidthResponsive(context),
    );
  }
}

// Custom responsive widgets
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;
  
  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    DeviceType deviceType;
    
    if (ResponsiveHelper.isMobile(context)) {
      deviceType = DeviceType.mobile;
    } else if (ResponsiveHelper.isTablet(context)) {
      deviceType = DeviceType.tablet;
    } else {
      deviceType = DeviceType.desktop;
    }
    
    return builder(context, deviceType);
  }
}

enum DeviceType { mobile, tablet, desktop }

class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final double itemWidth;
  final double spacing;
  final double runSpacing;
  
  const ResponsiveGridView({
    super.key,
    required this.children,
    required this.itemWidth,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = ResponsiveHelper.getCrossAxisCount(context, itemWidth);
    
    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: spacing,
      mainAxisSpacing: runSpacing,
      childAspectRatio: 1.0,
      children: children,
    );
  }
}