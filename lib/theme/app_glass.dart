import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

/// Glass material for the navigation layer only (design system rule 11):
/// tab bar, top bar buttons, "…" menus and small sheets. Content (lists, next-step block, fields, background) stays opaque.
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
    this.elevated = false,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Fill color; defaults to [AppColors.surface].
  final CupertinoDynamicColor? tint;

  final bool enabled;
  final bool reduceTransparency;
  final double blurSigma;

  /// Alpha of the fill while translucent (0..1).
  final double opacity;

  /// Floating controls (tab bar, top bar buttons, menus): hairline edge in
  /// [AppColors.glassEdge], no shadow.
  final bool elevated;

  static const double defaultBlurSigma = 20;
  static const double defaultOpacity = 0.78;

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
    final glass = _buildGlass(context);
    if (!elevated) return glass;
    // Campo theme: no shadow, a hairline edge so the glass stays visible over
    // a background of the same color.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          width: 1,
          color: AppColors.glassEdge.resolveFrom(context),
        ),
      ),
      child: glass,
    );
  }

  Widget _buildGlass(BuildContext context) {
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
