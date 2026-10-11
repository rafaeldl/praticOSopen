import 'package:flutter/cupertino.dart';

/// Type scale of the PraticOS app design system (system font, SF Pro).
///
/// Styles carry size and weight only; apply a color from AppColors at the
/// call site with `.copyWith(color: AppColors.text.resolveFrom(context))`.
///
/// Dynamic Type: sizes are the iPhone default ("Large") sizes. `Text` scales
/// them with `MediaQuery.textScalerOf(context)`; never clamp or override the
/// text scaler. `height` is always a multiplier of the font size (never a
/// fixed pixel line height), so lines grow with the text.
class AppTypography {
  AppTypography._();

  /// Screen title: the iOS Large Title (34 bold). Use it through the native
  /// `CupertinoSliverNavigationBar.largeTitle`, which collapses on scroll.
  /// No `height`, so the system font metrics apply at every text size.
  static const title = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.37,
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
