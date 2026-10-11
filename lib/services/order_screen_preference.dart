import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local (per device) switch "Nova tela da OS".
///
/// On by default: the redesigned screen is the order screen for everyone.
/// Turning it off goes back to the legacy `OrderForm` (escape hatch). The
/// value is kept in [SharedPreferences] and mirrored in [useNewScreen] so
/// routing can read it synchronously.
class OrderScreenPreference {
  OrderScreenPreference._();

  /// New key so choices saved during the pilot (default off) are reset and
  /// every device starts on the new screen.
  static const String storageKey = 'useNewOrderScreenDefault';

  /// The new screen is the default.
  static const bool defaultValue = true;

  /// Current value. Loaded at startup by [load].
  static final ValueNotifier<bool> useNewScreen =
      ValueNotifier<bool>(defaultValue);

  /// Reads the saved value. Failures keep the default (new screen).
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
