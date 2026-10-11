import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// "‹ October 2026 ›": steps through periods below a screen title.
///
/// Both arrows have a 44pt touch target and a spoken label. Tapping the
/// label returns to the current period ([onTapLabel], null when already
/// there). [onNext] is null when there is no later period.
class PeriodStepper extends StatelessWidget {
  const PeriodStepper({
    super.key,
    required this.label,
    required this.previousLabel,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
    this.onTapLabel,
  });

  final String label;
  final String previousLabel;
  final String nextLabel;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTapLabel;

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text.resolveFrom(context);
    final disabled = AppColors.textSecondary.resolveFrom(context);
    final accent = AppColors.accentText.resolveFrom(context);

    Widget arrow({
      required IconData icon,
      required String semanticLabel,
      required VoidCallback? onPressed,
    }) {
      return Semantics(
        button: true,
        enabled: onPressed != null,
        label: semanticLabel,
        excludeSemantics: true,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(AppSizes.minTouchTarget),
          onPressed: onPressed,
          child: Icon(
            icon,
            size: 22,
            color: onPressed == null ? disabled.withValues(alpha: 0.4) : accent,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          arrow(
            icon: CupertinoIcons.chevron_left,
            semanticLabel: previousLabel,
            onPressed: onPrevious,
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTapLabel,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.minTouchTarget,
                ),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyStrong.copyWith(color: textColor),
                  ),
                ),
              ),
            ),
          ),
          arrow(
            icon: CupertinoIcons.chevron_right,
            semanticLabel: nextLabel,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
