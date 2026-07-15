import 'package:flutter/material.dart';

/// Responsive layout helper for web vs mobile.
/// Keeps mobile layout unchanged, applies constrained/grid layouts on web/desktop.
class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  static double contentMaxWidth(BuildContext context) {
    if (isDesktop(context)) return 1100;
    if (isTablet(context)) return 800;
    return double.infinity;
  }

  static int gridColumns(BuildContext context) {
    if (isDesktop(context)) return 4;
    if (isTablet(context)) return 3;
    return 2;
  }

  static double gridAspectRatio(BuildContext context) {
    if (isDesktop(context)) return 1.6;
    if (isTablet(context)) return 1.4;
    return 1.3;
  }
}

/// Wraps content in a centered, max-width container for web.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? Responsive.contentMaxWidth(context),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
