import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/payment_transaction.dart';

void main() {
  group('OrderCharge.fromJson', () {
    test('lê cobrança parcelada gravada pelo servidor', () {
      final charge = OrderCharge.fromJson({
        'id': 'ch1',
        'asaasPaymentId': 'pay_1',
        'asaasInstallmentId': 'ins_1',
        'mode': 'cardInstallments',
        'installmentCount': 3,
        'value': 700,
        'dueDate': '2026-10-07',
        'status': 'pending',
        'invoiceUrl': 'https://sandbox.asaas.com/i/abc',
        'paidAsaasPaymentIds': ['pay_1'],
        'createdBy': {'id': 'u1', 'name': 'Rafael'},
        'createdAt': '2026-10-04T12:00:00.000Z',
      });

      expect(charge.id, 'ch1');
      expect(charge.mode, ChargeMode.cardInstallments);
      expect(charge.installmentCount, 3);
      expect(charge.value, 700.0);
      expect(charge.status, ChargeStatus.pending);
      expect(charge.paidAsaasPaymentIds, ['pay_1']);
      expect(charge.createdBy?.name, 'Rafael');
      expect(charge.createdAt, DateTime.utc(2026, 10, 4, 12));
      expect(charge.dueDateValue, DateTime(2026, 10, 7));
      expect(charge.isOpen, isTrue);
    });

    test('status e modo desconhecidos viram null sem lançar', () {
      final charge = OrderCharge.fromJson({
        'id': 'ch1',
        'status': 'awaiting_risk_analysis',
        'mode': 'pix',
      });

      expect(charge.status, isNull);
      expect(charge.mode, isNull);
      expect(charge.isOpen, isFalse);
    });

    test('vencida conta como em aberto', () {
      expect(OrderCharge(status: ChargeStatus.overdue).isOpen, isTrue);
      expect(OrderCharge(status: ChargeStatus.paid).isOpen, isFalse);
    });
  });

  group('OrderCharge.current', () {
    OrderCharge charge(String id, ChargeStatus status) =>
        OrderCharge(id: id, status: status);

    test('prefere a cobrança em aberto', () {
      final current = OrderCharge.current([
        charge('a', ChargeStatus.paid),
        charge('b', ChargeStatus.overdue),
      ]);

      expect(current?.id, 'b');
    });

    test('sem cobrança em aberto devolve a mais recente', () {
      final current = OrderCharge.current([
        charge('a', ChargeStatus.canceled),
        charge('b', ChargeStatus.paid),
      ]);

      expect(current?.id, 'a');
    });

    test('lista vazia devolve null', () {
      expect(OrderCharge.current(const []), isNull);
    });
  });

  group('PaymentTransaction.isAsaas', () {
    test('id com prefixo asaas_ é transação do Asaas', () {
      final txn = PaymentTransaction(
        id: 'asaas_pay_1',
        type: PaymentTransactionType.payment,
        amount: 10,
      );

      expect(txn.isAsaas, isTrue);
    });

    test('pagamento manual não é do Asaas', () {
      final manual = PaymentTransaction(
        id: '1728000000000',
        type: PaymentTransactionType.payment,
        amount: 10,
      );
      final withoutId = PaymentTransaction(
        type: PaymentTransactionType.discount,
        amount: 10,
      );

      expect(manual.isAsaas, isFalse);
      expect(withoutId.isAsaas, isFalse);
    });

    test('isAsaas não vai para o JSON', () {
      final txn = PaymentTransaction(
        id: 'asaas_pay_1',
        type: PaymentTransactionType.payment,
        amount: 10,
      );

      expect(txn.toJson().containsKey('isAsaas'), isFalse);
    });
  });
}
