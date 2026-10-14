import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// "‹ October 2026 ›": steps through periods below a screen title, compact
/// and left-aligned, with the period in secondary text.
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
    final secondary = AppColors.textSecondary.resolveFrom(context);
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

    // Compact and left-aligned under the large title, as in the prototype:
    // the chevrons hug the label instead of sitting at the screen edges.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          arrow(
            icon: CupertinoIcons.chevron_back,
            semanticLabel: previousLabel,
            onPressed: onPrevious,
          ),
          Flexible(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTapLabel,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.minTouchTarget,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: AppTypography.callout.copyWith(color: secondary),
                  ),
                ),
              ),
            ),
          ),
          arrow(
            icon: CupertinoIcons.chevron_forward,
            semanticLabel: nextLabel,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
