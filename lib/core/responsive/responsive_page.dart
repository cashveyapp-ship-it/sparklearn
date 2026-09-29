import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double phone = 700;
  static const double tablet = 1100;

  static bool isPhone(BuildContext context) {
    return MediaQuery.sizeOf(context).width < phone;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= phone && width < tablet;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= tablet;
  }
}

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.mobilePadding = 16,
    this.tabletPadding = 24,
    this.desktopPadding = 32,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final double mobilePadding;
  final double tabletPadding;
  final double desktopPadding;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final horizontalPadding = width < ResponsiveBreakpoints.phone
        ? mobilePadding
        : width < ResponsiveBreakpoints.tablet
            ? tabletPadding
            : desktopPadding;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
          ),
          child: child,
        ),
      ),
    );
  }
}

class ResponsiveAuthPage extends StatelessWidget {
  const ResponsiveAuthPage({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      maxWidth: 560,
      mobilePadding: 16,
      tabletPadding: 24,
      desktopPadding: 24,
      child: child,
    );
  }
}
