import 'package:flutter/cupertino.dart';

/// Color roles of the PraticOS app design system.
///
/// Each token is a role, not a hue: use it only for its job (see
/// docs/APP_DESIGN_SYSTEM.md). All tokens are dynamic — always resolve them:
///
/// ```dart
/// color: AppColors.accent.resolveFrom(context)
/// ```
///
/// Every token also has an "Increase Contrast" variant (light and dark), as
/// the HIG asks for custom colors; [CupertinoDynamicColor.resolveFrom] picks it
/// when `MediaQuery.highContrastOf(context)` is true.
///
/// Contrast of every text/background pair is measured, in all four variants,
/// in test/theme/app_colors_contrast_test.dart.
class AppColors {
  AppColors._();

  // Surfaces
  static const background = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF000000),
    highContrastColor: Color(0xFFFFFFFF),
    darkHighContrastColor: Color(0xFF000000),
  );
  /// Gray behind the white cards of a form sheet (Lembretes, Calendário).
  static const groupedBackground =
      CupertinoDynamicColor.withBrightnessAndContrast(
        color: Color(0xFFF2F2F7),
        darkColor: Color(0xFF000000),
        highContrastColor: Color(0xFFEBEBF0),
        darkHighContrastColor: Color(0xFF000000),
      );
  static const surface = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1C1C1E),
    highContrastColor: Color(0xFFFFFFFF),
    darkHighContrastColor: Color(0xFF1C1C1E),
  );
  static const separator = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFEFEFF4),
    darkColor: Color(0xFF38383A),
    highContrastColor: Color(0xFFC6C6C8),
    darkHighContrastColor: Color(0xFF545458),
  );

  // Text
  static const text = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF1C1C1E),
    darkColor: Color(0xFFFFFFFF),
    highContrastColor: Color(0xFF000000),
    darkHighContrastColor: Color(0xFFFFFFFF),
  );
  static const textSecondary = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF6C6C70),
    darkColor: Color(0xFFAEAEB2),
    highContrastColor: Color(0xFF3A3A3C),
    darkHighContrastColor: Color(0xFFD1D1D6),
  );

  // Primary action: the single filled button of a screen. Brand blue.
  static const accent = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF116BB5),
    darkColor: Color(0xFF116BB5),
    highContrastColor: Color(0xFF0A4F8A),
    darkHighContrastColor: Color(0xFF116BB5),
  );
  static const onAccent = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFFFFFFFF),
    highContrastColor: Color(0xFFFFFFFF),
    darkHighContrastColor: Color(0xFFFFFFFF),
  );

  /// Accent used as text (links, "Trocar") on [background]/[surface].
  static const accentText = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF116BB5),
    darkColor: Color(0xFF67AAED),
    highContrastColor: Color(0xFF0A4F8A),
    darkHighContrastColor: Color(0xFF9DCBF7),
  );

  // "Next step" block.
  static const accentSoft = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFE0F1FF),
    darkColor: Color(0xFF142F4B),
    highContrastColor: Color(0xFFD2E8FB),
    darkHighContrastColor: Color(0xFF0F2742),
  );
  static const onAccentSoft = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF0B3D80),
    darkColor: Color(0xFFFFFFFF),
    highContrastColor: Color(0xFF062B5C),
    darkHighContrastColor: Color(0xFFFFFFFF),
  );

  // Every other action.
  static const secondaryFill = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFF2F2F7),
    darkColor: Color(0xFF2C2C2E),
    highContrastColor: Color(0xFFE5E5EA),
    darkHighContrastColor: Color(0xFF2C2C2E),
  );
  static const onSecondaryFill = text;

  /// Persistent assistant button ("Falar"): graphite in light, inverted in dark.
  static const assistantFill = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF1C1C1E),
    darkColor: Color(0xFFF2F2F7),
    highContrastColor: Color(0xFF000000),
    darkHighContrastColor: Color(0xFFFFFFFF),
  );
  static const onAssistantFill =
      CupertinoDynamicColor.withBrightnessAndContrast(
        color: Color(0xFFFFFFFF),
        darkColor: Color(0xFF1C1C1E),
        highContrastColor: Color(0xFFFFFFFF),
        darkHighContrastColor: Color(0xFF000000),
      );

  /// Highlighter (logo yellow): marks what the AI is about to change. Only that.
  /// Text on it is always [onMarker], in both modes.
  static const marker = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFFCF2A2),
    darkColor: Color(0xFFFCF2A2),
    highContrastColor: Color(0xFFFCF2A2),
    darkHighContrastColor: Color(0xFFFCF2A2),
  );
  static const onMarker = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF1C1C1E),
    darkColor: Color(0xFF1C1C1E),
    highContrastColor: Color(0xFF000000),
    darkHighContrastColor: Color(0xFF000000),
  );

  // Status. Never used for buttons; always paired with text.
  static const success = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF1D7D3E),
    darkColor: Color(0xFF65C67D),
    highContrastColor: Color(0xFF11602C),
    darkHighContrastColor: Color(0xFF8AD89D),
  );
  static const warning = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF974D00),
    darkColor: Color(0xFFECA851),
    highContrastColor: Color(0xFF7A3B00),
    darkHighContrastColor: Color(0xFFF5C27F),
  );
  static const warningSoft = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFFFEBD2),
    darkColor: Color(0xFF3E290F),
    highContrastColor: Color(0xFFFFEBD2),
    darkHighContrastColor: Color(0xFF3E290F),
  );
  static const onWarningSoft = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF7A3B00),
    darkColor: Color(0xFFECA851),
    highContrastColor: Color(0xFF5C2C00),
    darkHighContrastColor: Color(0xFFF5C27F),
  );
  static const danger = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFC93029),
    darkColor: Color(0xFFF17264),
    highContrastColor: Color(0xFFA1201A),
    darkHighContrastColor: Color(0xFFFF9A8F),
  );
}
