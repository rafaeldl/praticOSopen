import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/screens/payments/widgets/receive_date_row.dart'
    show paidAtFor;
import 'package:praticos/screens/payments/widgets/receive_payment_sheet.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/utils/order_payment_math.dart';
import 'package:praticos/utils/payment_update_failure.dart';

/// Saves a filled [ReceivePaymentSheet]: the payment, then its receipt.
/// [transaction] is null when the payment did not go in.
Future<({PaymentTransaction? transaction, bool receiptOk})>
registerOrderPayment(OrderStore store, ReceiveDraft draft) async {
  final transaction = await store.addPayment(
    draft.amount,
    paidAt: paidAtFor(draft.paidDay),
    paymentMethod: draft.paymentMethod,
  );
  var receiptOk = true;
  final receipt = draft.receipt;
  if (transaction != null && receipt != null) {
    final index = store.transactions.indexWhere((t) => t.id == transaction.id);
    if (index >= 0) {
      receiptOk = await store.attachReceiptToTransaction(
        index,
        receipt.file,
        receipt.contentType,
        receipt.name,
      );
    }
  }
  return (transaction: transaction, receiptOk: receiptOk);
}

/// Says what stays open on the order after receiving [amount].
String receivePreview(AppLocalizations l10n, double amount, double remaining) {
  final left = remaining - amount;
  if (left <= OrderPaymentMath.centTolerance) return l10n.receivePreviewAll(1);
  return l10n.receivePreviewLeft(FormatService().formatCurrency(left));
}

/// Localized message for the last failed payment operation of [store].
String paymentFailureMessage(AppLocalizations l10n, OrderStore store) {
  switch (store.lastPaymentFailure) {
    case PaymentUpdateFailure.requiresConnection:
      return l10n.paymentRequiresConnection;
    case PaymentUpdateFailure.asaasLocked:
      return l10n.asaasTransactionCannotBeRemoved;
    case PaymentUpdateFailure.failed:
    case null:
      return l10n.paymentUpdateFailed;
  }
}
