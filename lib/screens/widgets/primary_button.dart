import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_glass.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// The single filled button of a screen: `accent` / `onAccent`, 58 high,
/// radius 16, `bodyStrong` label. One per screen.
///
/// With [floating] the button is glass tinted with the brand blue (design
/// system rule 11) and is meant to float above the tab bar. It falls back to
/// an opaque fill under "Increase Contrast".
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.floating = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool floating;

  /// Fills the available width. When false the button hugs its label.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final onAccent = AppColors.onAccent.resolveFrom(context);
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(AppRadii.button);

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: onAccent),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.bodyStrong.copyWith(color: onAccent),
          ),
        ),
      ],
    );

    final body = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppSizes.primaryButtonHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Center(widthFactor: 1, child: content),
      ),
    );

    final Widget filled = floating
        ? AppGlass(
            tint: AppColors.accent,
            opacity: 0.88,
            borderRadius: radius,
            child: body,
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.accent.resolveFrom(context),
              borderRadius: radius,
            ),
            child: body,
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: filled,
        ),
      ),
    );
  }
}
