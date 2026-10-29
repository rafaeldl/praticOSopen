import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/payments/widgets/receive_date_row.dart';
import 'package:praticos/screens/payments/widgets/receive_payment_row.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/utils/financial_summary.dart';
import 'package:praticos/utils/order_payment_math.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => FormatService().setLocale('pt-BR'));
  final l10n = AppLocalizationsPt();
  final now = DateTime(2026, 10, 14, 15, 20);

  test('paymentDayLabel: Hoje, Ontem or the date', () {
    expect(paymentDayLabel(l10n, DateTime(2026, 10, 14), now: now), 'Hoje');
    expect(paymentDayLabel(l10n, DateTime(2026, 10, 13), now: now), 'Ontem');
    expect(
      paymentDayLabel(l10n, DateTime(2026, 10, 2), now: now),
      FormatService().formatDate(DateTime(2026, 10, 2)),
    );
  });

  test('paidAtFor: now when today, noon of the day otherwise', () {
    expect(paidAtFor(DateTime(2026, 10, 14), now: now), now);
    expect(
      paidAtFor(DateTime(2026, 10, 10, 8), now: now),
      DateTime(2026, 10, 10, 12),
    );
  });

  test('a single-order payment carries paidAt into the order update', () {
    final tx = PaymentTransaction.payment(
      amount: 50,
      paidAt: DateTime(2026, 10, 10, 12),
    );
    final update = OrderPaymentMath.addPaymentUpdate(
      current: Order()
        ..total = 100
        ..paidAmount = 0,
      tx: tx,
    );
    final json = (update['transactions'] as ArrayUnionOp).values.single as Map;
    expect(json['paidAt'], isNotNull);
    expect(
      PaymentTransaction.fromJson(Map<String, dynamic>.from(json)).paidAt,
      DateTime(2026, 10, 10, 12),
    );
  });

  test('the payment row shows the chosen day when it differs', () {
    final format = FormatService();
    final late = PaymentTransaction(
      id: 't',
      type: PaymentTransactionType.payment,
      amount: 10,
      createdAt: DateTime(2026, 10, 14, 9),
      paidAt: DateTime(2026, 10, 10, 12),
    );
    expect(
      paymentWhenLabel(late, format),
      format.formatDate(DateTime(2026, 10, 10)),
    );
    final sameDay = PaymentTransaction(
      id: 't',
      type: PaymentTransactionType.payment,
      amount: 10,
      createdAt: DateTime(2026, 10, 14, 9),
      paidAt: DateTime(2026, 10, 14, 9),
    );
    expect(
      paymentWhenLabel(sameDay, format),
      format.formatDateTime(DateTime(2026, 10, 14, 9)),
    );
  });

  test('"Recebido em" uses paidAt over createdAt', () {
    final order = Order()
      ..total = 100
      ..paidAmount = 100
      ..payment = 'paid'
      ..transactions = [
        PaymentTransaction(
          id: 't',
          type: PaymentTransactionType.payment,
          amount: 100,
          createdAt: DateTime(2026, 11, 2),
          paidAt: DateTime(2026, 10, 30, 12),
        ),
      ];
    expect(FinancialSummary.paidDate(order), DateTime(2026, 10, 30, 12));
  });
}
