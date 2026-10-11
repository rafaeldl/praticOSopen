import 'package:praticos/models/payment_transaction.dart';

/// How the customer paid an Asaas charge.
enum AsaasBillingType { pix, boleto, card, other }

/// Billing type of a payment posted by the Asaas webhook.
///
/// Newer webhook versions store it in [PaymentTransaction.billingType]
/// (`PIX`, `BOLETO`, `CREDIT_CARD`, `DEBIT_CARD`...). Older ones only wrote it
/// inside the description (`Asaas • Pix`, `Asaas • Boleto`, `Asaas • Cartão
/// 2/3`; see describeAsaasPayment in firebase/functions), which stays the
/// fallback. Returns null for manual payments and discounts: the payment
/// method is never asked nor shown for them.
AsaasBillingType? asaasBillingTypeOf(PaymentTransaction transaction) {
  if (!transaction.isAsaas) return null;
  final stored = _fromAsaasCode(transaction.billingType);
  if (stored != null) return stored;
  final description = (transaction.description ?? '').toLowerCase();
  if (description.contains('pix')) return AsaasBillingType.pix;
  if (description.contains('boleto')) return AsaasBillingType.boleto;
  if (description.contains('cart')) return AsaasBillingType.card;
  return AsaasBillingType.other;
}

/// Null for a missing code so the description fallback still runs.
AsaasBillingType? _fromAsaasCode(String? code) {
  final value = code?.trim().toUpperCase();
  if (value == null || value.isEmpty) return null;
  switch (value) {
    case 'PIX':
      return AsaasBillingType.pix;
    case 'BOLETO':
      return AsaasBillingType.boleto;
    case 'CREDIT_CARD':
    case 'DEBIT_CARD':
      return AsaasBillingType.card;
    default:
      return AsaasBillingType.other;
  }
}

/// Receipt page Asaas generated for a payment, or null.
///
/// Only for Asaas payments and only https links on an Asaas domain (the
/// webhook already filters; this is a second check before opening a link).
Uri? asaasReceiptUri(PaymentTransaction transaction) {
  if (!transaction.isAsaas) return null;
  final raw = transaction.receiptUrl?.trim();
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'https') return null;
  final host = uri.host.toLowerCase();
  if (host != 'asaas.com' && !host.endsWith('.asaas.com')) return null;
  return uri;
}
