import 'package:flutter/widgets.dart';
import 'package:praticos/responsive/breakpoints.dart';

/// A builder widget that provides the current [ScreenSize] to its child.
///
/// Uses [MediaQuery] width to determine the screen size category
/// and rebuilds when the category changes.
///
/// ```dart
/// ResponsiveBuilder(
///   builder: (context, screenSize) {
///     if (screenSize == ScreenSize.desktop) {
///       return DesktopLayout();
///     }
///     return MobileLayout();
///   },
/// )
/// ```
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize screenSize) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final screenSize = Breakpoints.getScreenSize(width);
    return builder(context, screenSize);
  }
}
