import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Section header above a list: sentence case (never uppercase, see
/// APP_DESIGN_SYSTEM.md), `label` style in `textSecondary`. Wraps at large
/// text sizes. Marked as a header for screen readers.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMargin,
          AppSpacing.xl,
          AppSpacing.pageMargin,
          AppSpacing.sm,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            text,
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary.resolveFrom(context),
            ),
          ),
        ),
      ),
    );
  }
}
