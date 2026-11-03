import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/utils/order_payment_math.dart';
import 'package:praticos/utils/payment_update_failure.dart';

/// Firebase core mock whose default app has a storage bucket.
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

Order _order({String? id = 'o1'}) => Order()
  ..id = id
  ..status = 'approved'
  ..services = [OrderService()..value = 100]
  ..products = []
  ..discount = 0
  ..total = 100
  ..paidAmount = 90
  ..paid = false
  ..payment = 'unpaid'
  ..transactions = [];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  setUp(() => Global.companyAggr = CompanyAggr()..id = 'c1');
  tearDown(() => Global.companyAggr = null);

  // Same as the API (PAYMENT_EXCEEDS_BALANCE): R$ 20 on R$ 10 left is
  // refused before anything is written or shown.
  for (final id in ['o1', null]) {
    test('a payment above the balance is refused (order id $id)', () async {
      final store = OrderStore()..order = _order(id: id);

      final tx = await store.addPayment(20);

      expect(tx, isNull);
      expect(store.lastPaymentFailure, PaymentUpdateFailure.exceedsBalance);
      expect(store.order!.paidAmount, 90);
      expect(store.order!.transactions, isEmpty);
    });
  }

  test('the refusal is classified for the message', () {
    expect(
      classifyPaymentUpdateFailure(const PaymentExceedsBalanceException(10)),
      PaymentUpdateFailure.exceedsBalance,
    );
  });
}
