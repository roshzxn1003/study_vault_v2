import 'package:flutter/material.dart';

/// Responsive layout breakpoints and utilities for Study Vault.
enum DeviceType { mobile, tablet, desktop }

class AppBreakpoints {
  AppBreakpoints._();

  static const double mobileMax = 600.0;
  static const double tabletMax = 1024.0;

  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileMax) return DeviceType.mobile;
    if (width < tabletMax) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  static bool isMobile(BuildContext context) =>
      isMobileWidth(MediaQuery.of(context).size.width);

  static bool isTablet(BuildContext context) =>
      isTabletWidth(MediaQuery.of(context).size.width);

  static bool isDesktop(BuildContext context) =>
      isDesktopWidth(MediaQuery.of(context).size.width);

  static bool isMobileWidth(double width) => width < mobileMax;

  static bool isTabletWidth(double width) =>
      width >= mobileMax && width < tabletMax;

  static bool isDesktopWidth(double width) => width >= tabletMax;
}

/// Adaptive layout builder widget that switches based on screen width.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = AppBreakpoints.getDeviceType(context);

    switch (deviceType) {
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.mobile:
        return mobile;
    }
  }
}
