import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/services/format_service.dart';

/// A compact 2-line item for the financial entries (bills) timeline.
///
/// Displays entry description, amount, due date, category, and status
/// with color-coded icons by direction (payable/receivable).
class EntryTimelineItem extends StatelessWidget {
  final FinancialEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onSwipePay;
  final VoidCallback? onSwipeDelete;

  const EntryTimelineItem({
    super.key,
    required this.entry,
    this.onTap,
    this.onSwipePay,
    this.onSwipeDelete,
  });

  bool get _isPaid => entry.status == FinancialEntryStatus.paid;
  bool get _isCancelled => entry.status == FinancialEntryStatus.cancelled;
  bool get _isOverdue => entry.isOverdue;
  bool get _isInactive => _isPaid || _isCancelled;

  Color get _directionColor {
    if (_isInactive) return CupertinoColors.systemGrey;
    if (_isOverdue) return CupertinoColors.systemOrange;
    switch (entry.direction) {
      case FinancialEntryDirection.payable:
        return CupertinoColors.systemRed;
      case FinancialEntryDirection.receivable:
        return CupertinoColors.systemGreen;
      case null:
        return CupertinoColors.systemGrey;
    }
  }

  IconData get _directionIcon {
    switch (entry.direction) {
      case FinancialEntryDirection.payable:
        return CupertinoIcons.arrow_up_right;
      case FinancialEntryDirection.receivable:
        return CupertinoIcons.arrow_down_left;
      case null:
        return CupertinoIcons.minus;
    }
  }

  String _formatAmount() {
    final remaining = entry.remainingBalance;
    final formatted = FormatService().formatCurrency(remaining);
    if (_isInactive) return FormatService().formatCurrency(entry.amount ?? 0);
    switch (entry.direction) {
      case FinancialEntryDirection.receivable:
        return '+$formatted';
      case FinancialEntryDirection.payable:
        return '-$formatted';
      case null:
        return formatted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final textDecoration =
        _isCancelled ? TextDecoration.lineThrough : TextDecoration.none;
    final textColor = _isInactive ? CupertinoColors.systemGrey : labelColor;
    final valueColor = _directionColor;

    Widget item = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Direction icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _directionColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  _directionIcon,
                  size: 16,
                  color: _directionColor,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Description + secondary info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line 1: description
                  Text(
                    entry.description ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      decoration: textDecoration,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Line 2: category · supplier/customer · installment
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _buildSecondaryText(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryLabelColor,
                            decoration: textDecoration,
                          ),
                        ),
                      ),
                      if (_isOverdue && !_isInactive)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            context.l10n.overdue,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.systemOrange,
                            ),
                          ),
                        ),
                      if (_isPaid)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            CupertinoIcons.checkmark_circle_fill,
                            size: 14,
                            color: CupertinoColors.systemGreen,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Amount
            Text(
              _formatAmount(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: valueColor,
                decoration: textDecoration,
              ),
            ),
          ],
        ),
      ),
    );

    // Swipe actions (single Dismissible with both directions)
    final hasSwipeRight = onSwipePay != null;
    final hasSwipeLeft = onSwipeDelete != null;

    if (hasSwipeRight || hasSwipeLeft) {
      final direction = (hasSwipeRight && hasSwipeLeft)
          ? DismissDirection.horizontal
          : hasSwipeRight
              ? DismissDirection.startToEnd
              : DismissDirection.endToStart;

      item = Dismissible(
        key: ValueKey('entry_${entry.id}'),
        direction: direction,
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            onSwipePay?.call();
          } else {
            onSwipeDelete?.call();
          }
          return false;
        },
        // Swipe-right background (pay)
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          color: CupertinoColors.activeBlue,
          child: Row(
            children: [
              const Icon(CupertinoIcons.money_dollar_circle,
                  color: CupertinoColors.white, size: 22),
              const SizedBox(width: 8),
              Text(context.l10n.pay,
                  style: const TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        // Swipe-left background (delete)
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: CupertinoColors.systemRed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(context.l10n.delete,
                  style: const TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.trash,
                  color: CupertinoColors.white, size: 22),
            ],
          ),
        ),
        child: item,
      );
    }

    return item;
  }

  String _buildSecondaryText(BuildContext context) {
    final parts = <String>[];
    if (entry.category != null && entry.category!.isNotEmpty) {
      parts.add(entry.category!);
    }
    if (entry.supplier != null && entry.supplier!.isNotEmpty) {
      parts.add(entry.supplier!);
    }
    if (entry.customer?.name != null && entry.customer!.name!.isNotEmpty) {
      parts.add(entry.customer!.name!);
    }
    if (entry.isInstallment) {
      parts.add('${entry.installmentNumber}/${entry.installmentTotal}');
    }
    if (entry.dueDate != null) {
      parts.add(FormatService().formatDate(entry.dueDate!));
    }
    return parts.join(' \u00b7 ');
  }
}
