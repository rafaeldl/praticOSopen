import 'package:praticos/utils/order_payment_math.dart';
import 'package:praticos/services/ai_order_assist_service.dart';

/// What the order looks like when the card opens. The server does not know
/// which order this is, so amounts, rules and permissions are all here.
class AiActionsContext {
  const AiActionsContext({
    required this.status,
    required this.total,
    required this.remaining,
    required this.showMoney,
    required this.canReceive,
    required this.canDiscount,
    required this.canChangeStatus,
    this.pendingChecklists = 0,
    this.nfseAutoIssue,
  });

  final String? status;
  final double total;
  final double remaining;

  /// "Valores e cobrança" on and the user sees prices. Off: money is ignored
  /// without a word, the company does not use that part.
  final bool showMoney;
  final bool canReceive;
  final bool canDiscount;
  final bool Function(String status) canChangeStatus;
  final int pendingChecklists;

  /// 'paid' or 'completed' when a nota goes out by itself.
  final String? nfseAutoIssue;
}

/// What the user changed on the card, over what the assistant understood.
class AiActionsEdits {
  const AiActionsEdits({
    this.discount,
    this.payment,
    this.method,
    this.methodEdited = false,
    this.paidDay,
    this.receipt,
  });

  final double? discount;
  final double? payment;
  final String? method;
  final bool methodEdited;
  final DateTime? paidDay;

  /// `PickedReceiptFile` chosen on the receive sheet.
  final Object? receipt;
}

/// Why a part of the request is not on the card.
enum AiActionNoticeKind {
  cannotReceive,
  cannotDiscount,
  canceled,
  nothingToReceive,
  onlyLeft,
  pendingChecklists,
  statusDenied,
}

class AiActionNotice {
  const AiActionNotice(this.kind, {this.amount, this.count});

  final AiActionNoticeKind kind;
  final double? amount;
  final int? count;
}

/// A payment on the card. [amount] null means nothing was said: the row asks.
class AiPaymentStep {
  const AiPaymentStep({
    required this.amount,
    required this.max,
    required this.method,
    required this.paidDay,
    required this.settlesAll,
    this.receipt,
  });

  final double? amount;

  /// Balance at this point of the card (after the discount).
  final double max;
  final String? method;

  /// Null = today.
  final DateTime? paidDay;

  /// "Pagou tudo" as understood: on saving it takes the balance of that
  /// moment, not the one shown when the card opened.
  final bool settlesAll;
  final Object? receipt;

  double? get left =>
      amount == null ? null : OrderPaymentMath.roundMoney(max - amount!);
  bool get paysOff =>
      amount != null && left! <= OrderPaymentMath.centTolerance;
}

/// The card: what will run, in order, and what could not be included.
class AiActionsPlan {
  const AiActionsPlan({
    required this.total,
    this.discount,
    this.discountMax = 0,
    this.approveFirst = false,
    this.payment,
    this.status,
    this.previousStatus,
    this.notices = const [],
    this.issuesNfse = false,
  });

  final double total;
  final double? discount;
  final double discountMax;

  /// A quote takes no payment: it is approved first, in plain sight.
  final bool approveFirst;
  final AiPaymentStep? payment;
  final String? status;
  final String? previousStatus;
  final List<AiActionNotice> notices;
  final bool issuesNfse;

  bool get hasSteps =>
      discount != null || approveFirst || payment != null || status != null;

  /// False while the payment row still waits for an amount.
  bool get canConfirm =>
      hasSteps && (payment == null || (payment!.amount ?? 0) > 0);

  /// For `ai_action_proposed`: never amounts.
  String get types => [
    if (payment != null) 'payment',
    if (discount != null) 'discount',
    if (approveFirst || status != null) 'status',
  ].join(',');
}

const List<String> _statusFlow = ['quote', 'approved', 'progress', 'done'];

double _round(double value) => OrderPaymentMath.roundMoney(value);

/// Turns what was said into the card. Pure: the same request and order always
/// give the same card, and the card is rebuilt on every edit.
AiActionsPlan planAiActions(
  AiOrderActions actions,
  AiActionsContext order, {
  AiActionsEdits edits = const AiActionsEdits(),
}) {
  if (order.status == 'canceled') {
    return AiActionsPlan(
      total: order.total,
      notices: const [AiActionNotice(AiActionNoticeKind.canceled)],
    );
  }
  final notices = <AiActionNotice>[];
  var balance = order.remaining;

  void nothingToReceive() {
    if (!notices.any((n) => n.kind == AiActionNoticeKind.nothingToReceive)) {
      notices.add(const AiActionNotice(AiActionNoticeKind.nothingToReceive));
    }
  }

  double? discount;
  var discountMax = 0.0;
  final askedDiscount = order.showMoney ? actions.discount : null;
  if (askedDiscount != null) {
    if (!order.canDiscount) {
      notices.add(const AiActionNotice(AiActionNoticeKind.cannotDiscount));
    } else if (balance <= 0) {
      nothingToReceive();
    } else {
      discountMax = balance;
      final said =
          edits.discount ??
          (askedDiscount.isPercent
              ? _round(order.total * askedDiscount.value / 100)
              : askedDiscount.value);
      discount = said > balance ? balance : said;
      balance = _round(balance - discount);
    }
  }

  AiPaymentStep? payment;
  var approveFirst = false;
  final askedPayment = order.showMoney ? actions.payment : null;
  if (askedPayment != null) {
    if (!order.canReceive) {
      notices.add(const AiActionNotice(AiActionNoticeKind.cannotReceive));
    } else if (balance <= 0) {
      nothingToReceive();
    } else if (order.status == 'quote' && !order.canChangeStatus('approved')) {
      // Nothing is saved: a quote takes no payment and they can't approve it.
      notices.add(const AiActionNotice(AiActionNoticeKind.statusDenied));
    } else {
      approveFirst = order.status == 'quote';
      final said = edits.payment ?? _paymentAmount(askedPayment, balance);
      var amount = said != null && said > 0 ? said : null;
      if (amount != null && amount > balance) {
        notices.add(
          AiActionNotice(AiActionNoticeKind.onlyLeft, amount: balance),
        );
        amount = balance;
      }
      payment = AiPaymentStep(
        amount: amount,
        max: balance,
        method: edits.methodEdited ? edits.method : askedPayment.method,
        paidDay: edits.paidDay ?? askedPayment.paidDay,
        settlesAll: askedPayment.kind == 'full' && edits.payment == null,
        receipt: edits.receipt,
      );
    }
  }

  // Forward only: going back is not something the assistant does.
  final current = approveFirst ? 'approved' : order.status;
  String? status;
  final asked = actions.status;
  if (asked != null &&
      _statusFlow.indexOf(asked) > _statusFlow.indexOf(current ?? 'quote')) {
    if (!order.canChangeStatus(asked)) {
      notices.add(const AiActionNotice(AiActionNoticeKind.statusDenied));
    } else if (asked == 'done' && order.pendingChecklists > 0) {
      notices.add(
        AiActionNotice(
          AiActionNoticeKind.pendingChecklists,
          count: order.pendingChecklists,
        ),
      );
    } else {
      status = asked;
    }
  }

  // A discount that closes the order issues nothing: no money came in
  // (`closedByDiscount` in the order trigger).
  final issuesNfse = switch (order.nfseAutoIssue) {
    'paid' => payment?.paysOff ?? false,
    'completed' => status == 'done',
    _ => false,
  };

  return AiActionsPlan(
    total: order.total,
    discount: discount,
    discountMax: discountMax,
    approveFirst: approveFirst,
    payment: payment,
    status: status,
    previousStatus: order.status,
    notices: notices,
    issuesNfse: issuesNfse,
  );
}

double? _paymentAmount(AiPaymentAction payment, double balance) {
  final value = payment.value;
  return switch (payment.kind) {
    'full' => balance,
    'percent' when value != null => _round(balance * value / 100),
    'leaving' when value != null => _round(balance - value),
    _ => value,
  };
}
