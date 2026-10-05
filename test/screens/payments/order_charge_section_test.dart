import 'dart:async';

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
import 'package:praticos/screens/payments/widgets/order_charge_card.dart';
import 'package:praticos/screens/payments/widgets/order_charge_section.dart';

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

  OrderStore storeWith(String status) {
    final order = Order()
      ..id = 'o1'
      ..number = 42
      ..status = status
      ..total = 1000
      ..paidAmount = 400;
    return OrderStore()
      ..order = order
      ..status = status
      ..total = 1000
      ..paidAmount = 400;
  }

  Future<List<double>> pumpSection(
    WidgetTester tester, {
    String status = 'approved',
    bool canCharge = true,
    PaymentSettings? settings,
  }) async {
    final opened = <double>[];
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: ListView(
            children: [
              OrderChargeSection(
                store: storeWith(status),
                canCharge: canCharge,
                settingsStream: Stream.value(settings ??
                    PaymentSettings(asaasEnabled: true, asaasConnected: true)),
                chargesStream: Stream.value(const <OrderCharge>[]),
                onCreateCharge: opened.add,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return opened;
  }

  testWidgets('visível com permissão, Asaas habilitado e OS aprovada',
      (tester) async {
    final opened = await pumpSection(tester);

    expect(find.byType(OrderChargeCard), findsOneWidget);
    final card = tester.widget<OrderChargeCard>(find.byType(OrderChargeCard));
    expect(card.remainingBalance, 600);
    expect(card.canCreateCharge, isTrue);
    expect(card.onChargeSettled, isNotNull);

    await tester.tap(find.byKey(const Key('createChargeTile')));
    await tester.pumpAndSettle();
    expect(opened, [600]);
  });

  testWidgets('oculta sem a permissão chargeOrder', (tester) async {
    await pumpSection(tester, canCharge: false);

    expect(find.byType(OrderChargeCard, skipOffstage: false), findsNothing);
  });

  testWidgets('oculta quando asaasEnabled é false', (tester) async {
    await pumpSection(tester,
        settings: PaymentSettings(asaasEnabled: false, asaasConnected: true));

    expect(find.byType(OrderChargeCard, skipOffstage: false), findsNothing);
  });

  testWidgets('erro no stream de configurações oculta a seção',
      (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OrderChargeSection(
          store: storeWith('approved'),
          canCharge: true,
          settingsStream: Stream.error(Exception('permission-denied')),
          chargesStream: Stream.value(const <OrderCharge>[]),
          onCreateCharge: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OrderChargeCard, skipOffstage: false), findsNothing);
  });

  testWidgets('oculta para orçamento', (tester) async {
    await pumpSection(tester, status: 'quote');

    expect(find.byType(OrderChargeCard, skipOffstage: false), findsNothing);
  });

  testWidgets('oculta para OS cancelada', (tester) async {
    await pumpSection(tester, status: 'canceled');

    expect(find.byType(OrderChargeCard, skipOffstage: false), findsNothing);
  });

  testWidgets('desconectado: card sem o botão Cobrar', (tester) async {
    await pumpSection(tester,
        settings: PaymentSettings(asaasEnabled: true, asaasConnected: false));

    // Without a charge the card renders nothing (zero-size, offstage).
    final card = tester.widget<OrderChargeCard>(
        find.byType(OrderChargeCard, skipOffstage: false));
    expect(card.canCreateCharge, isFalse);
    expect(find.byKey(const Key('createChargeTile')), findsNothing);
  });

  group('recarga dos pagamentos ao abrir', () {
    Future<int> pumpWithSettings(
      WidgetTester tester,
      Stream<PaymentSettings> settings, {
      String status = 'approved',
      bool canCharge = true,
    }) async {
      var reloads = 0;
      final store = storeWith(status)
        ..fetchOrderFromServer = (companyId, orderId) async {
          reloads++;
          return null;
        };
      await tester.pumpWidget(
        CupertinoApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CupertinoPageScaffold(
            child: ListView(
              children: [
                OrderChargeSection(
                  store: store,
                  canCharge: canCharge,
                  settingsStream: settings,
                  chargesStream: Stream.value(const <OrderCharge>[]),
                  onCreateCharge: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return reloads;
    }

    testWidgets('recarrega uma vez na primeira emissão com Asaas habilitado',
        (tester) async {
      final reloads = await pumpWithSettings(
        tester,
        Stream.fromIterable([
          PaymentSettings(asaasEnabled: true, asaasConnected: true),
          PaymentSettings(asaasEnabled: true, asaasConnected: false),
          PaymentSettings(asaasEnabled: true, asaasConnected: true),
        ]),
      );

      expect(reloads, 1);
    });

    testWidgets('não recarrega quando asaasEnabled é false', (tester) async {
      final reloads = await pumpWithSettings(
        tester,
        Stream.value(PaymentSettings(asaasEnabled: false)),
      );

      expect(reloads, 0);
    });

    testWidgets('não recarrega sem a permissão chargeOrder', (tester) async {
      final reloads = await pumpWithSettings(
        tester,
        Stream.value(PaymentSettings(asaasEnabled: true)),
        canCharge: false,
      );

      expect(reloads, 0);
    });

    testWidgets('não recarrega para orçamento', (tester) async {
      final reloads = await pumpWithSettings(
        tester,
        Stream.value(PaymentSettings(asaasEnabled: true)),
        status: 'quote',
      );

      expect(reloads, 0);
    });
  });

  testWidgets('checagem padrão: sem papel com chargeOrder, oculta',
      (tester) async {
    // No logged user → AuthorizationService denies chargeOrder.
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OrderChargeSection(
          store: storeWith('approved'),
          settingsStream: Stream.value(
              PaymentSettings(asaasEnabled: true, asaasConnected: true)),
          chargesStream: Stream.value(const <OrderCharge>[]),
          onCreateCharge: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OrderChargeCard, skipOffstage: false), findsNothing);
  });
}
