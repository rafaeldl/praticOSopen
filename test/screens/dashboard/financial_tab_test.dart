import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/financial_tab_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/screens/dashboard/financial_tab.dart';
import 'package:praticos/screens/payments/send_charge_flow.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/utils/financial_summary.dart';
import 'package:praticos/utils/next_charge.dart';
import 'package:shared_preferences/shared_preferences.dart';

Order _order(
  String id,
  int number, {
  required String customer,
  required double total,
  double paid = 0,
  required DateTime createdAt,
  String? payment,
  String status = 'done',
}) {
  return Order()
    ..id = id
    ..number = number
    ..total = total
    ..paidAmount = paid
    ..payment = payment ?? (paid >= total ? 'paid' : 'unpaid')
    ..status = status
    ..createdAt = createdAt
    ..updatedAt = createdAt
    ..customer = (CustomerAggr()
      ..id = customer
      ..name = customer);
}

void main() {
  final now = DateTime(2026, 10, 15);

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await initializeDateFormatting('en_US');
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  FinancialTabStore storeWith({
    List<Order> month = const [],
    List<Order> open = const [],
    Future<List<Order?>> Function()? openLoader,
    List<int>? monthCalls,
    Set<String> withLink = const {},
  }) {
    return FinancialTabStore(
      clock: () => now,
      monthLoader: (offset) async {
        monthCalls?.add(offset);
        return month;
      },
      paidLoader: (_) async => [],
      openLoader: openLoader ?? () async => open,
      openChargeChecker: (debtor) async => withLink.contains(debtor.key),
      snoozes: NextChargeSnoozes(companyId: () => 'c1', clock: () => now),
    );
  }

  Future<void> pumpTab(
    WidgetTester tester,
    FinancialTabStore store, {
    String locale = 'pt',
    Brightness brightness = Brightness.light,
    List<Order>? opened,
    List<Order>? screens,
    List<Order>? charged,
    List<bool>? reports,
    List<Debtor>? received,
    bool settle = true,
  }) async {
    FormatService().setLocale(locale);
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CupertinoApp(
        locale: Locale(locale),
        theme: CupertinoThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FinancialTab(
          store: store,
          onOpenOrder: (_, order) => opened?.add(order),
          onOpenOrderScreen: (_, order) => screens?.add(order),
          onSendCharge: (_, order) => charged?.add(order),
          onOpenReport: (_, {required customPeriod}) =>
              reports?.add(customPeriod),
          onReceiveFromCustomer: (_, debtor) async {
            received?.add(debtor);
            return true;
          },
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  // Completed orders. Ana owes 1.250 (OS 183, since 02/10), Bia 480 across two
  // orders, Caio 0 → not listed. Paid this month: OS 186.
  final ana = _order(
    'a1',
    183,
    customer: 'Ana',
    total: 1250,
    createdAt: DateTime(2026, 10, 2),
  );
  final bia1 = _order(
    'b1',
    190,
    customer: 'Bia',
    total: 300,
    createdAt: DateTime(2026, 10, 9),
  );
  final bia2 = _order(
    'b2',
    191,
    customer: 'Bia',
    total: 180,
    createdAt: DateTime(2026, 10, 5),
  );
  final paid = _order(
    'p1',
    186,
    customer: 'Caio',
    total: 8300,
    paid: 8300,
    createdAt: DateTime(2026, 10, 8),
  );

  String money(double value) => FormatService().formatCurrency(value);

  Future<void> openReceivable(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('financialReceivable')));
    await tester.pumpAndSettle();
  }

  Future<void> openNextCharge(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('financialNextCharge')));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the five values and nothing of the old screen', (
    tester,
  ) async {
    final running = _order(
      'r1',
      200,
      customer: 'Dora',
      total: 700,
      paid: 100,
      status: 'progress',
      createdAt: DateTime(2026, 10, 3),
    );
    final canceled = _order(
      'c1',
      201,
      customer: 'Eva',
      total: 9000,
      status: 'canceled',
      createdAt: DateTime(2026, 10, 4),
    );
    await pumpTab(
      tester,
      storeWith(
        month: [paid, ana, running, canceled],
        open: [ana, bia1, bia2, running],
      ),
    );

    expect(find.text('Financeiro'), findsWidgets);
    expect(find.text('Outubro de 2026'), findsOneWidget);
    expect(find.text('Recebido'), findsOneWidget);
    expect(find.text(money(8400)), findsOneWidget); // 8.300 + entrada de 100
    expect(find.text('Vendido'), findsOneWidget);
    expect(find.text(money(10250)), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('A receber'), findsOneWidget);
    expect(find.text(money(1730)), findsOneWidget);
    expect(find.text('Em andamento'), findsOneWidget);
    expect(find.text(money(600)), findsOneWidget);
    expect(find.text('Próxima cobrança'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);

    expect(find.text('Quem deve'), findsNothing);
    expect(find.textContaining('Falta receber'), findsNothing);
    expect(find.text('Bia'), findsNothing); // the list moved to A receber
    expect(find.textContaining(' OS'), findsNothing); // no counts
    expect(find.byKey(const Key('financialSendCharge')), findsNothing);
  });

  testWidgets('month blocks stack at accessibility text sizes', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpTab(tester, storeWith(open: [ana], month: [paid]));

    final received = tester.getTopLeft(find.text('Recebido'));
    final sold = tester.getTopLeft(find.text('Vendido'));
    expect(sold.dy, greaterThan(received.dy));
    expect(sold.dx, received.dx);
    expect(tester.takeException(), isNull);
  });

  testWidgets('month blocks stay side by side at the default size', (
    tester,
  ) async {
    await pumpTab(tester, storeWith(open: [ana], month: [paid]));

    final received = tester.getTopLeft(find.text('Recebido'));
    final sold = tester.getTopLeft(find.text('Vendido'));
    expect(sold.dy, received.dy);
    expect(sold.dx, greaterThan(received.dx));
  });

  testWidgets('a month with no orders keeps Hoje on screen', (tester) async {
    final old = _order(
      'o',
      7,
      customer: 'Ana',
      total: 90,
      createdAt: DateTime(2026, 7, 1),
    );
    await pumpTab(tester, storeWith(open: [old]));

    expect(find.textContaining('Nenhuma OS'), findsNothing);
    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text(money(90)), findsWidgets);
    expect(find.text(money(0)), findsWidgets);
  });

  testWidgets('with no orders at all there is still the screen, without '
      'Próxima cobrança', (tester) async {
    await pumpTab(tester, storeWith());

    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('Vendido'), findsOneWidget);
    expect(find.text('Próxima cobrança'), findsNothing);
  });

  testWidgets('A receber: subtitle and rows; running orders stay out', (
    tester,
  ) async {
    final running = _order(
      'r1',
      200,
      customer: 'Dora',
      total: 700,
      status: 'progress',
      createdAt: DateTime(2026, 10, 3),
    );
    await pumpTab(tester, storeWith(open: [bia1, bia2, ana, running]));

    await openReceivable(tester);

    expect(find.text('A receber'), findsWidgets);
    expect(find.text('${money(1730)} de 2 clientes'), findsOneWidget);
    expect(find.text('desde 02/10'), findsOneWidget);
    expect(find.text('desde 05/10'), findsOneWidget);
    expect(find.text('Dora'), findsNothing);

    // Oldest first: Ana 02/10 before Bia 05/10.
    final ya = tester.getTopLeft(find.byKey(const ValueKey('debtor-Ana'))).dy;
    final yb = tester.getTopLeft(find.byKey(const ValueKey('debtor-Bia'))).dy;
    expect(ya, lessThan(yb));
  });

  testWidgets('A receber with nobody shows the empty state', (tester) async {
    await pumpTab(tester, storeWith());

    await openReceivable(tester);
    expect(find.text('Ninguém com valor a receber.'), findsOneWidget);
  });

  testWidgets('a debtor with one order opens it', (tester) async {
    final opened = <Order>[];
    await pumpTab(tester, storeWith(open: [ana]), opened: opened);

    await openReceivable(tester);
    await tester.tap(find.byKey(const ValueKey('debtor-Ana')));
    await tester.pump();
    expect(opened.single.id, 'a1');
  });

  testWidgets('a customer with several orders opens "Receber de Bia", '
      'oldest order first (no "Qual OS?")', (tester) async {
    final opened = <Order>[];
    final received = <Debtor>[];
    await pumpTab(
      tester,
      storeWith(open: [bia1, bia2]),
      opened: opened,
      received: received,
    );

    await openReceivable(tester);
    await tester.tap(find.byKey(const ValueKey('debtor-Bia')));
    await tester.pumpAndSettle();

    expect(find.text('Qual OS?'), findsNothing);
    expect(opened, isEmpty);
    expect(received.single.name, 'Bia');
    expect(received.single.orders.map((o) => o.id), ['b2', 'b1']);
  });

  testWidgets('receiving also offers the customer\'s running orders', (
    tester,
  ) async {
    final opened = <Order>[];
    final received = <Debtor>[];
    final running = _order(
      'r1',
      200,
      customer: 'Ana',
      total: 700,
      status: 'progress',
      createdAt: DateTime(2026, 10, 3),
    );
    await pumpTab(
      tester,
      storeWith(open: [ana, running]),
      opened: opened,
      received: received,
    );

    await openReceivable(tester);
    await tester.tap(find.byKey(const ValueKey('debtor-Ana')));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(received.single.openOrders.map((o) => o.id), ['a1', 'r1']);
  });

  testWidgets('orders without a customer still ask which one', (tester) async {
    final opened = <Order>[];
    final received = <Debtor>[];
    final x1 = _order(
      'x1',
      300,
      customer: 'X',
      total: 100,
      createdAt: DateTime(2026, 10, 3),
    )..customer = null;
    final x2 = _order(
      'x2',
      301,
      customer: 'X',
      total: 50,
      createdAt: DateTime(2026, 10, 4),
    )..customer = null;
    await pumpTab(
      tester,
      storeWith(open: [x1, x2]),
      opened: opened,
      received: received,
    );

    await openReceivable(tester);
    expect(find.text('Cliente sem nome'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('debtor-${Debtor.noCustomerKey}')),
    );
    await tester.pumpAndSettle();

    // The "Escolher" screen: question as the title.
    expect(find.text('Qual OS?'), findsWidgets);
    expect(find.byType(CupertinoActionSheet), findsNothing);
    await tester.tap(find.textContaining('OS 301'));
    await tester.pumpAndSettle();
    expect(opened.single.id, 'x2');
    expect(received, isEmpty);
  });

  testWidgets('Em andamento lists the balance of each order and opens it', (
    tester,
  ) async {
    final screens = <Order>[];
    final approved = _order(
      'r1',
      200,
      customer: 'Dora',
      total: 700,
      paid: 100,
      status: 'approved',
      createdAt: DateTime(2026, 10, 3),
    );
    final progress = _order(
      'r2',
      201,
      customer: 'Eva',
      total: 300,
      status: 'progress',
      createdAt: DateTime(2026, 10, 1),
    );
    await pumpTab(
      tester,
      storeWith(open: [approved, progress, ana]),
      screens: screens,
    );

    await tester.tap(find.byKey(const ValueKey('financialInProgress')));
    await tester.pumpAndSettle();

    expect(find.text('${money(900)} em 2 OS'), findsOneWidget);
    expect(find.text('OS 200 · desde 03/10'), findsOneWidget);
    expect(find.text(money(600)), findsOneWidget); // balance, not the total
    expect(find.text('Ana'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('order-r1')));
    await tester.pump();
    expect(screens.single.id, 'r1');
  });

  testWidgets('Vendido lists the orders opened in the month and opens them', (
    tester,
  ) async {
    final screens = <Order>[];
    await pumpTab(tester, storeWith(month: [paid, ana]), screens: screens);

    await tester.tap(find.byKey(const ValueKey('financialSold')));
    await tester.pumpAndSettle();

    expect(
      find.text('Outubro de 2026 · ${money(9550)}'),
      findsOneWidget,
    );
    expect(find.text('OS 183 · 02/10'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('order-p1')));
    await tester.pump();
    expect(screens.single.id, 'p1');
  });

  testWidgets('Recebido opens the report', (tester) async {
    final reports = <bool>[];
    await pumpTab(tester, storeWith(open: [ana]), reports: reports);

    await tester.tap(find.byKey(const ValueKey('financialReceived')));
    expect(reports, [false]);
  });

  group('Próxima cobrança', () {
    testWidgets('the sheet says who owes and sends the charge', (tester) async {
      final charged = <Order>[];
      await pumpTab(tester, storeWith(open: [ana]), charged: charged);

      await openNextCharge(tester);

      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(
        find.text('Ana deve ${money(1250)} desde 02/10'),
        findsOneWidget,
      );
      expect(find.text('Agora não'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      await tester.tap(find.byKey(const Key('financialSendCharge')));
      await tester.pumpAndSettle();
      expect(charged.single.id, 'a1');
    });

    testWidgets('several orders: asks which one before charging', (
      tester,
    ) async {
      final charged = <Order>[];
      await pumpTab(tester, storeWith(open: [bia1, bia2]), charged: charged);

      await openNextCharge(tester);
      await tester.tap(find.byKey(const Key('financialSendCharge')));
      await tester.pumpAndSettle();

      expect(find.text('Qual OS?'), findsWidgets);
      expect(charged, isEmpty);
      await tester.tap(find.textContaining('OS 190'));
      await tester.pumpAndSettle();
      expect(charged.single.id, 'b1');
    });

    testWidgets('"Qual OS?" does not offer orders that are still running', (
      tester,
    ) async {
      final charged = <Order>[];
      final running = _order(
        'r1',
        200,
        customer: 'Bia',
        total: 700,
        status: 'progress',
        createdAt: DateTime(2026, 10, 1),
      );
      await pumpTab(
        tester,
        storeWith(open: [bia1, bia2, running]),
        charged: charged,
      );

      await openNextCharge(tester);
      await tester.tap(find.byKey(const Key('financialSendCharge')));
      await tester.pumpAndSettle();

      expect(find.textContaining('OS 200'), findsNothing);
      expect(find.textContaining('OS 190'), findsOneWidget);
    });

    testWidgets('"Agora não" moves on; the customer stays in A receber', (
      tester,
    ) async {
      await pumpTab(tester, storeWith(open: [ana, bia1]));

      await openNextCharge(tester);
      await tester.tap(find.byKey(const Key('financialNotNow')));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.text('Ana'), findsNothing);
      expect(find.text('Bia'), findsOneWidget);
      expect(find.text(money(1550)), findsOneWidget);

      await openReceivable(tester);
      expect(find.byKey(const ValueKey('debtor-Ana')), findsOneWidget);
    });

    testWidgets('Cancelar changes nothing', (tester) async {
      final charged = <Order>[];
      await pumpTab(tester, storeWith(open: [ana]), charged: charged);

      await openNextCharge(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(charged, isEmpty);
      expect(find.text('Ana'), findsOneWidget);
    });

    testWidgets('no candidates: the section goes away', (tester) async {
      await pumpTab(tester, storeWith(open: [ana], withLink: {'Ana'}));

      expect(find.text('Próxima cobrança'), findsNothing);
      expect(find.text(money(1250)), findsOneWidget);
    });
  });

  testWidgets('loading shows an indicator under the title and month', (
    tester,
  ) async {
    final completer = Completer<List<Order?>>();
    await pumpTab(
      tester,
      storeWith(openLoader: () => completer.future),
      settle: false,
    );

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text('Outubro de 2026'), findsOneWidget);
    expect(find.text('Hoje'), findsNothing);

    completer.complete([]);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets('error shows a fixed message and retries', (tester) async {
    var fail = true;
    final store = storeWith(
      openLoader: () async {
        if (fail) throw Exception('boom Exception: details');
        return [];
      },
    );
    await pumpTab(tester, store);

    expect(find.text('Não deu para carregar o financeiro.'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing); // no raw exception text

    fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Hoje'), findsOneWidget);
  });

  testWidgets('stepping to the previous month reloads; next is disabled on '
      'the current month', (tester) async {
    final calls = <int>[];
    final store = storeWith(monthCalls: calls, open: [ana]);
    await pumpTab(tester, store);

    // Next month is disabled on the current month: tapping does nothing.
    await tester.tap(find.bySemanticsLabel('Próximo mês'), warnIfMissed: false);
    await tester.pump();
    expect(calls, [0]);

    await tester.tap(find.bySemanticsLabel('Mês anterior'));
    await tester.pumpAndSettle();

    expect(calls, [0, -1]);
    expect(find.text('Setembro de 2026'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text(money(1250)), findsWidgets);

    // Tapping the label goes back to the current month.
    await tester.tap(find.text('Setembro de 2026'));
    await tester.pumpAndSettle();
    expect(calls, [0, -1, 0]);
    expect(find.text('Outubro de 2026'), findsOneWidget);
  });

  testWidgets('"…" opens the report and the period picker', (tester) async {
    final reports = <bool>[];
    await pumpTab(tester, storeWith(open: [ana]), reports: reports);

    await tester.tap(find.byKey(const Key('financialMore')));
    await tester.pumpAndSettle();
    expect(find.text('Outro período'), findsOneWidget);
    await tester.tap(find.text('Outro período'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('financialMore')));
    await tester.pumpAndSettle();
    // Pull-down menu (no action sheet, no "Cancelar").
    expect(find.byType(CupertinoActionSheet), findsNothing);
    expect(find.text('Cancelar'), findsNothing);
    await tester.tap(find.text('Relatório'));
    await tester.pumpAndSettle();

    expect(reports, [true, false]);
  });

  testWidgets('dates from other years show the year', (tester) async {
    final old = _order(
      'o1',
      90,
      customer: 'Dora',
      total: 500,
      createdAt: DateTime(2025, 10, 24),
    );
    await pumpTab(tester, storeWith(open: [old, ana]));

    await openReceivable(tester);
    expect(find.text('desde 24/10/2025'), findsOneWidget);
    expect(find.text('desde 02/10'), findsOneWidget);
  });

  testWidgets('english: no Portuguese text and US date format', (tester) async {
    await pumpTab(tester, storeWith(open: [ana], month: [paid]), locale: 'en');

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('To receive'), findsOneWidget);
    expect(find.text('Sold'), findsOneWidget);
    expect(find.text('Next charge'), findsOneWidget);
    expect(find.textContaining('Falta'), findsNothing);

    await openReceivable(tester);
    expect(find.text('since 10/2'), findsOneWidget);
  });

  testWidgets('renders in dark mode without exceptions', (tester) async {
    await pumpTab(
      tester,
      storeWith(open: [ana], month: [paid]),
      brightness: Brightness.dark,
    );

    expect(find.text('Próxima cobrança'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '"Mandar cobrança" with Asaas: creates the charge, then shares, once',
    (tester) async {
      FormatService().setLocale('pt');
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final calls = <String>[];
      final createGate = Completer<OrderCharge?>();
      final flow = SendChargeFlow(
        canCharge: true,
        settingsLoader: () async =>
            PaymentSettings(asaasEnabled: true, asaasConnected: true),
        openChargeLoader: (_) async => null,
        createCharge: (_, order, remaining) {
          calls.add('create:${order.id}:$remaining');
          return createGate.future;
        },
        share: (_, order) async => calls.add('share:${order.id}'),
      );

      await tester.pumpWidget(
        CupertinoApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FinancialTab(
            store: storeWith(open: [ana]),
            sendChargeFlow: flow,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openNextCharge(tester);
      await tester.tap(find.byKey(const Key('financialSendCharge')));
      await tester.pumpAndSettle();
      // A second tap while the charge screen is open opens nothing.
      await tester.tap(find.byKey(const ValueKey('financialNextCharge')));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(calls, ['create:a1:1250.0']);

      createGate.complete(OrderCharge(id: 'ch1', status: ChargeStatus.pending));
      await tester.pumpAndSettle();
      expect(calls, ['create:a1:1250.0', 'share:a1']);
    },
  );
}
