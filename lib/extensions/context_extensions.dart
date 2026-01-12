import 'package:flutter/material.dart';
import 'package:praticos/l10n/app_localizations.dart';

/// Extension to provide easy access to AppLocalizations from BuildContext.
///
/// Usage:
/// ```dart
/// Text(context.l10n.save)  // Instead of AppLocalizations.of(context)!.save
/// ```
extension LocalizationExtension on BuildContext {
  /// Get the AppLocalizations instance for the current context.
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Extension to check current locale from BuildContext.
extension LocaleExtension on BuildContext {
  /// Get the current Locale from the context.
  Locale get currentLocale => Localizations.localeOf(this);

  /// Check if current locale is Portuguese.
  bool get isPortuguese => currentLocale.languageCode == 'pt';

  /// Check if current locale is English.
  bool get isEnglish => currentLocale.languageCode == 'en';

  /// Check if current locale is Spanish.
  bool get isSpanish => currentLocale.languageCode == 'es';

  /// Get the locale code string (e.g., "pt-BR").
  String get localeCode =>
      '${currentLocale.languageCode}-${currentLocale.countryCode ?? ''}';
}
