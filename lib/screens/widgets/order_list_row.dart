import 'package:flutter/cupertino.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Row of an order in a list: customer + value, status line with its dot,
/// and a third line ("OS 184 · Fiat Uno 2015"). The status color lives only
/// on the dot; the text is neutral, except overdue (danger, bold). No photo:
/// rows with and without one would start at different points; the photo
/// lives inside the order.
class OrderListRow extends StatelessWidget {
  const OrderListRow({
    super.key,
    required this.customerName,
    required this.statusText,
    required this.dotColor,
    this.valueText,
    this.overdue = false,
    this.paidText,
    this.detailText,
    this.progress,
    this.onTap,
  });

  final String customerName;
  final String? valueText;
  final String statusText;
  final Color dotColor;

  /// Overdue: status text in danger, bold.
  final bool overdue;

  /// "Pago", shown in `success` after the status when set.
  final String? paidText;
  final String? detailText;

  /// Execution percentage (0..100) for segments that track it.
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final statusStyle = overdue
        ? AppTypography.label.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.danger.resolveFrom(context),
          )
        : AppTypography.label.copyWith(color: secondary);

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                customerName,
                style: AppTypography.bodyStrong.copyWith(color: text),
              ),
            ),
            if (valueText != null) ...[
              const SizedBox(width: AppSpacing.md),
              Text(
                valueText!,
                style: AppTypography.body.copyWith(
                  color: text,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StatusDot(color: dotColor),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: Text(statusText, style: statusStyle)),
            if (paidText != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                paidText!,
                style: AppTypography.label.copyWith(
                  color: AppColors.success.resolveFrom(context),
                ),
              ),
            ],
          ],
        ),
        if (detailText != null) ...[
          const SizedBox(height: 2),
          Text(
            detailText!,
            style: AppTypography.label.copyWith(color: secondary),
          ),
        ],
        if (progress != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _ProgressBar(percent: progress!),
        ],
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
          children: [
            Expanded(child: main),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(CupertinoIcons.chevron_forward, size: 18, color: secondary),
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

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final fraction = (percent / 100).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  ColoredBox(
                    color: AppColors.separator.resolveFrom(context),
                    child: const SizedBox.expand(),
                  ),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: ColoredBox(
                      color: AppColors.accent.resolveFrom(context),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${percent.toInt()}%',
          style: AppTypography.label.copyWith(
            color: secondary,
            fontFeatures: AppTypography.tabular,
          ),
        ),
      ],
    );
  }
}
