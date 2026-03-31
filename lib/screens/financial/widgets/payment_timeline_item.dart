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

  const PaymentTimelineItem({
    super.key,
    required this.payment,
    this.onTap,
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

    return GestureDetector(
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
                  // Line 2: method + account
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
  }

  String _buildSecondaryText(BuildContext context) {
    final parts = <String>[];
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
}
