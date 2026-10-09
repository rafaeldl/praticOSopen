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
/// Contrast of every text/background pair is measured in
/// test/theme/app_colors_contrast_test.dart.
class AppColors {
  AppColors._();

  // Surfaces
  static const background = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF000000),
  );
  static const surface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1C1C1E),
  );
  static const separator = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFEFEFF4),
    darkColor: Color(0xFF38383A),
  );

  // Text
  static const text = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1C1C1E),
    darkColor: Color(0xFFFFFFFF),
  );
  static const textSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF6C6C70),
    darkColor: Color(0xFFAEAEB2),
  );

  // Primary action: the single filled button of a screen. Brand blue.
  static const accent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF116BB5),
    darkColor: Color(0xFF116BB5),
  );
  static const onAccent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFFFFFFFF),
  );

  /// Accent used as text (links, "Trocar") on [background]/[surface].
  static const accentText = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF116BB5),
    darkColor: Color(0xFF67AAED),
  );

  // "Next step" block.
  static const accentSoft = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE0F1FF),
    darkColor: Color(0xFF142F4B),
  );
  static const onAccentSoft = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0B3D80),
    darkColor: Color(0xFFFFFFFF),
  );

  // Every other action.
  static const secondaryFill = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2F2F7),
    darkColor: Color(0xFF2C2C2E),
  );
  static const onSecondaryFill = text;

  /// Persistent assistant button ("Falar"): graphite in light, inverted in dark.
  static const assistantFill = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1C1C1E),
    darkColor: Color(0xFFF2F2F7),
  );
  static const onAssistantFill = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1C1C1E),
  );

  /// Highlighter (logo yellow): marks what the AI is about to change. Only that.
  /// Text on it is always [onMarker], in both modes.
  static const marker = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFCF2A2),
    darkColor: Color(0xFFFCF2A2),
  );
  static const onMarker = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1C1C1E),
    darkColor: Color(0xFF1C1C1E),
  );

  // Status. Never used for buttons; always paired with text.
  static const success = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1D7D3E),
    darkColor: Color(0xFF65C67D),
  );
  static const warning = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF974D00),
    darkColor: Color(0xFFECA851),
  );
  static const warningSoft = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFEBD2),
    darkColor: Color(0xFF3E290F),
  );
  static const onWarningSoft = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF7A3B00),
    darkColor: Color(0xFFECA851),
  );
  static const danger = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC93029),
    darkColor: Color(0xFFF17264),
  );
}
