import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:praticos/responsive/breakpoints.dart';

/// Returns true when the screen width is >= tablet breakpoint (768px).
bool isDesktopLayout(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return Breakpoints.getScreenSize(width) != ScreenSize.mobile;
}

/// Returns true when running on Flutter Web.
bool isWebPlatform() => kIsWeb;
