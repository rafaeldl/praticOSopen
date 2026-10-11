import 'package:praticos/models/payment_transaction.dart';

/// How the customer paid an Asaas charge.
enum AsaasBillingType { pix, boleto, card, other }

/// Billing type of a payment posted by the Asaas webhook.
///
/// The webhook stores the billing type only inside the transaction
/// description (`Asaas • Pix`, `Asaas • Boleto`, `Asaas • Cartão 2/3`; see
/// describeAsaasPayment in firebase/functions). Returns null for manual
/// payments and discounts: the payment method is never asked nor shown for
/// them.
AsaasBillingType? asaasBillingTypeOf(PaymentTransaction transaction) {
  if (!transaction.isAsaas) return null;
  final description = (transaction.description ?? '').toLowerCase();
  if (description.contains('pix')) return AsaasBillingType.pix;
  if (description.contains('boleto')) return AsaasBillingType.boleto;
  if (description.contains('cart')) return AsaasBillingType.card;
  return AsaasBillingType.other;
}
