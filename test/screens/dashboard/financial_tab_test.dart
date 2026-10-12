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

Order _order(
  String id,
  int number, {
  required String customer,
  required double total,
  double paid = 0,
  required DateTime createdAt,
  String? payment,
}) {
  return Order()
    ..id = id
    ..number = number
    ..total = total
    ..paidAmount = paid
    ..payment = payment ?? (paid >= total ? 'paid' : 'unpaid')
    ..status = 'approved'
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

  FinancialTabStore storeWith({
    List<Order> month = const [],
    List<Order> open = const [],
    Future<List<Order?>> Function()? openLoader,
    List<int>? monthCalls,
  }) {
    return FinancialTabStore(
      clock: () => now,
      monthLoader: (offset) async {
        monthCalls?.add(offset);
        return month;
      },
      openLoader: openLoader ?? () async => open,
    );
  }

  Future<void> pumpTab(
    WidgetTester tester,
    FinancialTabStore store, {
    String locale = 'pt',
    Brightness brightness = Brightness.light,
    List<Order>? opened,
    List<Order>? charged,
    List<bool>? reports,
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
          onSendCharge: (_, order) => charged?.add(order),
          onOpenReport: (_, {required customPeriod}) =>
              reports?.add(customPeriod),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  // Ana owes 1.250 (OS 183, since 02/10), Bia 480 across two orders,
  // Caio 0 → not listed. Paid this month: OS 186.
  final ana = _order('a1', 183, customer: 'Ana', total: 1250, createdAt: DateTime(2026, 10, 2));
  final bia1 = _order('b1', 190, customer: 'Bia', total: 300, createdAt: DateTime(2026, 10, 9));
  final bia2 = _order('b2', 191, customer: 'Bia', total: 180, createdAt: DateTime(2026, 10, 5));
  final paid = _order('p1', 186, customer: 'Caio', total: 8300, paid: 8300, createdAt: DateTime(2026, 10, 8));

  testWidgets('shows the title, month stepper, next step and both lists',
      (tester) async {
    await pumpTab(tester, storeWith(month: [paid, ana], open: [ana, bia1, bia2]));

    expect(find.text('Financeiro'), findsWidgets);
    expect(find.text('outubro de 2026'), findsOneWidget);
    expect(
      find.text('Falta receber ${FormatService().formatCurrency(1730)} de 2 clientes'),
      findsOneWidget,
    );
    expect(find.textContaining('Ana deve há mais tempo'), findsOneWidget);
    expect(find.text('Mandar cobrança para Ana'), findsOneWidget);
    expect(find.text('Falta receber'), findsOneWidget); // section label
    expect(find.text('OS 183 · desde 02/10'), findsOneWidget);
    expect(find.text('2 OS · desde 05/10'), findsOneWidget);
    // One "Recebido em <mês>" row (prototype), not the list of receipts.
    expect(find.text('Recebido em outubro'), findsOneWidget);
    expect(find.text(FormatService().formatCurrency(8300)), findsOneWidget);
    expect(find.text('1 OS · ver todas'), findsOneWidget);
    expect(find.text('OS 186 · pago 08/10'), findsNothing);
    expect(find.textContaining('Entrou'), findsNothing);

    // Debtors: oldest first (Ana 02/10 before Bia 05/10).
    final ya = tester.getTopLeft(find.text('Ana').first).dy;
    final yb = tester.getTopLeft(find.text('Bia')).dy;
    expect(ya, lessThan(yb));
  });

  testWidgets('"Mandar cobrança" sends the oldest open order of the oldest debtor',
      (tester) async {
    final charged = <Order>[];
    await pumpTab(
      tester,
      storeWith(open: [bia1, bia2, ana]),
      charged: charged,
    );

    await tester.tap(find.byKey(const Key('financialSendCharge')));
    expect(charged.single.id, 'a1');
  });

  testWidgets('with nothing owed there is no next step block', (tester) async {
    await pumpTab(tester, storeWith(month: [paid]));

    expect(find.byKey(const Key('financialSendCharge')), findsNothing);
    expect(find.text('Recebido em outubro'), findsOneWidget);
  });

  testWidgets('a debtor with one order opens it', (tester) async {
    final opened = <Order>[];
    await pumpTab(tester, storeWith(open: [ana]), opened: opened);

    await tester.tap(find.byKey(const ValueKey('debtor-Ana')));
    await tester.pump();
    expect(opened.single.id, 'a1');
  });

  testWidgets('a debtor with several orders asks which one', (tester) async {
    final opened = <Order>[];
    await pumpTab(tester, storeWith(open: [bia1, bia2]), opened: opened);

    await tester.tap(find.byKey(const ValueKey('debtor-Bia')));
    await tester.pumpAndSettle();

    expect(find.text('OS em aberto de Bia'), findsOneWidget);
    await tester.tap(find.textContaining('OS 190'));
    await tester.pumpAndSettle();
    expect(opened.single.id, 'b1');
  });

  testWidgets('shows 5 debtors and expands with "Ver todos"', (tester) async {
    final many = [
      for (var i = 1; i <= 7; i++)
        _order('d$i', i, customer: 'Cliente $i', total: 100.0 * i,
            createdAt: DateTime(2026, 10, i)),
    ];
    await pumpTab(tester, storeWith(open: many));

    expect(find.byKey(const ValueKey('debtor-Cliente 5')), findsOneWidget);
    expect(find.byKey(const ValueKey('debtor-Cliente 6')), findsNothing);

    await tester.tap(find.text('Ver todos (7)'));
    await tester.pump();
    expect(find.byKey(const ValueKey('debtor-Cliente 7')), findsOneWidget);
    expect(find.text('Ver menos'), findsOneWidget);
  });

  testWidgets('month without orders and no debt shows only the empty state',
      (tester) async {
    await pumpTab(tester, storeWith());

    expect(find.text('Nenhuma OS em outubro de 2026.'), findsOneWidget);
    expect(find.byKey(const Key('financialSendCharge')), findsNothing);
    expect(find.textContaining('Entrou'), findsNothing);
  });

  testWidgets('old debt still shows in an empty month', (tester) async {
    final old = _order('o', 7, customer: 'Ana', total: 90, createdAt: DateTime(2026, 7, 1));
    await pumpTab(tester, storeWith(open: [old]));

    expect(find.text('Nenhuma OS em outubro de 2026.'), findsNothing);
    expect(find.text('Mandar cobrança para Ana'), findsOneWidget);
    expect(find.textContaining('Recebido em'), findsOneWidget);
    expect(find.text('0 OS · ver todas'), findsOneWidget);
  });

  testWidgets('loading shows an indicator under the title and month',
      (tester) async {
    final completer = Completer<List<Order?>>();
    await pumpTab(tester, storeWith(openLoader: () => completer.future));

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text('outubro de 2026'), findsOneWidget);
    expect(find.textContaining('Entrou'), findsNothing);

    completer.complete([]);
    await tester.pump();
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets('error shows a fixed message and retries', (tester) async {
    var fail = true;
    final store = storeWith(openLoader: () async {
      if (fail) throw Exception('boom Exception: details');
      return [];
    });
    await pumpTab(tester, store);

    expect(find.text('Não deu para carregar o financeiro.'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing); // no raw exception text

    fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Nenhuma OS em outubro de 2026.'), findsOneWidget);
  });

  testWidgets('stepping to the previous month reloads; next is disabled on '
      'the current month', (tester) async {
    final calls = <int>[];
    final store = storeWith(monthCalls: calls);
    await pumpTab(tester, store);

    // Next month is disabled on the current month: tapping does nothing.
    await tester.tap(find.bySemanticsLabel('Próximo mês'), warnIfMissed: false);
    await tester.pump();
    expect(calls, [0]);

    await tester.tap(find.bySemanticsLabel('Mês anterior'));
    await tester.pump();
    await tester.pump();

    expect(calls, [0, -1]);
    expect(find.text('setembro de 2026'), findsOneWidget);
    expect(find.text('Nenhuma OS em setembro de 2026.'), findsOneWidget);

    // Tapping the label goes back to the current month.
    await tester.tap(find.text('setembro de 2026'));
    await tester.pump();
    await tester.pump();
    expect(calls, [0, -1, 0]);
    expect(find.text('outubro de 2026'), findsOneWidget);
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
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoActionSheet),
        matching: find.text('Relatório'),
      ),
    );
    await tester.pumpAndSettle();

    expect(reports, [true, false]);
  });

  testWidgets('the "Recebido em <mês>" row opens the report', (tester) async {
    final reports = <bool>[];
    await pumpTab(tester, storeWith(open: [ana]), reports: reports);

    await tester.tap(find.text('Recebido em outubro'));
    expect(reports, [false]);
  });

  testWidgets('dates from other years show the year', (tester) async {
    final old = _order('o1', 90, customer: 'Dora', total: 500, createdAt: DateTime(2025, 10, 24));
    final old2 = _order('o2', 91, customer: 'Dora', total: 100, createdAt: DateTime(2025, 11, 7));
    await pumpTab(tester, storeWith(open: [old, old2, ana]));

    expect(find.text('2 OS · desde 24/10/2025'), findsOneWidget);
    expect(find.text('OS 183 · desde 02/10'), findsOneWidget);
    expect(find.textContaining('Dora deve há mais tempo'), findsOneWidget);
    expect(find.textContaining('desde 24/10/2025'), findsWidgets);

    await tester.tap(find.text('Dora'));
    await tester.pumpAndSettle();
    expect(find.textContaining('07/11/2025'), findsOneWidget);
  });

  testWidgets('english: no Portuguese text and US date format', (tester) async {
    await pumpTab(
      tester,
      storeWith(open: [ana], month: [paid]),
      locale: 'en',
    );

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Order 183 · since 10/2'), findsOneWidget);
    expect(find.text('Received in October'), findsOneWidget);
    expect(find.text('1 orders · see all'), findsOneWidget);
    expect(find.text('Send payment request to Ana'), findsOneWidget);
    expect(find.textContaining('ordens'), findsNothing);
    expect(find.textContaining('Falta'), findsNothing);
  });

  testWidgets('renders in dark mode without exceptions', (tester) async {
    await pumpTab(
      tester,
      storeWith(open: [ana], month: [paid]),
      brightness: Brightness.dark,
    );

    expect(find.text('Mandar cobrança para Ana'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Mandar cobrança" with Asaas: creates the charge, then shares, once',
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
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('financialSendCharge')));
    await tester.pump();
    await tester.pump();
    // Second tap while the charge screen is open is ignored.
    await tester.tap(find.byKey(const Key('financialSendCharge')));
    await tester.pump();
    expect(calls, ['create:a1:1250.0']);

    createGate.complete(OrderCharge(id: 'ch1', status: ChargeStatus.pending));
    await tester.pump();
    await tester.pump();
    expect(calls, ['create:a1:1250.0', 'share:a1']);
    expect(find.text('Mandar cobrança para Ana'), findsOneWidget);
  });
}
