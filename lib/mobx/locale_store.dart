import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../global.dart';

part 'locale_store.g.dart';

/// Store for managing app locale/language settings.
///
/// Supports 3 languages: pt-BR, en-US, es-ES.
/// Persists locale preference in SharedPreferences and syncs
/// with SegmentConfigProvider for dynamic labels.
class LocaleStore = _LocaleStore with _$LocaleStore;

abstract class _LocaleStore with Store {
  static const String _localeKey = 'app_locale';

  /// Mapping of locale codes to Locale objects
  static const Map<String, Locale> supportedLocales = {
    'pt-BR': Locale('pt', 'BR'),
    'en-US': Locale('en', 'US'),
    'es-ES': Locale('es', 'ES'),
  };

  /// Current selected locale
  @observable
  Locale currentLocale = const Locale('pt', 'BR');

  /// Flag indicating if locale has been loaded from storage
  @observable
  bool isLoaded = false;

  /// Load saved locale from SharedPreferences or detect from system
  @action
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);

    if (savedLocale != null && supportedLocales.containsKey(savedLocale)) {
      currentLocale = supportedLocales[savedLocale]!;
    } else {
      // Detect from system locale
      currentLocale = _detectSystemLocale();
    }

    // NOTE: Não chamar SegmentConfigProvider.setLocale() aqui
    // O MaterialApp builder vai chamar injectL10n() automaticamente
    // quando reconstruir com o novo AppLocalizations

    isLoaded = true;
  }

  /// Set a new locale and persist to storage.
  /// Also syncs preferredLanguage to Firestore (fire-and-forget).
  @action
  Future<void> setLocale(String localeCode) async {
    if (supportedLocales.containsKey(localeCode)) {
      currentLocale = supportedLocales[localeCode]!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, localeCode);

      // Sync to Firestore (fire-and-forget)
      _syncLocaleToFirestore(localeCode);
    }
  }

  /// Returns the real device locale as a BCP47 string (e.g., "fr-FR", "de-DE").
  /// This is NOT mapped to the 3 supported locales — it's the raw OS locale.
  String get deviceLocaleCode {
    final systemLocale =
        WidgetsBinding.instance.platformDispatcher.locale;
    final lang = systemLocale.languageCode;
    final country = systemLocale.countryCode;
    if (country != null && country.isNotEmpty) {
      return '$lang-$country';
    }
    return lang;
  }

  /// On login, if Firestore has a preferredLanguage, map it to the closest
  /// supported locale and apply it to the app UI.
  @action
  Future<void> syncFromFirestore(String? firestoreLocale) async {
    if (firestoreLocale == null || firestoreLocale.isEmpty) return;

    final mapped = _mapToSupportedLocale(firestoreLocale);
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);

    // Only override if the user hasn't manually set a locale
    if (savedLocale == null) {
      currentLocale = supportedLocales[mapped]!;
      await prefs.setString(_localeKey, mapped);
    }
  }

  /// Maps any BCP47 locale code to the closest supported locale.
  /// Used only for the app UI (3 options: pt-BR, en-US, es-ES).
  String _mapToSupportedLocale(String locale) {
    final lang = locale.split('-').first.toLowerCase();
    if (lang == 'pt') return 'pt-BR';
    if (lang == 'es') return 'es-ES';
    return 'en-US'; // fallback
  }

  /// Detect system locale and map to supported locale
  Locale _detectSystemLocale() {
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final languageCode = systemLocale.languageCode;

    if (languageCode == 'pt') return const Locale('pt', 'BR');
    if (languageCode == 'es') return const Locale('es', 'ES');
    return const Locale('en', 'US'); // Default to English
  }

  /// Fire-and-forget: update preferredLanguage on the user doc in Firestore
  void _syncLocaleToFirestore(String localeCode) {
    final userId = Global.currentUser?.uid;
    if (userId == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'preferredLanguage': localeCode}).catchError((e) {
      // Silently ignore — fire-and-forget
      print('LocaleStore: failed to sync locale to Firestore: $e');
    });
  }

  /// Get the current locale code string (e.g., "pt-BR")
  @computed
  String get currentLocaleCode {
    return '${currentLocale.languageCode}-${currentLocale.countryCode}';
  }

  /// Get the display name for the current locale
  @computed
  String get currentLocaleDisplayName {
    switch (currentLocaleCode) {
      case 'pt-BR':
        return 'Português';
      case 'en-US':
        return 'English';
      case 'es-ES':
        return 'Español';
      default:
        return 'Português';
    }
  }

  /// Get all available locales for UI selection
  List<Map<String, String>> get availableLocales => [
        {'code': 'pt-BR', 'name': 'Português', 'flag': '🇧🇷'},
        {'code': 'en-US', 'name': 'English', 'flag': '🇺🇸'},
        {'code': 'es-ES', 'name': 'Español', 'flag': '🇪🇸'},
      ];
}
