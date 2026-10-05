import 'package:flutter/cupertino.dart';
import 'package:praticos/models/payment_transaction.dart';

/// Leading icon of a payment history row. Asaas payments get a card icon so
/// they stand out from manual payments.
class PaymentTransactionIcon extends StatelessWidget {
  const PaymentTransactionIcon({super.key, required this.transaction});

  final PaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isPayment = transaction.type == PaymentTransactionType.payment;
    final Color color;
    final IconData icon;
    if (transaction.isAsaas) {
      color = CupertinoColors.systemIndigo;
      icon = CupertinoIcons.creditcard_fill;
    } else if (isPayment) {
      color = CupertinoColors.systemGreen;
      icon = CupertinoIcons.arrow_down_circle;
    } else {
      color = CupertinoColors.systemOrange;
      icon = CupertinoIcons.tag;
    }
    final resolved = CupertinoDynamicColor.resolve(color, context);

    return Container(
      key: const Key('paymentTransactionIcon'),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: resolved, size: 20),
    );
  }
}
