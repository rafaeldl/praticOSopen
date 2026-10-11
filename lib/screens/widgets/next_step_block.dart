import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// "What to do now": a soft colored block with an optional short [label], one
/// sentence ([text], `highlight` style) and optionally one action: a
/// [PrimaryButton]-like [button] or a [linkLabel] link. Render nothing (don't
/// build it) when there is no next step.
///
/// [warning] is the "something is missing / late" variant (`warningSoft`).
class NextStepBlock extends StatelessWidget {
  const NextStepBlock({
    super.key,
    required this.text,
    this.label,
    this.linkLabel,
    this.onLink,
    this.button,
    this.warning = false,
  });

  final String text;
  final String? label;
  final String? linkLabel;
  final VoidCallback? onLink;

  /// A button shown under the sentence (e.g. a `PrimaryButton`).
  final Widget? button;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final background = (warning ? AppColors.warningSoft : AppColors.accentSoft)
        .resolveFrom(context);
    final foreground =
        (warning ? AppColors.onWarningSoft : AppColors.onAccentSoft)
            .resolveFrom(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.blockMargin),
      padding: const EdgeInsets.all(AppSpacing.xl - 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.block),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: AppTypography.label.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            text,
            style: AppTypography.highlight.copyWith(color: foreground),
          ),
          if (linkLabel != null && onLink != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(
                  AppSizes.minTouchTarget,
                  AppSizes.minTouchTarget,
                ),
                onPressed: onLink,
                child: Text(
                  linkLabel!,
                  style: AppTypography.callout.copyWith(
                    fontWeight: FontWeight.w600,
                    color: foreground,
                    decoration: TextDecoration.underline,
                    decorationColor: foreground,
                  ),
                ),
              ),
            ),
          if (button != null) ...[
            const SizedBox(height: AppSpacing.lg),
            button!,
          ],
        ],
      ),
    );
  }
}
