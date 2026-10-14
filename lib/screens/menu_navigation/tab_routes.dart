/// Route names of the main tabs, used for Firebase Analytics screen tracking.
///
/// Each tab lives in its own `CupertinoTabView` navigator, so the global
/// `FirebaseAnalyticsObserver` never sees tab switches. The navigation
/// controller logs a screen view with these names instead.
class TabRoutes {
  TabRoutes._();

  static const home = '/home';
  static const agenda = '/agenda';
  static const financial = '/financial';

  /// Every tab, in the fixed tab bar order.
  static const List<String> all = [home, agenda, financial];

  /// Returns the route name for a tab [index], or null when out of range.
  ///
  /// Some tabs can be hidden, so pass the [routes] of the visible tabs (in
  /// tab bar order) to map the index the tab bar reports.
  static String? nameForIndex(int index, {List<String> routes = all}) =>
      index >= 0 && index < routes.length ? routes[index] : null;
}
