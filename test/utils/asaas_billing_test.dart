import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/utils/asaas_billing.dart';

PaymentTransaction tx(String? id, String? description) => PaymentTransaction(
      id: id,
      type: PaymentTransactionType.payment,
      amount: 100,
      description: description,
    );

void main() {
  group('asaasBillingTypeOf', () {
    test('reads Pix, Boleto and Cartão from Asaas transactions', () {
      expect(asaasBillingTypeOf(tx('asaas_1', 'Asaas • Pix')),
          AsaasBillingType.pix);
      expect(asaasBillingTypeOf(tx('asaas_1', 'Asaas • Boleto')),
          AsaasBillingType.boleto);
      expect(asaasBillingTypeOf(tx('asaas_1', 'Asaas • Cartão 2/3')),
          AsaasBillingType.card);
    });

    test('Asaas without a known type is "other"', () {
      expect(asaasBillingTypeOf(tx('asaas_1', 'Asaas')), AsaasBillingType.other);
      expect(asaasBillingTypeOf(tx('asaas_1', null)), AsaasBillingType.other);
    });

    test('manual payments never have a billing type', () {
      expect(asaasBillingTypeOf(tx('1728000000000', 'Pix do cliente')), isNull);
      expect(asaasBillingTypeOf(tx(null, null)), isNull);
    });
  });
}
