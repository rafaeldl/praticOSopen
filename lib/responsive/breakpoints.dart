/// Screen size categories for responsive layouts.
enum ScreenSize {
  mobile,
  tablet,
  desktop,
}

/// Breakpoint constants and utilities for responsive design.
class Breakpoints {
  Breakpoints._();

  /// Width threshold for tablet layout (>= 768px).
  static const double tablet = 768;

  /// Width threshold for desktop layout (>= 1024px).
  static const double desktop = 1024;

  /// Maximum content width for centered desktop layouts.
  static const double maxContentWidth = 1200;

  /// Determine the screen size category for a given width.
  static ScreenSize getScreenSize(double width) {
    if (width >= desktop) return ScreenSize.desktop;
    if (width >= tablet) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }
}
