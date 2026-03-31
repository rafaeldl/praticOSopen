import 'package:praticos/models/financial_payment.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/payment_method.dart';
import 'package:test/test.dart';

void main() {
  group('FinancialPayment JSON round-trip', () {
    test('basic fields survive round-trip', () {
      final paymentDate = DateTime(2026, 3, 27, 14, 30);
      final payment = FinancialPayment()
        ..id = 'pay_123'
        ..type = FinancialPaymentType.expense
        ..status = FinancialPaymentStatus.completed
        ..amount = 2500.0
        ..discount = 0.0
        ..paymentDate = paymentDate
        ..paymentMethod = PaymentMethod.pix
        ..description = 'Aluguel escritório março'
        ..notes = 'Pago via Pix'
        ..entryId = 'entry_456'
        ..category = 'rent';

      final json = payment.toJson();
      final restored = FinancialPayment.fromJson(json);

      expect(restored.id, equals('pay_123'));
      expect(restored.type, equals(FinancialPaymentType.expense));
      expect(restored.status, equals(FinancialPaymentStatus.completed));
      expect(restored.amount, equals(2500.0));
      expect(restored.discount, equals(0.0));
      expect(restored.paymentDate, equals(paymentDate));
      expect(restored.paymentMethod, equals(PaymentMethod.pix));
      expect(restored.description, equals('Aluguel escritório março'));
      expect(restored.notes, equals('Pago via Pix'));
      expect(restored.entryId, equals('entry_456'));
      expect(restored.category, equals('rent'));
    });

    test('all payment types survive round-trip', () {
      for (final type in FinancialPaymentType.values) {
        final payment = FinancialPayment()..type = type;
        final json = payment.toJson();
        final restored = FinancialPayment.fromJson(json);
        expect(restored.type, equals(type));
      }
    });

    test('all payment statuses survive round-trip', () {
      for (final status in FinancialPaymentStatus.values) {
        final payment = FinancialPayment()..status = status;
        final json = payment.toJson();
        final restored = FinancialPayment.fromJson(json);
        expect(restored.status, equals(status));
      }
    });

    test('all payment methods survive round-trip', () {
      for (final method in PaymentMethod.values) {
        final payment = FinancialPayment()..paymentMethod = method;
        final json = payment.toJson();
        final restored = FinancialPayment.fromJson(json);
        expect(restored.paymentMethod, equals(method));
      }
    });

    test('transfer fields survive round-trip', () {
      final payment = FinancialPayment()
        ..type = FinancialPaymentType.transfer
        ..targetAccountId = 'acc_dest'
        ..targetAccount = (FinancialAccountAggr()
          ..id = 'acc_dest'
          ..name = 'Banco'
          ..type = FinancialAccountType.bank)
        ..transferGroupId = 'transfer_group_123'
        ..transferDirection = 'out';

      final json = payment.toJson();
      final restored = FinancialPayment.fromJson(json);

      expect(restored.targetAccountId, equals('acc_dest'));
      expect(restored.targetAccount?.id, equals('acc_dest'));
      expect(restored.targetAccount?.name, equals('Banco'));
      expect(restored.transferGroupId, equals('transfer_group_123'));
      expect(restored.transferDirection, equals('out'));
    });

    test('reversal fields survive round-trip', () {
      final reversedAt = DateTime(2026, 3, 28, 10, 0);
      final payment = FinancialPayment()
        ..status = FinancialPaymentStatus.reversed
        ..reversedPaymentId = 'pay_original'
        ..reversedByPaymentId = 'pay_reversal'
        ..reversedAt = reversedAt
        ..reversalReason = 'Pagamento duplicado';

      final json = payment.toJson();
      final restored = FinancialPayment.fromJson(json);

      expect(restored.reversedPaymentId, equals('pay_original'));
      expect(restored.reversedByPaymentId, equals('pay_reversal'));
      expect(restored.reversedAt, equals(reversedAt));
      expect(restored.reversalReason, equals('Pagamento duplicado'));
    });

    test('order link fields survive round-trip', () {
      final payment = FinancialPayment()
        ..orderId = 'order_789'
        ..orderNumber = 142;

      final json = payment.toJson();
      final restored = FinancialPayment.fromJson(json);

      expect(restored.orderId, equals('order_789'));
      expect(restored.orderNumber, equals(142));
    });

    test('nested account aggr survives round-trip', () {
      final payment = FinancialPayment()
        ..accountId = 'acc_123'
        ..account = (FinancialAccountAggr()
          ..id = 'acc_123'
          ..name = 'Caixa'
          ..type = FinancialAccountType.cash);

      final json = payment.toJson();
      final restored = FinancialPayment.fromJson(json);

      expect(restored.accountId, equals('acc_123'));
      expect(restored.account?.id, equals('acc_123'));
      expect(restored.account?.name, equals('Caixa'));
      expect(restored.account?.type, equals(FinancialAccountType.cash));
    });

    test('nested customer aggr survives round-trip', () {
      final payment = FinancialPayment()
        ..customer = (CustomerAggr()
          ..id = 'cust_123'
          ..name = 'Maria Santos');

      final json = payment.toJson();
      final restored = FinancialPayment.fromJson(json);

      expect(restored.customer?.id, equals('cust_123'));
      expect(restored.customer?.name, equals('Maria Santos'));
    });

    test('soft delete fields survive round-trip', () {
      final deletedAt = DateTime(2026, 3, 28);
      final payment = FinancialPayment()
        ..deletedAt = deletedAt
        ..syncSource = 'financial';

      final json = payment.toJson();
      final restored = FinancialPayment.fromJson(json);

      expect(restored.deletedAt, equals(deletedAt));
      expect(restored.syncSource, equals('financial'));
    });

    test('attachments survive round-trip', () {
      final payment = FinancialPayment()
        ..attachments = [
          'https://storage.example.com/receipt1.jpg',
          'https://storage.example.com/receipt2.pdf',
        ];

      final json = payment.toJson();
      final restored = FinancialPayment.fromJson(json);

      expect(restored.attachments, hasLength(2));
      expect(restored.attachments?[0],
          equals('https://storage.example.com/receipt1.jpg'));
    });

    test('null fields survive round-trip', () {
      final payment = FinancialPayment();
      final json = payment.toJson();
      final restored = FinancialPayment.fromJson(json);

      expect(restored.type, isNull);
      expect(restored.status, isNull);
      expect(restored.amount, isNull);
      expect(restored.paymentMethod, isNull);
      expect(restored.entryId, isNull);
      expect(restored.orderId, isNull);
      expect(restored.transferGroupId, isNull);
      expect(restored.reversedPaymentId, isNull);
      expect(restored.deletedAt, isNull);
    });
  });

  group('FinancialPayment JSON values', () {
    test('payment type serializes to correct string', () {
      final income = FinancialPayment()..type = FinancialPaymentType.income;
      expect(income.toJson()['type'], equals('income'));

      final expense = FinancialPayment()..type = FinancialPaymentType.expense;
      expect(expense.toJson()['type'], equals('expense'));

      final transfer =
          FinancialPayment()..type = FinancialPaymentType.transfer;
      expect(transfer.toJson()['type'], equals('transfer'));
    });

    test('payment status serializes to correct string', () {
      final completed =
          FinancialPayment()..status = FinancialPaymentStatus.completed;
      expect(completed.toJson()['status'], equals('completed'));

      final reversed =
          FinancialPayment()..status = FinancialPaymentStatus.reversed;
      expect(reversed.toJson()['status'], equals('reversed'));
    });

    test('payment method serializes to correct string', () {
      final pix = FinancialPayment()..paymentMethod = PaymentMethod.pix;
      expect(pix.toJson()['paymentMethod'], equals('pix'));

      final card =
          FinancialPayment()..paymentMethod = PaymentMethod.creditCard;
      expect(card.toJson()['paymentMethod'], equals('creditCard'));

      final cash = FinancialPayment()..paymentMethod = PaymentMethod.cash;
      expect(cash.toJson()['paymentMethod'], equals('cash'));
    });
  });
}
