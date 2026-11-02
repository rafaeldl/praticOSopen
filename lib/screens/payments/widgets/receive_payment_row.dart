import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/utils/asaas_billing.dart';

/// Localized [PaymentMethod]; null when it was not informed or is unknown
/// (written by a newer version).
String? paymentMethodLabel(AppLocalizations l10n, String? method) {
  return switch (method) {
    PaymentMethod.pix => l10n.paymentMethodPix,
    PaymentMethod.cash => l10n.paymentMethodCash,
    PaymentMethod.card => l10n.paymentMethodCard,
    PaymentMethod.other => l10n.paymentMethodOther,
    _ => null,
  };
}

/// How the payment came in: "Pix pelo link" style for Asaas, the method
/// chosen for a manual payment; null for discounts and manual payments
/// without one (all the older ones).
String? receiveBillingLabel(BuildContext context, PaymentTransaction tx) {
  final type = asaasBillingTypeOf(tx);
  if (type == null) return paymentMethodLabel(context.l10n, tx.paymentMethod);
  switch (type) {
    case AsaasBillingType.pix:
      return context.l10n.receiveViaPix;
    case AsaasBillingType.boleto:
      return context.l10n.receiveViaBoleto;
    case AsaasBillingType.card:
      return context.l10n.receiveViaCard;
    case AsaasBillingType.other:
      return context.l10n.receiveViaLink;
  }
}

/// When the payment came in: the chosen day (`paidAt`) when it differs from
/// the day it was recorded, otherwise the recording date and time.
String paymentWhenLabel(PaymentTransaction tx, FormatService format) {
  final paidAt = tx.paidAt;
  if (paidAt != null && !DateUtils.isSameDay(paidAt, tx.createdAt)) {
    return format.formatDate(paidAt);
  }
  return format.formatDateTime(tx.createdAt);
}

/// One line of the received payments list: amount, what/when, and whether it
/// has a receipt. Tapping opens the payment sheet (no swipe to delete).
class ReceivePaymentRow extends StatelessWidget {
  const ReceivePaymentRow({
    super.key,
    required this.transaction,
    required this.onTap,
    this.showReceiptState = true,
  });

  final PaymentTransaction transaction;
  final VoidCallback onTap;

  /// False hides "com/sem comprovante" (no permission to view photos).
  final bool showReceiptState;

  @override
  Widget build(BuildContext context) {
    final format = FormatService();
    final isPayment = transaction.type == PaymentTransactionType.payment;
    final label = isPayment
        ? receiveBillingLabel(context, transaction) ??
              transaction.typeLabel(context.l10n)
        : transaction.typeLabel(context.l10n);
    final parts = <String>[
      paymentWhenLabel(transaction, format),
      if (isPayment && showReceiptState)
        transaction.hasReceipt || asaasReceiptUri(transaction) != null
            ? context.l10n.receiveWithReceipt
            : context.l10n.receiveNoReceipt,
    ];
    return AppListRow(
      key: ValueKey(
        'receivePayment_${transaction.createdAt.microsecondsSinceEpoch}',
      ),
      title: label,
      subtitle: parts.join(' · '),
      trailing: isPayment
          ? format.formatCurrency(transaction.amount)
          : '- ${format.formatCurrency(transaction.amount)}',
      onTap: onTap,
    );
  }
}
