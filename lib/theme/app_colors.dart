import 'package:flutter/cupertino.dart';

/// Color roles of the PraticOS app design system: the "Campo" theme
/// (docs/DESIGN_TOKENS.md), the system layer — white background, navy text,
/// warm grays, yellow for the one main action, blue for links and selection.
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
    darkColor: Color(0xFF0C1015),
    highContrastColor: Color(0xFFFFFFFF),
    darkHighContrastColor: Color(0xFF0C1015),
  );

  /// Warm gray behind the white cards of a form sheet.
  static const groupedBackground =
      CupertinoDynamicColor.withBrightnessAndContrast(
        color: Color(0xFFF2F0EC),
        darkColor: Color(0xFF13181D),
        highContrastColor: Color(0xFFF2F0EC),
        darkHighContrastColor: Color(0xFF13181D),
      );
  static const surface = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1D2228),
    highContrastColor: Color(0xFFFFFFFF),
    darkHighContrastColor: Color(0xFF1D2228),
  );
  static const separator = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFE3E0DA),
    darkColor: Color(0xFF2A3038),
    highContrastColor: Color(0xFFC4BFB6),
    darkHighContrastColor: Color(0xFF4A525C),
  );

  // Text
  static const text = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF07294F),
    darkColor: Color(0xFFF1EEE8),
    highContrastColor: Color(0xFF07294F),
    darkHighContrastColor: Color(0xFFFFFFFF),
  );
  static const textSecondary = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF646A71),
    darkColor: Color(0xFFB4BAC2),
    highContrastColor: Color(0xFF3A3F45),
    darkHighContrastColor: Color(0xFFD3D8DE),
  );

  /// Supporting text only (service, note, value under a name): 3.3:1 on
  /// white, so never for anything the user must read to act.
  static const textTertiary = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF8A8F96),
    darkColor: Color(0xFF8A9099),
    highContrastColor: Color(0xFF5E636A),
    darkHighContrastColor: Color(0xFFB4BAC2),
  );

  /// Main action: the single filled button of a screen (58 high), the ✓ that
  /// saves and the "OK" of select mode. Logo yellow with navy text, the same
  /// in both modes; always drawn with [actionBorder].
  static const action = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFFFC921),
    darkColor: Color(0xFFFFC921),
    highContrastColor: Color(0xFFFFC921),
    darkHighContrastColor: Color(0xFFFFC921),
  );
  static const onAction = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF07294F),
    darkColor: Color(0xFF07294F),
    highContrastColor: Color(0xFF07294F),
    darkHighContrastColor: Color(0xFF07294F),
  );

  /// Hairline around [action]: yellow on white has little edge (1.4:1).
  /// Not needed on the dark background.
  static const actionBorder = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0x4707294F),
    darkColor: Color(0x00000000),
    highContrastColor: Color(0x8007294F),
    darkHighContrastColor: Color(0x00000000),
  );

  /// Brand blue as a fill: selection (checked circle, picked day), the
  /// current tab. Never a button.
  static const accent = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF1467C2),
    darkColor: Color(0xFF2775C8),
    highContrastColor: Color(0xFF0F4F96),
    darkHighContrastColor: Color(0xFF2775C8),
  );
  static const onAccent = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFFFFFFFF),
    highContrastColor: Color(0xFFFFFFFF),
    darkHighContrastColor: Color(0xFFFFFFFF),
  );

  /// Brand blue as text: links, "+ Adicionar", the current tab.
  static const accentText = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF1467C2),
    darkColor: Color(0xFF7DB6F2),
    highContrastColor: Color(0xFF0F4F96),
    darkHighContrastColor: Color(0xFFA9D0F7),
  );

  /// Background of a selected row, and of what the assistant just filled.
  static const accentSoft = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFEAF2FB),
    darkColor: Color(0xFF16304A),
    highContrastColor: Color(0xFFEAF2FB),
    darkHighContrastColor: Color(0xFF12283E),
  );
  static const onAccentSoft = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF07294F),
    darkColor: Color(0xFFF1EEE8),
    highContrastColor: Color(0xFF07294F),
    darkHighContrastColor: Color(0xFFFFFFFF),
  );

  // Every other action.
  static const secondaryFill = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFF1EEE7),
    darkColor: Color(0xFF232931),
    highContrastColor: Color(0xFFF1EEE7),
    darkHighContrastColor: Color(0xFF2C333B),
  );
  static const onSecondaryFill = text;

  /// Navy fill: the "+" (Nova OS) beside the tabs and the chosen filter on
  /// Início (like the site and the web). Inverted (cream) in dark,
  /// where navy would vanish into the background.
  static const navyFill = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF07294F),
    darkColor: Color(0xFFF1EEE8),
    highContrastColor: Color(0xFF07294F),
    darkHighContrastColor: Color(0xFFFFFFFF),
  );
  static const onNavyFill = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF07294F),
    highContrastColor: Color(0xFFFFFFFF),
    darkHighContrastColor: Color(0xFF07294F),
  );

  /// Hairline edge of the glass (tab bar, top buttons, small sheets).
  static const glassEdge = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0x1F07294F),
    darkColor: Color(0x1FFFFFFF),
    highContrastColor: Color(0x5207294F),
    darkHighContrastColor: Color(0x52FFFFFF),
  );

  /// Site navy and logo yellow, fixed (login, navy bands). For roles use
  /// [text], [action] and [navyFill].
  static const brandNavy = Color(0xFF07294F);
  static const brandYellow = Color(0xFFFFC921);

  // Status. Never used for buttons; always paired with text.
  static const success = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF1D7D3E),
    darkColor: Color(0xFF65C67D),
    highContrastColor: Color(0xFF136239),
    darkHighContrastColor: Color(0xFF8AD89D),
  );
  static const warning = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF975800),
    darkColor: Color(0xFFF0B45A),
    highContrastColor: Color(0xFF7A4600),
    darkHighContrastColor: Color(0xFFF5C27F),
  );

  /// Only the "in progress" dot (and a stage's). Text uses [warning].
  static const warningDot = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFD98B09),
    darkColor: Color(0xFFF0A93B),
    highContrastColor: Color(0xFFB06F00),
    darkHighContrastColor: Color(0xFFF5C27F),
  );
  static const warningSoft = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFFFEBD2),
    darkColor: Color(0xFF3E290F),
    highContrastColor: Color(0xFFFFEBD2),
    darkHighContrastColor: Color(0xFF3E290F),
  );
  static const onWarningSoft = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFF7A4600),
    darkColor: Color(0xFFF0B45A),
    highContrastColor: Color(0xFF5C3400),
    darkHighContrastColor: Color(0xFFF5C27F),
  );
  static const danger = CupertinoDynamicColor.withBrightnessAndContrast(
    color: Color(0xFFC93029),
    darkColor: Color(0xFFFF7A6B),
    highContrastColor: Color(0xFFA1201A),
    darkHighContrastColor: Color(0xFFFF9A8F),
  );
}
