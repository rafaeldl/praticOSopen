import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

/// Glass material for the navigation layer only (design system rule 11):
/// tab bar, top bar buttons, "…" menus, small sheets and the floating primary
/// button. Content (lists, next-step block, fields, background) stays opaque.
///
/// Renders a translucent fill over a backdrop blur, clipped to [borderRadius].
/// Falls back to an opaque fill (no blur) when:
/// - [enabled] is false;
/// - "Increase Contrast" is on (`MediaQuery.highContrastOf`);
/// - [reduceTransparency] is true. Flutter does not expose iOS "Reduce
///   Transparency" in `MediaQuery`; callers pass it from a native channel
///   (`UIAccessibility.isReduceTransparencyEnabled`) when available.
///
/// Replace with the official material once `cupertino_ui` ships Liquid Glass.
class AppGlass extends StatelessWidget {
  const AppGlass({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.tint,
    this.enabled = true,
    this.reduceTransparency = false,
    this.blurSigma = defaultBlurSigma,
    this.opacity = defaultOpacity,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Fill color; defaults to [AppColors.surface]. Use [AppColors.accent] for
  /// the floating primary button (glass tinted with the brand blue).
  final CupertinoDynamicColor? tint;

  final bool enabled;
  final bool reduceTransparency;
  final double blurSigma;

  /// Alpha of the fill while translucent (0..1).
  final double opacity;

  static const double defaultBlurSigma = 20;
  static const double defaultOpacity = 0.72;

  /// Whether glass must render as an opaque fill in this [context].
  static bool isOpaque(
    BuildContext context, {
    bool enabled = true,
    bool reduceTransparency = false,
  }) {
    return !enabled ||
        reduceTransparency ||
        MediaQuery.maybeHighContrastOf(context) == true;
  }

  @override
  Widget build(BuildContext context) {
    final fill = (tint ?? AppColors.surface).resolveFrom(context);
    final opaque = isOpaque(
      context,
      enabled: enabled,
      reduceTransparency: reduceTransparency,
    );

    if (opaque) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(color: fill),
          child: child,
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(color: fill.withValues(alpha: opacity)),
          child: child,
        ),
      ),
    );
  }
}
