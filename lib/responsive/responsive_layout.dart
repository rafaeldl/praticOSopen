import 'package:flutter/widgets.dart';
import 'package:praticos/responsive/breakpoints.dart';
import 'package:praticos/responsive/responsive_builder.dart';

/// Renders different widgets based on screen size.
///
/// [mobile] is required. [tablet] and [desktop] are optional and fall back
/// to the next smaller size: desktop -> tablet -> mobile.
///
/// ```dart
/// ResponsiveLayout(
///   mobile: MobileHome(),
///   tablet: TabletHome(),
///   desktop: DesktopHome(),
/// )
/// ```
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
    return ResponsiveBuilder(
      builder: (context, screenSize) {
        switch (screenSize) {
          case ScreenSize.desktop:
            return desktop ?? tablet ?? mobile;
          case ScreenSize.tablet:
            return tablet ?? mobile;
          case ScreenSize.mobile:
            return mobile;
        }
      },
    );
  }
}
