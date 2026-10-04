import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/utils/order_payment_math.dart';

Order _order({
  double services = 100,
  double discount = 0,
  double paid = 0,
  List<PaymentTransaction>? transactions,
}) {
  final order = Order()
    ..id = 'o1'
    ..status = 'approved'
    ..services = [OrderService()..value = services]
    ..products = []
    ..discount = discount
    ..paidAmount = paid
    ..transactions = transactions ?? [];
  order.total = OrderPaymentMath.computeTotal(order);
  order.payment = 'unpaid';
  return order;
}

PaymentTransaction _payment(String id, double amount) => PaymentTransaction(
      id: id,
      type: PaymentTransactionType.payment,
      amount: amount,
      createdAt: DateTime(2026, 10, 4),
    );

PaymentTransaction _discount(String id, double amount) => PaymentTransaction(
      id: id,
      type: PaymentTransactionType.discount,
      amount: amount,
      createdAt: DateTime(2026, 10, 4),
    );

void main() {
  group('stripPaymentFields', () {
    test('remove os campos de pagamento e mantém o resto', () {
      final json = _order(paid: 10, transactions: [_payment('p1', 10)]).toJson();

      final stripped = OrderPaymentMath.stripPaymentFields(json);

      for (final field in ['transactions', 'paidAmount', 'paid', 'payment']) {
        expect(stripped.containsKey(field), isFalse, reason: field);
      }
      expect(stripped['total'], 100);
      expect(stripped['discount'], 0);
      expect(stripped['status'], 'approved');
      expect(json.containsKey('transactions'), isTrue, reason: 'não altera o map original');
    });
  });

  group('paymentUpdateOf', () {
    test('contém só campos de pagamento, desconto, total e auditoria', () {
      final order = OrderPaymentMath.addPayment(_order(), _payment('p1', 40));
      order.updatedAt = DateTime(2026, 10, 4, 12);

      final update = OrderPaymentMath.paymentUpdateOf(order);

      expect(update.keys.toSet(), {
        'transactions',
        'paidAmount',
        'paid',
        'payment',
        'discount',
        'total',
        'updatedAt',
      });
      expect((update['transactions'] as List).single['id'], 'p1');
      expect(update['paidAmount'], 40);
      expect(update['payment'], 'unpaid');
    });
  });

  group('addPayment', () {
    test('pagamento parcial fica unpaid', () {
      final order = OrderPaymentMath.addPayment(_order(), _payment('p1', 40));

      expect(order.paidAmount, 40);
      expect(order.payment, 'unpaid');
      expect(order.paid, isFalse);
      expect(OrderPaymentMath.remainingBalance(order), 60);
    });

    test('pagamento que quita fica paid', () {
      final order = OrderPaymentMath.addPayment(_order(paid: 60), _payment('p1', 40));

      expect(order.payment, 'paid');
      expect(order.paid, isTrue);
      expect(OrderPaymentMath.remainingBalance(order), 0);
    });

    test('arredonda para centavos', () {
      final order = Order()
        ..total = 0.3
        ..paidAmount = 0.1
        ..transactions = [];

      OrderPaymentMath.addPayment(order, _payment('p1', 0.2));

      expect(order.paidAmount, 0.3);
      expect(order.payment, 'paid');
    });
  });


  group('addPaymentUpdate', () {
    test('pagamento parcial: union + increment, unpaid', () {
      final update = OrderPaymentMath.addPaymentUpdate(
        current: _order(),
        tx: _payment('p1', 40),
      );

      final union = update['transactions'] as ArrayUnionOp;
      expect((union.values.single as Map)['id'], 'p1');
      expect((update['paidAmount'] as IncrementOp).by, 40);
      expect(update['paid'], isFalse);
      expect(update['payment'], 'unpaid');
      expect(update.containsKey('updatedAt'), isTrue);
      expect(update.containsKey('updatedBy'), isFalse);
      expect(update.containsKey('total'), isFalse);
    });

    test('pagamento que quita vira paid', () {
      final update = OrderPaymentMath.addPaymentUpdate(
        current: _order(paid: 60),
        tx: _payment('p1', 40),
      );

      expect(update['paid'], isTrue);
      expect(update['payment'], 'paid');
    });

    test('não altera o pedido atual', () {
      final current = _order(paid: 10);
      OrderPaymentMath.addPaymentUpdate(current: current, tx: _payment('p1', 5));

      expect(current.paidAmount, 10);
      expect(current.transactions, isEmpty);
    });
  });

  group('addDiscountUpdate', () {
    test('desconto reduz o total e incrementa discount', () {
      final update = OrderPaymentMath.addDiscountUpdate(
        current: _order(paid: 50),
        tx: _discount('d1', 10),
      );

      final union = update['transactions'] as ArrayUnionOp;
      expect((union.values.single as Map)['type'], 'discount');
      expect((update['discount'] as IncrementOp).by, 10);
      expect((update['total'] as IncrementOp).by, -10);
      expect(update['payment'], 'unpaid');
      expect(update['paid'], isFalse);
      expect(update.containsKey('paidAmount'), isFalse);
    });

    test('desconto que cobre o saldo vira paid', () {
      final update = OrderPaymentMath.addDiscountUpdate(
        current: _order(paid: 90),
        tx: _discount('d1', 10),
      );

      expect(update['paid'], isTrue);
      expect(update['payment'], 'paid');
    });
  });

  group('addDiscount', () {
    test('desconto reduz o total (total líquido)', () {
      final order = OrderPaymentMath.addDiscount(_order(paid: 50), _discount('d1', 10));

      expect(order.discount, 10);
      expect(order.total, 90);
      expect(OrderPaymentMath.remainingBalance(order), 40);
      expect(order.payment, 'unpaid');
    });

    test('desconto que cobre o saldo marca paid', () {
      final order = OrderPaymentMath.addDiscount(_order(paid: 90), _discount('d1', 10));

      expect(order.payment, 'paid');
    });
  });

  group('markAsFullyPaid', () {
    test('lança o saldo restante como pagamento', () {
      final order = OrderPaymentMath.markAsFullyPaid(
        _order(paid: 30),
        (remaining) => _payment('full', remaining),
      );

      expect(order.transactions!.last.amount, 70);
      expect(order.paidAmount, 100);
      expect(order.payment, 'paid');
      expect(order.paid, isTrue);
    });

    test('sem saldo não cria transação', () {
      final order = OrderPaymentMath.markAsFullyPaid(
        _order(paid: 100),
        (remaining) => _payment('full', remaining),
      );

      expect(order.transactions, isEmpty);
      expect(order.payment, 'paid');
    });
  });

  group('removeTransaction', () {
    test('remover pagamento reduz paidAmount', () {
      final p1 = _payment('p1', 100);
      final order = OrderPaymentMath.removeTransaction(
        _order(paid: 100, transactions: [p1])..payment = 'paid',
        p1,
      );

      expect(order.transactions, isEmpty);
      expect(order.paidAmount, 0);
      expect(order.payment, 'unpaid');
    });

    test('remover desconto devolve o total', () {
      final d1 = _discount('d1', 10);
      final order = OrderPaymentMath.removeTransaction(
        _order(discount: 10, transactions: [d1]),
        d1,
      );

      expect(order.discount, 0);
      expect(order.total, 100);
    });

    test('casa pelo id mesmo com transações novas no servidor', () {
      final local = _payment('p1', 20);
      final fresh = _order(paid: 50, transactions: [
        _payment('asaas_pay_1', 30),
        _payment('p1', 20),
      ]);

      final order = OrderPaymentMath.removeTransaction(fresh, local);

      expect(order.transactions!.map((t) => t.id), ['asaas_pay_1']);
      expect(order.paidAmount, 30);
    });

    test('transação do Asaas não pode ser removida', () {
      final asaas = _payment('asaas_pay_1', 30);

      expect(
        () => OrderPaymentMath.removeTransaction(
          _order(paid: 30, transactions: [asaas]),
          asaas,
        ),
        throwsA(isA<AsaasTransactionLockedException>()),
      );
    });

    test('transação sem id casa por tipo, valor e data', () {
      final legacy = PaymentTransaction(
        type: PaymentTransactionType.discount,
        amount: 5,
        createdAt: DateTime(2026, 1, 1),
      );
      final copy = PaymentTransaction.fromJson(legacy.toJson());

      final order = OrderPaymentMath.removeTransaction(
        _order(discount: 5, transactions: [copy]),
        legacy,
      );

      expect(order.transactions, isEmpty);
    });
  });

  group('resetPayments', () {
    test('zera pagamentos manuais e mantém os do Asaas', () {
      final order = OrderPaymentMath.resetPayments(_order(
        discount: 10,
        paid: 50,
        transactions: [
          _payment('p1', 20),
          _discount('d1', 10),
          _payment('asaas_pay_1', 30),
        ],
      ));

      expect(order.transactions!.map((t) => t.id), ['asaas_pay_1']);
      expect(order.paidAmount, 30);
      expect(order.discount, 0);
      expect(order.total, 100);
      expect(order.payment, 'unpaid');
    });
  });

  group('setReceipt', () {
    test('liga e desliga o comprovante da transação', () {
      final p1 = _payment('p1', 10);
      final fresh = _order(paid: 10, transactions: [_payment('p1', 10)]);

      OrderPaymentMath.setReceipt(fresh, p1, 'doc1');
      expect(fresh.transactions!.single.receiptDocumentId, 'doc1');

      OrderPaymentMath.setReceipt(fresh, p1, null);
      expect(fresh.transactions!.single.receiptDocumentId, isNull);
    });
  });

  group('applyOrderStatus', () {
    test('orçamento e cancelada ficam sem payment', () {
      expect(OrderPaymentMath.applyOrderStatus(_order(), 'quote').payment, isNull);
      expect(OrderPaymentMath.applyOrderStatus(_order(), 'canceled').payment, isNull);
    });

    test('ao sair de orçamento recalcula a partir dos valores', () {
      final fresh = _order(paid: 100)..payment = null;

      expect(OrderPaymentMath.applyOrderStatus(fresh, 'approved').payment, 'paid');
    });
  });

  test('remainingBalance nunca é negativo', () {
    expect(OrderPaymentMath.remainingBalance(_order(paid: 150)), 0);
  });

  group('mergePendingTransactions', () {
    test('mantém pagamento pendente que ainda não está no fresh', () {
      // Server state (fresh) already has p1; p2 was added offline and not acked.
      final fresh = _order(paid: 30, transactions: [_payment('p1', 30)]);

      final merged = OrderPaymentMath.mergePendingTransactions(
        fresh,
        [_payment('p2', 20)],
      );

      expect(merged.transactions!.map((t) => t.id), ['p1', 'p2']);
      expect(merged.paidAmount, 50);
      expect(merged.payment, 'unpaid');
    });

    test('pagamento pendente que já chegou ao servidor não conta duas vezes', () {
      final fresh = _order(
          paid: 50, transactions: [_payment('p1', 30), _payment('p2', 20)]);

      final merged = OrderPaymentMath.mergePendingTransactions(
        fresh,
        [_payment('p2', 20)],
      );

      expect(merged.transactions!.map((t) => t.id), ['p1', 'p2']);
      expect(merged.paidAmount, 50);
    });

    test('desconto pendente reduz o total e pode quitar a OS', () {
      final fresh = _order(paid: 90, transactions: [_payment('p1', 90)]);

      final merged = OrderPaymentMath.mergePendingTransactions(
        fresh,
        [_discount('d1', 10)],
      );

      expect(merged.discount, 10);
      expect(merged.total, 90);
      expect(merged.paidAmount, 90);
      expect(merged.payment, 'paid');
      expect(merged.paid, isTrue);
    });

    test('sem pendentes devolve o fresh como está', () {
      final fresh = _order(paid: 30, transactions: [_payment('p1', 30)]);

      final merged = OrderPaymentMath.mergePendingTransactions(fresh, const []);

      expect(merged.transactions!.map((t) => t.id), ['p1']);
      expect(merged.paidAmount, 30);
    });
  });

  group('orderStatusPaymentUpdate', () {
    test('cancelada grava payment null e paid false (offline-safe)', () {
      final update = OrderPaymentMath.orderStatusPaymentUpdate(
        'canceled',
        updatedAt: DateTime(2026, 10, 4, 12),
      );

      expect(update, isNotNull);
      expect(update!.containsKey('payment'), isTrue);
      expect(update['payment'], isNull);
      expect(update['paid'], false);
      expect(update['updatedAt'], DateTime(2026, 10, 4, 12).toIso8601String());
      expect(update.containsKey('transactions'), isFalse);
      expect(update.containsKey('paidAmount'), isFalse);
    });

    test('orçamento também grava payment null', () {
      final update = OrderPaymentMath.orderStatusPaymentUpdate('quote');
      expect(update!['payment'], isNull);
      expect(update['paid'], false);
    });

    test('status ativo precisa recalcular (transação): devolve null', () {
      expect(OrderPaymentMath.orderStatusPaymentUpdate('approved'), isNull);
      expect(OrderPaymentMath.orderStatusPaymentUpdate('progress'), isNull);
      expect(OrderPaymentMath.orderStatusPaymentUpdate(null), isNull);
    });
  });
}
