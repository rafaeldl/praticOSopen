import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// The single filled button of a screen: `action` / `onAction` (logo yellow,
/// navy label) with the [AppColors.actionBorder] hairline, 58 high, radius 16,
/// `bodyStrong` label. One per screen.
///
/// [floating] marks a button that floats over content (above the tab bar or
/// at the bottom of a scroll view). It stays opaque: glass is for navigation.
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
    final onAction = AppColors.onAction.resolveFrom(context);
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(AppRadii.button);

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: onAction),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.bodyStrong.copyWith(color: onAction),
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

    final Widget filled = DecoratedBox(
      decoration: actionDecoration(context, radius),
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

  /// Fill and hairline of the main action, for buttons that cannot be a
  /// [PrimaryButton] (round ✓, custom content).
  static BoxDecoration actionDecoration(
    BuildContext context,
    BorderRadius? radius, {
    BoxShape shape = BoxShape.rectangle,
  }) => BoxDecoration(
    color: AppColors.action.resolveFrom(context),
    borderRadius: shape == BoxShape.circle ? null : radius,
    shape: shape,
    border: Border.all(
      width: 1,
      color: AppColors.actionBorder.resolveFrom(context),
    ),
  );
}

/// Hairline of the main action around a yellow `CupertinoButton` that cannot
/// be a [PrimaryButton] (it has a loading state or a custom child).
class ActionOutline extends StatelessWidget {
  const ActionOutline({super.key, required this.child, this.radius});

  final Widget child;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius ?? BorderRadius.circular(AppRadii.button),
        border: Border.all(
          width: 1,
          color: AppColors.actionBorder.resolveFrom(context),
        ),
      ),
      child: child,
    );
  }
}
