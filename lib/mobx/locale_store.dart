import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Set a new locale and persist to storage
  @action
  Future<void> setLocale(String localeCode) async {
    if (supportedLocales.containsKey(localeCode)) {
      currentLocale = supportedLocales[localeCode]!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, localeCode);

      // NOTE: Não chamar SegmentConfigProvider.setLocale() aqui
      // O MaterialApp vai rebuildar automaticamente com novo Locale,
      // e injectL10n() será chamado com novo AppLocalizations
    }
  }

  /// Detect system locale and map to supported locale
  Locale _detectSystemLocale() {
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final languageCode = systemLocale.languageCode;

    if (languageCode == 'pt') return const Locale('pt', 'BR');
    if (languageCode == 'es') return const Locale('es', 'ES');
    return const Locale('en', 'US'); // Default to English
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
