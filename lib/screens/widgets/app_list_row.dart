import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Text scale from which [AppListRow] stacks the trailing value under the
/// title (iOS accessibility text sizes start around 1.35 of the default).
const double kAppListRowStackScale = 1.35;

/// Standard list row of the app design system.
///
/// Optional [leading], [title] (wraps, never ellipsized), optional [subtitle]
/// and [trailing] value. Pass [onTap] to make the row tappable; the chevron
/// shows only when [onTap] is set, meaning the row opens another screen. At
/// accessibility text sizes the [trailing] value goes under the title instead
/// of beside it. Minimum height is [AppSizes.minTouchTarget].
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
    this.showChevron,
    this.titleStyle,
    this.trailingStyle,
  });

  final String title;
  final String? subtitle;

  /// Value shown at the end of the row (e.g. a formatted amount or status).
  final String? trailing;
  final Widget? leading;
  final VoidCallback? onTap;

  /// Overrides the chevron. Defaults to `onTap != null`.
  final bool? showChevron;
  final TextStyle? titleStyle;
  final TextStyle? trailingStyle;

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final stacked = MediaQuery.textScalerOf(context).scale(100) / 100 >=
        kAppListRowStackScale;
    final chevron = showChevron ?? onTap != null;

    final titleText = Text(
      title,
      style: (titleStyle ?? AppTypography.body).copyWith(color: textColor),
    );
    final valueText = trailing == null
        ? null
        : Text(
            trailing!,
            textAlign: stacked ? TextAlign.start : TextAlign.end,
            style: (trailingStyle ?? AppTypography.body).copyWith(
              color: secondary,
              fontFeatures: AppTypography.tabular,
            ),
          );

    final main = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleText,
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              style: AppTypography.callout.copyWith(color: secondary),
            ),
          ),
        if (stacked && valueText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: valueText,
          ),
      ],
    );

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageMargin,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(child: main),
            if (!stacked && valueText != null) ...[
              const SizedBox(width: AppSpacing.md),
              Flexible(child: valueText),
            ],
            if (chevron) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 18,
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}
