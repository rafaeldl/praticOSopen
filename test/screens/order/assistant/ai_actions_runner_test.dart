import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/screens/order/assistant/ai_actions_plan.dart';
import 'package:praticos/screens/order/assistant/ai_actions_runner.dart';

/// OrderStore creates Firestore/Storage services in its fields.
class _FirebaseCoreMockWithBucket extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [
    CoreInitializeResponse(
      name: defaultFirebaseAppName,
      options: CoreFirebaseOptions(
        apiKey: '123',
        projectId: '123',
        appId: '123',
        messagingSenderId: '123',
        storageBucket: 'test.appspot.com',
      ),
      pluginConstants: {},
    ),
  ];
}

class MoneyStore extends OrderStore {
  MoneyStore({double total = 800, this.failPayment = false, String? current}) {
    order = Order()..status = current ?? 'approved';
    status = current ?? 'approved';
    this.total = total;
    paidAmount = 0;
  }

  final bool failPayment;
  bool failRemove = false;
  final List<String> calls = [];
  int _ids = 0;

  void _add(PaymentTransaction tx, double amount) {
    tx.id = 't${++_ids}';
    transactions.add(tx);
    paidAmount = (paidAmount ?? 0) + amount;
  }

  @override
  Future<bool> addDiscountTransaction(
    double amount, {
    String? description,
  }) async {
    calls.add('discount $amount');
    total = total! - amount;
    transactions.add(
      PaymentTransaction.discount(amount: amount)..id = 't${++_ids}',
    );
    return true;
  }

  @override
  Future<PaymentTransaction?> addPayment(
    double amount, {
    String? description,
    DateTime? paidAt,
    String? paymentMethod,
  }) async {
    calls.add('payment $amount $paymentMethod');
    if (failPayment) return null;
    final tx = PaymentTransaction.payment(amount: amount);
    _add(tx, amount);
    return tx;
  }

  @override
  // ignore: type_annotate_public_apis
  setStatus(String? status) {
    calls.add('status $status');
    this.status = status;
    order!.status = status;
  }

  @override
  Future<bool> removeTransaction(int index) async {
    calls.add('remove ${transactions[index].id}');
    if (failRemove) return false;
    transactions.removeAt(index);
    return true;
  }
}

AiPaymentStep _payment(double? amount, {bool all = false, String? method}) =>
    AiPaymentStep(
      amount: amount,
      max: 800,
      method: method,
      paidDay: null,
      settlesAll: all,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  test('runs discount, approval, payment and status, in that order', () async {
    final store = MoneyStore(current: 'quote');
    final outcome = await runAiActions(
      store,
      AiActionsPlan(
        total: 800,
        discount: 100,
        approveFirst: true,
        payment: _payment(300, method: 'pix'),
        status: 'done',
      ),
    );
    expect(store.calls, [
      'discount 100.0',
      'status approved',
      'payment 300.0 pix',
      'status done',
    ]);
    expect(outcome.failedStep, isNull);
    expect(outcome.statusBefore, 'quote');
    expect(outcome.statusAfter, 'done');
    expect(outcome.payment, 300);
  });

  test('"pagou tudo" takes the balance of the moment it saves', () async {
    final store = MoneyStore(total: 950);
    await runAiActions(
      store,
      AiActionsPlan(total: 800, payment: _payment(800, all: true)),
    );
    expect(store.calls, ['payment 950.0 null']);
  });

  test('never above the balance, even if it went down meanwhile', () async {
    final store = MoneyStore(total: 200);
    final outcome = await runAiActions(
      store,
      AiActionsPlan(total: 800, payment: _payment(300)),
    );
    expect(outcome.payment, 200);
  });

  test('a failure stops the steps after it', () async {
    final store = MoneyStore(failPayment: true);
    final outcome = await runAiActions(
      store,
      AiActionsPlan(total: 800, payment: _payment(300), status: 'done'),
    );
    expect(store.calls, ['payment 300.0 null']);
    expect(outcome.failedStep, 'payment');
    expect(outcome.changedSomething, isFalse);
  });

  test('keeps what went in before the failure', () async {
    final store = MoneyStore(failPayment: true);
    final outcome = await runAiActions(
      store,
      AiActionsPlan(total: 800, discount: 100, payment: _payment(300)),
    );
    expect(outcome.discount, 100);
    expect(outcome.changedSomething, isTrue);
  });

  group('undo', () {
    Future<(MoneyStore, AiActionsOutcome)> ran() async {
      final store = MoneyStore(current: 'quote');
      final outcome = await runAiActions(
        store,
        AiActionsPlan(
          total: 800,
          discount: 100,
          approveFirst: true,
          payment: _payment(300),
        ),
      );
      store.calls.clear();
      return (store, outcome);
    }

    test('last step first, and the status goes back', () async {
      final (store, outcome) = await ran();
      final result = await undoAiActions(
        store,
        outcome,
        canChangeStatus: (_) => true,
      );
      expect(result.ok, isTrue);
      expect(result.statusKept, isFalse);
      expect(store.calls, ['remove t2', 'status quote', 'remove t1']);
    });

    test('no permission: the status stays and it says so', () async {
      final (store, outcome) = await ran();
      final result = await undoAiActions(
        store,
        outcome,
        canChangeStatus: (_) => false,
      );
      expect(result.ok, isTrue);
      expect(result.statusKept, isTrue);
      expect(store.status, 'approved');
    });

    test('offline: stops, and a new try picks up from there', () async {
      final (store, outcome) = await ran();
      store.failRemove = true;
      final first = await undoAiActions(
        store,
        outcome,
        canChangeStatus: (_) => true,
      );
      expect(first.ok, isFalse);
      expect(store.status, 'approved');

      store.failRemove = false;
      final second = await undoAiActions(
        store,
        outcome,
        canChangeStatus: (_) => true,
      );
      expect(second.ok, isTrue);
      expect(store.status, 'quote');
      expect(store.transactions, isEmpty);
    });
  });
}
