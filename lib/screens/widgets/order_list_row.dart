import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Row of an order in a list, in the style of Mail: customer and value on
/// the first line, what is being done ("Fiat Uno · troca de embreagem") on
/// the second, the status in grey on the third. Color is spent only on what
/// needs attention: an overdue order gets a red dot on the left (where Mail
/// puts "unread") and its status in danger, bold. No photo, no status dot on
/// the other rows.
class OrderListRow extends StatelessWidget {
  const OrderListRow({
    super.key,
    required this.customerName,
    required this.statusText,
    this.valueText,
    this.detailText,
    this.statusExtra,
    this.overdue = false,
    this.onTap,
  });

  final String customerName;

  /// Order total (or the visit time for a technician), grey, on the right.
  final String? valueText;

  /// Second line: device and services.
  final String? detailText;
  final String statusText;

  /// Bold piece after the status ("falta receber R$ 180").
  final String? statusExtra;

  /// Overdue: red dot on the left, status in danger and bold.
  final bool overdue;
  final VoidCallback? onTap;

  /// Room on the left for the overdue dot; dividers start here too.
  static const double leadingInset = 36;

  @override
  Widget build(BuildContext context) {
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final danger = AppColors.danger.resolveFrom(context);
    final statusStyle = overdue
        ? AppTypography.callout.copyWith(
            fontWeight: FontWeight.w700,
            color: danger,
          )
        : AppTypography.callout.copyWith(color: secondary);

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          leadingInset,
          AppSpacing.md,
          AppSpacing.pageMargin,
          AppSpacing.md,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (overdue)
              Positioned(
                left: -23,
                top: 9,
                child: Container(
                  key: const Key('order_row_overdue_dot'),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        customerName,
                        style: AppTypography.bodyStrong.copyWith(color: text),
                      ),
                    ),
                    if (valueText != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        valueText!,
                        style: AppTypography.callout.copyWith(
                          color: secondary,
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                    ],
                    if (onTap != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        CupertinoIcons.chevron_forward,
                        size: 14,
                        color: AppColors.separator.resolveFrom(context),
                      ),
                    ],
                  ],
                ),
                if (detailText != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    detailText!,
                    style: AppTypography.callout.copyWith(color: text),
                  ),
                ],
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    text: statusText,
                    children: [
                      if (statusExtra != null)
                        TextSpan(
                          text: ' · ',
                          children: [
                            TextSpan(
                              text: statusExtra,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: text,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  style: statusStyle.copyWith(
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ],
            ),
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
