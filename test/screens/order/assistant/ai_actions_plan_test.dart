import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/order/assistant/ai_actions_plan.dart';
import 'package:praticos/services/ai_order_assist_service.dart';

AiActionsContext _order({
  String? status = 'approved',
  double total = 800,
  double remaining = 800,
  bool showMoney = true,
  bool canReceive = true,
  bool canDiscount = true,
  bool Function(String)? canChangeStatus,
  int pendingChecklists = 0,
  String? nfse,
}) => AiActionsContext(
  status: status,
  total: total,
  remaining: remaining,
  showMoney: showMoney,
  canReceive: canReceive,
  canDiscount: canDiscount,
  canChangeStatus: canChangeStatus ?? (_) => true,
  pendingChecklists: pendingChecklists,
  nfseAutoIssue: nfse,
);

AiOrderActions _pay(String kind, [double? value]) => AiOrderActions(
  payment: AiPaymentAction(kind: kind, value: value),
);

List<AiActionNoticeKind> _notices(AiActionsPlan plan) => [
  for (final n in plan.notices) n.kind,
];

void main() {
  group('amount of each kind', () {
    test('"pagou tudo" is the balance and follows it on saving', () {
      final step = planAiActions(_pay('full'), _order()).payment!;
      expect(step.amount, 800);
      expect(step.settlesAll, isTrue);
      expect(step.paysOff, isTrue);
    });

    test('"deu 500" leaves the rest', () {
      final step = planAiActions(_pay('value', 500), _order()).payment!;
      expect(step.amount, 500);
      expect(step.left, 300);
      expect(step.settlesAll, isFalse);
    });

    test('"pagou metade" is a share of the balance', () {
      final step = planAiActions(_pay('percent', 50), _order()).payment!;
      expect(step.amount, 400);
    });

    test('"ficou devendo 200" is the balance minus that', () {
      final step = planAiActions(_pay('leaving', 200), _order()).payment!;
      expect(step.amount, 600);
    });

    test('uses the balance of the order, so an item from the same phrase '
        'counts', () {
      final step = planAiActions(
        _pay('full'),
        _order(total: 1000, remaining: 1000),
      ).payment!;
      expect(step.amount, 1000);
    });

    test('no amount said: the row asks and Confirmar waits', () {
      final plan = planAiActions(_pay('value'), _order());
      expect(plan.payment!.amount, isNull);
      expect(plan.hasSteps, isTrue);
      expect(plan.canConfirm, isFalse);
    });

    test('an amount that comes out zero or negative also asks', () {
      final plan = planAiActions(_pay('leaving', 900), _order());
      expect(plan.payment!.amount, isNull);
      expect(plan.canConfirm, isFalse);
    });

    test('above the balance: never more than it, and it says so', () {
      final plan = planAiActions(
        _pay('value', 500),
        _order(total: 300, remaining: 300),
      );
      expect(plan.payment!.amount, 300);
      expect(_notices(plan), [AiActionNoticeKind.onlyLeft]);
      expect(plan.notices.single.amount, 300);
    });
  });

  group('discount', () {
    test('percent uses the total of the order', () {
      final plan = planAiActions(
        const AiOrderActions(
          discount: AiDiscountAction(isPercent: true, value: 10),
        ),
        _order(total: 800, remaining: 300),
      );
      expect(plan.discount, 80);
    });

    test('above the balance stops at the balance', () {
      final plan = planAiActions(
        const AiOrderActions(
          discount: AiDiscountAction(isPercent: false, value: 500),
        ),
        _order(remaining: 300),
      );
      expect(plan.discount, 300);
    });

    test('comes off the balance before the payment', () {
      final plan = planAiActions(
        const AiOrderActions(
          discount: AiDiscountAction(isPercent: false, value: 100),
          payment: AiPaymentAction(kind: 'full'),
        ),
        _order(),
      );
      expect(plan.payment!.amount, 700);
    });

    test('a consultant receives but gives no discount', () {
      final plan = planAiActions(
        const AiOrderActions(
          discount: AiDiscountAction(isPercent: false, value: 100),
          payment: AiPaymentAction(kind: 'full'),
        ),
        _order(canDiscount: false),
      );
      expect(plan.discount, isNull);
      expect(plan.payment!.amount, 800);
      expect(_notices(plan), [AiActionNoticeKind.cannotDiscount]);
    });
  });

  group('what can not happen', () {
    test('who can not receive sees why, and the status still goes', () {
      final plan = planAiActions(
        const AiOrderActions(
          payment: AiPaymentAction(kind: 'full'),
          status: 'done',
        ),
        _order(canReceive: false),
      );
      expect(plan.payment, isNull);
      expect(plan.status, 'done');
      expect(_notices(plan), [AiActionNoticeKind.cannotReceive]);
    });

    test('company without "Valores e cobrança": money ignored in silence', () {
      final plan = planAiActions(_pay('full'), _order(showMoney: false));
      expect(plan.hasSteps, isFalse);
      expect(plan.notices, isEmpty);
    });

    test('a canceled order takes nothing', () {
      final plan = planAiActions(
        const AiOrderActions(
          payment: AiPaymentAction(kind: 'full'),
          status: 'done',
        ),
        _order(status: 'canceled'),
      );
      expect(plan.hasSteps, isFalse);
      expect(_notices(plan), [AiActionNoticeKind.canceled]);
    });

    test('nothing to receive', () {
      final plan = planAiActions(_pay('full'), _order(remaining: 0));
      expect(plan.hasSteps, isFalse);
      expect(_notices(plan), [AiActionNoticeKind.nothingToReceive]);
    });

    test('pending checklist takes "pronta" out and keeps the rest', () {
      final plan = planAiActions(
        const AiOrderActions(
          payment: AiPaymentAction(kind: 'value', value: 300),
          status: 'done',
        ),
        _order(pendingChecklists: 1),
      );
      expect(plan.status, isNull);
      expect(plan.payment!.amount, 300);
      expect(_notices(plan), [AiActionNoticeKind.pendingChecklists]);
    });

    test('no permission for the status', () {
      final plan = planAiActions(
        const AiOrderActions(status: 'done'),
        _order(canChangeStatus: (_) => false),
      );
      expect(plan.hasSteps, isFalse);
      expect(_notices(plan), [AiActionNoticeKind.statusDenied]);
    });

    test('never goes back in the flow', () {
      final plan = planAiActions(
        const AiOrderActions(status: 'approved'),
        _order(status: 'done'),
      );
      expect(plan.hasSteps, isFalse);
      expect(plan.notices, isEmpty);
    });
  });

  group('quote', () {
    test('a payment approves first, in plain sight', () {
      final plan = planAiActions(_pay('value', 500), _order(status: 'quote'));
      expect(plan.approveFirst, isTrue);
      expect(plan.payment!.amount, 500);
      expect(plan.status, isNull);
    });

    test('"aprovou" together with a payment does not approve twice', () {
      final plan = planAiActions(
        const AiOrderActions(
          payment: AiPaymentAction(kind: 'full'),
          status: 'approved',
        ),
        _order(status: 'quote'),
      );
      expect(plan.approveFirst, isTrue);
      expect(plan.status, isNull);
    });

    test('who can receive but not approve: nothing goes in', () {
      final plan = planAiActions(
        _pay('full'),
        _order(status: 'quote', canChangeStatus: (_) => false),
      );
      expect(plan.hasSteps, isFalse);
      expect(_notices(plan), [AiActionNoticeKind.statusDenied]);
    });
  });

  group('automatic nota', () {
    test('"paid": warns when the payment closes the order', () {
      expect(
        planAiActions(_pay('full'), _order(nfse: 'paid')).issuesNfse,
        isTrue,
      );
      expect(
        planAiActions(_pay('value', 500), _order(nfse: 'paid')).issuesNfse,
        isFalse,
      );
    });

    test('"paid": a discount that closes it issues nothing', () {
      final plan = planAiActions(
        const AiOrderActions(
          discount: AiDiscountAction(isPercent: false, value: 800),
        ),
        _order(nfse: 'paid'),
      );
      expect(plan.issuesNfse, isFalse);
    });

    test('"completed": warns when the order becomes done', () {
      expect(
        planAiActions(
          const AiOrderActions(status: 'done'),
          _order(nfse: 'completed'),
        ).issuesNfse,
        isTrue,
      );
      expect(
        planAiActions(_pay('full'), _order(nfse: 'completed')).issuesNfse,
        isFalse,
      );
    });

    test('follows an edit on the card', () {
      final plan = planAiActions(
        _pay('full'),
        _order(nfse: 'paid'),
        edits: const AiActionsEdits(payment: 100),
      );
      expect(plan.issuesNfse, isFalse);
      expect(plan.payment!.settlesAll, isFalse);
    });
  });

  test('types never carry amounts', () {
    final plan = planAiActions(
      const AiOrderActions(
        payment: AiPaymentAction(kind: 'value', value: 300),
        status: 'done',
      ),
      _order(),
    );
    expect(plan.types, 'payment,status');
  });
}
