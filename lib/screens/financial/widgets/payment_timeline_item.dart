import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/financial_payment.dart';
import 'package:praticos/models/payment_method.dart';
import 'package:praticos/services/format_service.dart';

/// A compact 2-line item for the financial statement timeline.
///
/// Displays payment description, value, method, and account in a
/// compact row format with color-coded icons by payment type.
class PaymentTimelineItem extends StatelessWidget {
  final FinancialPayment payment;
  final VoidCallback? onTap;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onOrderTap;
  final Function(FinancialPayment payment, String reason)? onReverse;

  const PaymentTimelineItem({
    super.key,
    required this.payment,
    this.onTap,
    this.onSwipeRight,
    this.onOrderTap,
    this.onReverse,
  });

  bool get _isReversed =>
      payment.status == FinancialPaymentStatus.reversed;

  Color get _typeColor {
    if (_isReversed) return CupertinoColors.systemGrey;
    switch (payment.type) {
      case FinancialPaymentType.income:
        return CupertinoColors.systemGreen;
      case FinancialPaymentType.expense:
        return CupertinoColors.systemRed;
      case FinancialPaymentType.transfer:
        return CupertinoColors.activeBlue;
      case null:
        return CupertinoColors.systemGrey;
    }
  }

  IconData get _typeIcon {
    switch (payment.type) {
      case FinancialPaymentType.income:
        return CupertinoIcons.arrow_down_left;
      case FinancialPaymentType.expense:
        return CupertinoIcons.arrow_up_right;
      case FinancialPaymentType.transfer:
        return CupertinoIcons.arrow_right_arrow_left;
      case null:
        return CupertinoIcons.minus;
    }
  }

  String _paymentMethodLabel(BuildContext context, PaymentMethod? method) {
    switch (method) {
      case PaymentMethod.pix:
        return context.l10n.pix;
      case PaymentMethod.cash:
        return context.l10n.cash;
      case PaymentMethod.creditCard:
        return context.l10n.creditCard;
      case PaymentMethod.debitCard:
        return context.l10n.debitCard;
      case PaymentMethod.transfer:
        return context.l10n.transfer;
      case PaymentMethod.check:
        return context.l10n.check;
      case PaymentMethod.other:
        return context.l10n.other;
      case null:
        return '';
    }
  }

  String _formatAmount() {
    final formatted = FormatService().formatCurrency(payment.amount ?? 0);
    if (_isReversed) return formatted;
    switch (payment.type) {
      case FinancialPaymentType.income:
        return '+$formatted';
      case FinancialPaymentType.expense:
        return '-$formatted';
      case FinancialPaymentType.transfer:
      case null:
        return formatted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final valueColor = _isReversed ? CupertinoColors.systemGrey : _typeColor;
    final textDecoration =
        _isReversed ? TextDecoration.lineThrough : TextDecoration.none;
    final textColor = _isReversed ? CupertinoColors.systemGrey : labelColor;

    Widget item = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  _typeIcon,
                  size: 16,
                  color: _typeColor,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Description + payment method
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line 1: description
                  Text(
                    payment.description ?? '',
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
                  // Line 2: OS link + method + account
                  if (_hasOrderLink && onOrderTap != null)
                    GestureDetector(
                      onTap: onOrderTap,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'OS #${payment.orderNumber}',
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.activeBlue,
                                fontWeight: FontWeight.w500,
                                decoration: textDecoration,
                              ),
                            ),
                            TextSpan(
                              text: _buildSecondaryTextWithoutOS(context).isNotEmpty
                                  ? ' \u00b7 ${_buildSecondaryTextWithoutOS(context)}'
                                  : '',
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryLabelColor,
                                decoration: textDecoration,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    Text(
                      _buildSecondaryText(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryLabelColor,
                        decoration: textDecoration,
                      ),
                    ),
                  // Line 3: reversal reason (if reversed)
                  if (_isReversed && payment.reversalReason != null && payment.reversalReason!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        payment.reversalReason!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: secondaryLabelColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Value
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

    // Swipe-left to reverse (endToStart)
    if (_canReverse) {
      item = Dismissible(
        key: ValueKey('reverse_${payment.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          final reason = await _showReversalDialog(context);
          if (reason != null && reason.isNotEmpty) {
            onReverse!(payment, reason);
          }
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: CupertinoColors.systemRed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(context.l10n.reversePayment,
                  style: const TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.arrow_uturn_left,
                  color: CupertinoColors.white, size: 22),
            ],
          ),
        ),
        child: item,
      );
    }

    // Swipe-right to pay (startToEnd)
    if (onSwipeRight != null) {
      item = Dismissible(
        key: ValueKey('swipe_${payment.id}'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          onSwipeRight!();
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          color: CupertinoColors.activeBlue,
          child: const Row(
            children: [
              Icon(CupertinoIcons.money_dollar_circle,
                  color: CupertinoColors.white, size: 22),
              SizedBox(width: 8),
              Text('Pagar',
                  style: TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600)),
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
    if (payment.orderNumber != null) {
      parts.add('OS #${payment.orderNumber}');
    }
    final methodLabel = _paymentMethodLabel(context, payment.paymentMethod);
    if (methodLabel.isNotEmpty) {
      parts.add(methodLabel);
    }
    final accountName = payment.account?.name;
    if (accountName != null && accountName.isNotEmpty) {
      parts.add(accountName);
    }
    return parts.join(' \u00b7 ');
  }

  String _buildSecondaryTextWithoutOS(BuildContext context) {
    final parts = <String>[];
    final methodLabel = _paymentMethodLabel(context, payment.paymentMethod);
    if (methodLabel.isNotEmpty) parts.add(methodLabel);
    final accountName = payment.account?.name;
    if (accountName != null && accountName.isNotEmpty) parts.add(accountName);
    return parts.join(' \u00b7 ');
  }

  bool get _hasOrderLink =>
      payment.orderId != null && payment.orderNumber != null;

  /// Whether this payment can be reversed via swipe.
  bool get _canReverse =>
      onReverse != null &&
      payment.status == FinancialPaymentStatus.completed &&
      payment.reversedPaymentId == null;

  /// Shows a CupertinoAlertDialog requesting a reversal reason.
  /// Returns the reason string, or null if cancelled.
  Future<String?> _showReversalDialog(BuildContext context) async {
    String reason = '';
    return showCupertinoDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return CupertinoAlertDialog(
              title: Text(context.l10n.confirmReversal),
              content: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(context.l10n.confirmReversalMessage),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    placeholder: context.l10n.reversalReasonHint,
                    onChanged: (value) => setState(() => reason = value),
                    autofocus: true,
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.l10n.cancel),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: reason.trim().isEmpty
                      ? null
                      : () => Navigator.pop(ctx, reason.trim()),
                  child: Text(context.l10n.reversePayment),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
