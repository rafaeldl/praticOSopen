import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/theme/status_style.dart';

/// Row of an order in the customer and vehicle screens:
/// "OS 183 · Revisão completa" with the value at the right, and the status as
/// a colored dot plus text in `textSecondary` underneath (overdue: `danger`,
/// bold). No dot at the far left.
class OrderHistoryRow extends StatelessWidget {
  const OrderHistoryRow({
    super.key,
    required this.order,
    required this.onTap,
    this.showPrices = true,
    this.showDate = false,
    this.statusLabel,
    this.detail,
  });

  /// Appended to the status line, e.g. the device's reading at this visit
  /// ("98.000 km") in the vehicle screen.
  final String? detail;

  /// Segment-customized status names; defaults to [OrderStatusStyle.label].
  final String Function(String? status)? statusLabel;

  final Order order;
  final VoidCallback onTap;

  /// Shows the total at the right.
  final bool showPrices;

  /// Appends the entry date to the status line.
  final bool showDate;

  bool get _late =>
      (order.status == 'approved' || order.status == 'progress') &&
      order.dueDate != null &&
      order.dueDate!.isBefore(DateTime.now());

  String? get _firstService {
    for (final s in order.services ?? const <OrderService>[]) {
      final name = s.service?.name;
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = FormatService()..setLocale(l10n.localeName);
    final late = _late;
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final danger = AppColors.danger.resolveFrom(context);
    // The dot keeps the status color; "Atrasada" follows the status.
    final dot = OrderStatusStyle.dotColor(order.status);
    final statusLabelText =
        statusLabel?.call(order.status) ??
        OrderStatusStyle.label(l10n, order.status);
    final statusText = statusLabelText;
    final number = order.number == null ? '' : ' ${order.number}';
    final title = ['${l10n.orderShort}$number', ?_firstService].join(' · ');
    final value = !showPrices || order.total == null
        ? null
        : format.formatCurrency(order.total);

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.body.copyWith(color: text),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          StatusDot(color: dot),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                text: statusText,
                                children: [
                                  if (late)
                                    TextSpan(
                                      text: ' · ',
                                      children: [
                                        TextSpan(
                                          text: l10n.orderOverdue,
                                          style: TextStyle(
                                            color: danger,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  TextSpan(
                                    text: [
                                      if (showDate && order.createdAt != null)
                                        format.formatDate(order.createdAt),
                                      ?detail,
                                    ].map((part) => ' · $part').join(),
                                  ),
                                ],
                              ),
                              style: AppTypography.callout.copyWith(
                                color: secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    value,
                    style: AppTypography.body.copyWith(
                      color: text,
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ],
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 18,
                  color: secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
