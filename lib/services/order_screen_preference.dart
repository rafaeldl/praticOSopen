import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local (per device) switch "Nova tela da OS".
///
/// Off by default: the legacy `OrderForm` stays the order screen until the
/// redesigned one reaches parity. The value is kept in [SharedPreferences]
/// and mirrored in [useNewScreen] so routing can read it synchronously.
class OrderScreenPreference {
  OrderScreenPreference._();

  static const String storageKey = 'useNewOrderScreen';

  /// Default while the new screen is in pilot.
  static const bool defaultValue = false;

  /// Current value. Loaded at startup by [load].
  static final ValueNotifier<bool> useNewScreen =
      ValueNotifier<bool>(defaultValue);

  /// Reads the saved value. Failures keep the default (legacy screen).
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      useNewScreen.value = prefs.getBool(storageKey) ?? defaultValue;
    } catch (_) {
      useNewScreen.value = defaultValue;
    }
  }

  /// Turns the new screen on or off and saves the choice.
  static Future<void> set(bool value) async {
    useNewScreen.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(storageKey, value);
    } catch (_) {
      // Keeps working for this session even if it cannot be saved.
    }
  }
}
