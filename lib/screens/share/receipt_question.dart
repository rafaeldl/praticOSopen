import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/customer_receipt_service.dart'
    show PickedReceiptFile;
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/received_share.dart';
import 'package:praticos/utils/asaas_billing.dart';
import 'package:praticos/utils/order_payment_math.dart';

/// What the shared file is, answered in "O que é este arquivo?".
class SharedFileUse {
  /// "Só guardar na OS": a plain photo/document of the order.
  const SharedFileUse.keep() : payment = null, isNewPayment = false;

  /// "Comprovante do pagamento de R$ 200 · 12/10": the receipt of [payment].
  const SharedFileUse.receiptOf(PaymentTransaction this.payment)
    : isNewPayment = false;

  /// "Comprovante de um pagamento novo": opens Receber with it attached.
  const SharedFileUse.newPayment() : payment = null, isNewPayment = true;

  final PaymentTransaction? payment;
  final bool isNewPayment;

  bool get isKeep => payment == null && !isNewPayment;
}

/// Payments of [order] that can still get a receipt, as on the Receber
/// screen ("Anexar comprovante"): manual or Asaas payments without a receipt
/// and without an Asaas receipt page, not part of a customer receipt.
List<PaymentTransaction> paymentsWithoutReceipt(Order order) => [
  for (final t in order.transactions ?? const <PaymentTransaction>[])
    if (t.type == PaymentTransactionType.payment &&
        !t.hasReceipt &&
        asaasReceiptUri(t) == null &&
        t.receiptGroupId == null)
      t,
];

/// Whether to ask "O que é este arquivo?" after picking [order]: only one
/// file was shared, the user receives on this order (financial on) and the
/// order has a payment without receipt or something left to receive.
bool shouldAskWhatFileIs({
  required ReceivedBatch batch,
  required Order order,
  required bool canReceive,
}) {
  if (batch.photos.length + batch.pdfs.length != 1 || !canReceive) {
    return false;
  }
  return paymentsWithoutReceipt(order).isNotEmpty ||
      OrderPaymentMath.remainingBalance(order) > 0;
}

/// The options of "O que é este arquivo?" for [order], in order: one row per
/// payment without receipt, "pagamento novo" when something is left to
/// receive, and "Só guardar na OS".
List<PickerItem<SharedFileUse>> sharedFileUseOptions(
  AppLocalizations l10n,
  Order order,
) {
  final format = FormatService();
  return [
    for (final t in paymentsWithoutReceipt(order))
      PickerItem<SharedFileUse>(
        value: SharedFileUse.receiptOf(t),
        title: l10n.sharedFileReceiptOf(
          format.formatCurrency(t.amount),
          format.formatDayMonthOrDate(t.paidOn),
        ),
        key: Key('sharedFileReceipt_${t.id}'),
      ),
    if (OrderPaymentMath.remainingBalance(order) > 0)
      PickerItem<SharedFileUse>(
        value: const SharedFileUse.newPayment(),
        title: l10n.sharedFileNewPayment,
        key: const Key('sharedFileNewPayment'),
      ),
    PickerItem<SharedFileUse>(
      value: const SharedFileUse.keep(),
      title: l10n.sharedFileJustKeep,
      key: const Key('sharedFileJustKeep'),
    ),
  ];
}

/// Asks "O que é este arquivo?" ([pickOne]). Going back counts as "Só
/// guardar na OS": the user already chose the order, the file is not lost.
Future<SharedFileUse> askWhatFileIs(BuildContext context, Order order) async {
  final l10n = context.l10n;
  final picked = await pickOne<SharedFileUse>(
    context,
    title: l10n.sharedFileQuestion,
    subtitle: order.number == null ? null : l10n.receiveOrderLink(order.number!),
    options: sharedFileUseOptions(l10n, order),
  );
  return picked ?? const SharedFileUse.keep();
}

/// The single shared file of [batch] as a receipt file (what the Receber
/// screen attaches). Photos keep their image type (the share may be PNG or
/// HEIC), PDFs are `application/pdf`. Null when [batch] has no file.
PickedReceiptFile? receiptFileOf(ReceivedBatch batch) {
  if (batch.pdfs.isNotEmpty) {
    final f = batch.pdfs.first;
    return PickedReceiptFile(File(f.path), 'application/pdf', f.fileName);
  }
  if (batch.photos.isEmpty) return null;
  final f = batch.photos.first;
  final mime = f.mimeType?.toLowerCase().trim();
  final dot = f.fileName.lastIndexOf('.');
  final ext = dot == -1 ? '' : f.fileName.substring(dot + 1).toLowerCase();
  final type = mime != null && mime.startsWith('image/')
      ? mime
      : switch (ext) {
          'png' => 'image/png',
          'heic' => 'image/heic',
          'heif' => 'image/heif',
          'webp' => 'image/webp',
          _ => 'image/jpeg',
        };
  return PickedReceiptFile(File(f.path), type, f.fileName);
}
