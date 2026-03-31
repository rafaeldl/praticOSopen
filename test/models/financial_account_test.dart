import 'package:praticos/models/financial_account.dart';
import 'package:test/test.dart';

void main() {
  group('FinancialAccount JSON round-trip', () {
    test('basic fields survive round-trip', () {
      final account = FinancialAccount()
        ..id = 'acc_123'
        ..name = 'Conta Corrente Itaú'
        ..type = FinancialAccountType.bank
        ..initialBalance = 5000.0
        ..currentBalance = 12500.50
        ..currency = 'BRL'
        ..color = '#1E88E5'
        ..icon = 'bank'
        ..active = true
        ..isDefault = true;

      final json = account.toJson();
      final restored = FinancialAccount.fromJson(json);

      expect(restored.id, equals('acc_123'));
      expect(restored.name, equals('Conta Corrente Itaú'));
      expect(restored.type, equals(FinancialAccountType.bank));
      expect(restored.initialBalance, equals(5000.0));
      expect(restored.currentBalance, equals(12500.50));
      expect(restored.currency, equals('BRL'));
      expect(restored.color, equals('#1E88E5'));
      expect(restored.icon, equals('bank'));
      expect(restored.active, isTrue);
      expect(restored.isDefault, isTrue);
    });

    test('all account types survive round-trip', () {
      for (final type in FinancialAccountType.values) {
        final account = FinancialAccount()..type = type;
        final json = account.toJson();
        final restored = FinancialAccount.fromJson(json);
        expect(restored.type, equals(type));
      }
    });

    test('null fields survive round-trip', () {
      final account = FinancialAccount();
      final json = account.toJson();
      final restored = FinancialAccount.fromJson(json);

      expect(restored.name, isNull);
      expect(restored.type, isNull);
      expect(restored.initialBalance, isNull);
      expect(restored.currentBalance, isNull);
      expect(restored.active, isNull);
      expect(restored.isDefault, isNull);
      expect(restored.lastReconciledAt, isNull);
    });

    test('date field survives round-trip', () {
      final date = DateTime(2026, 3, 15, 14, 30);
      final account = FinancialAccount()..lastReconciledAt = date;

      final json = account.toJson();
      final restored = FinancialAccount.fromJson(json);

      expect(restored.lastReconciledAt, equals(date));
    });
  });

  group('FinancialAccountAggr', () {
    test('toAggr preserves essential fields', () {
      final account = FinancialAccount()
        ..id = 'acc_123'
        ..name = 'Caixa'
        ..type = FinancialAccountType.cash
        ..currentBalance = 3200.0
        ..active = true;

      final aggr = account.toAggr();

      expect(aggr.id, equals('acc_123'));
      expect(aggr.name, equals('Caixa'));
      expect(aggr.type, equals(FinancialAccountType.cash));
    });

    test('aggr JSON round-trip', () {
      final aggr = FinancialAccountAggr()
        ..id = 'acc_456'
        ..name = 'Pix PicPay'
        ..type = FinancialAccountType.digitalWallet;

      final json = aggr.toJson();
      final restored = FinancialAccountAggr.fromJson(json);

      expect(restored.id, equals('acc_456'));
      expect(restored.name, equals('Pix PicPay'));
      expect(restored.type, equals(FinancialAccountType.digitalWallet));
    });
  });
}
