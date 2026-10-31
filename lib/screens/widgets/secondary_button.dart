import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// The second action of a screen, beside the blue [PrimaryButton]: same
/// height and radius, a white card on the grouped gray background with an
/// `accentText` label.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final fill = AppColors.surface.resolveFrom(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: double.infinity,
        minHeight: AppSizes.primaryButtonHeight,
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        color: fill,
        disabledColor: fill.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadii.button),
        onPressed: onPressed,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.bodyStrong.copyWith(
            color: onPressed == null
                ? AppColors.textSecondary.resolveFrom(context)
                : AppColors.accentText.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
