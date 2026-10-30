import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/financial_tab_store.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/dashboard/financial_tab.dart';
import 'package:praticos/services/format_service.dart';

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
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('tapping a debtor opens "Receber" of the order, not the order '
      '(prototype: app-financeiro → app-receber)', (tester) async {
    FormatService().setLocale('pt');
    final order = Order()
      ..number = 183
      ..total = 1250
      ..paidAmount = 0
      ..payment = 'unpaid'
      ..status = 'approved'
      ..createdAt = DateTime(2026, 10, 2)
      ..customer = (CustomerAggr()
        ..id = 'Ana'
        ..name = 'Ana');
    final store = FinancialTabStore(
      clock: () => DateTime(2026, 10, 15),
      monthLoader: (_) async => [],
      paidLoader: (_) async => [],
      openLoader: () async => [order],
    );
    Object? args;
    String? route;

    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FinancialTab(store: store),
        onGenerateRoute: (settings) {
          route = settings.name;
          args = settings.arguments;
          return CupertinoPageRoute<void>(builder: (_) => const SizedBox());
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('debtor-Ana')));
    await tester.pump();

    expect(route, '/payment_management');
    final orderStore = (args as Map)['orderStore'] as OrderStore;
    expect(orderStore.order!.number, 183);
    Global.companyAggr = null;
  });
}
