import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Row of an order in a list, in the style of Mail: customer and value on
/// the first line, what is being done ("Fiat Uno · troca de embreagem") on
/// the second, the status on the third: "● Pintura · Pago", the dot in the
/// status color and the text in grey (docs/DESIGN_TOKENS.md, "Situação da
/// OS"). A problem (overdue, stopped) goes on the right of that line, bold,
/// in its own color: "Atrasada 2 dias", "Parada há 3 dias".
class OrderListRow extends StatelessWidget {
  const OrderListRow({
    super.key,
    required this.customerName,
    this.statusText,
    this.statusColor,
    this.valueText,
    this.detailText,
    this.statusExtra,
    this.statusExtraColor,
    this.problemText,
    this.problemColor,
    this.onTap,
  });

  final String customerName;

  /// Order total (or the visit time for a technician), grey, on the right.
  final String? valueText;

  /// Second line: device and services.
  final String? detailText;

  /// Status or stage ("Pintura", "Pronto para retirada"), in grey. No
  /// status line when null and there is no [statusExtra] nor [problemText].
  final String? statusText;

  /// Dot before the status; none when null.
  final Color? statusColor;

  /// Bold piece after the status: the payment ("Pago", "falta R$ 180").
  final String? statusExtra;

  /// Color of [statusExtra]; the text color when null.
  final Color? statusExtraColor;

  /// Problem on the right of the status line ("Atrasada 2 dias").
  final String? problemText;

  /// Color of [problemText] (danger for overdue, warning for stopped).
  final Color? problemColor;
  final VoidCallback? onTap;

  /// Left margin of the row; dividers start here too.
  static const double leadingInset = AppSpacing.pageMargin;

  @override
  Widget build(BuildContext context) {
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final statusStyle = AppTypography.callout.copyWith(
      color: secondary,
      fontFeatures: AppTypography.tabular,
    );

    final status = Text.rich(
      TextSpan(
        children: [
          if (statusColor != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  key: const Key('order_row_status_dot'),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          if (statusText != null) TextSpan(text: statusText),
          if (statusExtra != null)
            TextSpan(
              text: statusText == null ? '' : ' · ',
              children: [
                TextSpan(
                  text: statusExtra,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: statusExtraColor ?? text,
                  ),
                ),
              ],
            ),
        ],
      ),
      style: statusStyle,
    );

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          leadingInset,
          AppSpacing.md,
          AppSpacing.pageMargin,
          AppSpacing.md,
        ),
        child: Column(
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
            if (statusText != null ||
                statusExtra != null ||
                problemText != null) ...[
              const SizedBox(height: 2),
              if (problemText == null)
                status
              else
                // Status on the left, problem on the right; with large text the
                // problem drops below the status instead of squeezing it.
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: AppSpacing.sm,
                    children: [
                      status,
                      Text(
                        problemText!,
                        key: const Key('order_row_problem'),
                        style: statusStyle.copyWith(
                          fontWeight: FontWeight.w700,
                          color: problemColor ?? text,
                        ),
                      ),
                    ],
                  ),
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
