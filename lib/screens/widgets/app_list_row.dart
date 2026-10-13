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
    this.subtitleWidget,
    this.trailing,
    this.leading,
    this.onTap,
    this.showChevron,
    this.titleStyle,
    this.trailingStyle,
    this.marked = false,
    this.selected = false,
  });

  final String title;
  final String? subtitle;

  /// Second line built by the caller (e.g. a status dot and text). Wins over
  /// [subtitle].
  final Widget? subtitleWidget;

  /// Value shown at the end of the row (e.g. a formatted amount or status).
  final String? trailing;
  final Widget? leading;
  final VoidCallback? onTap;

  /// Overrides the chevron. Defaults to `onTap != null`.
  final bool? showChevron;
  final TextStyle? titleStyle;
  final TextStyle? trailingStyle;

  /// Highlighter (marca-texto): the assistant filled this row. Yellow
  /// [AppColors.marker] background with [AppColors.onMarker] text, in both
  /// modes.
  final bool marked;

  /// The current choice of a picker: blue check mark at the end of the row,
  /// after the [trailing] value. Announced as selected to screen readers.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final onMarker = AppColors.onMarker.resolveFrom(context);
    final textColor = marked ? onMarker : AppColors.text.resolveFrom(context);
    final secondary = marked
        ? onMarker.withValues(alpha: 0.75)
        : AppColors.textSecondary.resolveFrom(context);
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
        if (subtitleWidget != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: subtitleWidget,
          )
        else if (subtitle != null)
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
              Flexible(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: valueText,
                ),
              ),
            ],
            if (selected) ...[
              const SizedBox(width: AppSpacing.md),
              Icon(
                CupertinoIcons.checkmark_alt,
                size: 26,
                color: AppColors.accent.resolveFrom(context),
              ),
            ],
            if (chevron) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 18,
                color: secondary,
              ),
            ],
          ],
        ),
      ),
    );

    final content = marked
        ? ColoredBox(color: AppColors.marker.resolveFrom(context), child: row)
        : row;

    if (onTap == null) {
      return selected ? Semantics(selected: true, child: content) : content;
    }
    return Semantics(
      button: true,
      selected: selected ? true : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      ),
    );
  }
}
