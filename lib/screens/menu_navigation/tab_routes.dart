/// Route names of the main tabs, used for Firebase Analytics screen tracking.
///
/// Each tab lives in its own `CupertinoTabView` navigator, so the global
/// `FirebaseAnalyticsObserver` never sees tab switches. The navigation
/// controller logs a screen view with these names instead.
class TabRoutes {
  TabRoutes._();

  static const home = '/home';
  static const customers = '/customers';
  static const agenda = '/agenda';
  static const financial = '/financial';
  static const more = '/more';

  /// Same order as the tab bar items.
  static const List<String> all = [home, customers, agenda, financial, more];

  /// Returns the route name for a tab [index], or null when out of range.
  static String? nameForIndex(int index) =>
      index >= 0 && index < all.length ? all[index] : null;
}
