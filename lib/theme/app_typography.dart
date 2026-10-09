import 'package:flutter/cupertino.dart';

/// Type scale of the PraticOS app design system (system font, SF Pro).
///
/// Styles carry size and weight only; apply a color from AppColors at the
/// call site with `.copyWith(color: AppColors.text.resolveFrom(context))`.
class AppTypography {
  AppTypography._();

  /// Screen title.
  static const title = TextStyle(
    fontSize: 30,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );

  /// "Next step" sentence, the assistant transcript.
  static const highlight = TextStyle(
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );

  /// Rows, values and button labels.
  static const body = TextStyle(fontSize: 19, height: 1.3);
  static const bodyStrong = TextStyle(
    fontSize: 19,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  /// Links and secondary lines.
  static const callout = TextStyle(fontSize: 17, height: 1.3);

  /// Section labels (sentence case, never uppercase).
  static const label = TextStyle(fontSize: 15, height: 1.3);

  /// Money and quantities: keep digits aligned.
  static const tabular = [FontFeature.tabularFigures()];
}
