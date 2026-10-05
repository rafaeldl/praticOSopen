import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/screens/payments/widgets/payment_transaction_icon.dart';

void main() {
  Future<void> pumpIcon(WidgetTester tester, PaymentTransaction txn) async {
    await tester.pumpWidget(
      CupertinoApp(home: Center(child: PaymentTransactionIcon(transaction: txn))),
    );
  }

  group('PaymentTransactionIcon', () {
    testWidgets('transação Asaas usa ícone de cartão', (tester) async {
      await pumpIcon(
        tester,
        PaymentTransaction(
          id: 'asaas_pay_1',
          type: PaymentTransactionType.payment,
          amount: 100,
        ),
      );

      expect(find.byIcon(CupertinoIcons.creditcard_fill), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.arrow_down_circle), findsNothing);
    });

    testWidgets('pagamento manual mantém a seta', (tester) async {
      await pumpIcon(
        tester,
        PaymentTransaction(
          id: '1728000000000',
          type: PaymentTransactionType.payment,
          amount: 100,
        ),
      );

      expect(find.byIcon(CupertinoIcons.arrow_down_circle), findsOneWidget);
    });

    testWidgets('desconto mantém a etiqueta', (tester) async {
      await pumpIcon(
        tester,
        PaymentTransaction(type: PaymentTransactionType.discount, amount: 10),
      );

      expect(find.byIcon(CupertinoIcons.tag), findsOneWidget);
    });
  });
}
