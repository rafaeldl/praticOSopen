import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'engagement_reminder_store.g.dart';

class EngagementReminderStore = _EngagementReminderStore
    with _$EngagementReminderStore;

abstract class _EngagementReminderStore with Store {
  static const String _dailyKey = 'engagement_daily_enabled';
  static const String _inactivityKey = 'engagement_inactivity_enabled';
  static const String _pendingOsKey = 'engagement_pending_os_enabled';

  _EngagementReminderStore() {
    _loadPreferences();
  }

  @observable
  bool dailyEnabled = true;

  @observable
  bool inactivityEnabled = true;

  @observable
  bool pendingOsEnabled = true;

  @action
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    dailyEnabled = prefs.getBool(_dailyKey) ?? true;
    inactivityEnabled = prefs.getBool(_inactivityKey) ?? true;
    pendingOsEnabled = prefs.getBool(_pendingOsKey) ?? true;
  }

  @action
  Future<void> setDailyEnabled(bool value) async {
    dailyEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dailyKey, value);
  }

  @action
  Future<void> setInactivityEnabled(bool value) async {
    inactivityEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_inactivityKey, value);
  }

  @action
  Future<void> setPendingOsEnabled(bool value) async {
    pendingOsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingOsKey, value);
  }
}
