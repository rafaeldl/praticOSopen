import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/models/customer.dart';
import 'package:test/test.dart';

void main() {
  group('FinancialEntry JSON round-trip', () {
    test('basic fields survive round-trip', () {
      final entry = FinancialEntry()
        ..id = 'entry_123'
        ..direction = FinancialEntryDirection.payable
        ..status = FinancialEntryStatus.pending
        ..description = 'Aluguel escritório março'
        ..amount = 2500.0
        ..paidAmount = 0.0
        ..discountAmount = 0.0
        ..category = 'rent'
        ..supplier = 'Imobiliária XYZ'
        ..notes = 'Ref: contrato 2024';

      final json = entry.toJson();
      final restored = FinancialEntry.fromJson(json);

      expect(restored.id, equals('entry_123'));
      expect(restored.direction, equals(FinancialEntryDirection.payable));
      expect(restored.status, equals(FinancialEntryStatus.pending));
      expect(restored.description, equals('Aluguel escritório março'));
      expect(restored.amount, equals(2500.0));
      expect(restored.paidAmount, equals(0.0));
      expect(restored.discountAmount, equals(0.0));
      expect(restored.category, equals('rent'));
      expect(restored.supplier, equals('Imobiliária XYZ'));
      expect(restored.notes, equals('Ref: contrato 2024'));
    });

    test('all direction enums survive round-trip', () {
      for (final dir in FinancialEntryDirection.values) {
        final entry = FinancialEntry()..direction = dir;
        final json = entry.toJson();
        final restored = FinancialEntry.fromJson(json);
        expect(restored.direction, equals(dir));
      }
    });

    test('all status enums survive round-trip', () {
      for (final status in FinancialEntryStatus.values) {
        final entry = FinancialEntry()..status = status;
        final json = entry.toJson();
        final restored = FinancialEntry.fromJson(json);
        expect(restored.status, equals(status));
      }
    });

    test('date fields survive round-trip', () {
      final dueDate = DateTime(2026, 4, 10);
      final competenceDate = DateTime(2026, 4, 1);
      final paidDate = DateTime(2026, 4, 8, 14, 30);

      final entry = FinancialEntry()
        ..dueDate = dueDate
        ..competenceDate = competenceDate
        ..paidDate = paidDate;

      final json = entry.toJson();
      final restored = FinancialEntry.fromJson(json);

      expect(restored.dueDate, equals(dueDate));
      expect(restored.competenceDate, equals(competenceDate));
      expect(restored.paidDate, equals(paidDate));
    });

    test('installment fields survive round-trip', () {
      final entry = FinancialEntry()
        ..installmentGroupId = 'group_abc'
        ..installmentNumber = 3
        ..installmentTotal = 6;

      final json = entry.toJson();
      final restored = FinancialEntry.fromJson(json);

      expect(restored.installmentGroupId, equals('group_abc'));
      expect(restored.installmentNumber, equals(3));
      expect(restored.installmentTotal, equals(6));
    });

    test('nested account aggr survives round-trip', () {
      final entry = FinancialEntry()
        ..accountId = 'acc_456'
        ..account = (FinancialAccountAggr()
          ..id = 'acc_456'
          ..name = 'Conta Corrente'
          ..type = FinancialAccountType.bank);

      final json = entry.toJson();
      final restored = FinancialEntry.fromJson(json);

      expect(restored.accountId, equals('acc_456'));
      expect(restored.account?.id, equals('acc_456'));
      expect(restored.account?.name, equals('Conta Corrente'));
      expect(restored.account?.type, equals(FinancialAccountType.bank));
    });

    test('nested customer aggr survives round-trip', () {
      final entry = FinancialEntry()
        ..customer = (CustomerAggr()
          ..id = 'cust_789'
          ..name = 'João Silva');

      final json = entry.toJson();
      final restored = FinancialEntry.fromJson(json);

      expect(restored.customer?.id, equals('cust_789'));
      expect(restored.customer?.name, equals('João Silva'));
    });

    test('tags and attachments survive round-trip', () {
      final entry = FinancialEntry()
        ..tags = ['fixed', 'monthly']
        ..attachments = ['https://example.com/receipt.jpg'];

      final json = entry.toJson();
      final restored = FinancialEntry.fromJson(json);

      expect(restored.tags, equals(['fixed', 'monthly']));
      expect(restored.attachments, equals(['https://example.com/receipt.jpg']));
    });

    test('soft delete fields survive round-trip', () {
      final deletedAt = DateTime(2026, 3, 28, 10, 0);
      final entry = FinancialEntry()
        ..deletedAt = deletedAt
        ..syncSource = 'order';

      final json = entry.toJson();
      final restored = FinancialEntry.fromJson(json);

      expect(restored.deletedAt, equals(deletedAt));
      expect(restored.syncSource, equals('order'));
    });
  });

  group('FinancialEntry computed getters', () {
    test('remainingBalance = amount - paidAmount - discountAmount', () {
      final entry = FinancialEntry()
        ..amount = 1000.0
        ..paidAmount = 300.0
        ..discountAmount = 50.0;

      expect(entry.remainingBalance, equals(650.0));
    });

    test('remainingBalance handles null fields as zero', () {
      final entry = FinancialEntry()..amount = 500.0;
      expect(entry.remainingBalance, equals(500.0));
    });

    test('remainingBalance is zero when fully paid', () {
      final entry = FinancialEntry()
        ..amount = 1000.0
        ..paidAmount = 1000.0
        ..discountAmount = 0.0;

      expect(entry.remainingBalance, equals(0.0));
    });

    test('remainingBalance accounts for discount completing payment', () {
      final entry = FinancialEntry()
        ..amount = 1000.0
        ..paidAmount = 800.0
        ..discountAmount = 200.0;

      expect(entry.remainingBalance, equals(0.0));
    });

    test('isFullyPaid when remainingBalance <= 0', () {
      final paid = FinancialEntry()
        ..amount = 100.0
        ..paidAmount = 100.0
        ..discountAmount = 0.0;
      expect(paid.isFullyPaid, isTrue);

      final partial = FinancialEntry()
        ..amount = 100.0
        ..paidAmount = 50.0
        ..discountAmount = 0.0;
      expect(partial.isFullyPaid, isFalse);
    });

    test('isFullyPaid with discount covering remainder', () {
      final entry = FinancialEntry()
        ..amount = 1000.0
        ..paidAmount = 700.0
        ..discountAmount = 300.0;

      expect(entry.isFullyPaid, isTrue);
    });

    test('isOverdue when pending and past due', () {
      final overdue = FinancialEntry()
        ..status = FinancialEntryStatus.pending
        ..dueDate = DateTime.now().subtract(const Duration(days: 5));
      expect(overdue.isOverdue, isTrue);

      final future = FinancialEntry()
        ..status = FinancialEntryStatus.pending
        ..dueDate = DateTime.now().add(const Duration(days: 5));
      expect(future.isOverdue, isFalse);

      final paidPastDue = FinancialEntry()
        ..status = FinancialEntryStatus.paid
        ..dueDate = DateTime.now().subtract(const Duration(days: 5));
      expect(paidPastDue.isOverdue, isFalse);
    });

    test('isOverdue is false when dueDate is null', () {
      final entry = FinancialEntry()
        ..status = FinancialEntryStatus.pending
        ..dueDate = null;
      expect(entry.isOverdue, isFalse);
    });

    test('isInstallment checks both fields present', () {
      final installment = FinancialEntry()
        ..installmentNumber = 3
        ..installmentTotal = 6;
      expect(installment.isInstallment, isTrue);

      final single = FinancialEntry();
      expect(single.isInstallment, isFalse);

      final partial = FinancialEntry()..installmentNumber = 1;
      expect(partial.isInstallment, isFalse);
    });
  });

  group('FinancialRecurrence JSON round-trip', () {
    test('all fields survive round-trip', () {
      final nextDue = DateTime(2026, 5, 10);
      final lastGen = DateTime(2026, 4, 10);
      final endDate = DateTime(2027, 3, 10);

      final recurrence = FinancialRecurrence()
        ..frequency = 'monthly'
        ..interval = 1
        ..endDate = endDate
        ..nextDueDate = nextDue
        ..lastGeneratedDate = lastGen
        ..active = true;

      final json = recurrence.toJson();
      final restored = FinancialRecurrence.fromJson(json);

      expect(restored.frequency, equals('monthly'));
      expect(restored.interval, equals(1));
      expect(restored.endDate, equals(endDate));
      expect(restored.nextDueDate, equals(nextDue));
      expect(restored.lastGeneratedDate, equals(lastGen));
      expect(restored.active, isTrue);
    });

    test('embedded recurrence in entry survives round-trip', () {
      final entry = FinancialEntry()
        ..recurrence = (FinancialRecurrence()
          ..frequency = 'monthly'
          ..interval = 1
          ..active = true);

      final json = entry.toJson();
      final restored = FinancialEntry.fromJson(json);

      expect(restored.recurrence, isNotNull);
      expect(restored.recurrence?.frequency, equals('monthly'));
      expect(restored.recurrence?.interval, equals(1));
      expect(restored.recurrence?.active, isTrue);
    });
  });

  group('FinancialEntryAggr', () {
    test('toAggr preserves essential fields', () {
      final entry = FinancialEntry()
        ..id = 'entry_123'
        ..direction = FinancialEntryDirection.payable
        ..description = 'Aluguel'
        ..amount = 2500.0
        ..dueDate = DateTime(2026, 4, 10)
        ..status = FinancialEntryStatus.pending;

      final aggr = entry.toAggr();

      expect(aggr.id, equals('entry_123'));
      expect(aggr.direction, equals(FinancialEntryDirection.payable));
      expect(aggr.description, equals('Aluguel'));
      expect(aggr.amount, equals(2500.0));
      expect(aggr.dueDate, equals(DateTime(2026, 4, 10)));
      expect(aggr.status, equals(FinancialEntryStatus.pending));
    });
  });
}
