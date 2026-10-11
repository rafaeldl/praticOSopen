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

  group('billingType field (webhook) wins over the description', () {
    PaymentTransaction typed(String? billingType, {String? description, String id = 'asaas_1'}) =>
        PaymentTransaction(
          id: id,
          type: PaymentTransactionType.payment,
          amount: 100,
          description: description,
          billingType: billingType,
        );

    test('maps Asaas codes', () {
      expect(asaasBillingTypeOf(typed('PIX')), AsaasBillingType.pix);
      expect(asaasBillingTypeOf(typed('BOLETO')), AsaasBillingType.boleto);
      expect(asaasBillingTypeOf(typed('CREDIT_CARD')), AsaasBillingType.card);
      expect(asaasBillingTypeOf(typed('DEBIT_CARD')), AsaasBillingType.card);
      expect(asaasBillingTypeOf(typed('UNDEFINED')), AsaasBillingType.other);
    });

    test('field beats a conflicting description', () {
      expect(
        asaasBillingTypeOf(typed('BOLETO', description: 'Asaas • Pix')),
        AsaasBillingType.boleto,
      );
    });

    test('empty field falls back to the description', () {
      expect(asaasBillingTypeOf(typed('', description: 'Asaas • Pix')),
          AsaasBillingType.pix);
      expect(asaasBillingTypeOf(typed(null, description: 'Asaas • Boleto')),
          AsaasBillingType.boleto);
    });

    test('manual payment ignores the field', () {
      expect(asaasBillingTypeOf(typed('PIX', id: '1728000000000')), isNull);
    });
  });

  group('asaasReceiptUri', () {
    PaymentTransaction withReceipt(String? url, {String id = 'asaas_1'}) =>
        PaymentTransaction(
          id: id,
          type: PaymentTransactionType.payment,
          amount: 100,
          receiptUrl: url,
        );

    test('accepts https links on asaas.com and subdomains', () {
      expect(asaasReceiptUri(withReceipt('https://www.asaas.com/comprovantes/1')),
          Uri.parse('https://www.asaas.com/comprovantes/1'));
      expect(asaasReceiptUri(withReceipt('https://sandbox.asaas.com/comprovantes/1')),
          isNotNull);
    });

    test('rejects missing, http, other hosts and manual payments', () {
      expect(asaasReceiptUri(withReceipt(null)), isNull);
      expect(asaasReceiptUri(withReceipt('')), isNull);
      expect(asaasReceiptUri(withReceipt('http://www.asaas.com/c/1')), isNull);
      expect(asaasReceiptUri(withReceipt('https://asaas.com.evil.com/c')), isNull);
      expect(asaasReceiptUri(withReceipt('javascript:alert(1)')), isNull);
      expect(
        asaasReceiptUri(withReceipt('https://www.asaas.com/c/1', id: '1728000000000')),
        isNull,
      );
    });
  });

  group('PaymentTransaction JSON', () {
    test('old documents without the new fields still decode', () {
      final tx = PaymentTransaction.fromJson({
        'id': 'asaas_pay_1',
        'type': 'payment',
        'amount': 10,
        'description': 'Asaas • Pix',
        'createdAt': '2026-10-04T10:00:00.000Z',
      });
      expect(tx.receiptUrl, isNull);
      expect(tx.billingType, isNull);
      expect(asaasBillingTypeOf(tx), AsaasBillingType.pix);
    });

    test('manual payment does not write null keys; Asaas fields round-trip', () {
      final manual = PaymentTransaction(
        id: '1',
        type: PaymentTransactionType.payment,
        amount: 10,
      ).toJson();
      expect(manual.containsKey('receiptUrl'), isFalse);
      expect(manual.containsKey('billingType'), isFalse);

      final asaas = PaymentTransaction.fromJson({
        'id': 'asaas_pay_1',
        'type': 'payment',
        'amount': 10,
        'createdAt': '2026-10-04T10:00:00.000Z',
        'receiptUrl': 'https://www.asaas.com/comprovantes/1',
        'billingType': 'PIX',
      }).toJson();
      expect(asaas['receiptUrl'], 'https://www.asaas.com/comprovantes/1');
      expect(asaas['billingType'], 'PIX');
    });
  });
}
