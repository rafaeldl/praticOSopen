import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations_en.dart';
import 'package:praticos/l10n/app_localizations_es.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/screens/payments/widgets/receive_payment_row.dart';

void main() {
  final old = {
    'id': 'tx1',
    'type': 'payment',
    'amount': 100.0,
    'createdAt': '2026-01-10T10:00:00.000',
  };

  test('payments already saved have no method and write none back', () {
    final tx = PaymentTransaction.fromJson(old);
    expect(tx.paymentMethod, isNull);
    expect(tx.toJson().containsKey('paymentMethod'), isFalse);
  });

  test('a chosen method survives the round trip', () {
    final tx = PaymentTransaction.payment(
      amount: 10,
      paymentMethod: PaymentMethod.pix,
    );
    expect(
      PaymentTransaction.fromJson(tx.toJson()).paymentMethod,
      PaymentMethod.pix,
    );
  });

  test('an unknown value does not break reading and shows no label', () {
    final tx = PaymentTransaction.fromJson({...old, 'paymentMethod': 'crypto'});
    expect(tx.paymentMethod, 'crypto');
    expect(paymentMethodLabel(AppLocalizationsPt(), tx.paymentMethod), isNull);
  });

  test('labels in the three languages', () {
    expect(paymentMethodLabel(AppLocalizationsPt(), 'cash'), 'Dinheiro');
    expect(paymentMethodLabel(AppLocalizationsEn(), 'cash'), 'Cash');
    expect(paymentMethodLabel(AppLocalizationsEs(), 'card'), 'Tarjeta');
    expect(paymentMethodLabel(AppLocalizationsPt(), null), isNull);
  });
}
