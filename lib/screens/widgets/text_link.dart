import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Text action in `accentText`, `callout` semibold, touch target of at least
/// 44. Use for secondary actions ("Ver as atrasadas", "Tentar de novo"); never
/// as a second filled button.
class TextLink extends StatelessWidget {
  const TextLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget),
      onPressed: onPressed,
      child: Text(
        label,
        style: AppTypography.callout.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.accentText.resolveFrom(context),
          decoration: TextDecoration.underline,
          decorationColor: AppColors.accentText.resolveFrom(context),
        ),
      ),
    );
  }
}
