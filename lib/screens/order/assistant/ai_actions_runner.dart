import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/screens/order/assistant/ai_actions_plan.dart';
import 'package:praticos/screens/payments/order_payment_actions.dart';
import 'package:praticos/screens/payments/widgets/receive_payment_sheet.dart';
import 'package:praticos/services/customer_receipt_service.dart'
    show PickedReceiptFile;

/// What the card really did, for the note and for "Desfazer".
class AiActionsOutcome {
  String? discountId;
  double? discount;
  String? paymentId;
  double? payment;

  /// Status before the card touched it, when it did.
  String? statusBefore;
  String? statusAfter;

  /// 'discount', 'payment' or 'receipt': the step that failed; the ones after
  /// it did not run.
  String? failedStep;

  bool get changedSomething =>
      discountId != null || paymentId != null || statusAfter != null;
}

/// Runs the confirmed card: discount, approval (a quote takes no payment),
/// payment and status. Stops at the first failure.
Future<AiActionsOutcome> runAiActions(
  OrderStore store,
  AiActionsPlan plan,
) async {
  final outcome = AiActionsOutcome();
  final discount = plan.discount;
  if (discount != null) {
    if (!await store.addDiscountTransaction(discount)) {
      return outcome..failedStep = 'discount';
    }
    outcome
      ..discountId = store.transactions.lastOrNull?.id
      ..discount = discount;
  }

  void moveTo(String status) {
    outcome.statusBefore ??= store.status;
    store.setStatus(status);
    outcome.statusAfter = status;
  }

  if (plan.approveFirst) moveTo('approved');

  final payment = plan.payment;
  if (payment != null) {
    // The balance now, not the one shown when the card opened.
    final balance = store.remainingBalance;
    final amount = payment.settlesAll || payment.amount! > balance
        ? balance
        : payment.amount!;
    final (:transaction, :receiptOk) = await registerOrderPayment(
      store,
      ReceiveDraft(
        amount: amount,
        paidDay: payment.paidDay ?? DateTime.now(),
        receipt: payment.receipt as PickedReceiptFile?,
        paymentMethod: payment.method,
      ),
    );
    if (transaction == null) return outcome..failedStep = 'payment';
    outcome
      ..paymentId = transaction.id
      ..payment = amount;
    if (!receiptOk) return outcome..failedStep = 'receipt';
  }

  if (plan.status != null) moveTo(plan.status!);
  return outcome;
}

/// "Desfazer" of the card, last step first. A removal needs a connection;
/// [ok] false leaves the rest in place. The status stays when the user can't
/// change it back ([statusKept]).
Future<({bool ok, bool statusKept})> undoAiActions(
  OrderStore store,
  AiActionsOutcome outcome, {
  required bool Function(String status) canChangeStatus,
}) async {
  var statusKept = false;
  final before = outcome.statusBefore;

  void restoreStatus() {
    if (before == null || outcome.statusAfter == null) return;
    if (canChangeStatus(before)) {
      store.setStatus(before);
      outcome.statusAfter = null;
    } else {
      statusKept = true;
    }
  }

  Future<bool> remove(String? id) async {
    if (id == null) return true;
    final index = store.transactions.indexWhere((t) => t.id == id);
    return index < 0 || await store.removeTransaction(index);
  }

  if (!await remove(outcome.paymentId)) {
    return (ok: false, statusKept: false);
  }
  outcome.paymentId = null;
  restoreStatus();
  if (!await remove(outcome.discountId)) {
    return (ok: false, statusKept: statusKept);
  }
  outcome.discountId = null;
  return (ok: true, statusKept: statusKept);
}
