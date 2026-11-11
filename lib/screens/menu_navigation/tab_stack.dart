import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The navigator of one main tab: its key, to go back to the tab's first
/// screen, and how many screens are open on it.
///
/// Each tab lives in its own `CupertinoTabView` navigator. Pass [key] as its
/// `navigatorKey` and [observer] in its `navigatorObservers`.
class TabStack {
  /// Key for the tab's navigator.
  final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  late final NavigatorObserver observer = _DepthObserver(_moved);

  final _Changes _changes = _Changes();
  int _depth = 0;

  /// Notifies when a screen opens or closes on this tab.
  Listenable get changes => _changes;

  /// True while only the tab's first screen is showing (nothing pushed on it,
  /// no sheet or picker open on its navigator).
  bool get atRoot => _depth <= 1;

  /// Closes everything open on this tab and shows its first screen again, as
  /// tapping a tab does.
  void popToRoot() {
    key.currentState?.popUntil((route) => route.isFirst);
  }

  void _moved(int delta) {
    _depth += delta;
    // Navigators report routes while they build; listeners rebuild widgets,
    // so tell them after the frame in that case.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _changes.notify());
    } else {
      _changes.notify();
    }
  }

  void dispose() => _changes.dispose();
}

class _Changes extends ChangeNotifier {
  bool _disposed = false;

  void notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _DepthObserver extends NavigatorObserver {
  _DepthObserver(this._moved);

  final void Function(int delta) _moved;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _moved(1);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _moved(-1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _moved(-1);
}
