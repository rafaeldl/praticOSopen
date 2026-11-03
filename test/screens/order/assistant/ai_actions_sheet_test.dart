import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/screens/order/assistant/ai_actions_plan.dart';
import 'package:praticos/screens/order/assistant/ai_actions_sheet.dart';
import 'package:praticos/screens/payments/widgets/order_charge_section.dart';
import 'package:praticos/services/ai_order_assist_service.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // OrderStore creates Firestore/Storage repositories in its fields.
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  setUp(() => Global.companyAggr = CompanyAggr()..id = 'c1');
  tearDown(() => Global.companyAggr = null);

  Future<void> pumpSheet(
    WidgetTester tester,
    Stream<List<OrderCharge>> charges,
  ) async {
    final store = OrderStore()
      ..order = (Order()
        ..id = 'o1'
        ..status = 'approved'
        ..total = 800)
      ..status = 'approved'
      ..total = 800;
    final controller = OrderChargeController(
      store: store,
      canCharge: true,
      settingsStream: Stream.value(
        PaymentSettings(asaasEnabled: true, asaasConnected: true),
      ),
      chargesStream: charges,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiActionsSheet(
          actions: const AiOrderActions(payment: AiPaymentAction(kind: 'full')),
          order: AiActionsContext(
            status: 'approved',
            total: 800,
            remaining: 800,
            showMoney: true,
            canReceive: true,
            canDiscount: true,
            canChangeStatus: (_) => true,
          ),
          subtitle: 'OS 1 · Revenda Sul',
          statusLabel: (status) => status,
          store: store,
          customerName: 'Revenda Sul',
          charges: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('charges unreadable: warns a link may be open', (tester) async {
    await pumpSheet(tester, Stream.error(Exception('permission-denied')));
    expect(find.textContaining('Pode haver um link'), findsOneWidget);
  });

  testWidgets('no charge: no link warning', (tester) async {
    await pumpSheet(tester, Stream.value(const <OrderCharge>[]));
    expect(find.textContaining('Pode haver um link'), findsNothing);
  });
}
