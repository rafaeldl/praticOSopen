import 'dart:async';

import 'package:flutter/foundation.dart';
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

  /// 'discount', 'status', 'payment' or 'receipt': the step that failed; the
  /// ones after it did not run.
  String? failedStep;

  bool get changedSomething =>
      discountId != null || paymentId != null || statusAfter != null;
}

/// False when the server refused the status: it goes back on screen. Offline
/// nothing answers, and after [wait] the order counts as changed.
Future<bool> _saveStatus(
  OrderStore store,
  String status,
  Duration wait,
) async {
  final previous = store.status;
  try {
    await store.setStatus(status)?.timeout(wait);
    return true;
  } on TimeoutException {
    return true;
  } catch (e) {
    debugPrint('Could not save the order status: $e');
    store.restoreStatus(previous);
    return false;
  }
}

/// Runs the confirmed card: discount, approval (a quote takes no payment),
/// payment and status. Stops at the first failure.
Future<AiActionsOutcome> runAiActions(
  OrderStore store,
  AiActionsPlan plan, {
  required Duration statusWait,
}) async {
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

  Future<bool> moveTo(String status) async {
    final previous = store.status;
    if (!await _saveStatus(store, status, statusWait)) return false;
    outcome.statusBefore ??= previous;
    outcome.statusAfter = status;
    return true;
  }

  if (plan.approveFirst && !await moveTo('approved')) {
    return outcome..failedStep = 'status';
  }

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

  if (plan.status != null && !await moveTo(plan.status!)) {
    return outcome..failedStep = 'status';
  }
  return outcome;
}

/// "Desfazer" of the card, last step first. A removal needs a connection and
/// the server can refuse the status; [ok] false leaves the rest in place. The status stays when the user can't
/// change it back ([statusKept]).
Future<({bool ok, bool statusKept})> undoAiActions(
  OrderStore store,
  AiActionsOutcome outcome, {
  required bool Function(String status) canChangeStatus,
  required Duration statusWait,
}) async {
  var statusKept = false;
  final before = outcome.statusBefore;

  Future<bool> restoreStatus() async {
    if (before == null || outcome.statusAfter == null) return true;
    if (!canChangeStatus(before)) {
      statusKept = true;
      return true;
    }
    if (!await _saveStatus(store, before, statusWait)) return false;
    outcome.statusAfter = null;
    return true;
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
  if (!await restoreStatus()) return (ok: false, statusKept: false);
  if (!await remove(outcome.discountId)) {
    return (ok: false, statusKept: statusKept);
  }
  outcome.discountId = null;
  return (ok: true, statusKept: statusKept);
}
