import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'reminder_store.g.dart';

class ReminderStore = _ReminderStore with _$ReminderStore;

abstract class _ReminderStore with Store {
  static const String _reminderPreferenceKey = 'reminder_minutes';
  static const List<int> validOptions = [0, 15, 30, 60, 120];

  _ReminderStore() {
    _loadPreference();
  }

  @observable
  int reminderMinutes = 30;

  @action
  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_reminderPreferenceKey);
    if (saved != null && validOptions.contains(saved)) {
      reminderMinutes = saved;
    }
  }

  @action
  Future<void> setReminderMinutes(int minutes) async {
    if (!validOptions.contains(minutes)) return;
    reminderMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderPreferenceKey, minutes);
  }
}
