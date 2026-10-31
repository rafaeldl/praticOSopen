import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/order/new_order_form.dart';
import 'package:praticos/screens/payments/receive_customer_screen.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/services/customer_receipt_service.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/utils/financial_summary.dart';
import 'package:praticos/widgets/permission_widgets.dart';

class _FakeService extends CustomerReceiptService {
  _FakeService({this.fail, this.fresh});

  final CustomerReceiptFailure? fail;

  /// What the server has now; null = offline (the receipt goes on).
  final Map<String, Order>? fresh;
  final requests = <CustomerReceiptRequest>[];
  final freshReads = <List<String>>[];

  @override
  Future<Map<String, Order>?> readFromServer(Iterable<String> orderIds) async {
    freshReads.add(orderIds.toList());
    return fresh;
  }

  @override
  Future<Receipt> record(CustomerReceiptRequest request) async {
    requests.add(request);
    if (fail != null) throw CustomerReceiptException(fail!);
    return Receipt();
  }
}

Order _order(String id, int number, double total, {double paid = 0}) => Order()
  ..id = id
  ..number = number
  ..total = total
  ..paidAmount = paid;

final _customer = CustomerAggr()
  ..id = 'c1'
  ..name = 'João';

List<Order> _orders() => [
  _order('a', 182, 450),
  _order('b', 190, 600, paid: 100),
  _order('c', 201, 300),
];

void main() {
  setUp(() => FormatService().setLocale('pt-BR'));

  Future<_FakeService> pump(
    WidgetTester tester, {
    _FakeService? service,
    List<Order>? orders,
    String? name,
    List<bool>? popped,
    List<Object?>? openedOrders,
    Future<Order?> Function(String id)? reloadOrder,
    Future<PickedReceiptFile?> Function(BuildContext context)? pickReceipt,
  }) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = service ?? _FakeService();
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) {
          if (settings.name != '/order') return null;
          openedOrders?.add(settings.arguments);
          return CupertinoPageRoute<void>(
            settings: settings,
            builder: (context) => CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  child: const Text('tela da OS'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          );
        },
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                child: const Text('abrir'),
                onPressed: () async {
                  final done = await Navigator.of(context).push<bool>(
                    CupertinoPageRoute(
                      builder: (_) => ReceiveCustomerScreen(
                        orders: orders ?? _orders(),
                        customer: name == null ? _customer : null,
                        customerName: name,
                        service: fake,
                        canAttachReceipt: true,
                        reloadOrder: reloadOrder ?? (_) async => null,
                        pickReceipt: pickReceipt,
                      ),
                    ),
                  );
                  popped?.add(done ?? false);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return fake;
  }

  String brl(double v) => FormatService().formatCurrency(v);

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('receiveCustomerConfirm')));
    await tester.pumpAndSettle();
  }

  Future<void> typeAmount(WidgetTester tester, double value) async {
    await tester.enterText(
      find.byKey(const Key('receiveAmountField')),
      brl(value),
    );
    await tester.pump();
  }

  /// Taps "Marcar como recebido", optionally types and taps the ✓.
  Future<void> receive(WidgetTester tester, {double? amount}) async {
    await openSheet(tester);
    if (amount != null) await typeAmount(tester, amount);
    await tester.tap(find.byKey(const ValueKey('new_order_save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<NewOrderTopBar>(find.byType(NewOrderTopBar)).onSave != null;

  String summary(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('receiveSummaryLabel'))).data!;

  String amountOnTop(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('receiveSummaryAmount'))).data!;

  testWidgets('name, what is owed, one blue button and the orders', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('João'), findsOneWidget);
    expect(summary(tester), 'A receber · 3 OS');
    expect(amountOnTop(tester), brl(1250));
    expect(find.text('Marcar como recebido'), findsOneWidget);
    expect(find.byType(PrimaryButton), findsOneWidget);
    expect(find.text('OS incluídas'), findsOneWidget);
    // The form waits in the sheet; rows don't repeat what it does.
    expect(find.byType(CupertinoTextField), findsNothing);
    expect(find.text('Quando'), findsNothing);
    expect(find.text('Quita'), findsNothing);
    expect(find.textContaining('Pix'), findsNothing);
  });

  testWidgets('the sheet starts with the total and settles every order', (
    tester,
  ) async {
    await pump(tester);
    await openSheet(tester);

    expect(find.text('Recebido de João'), findsOneWidget);
    final field = tester.widget<CupertinoTextField>(
      find.byKey(const Key('receiveAmountField')),
    );
    expect(field.controller!.text, brl(1250));
    expect(field.keyboardType.decimal, isTrue);
    expect(field.clearButtonMode, OverlayVisibilityMode.editing);
    expect(field.autofocus, isFalse);
    expect(find.text('Quita as 3 OS.'), findsOneWidget);
    expect(find.text('Anexar'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('focused, an "OK" dismisses the numeric keyboard', (
    tester,
  ) async {
    await pump(tester);
    await openSheet(tester);
    expect(find.byKey(const Key('receiveKeyboardDone')), findsNothing);
    await tester.tap(find.byKey(const Key('receiveAmountField')));
    await tester.pump();
    expect(find.byKey(const Key('receiveKeyboardDone')), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.byKey(const Key('receiveKeyboardDone')), findsNothing);
  });

  testWidgets('order rows say "OS N · vehicle", falling back to a service', (
    tester,
  ) async {
    await pump(
      tester,
      orders: [
        _order('a', 15, 100)..device = (DeviceAggr()..name = 'Fiat Uno'),
        _order('b', 16, 50)
          ..services = [OrderService()..description = 'Troca de óleo'],
      ],
    );
    expect(find.text('OS 15 · Fiat Uno'), findsOneWidget);
    expect(find.text('OS 16 · Troca de óleo'), findsOneWidget);
  });

  testWidgets('a partial payment says what it does, oldest first', (
    tester,
  ) async {
    await pump(tester);
    await openSheet(tester);
    await typeAmount(tester, 750);

    expect(
      find.text('Quita OS 182. Paga ${brl(300)} da OS 190. Ficam ${brl(500)}.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a row toggles the check and the total follows', (
    tester,
  ) async {
    final service = await pump(tester);
    final check = find.byKey(const Key('receiveCustomerCheck_a'));
    expect(
      tester.widget<Icon>(check).icon,
      CupertinoIcons.checkmark_circle_fill,
    );

    await tester.tap(find.byKey(const Key('receiveCustomerToggle_a')));
    await tester.pump();
    expect(tester.widget<Icon>(check).icon, CupertinoIcons.circle);
    expect(summary(tester), 'A receber · 2 de 3 OS');
    // 1250 - 450.
    expect(amountOnTop(tester), brl(800));

    await openSheet(tester);
    await typeAmount(tester, 900);
    expect(saveEnabled(tester), isFalse);
    expect(
      find.text('Passa do que falta nessas OS (${brl(800)}).'),
      findsOneWidget,
    );
    await typeAmount(tester, 600);
    await tester.tap(find.byKey(const ValueKey('new_order_save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final request = service.requests.single;
    expect(request.allocations.map((a) => a.orderId), ['b', 'c']);
    expect(request.allocations.map((a) => a.amount), [500, 100]);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('nothing checked: buttons off with a hint', (tester) async {
    await pump(tester, orders: [_order('a', 1, 100), _order('b', 2, 50)]);
    await tester.tap(find.byKey(const Key('receiveCustomerToggle_a')));
    await tester.tap(find.byKey(const Key('receiveCustomerToggle_b')));
    await tester.pump();
    final button = tester.widget<PrimaryButton>(
      find.byKey(const Key('receiveCustomerConfirm')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Marque pelo menos uma OS.'), findsOneWidget);
  });

  testWidgets('zero in the sheet keeps the ✓ off with a hint', (tester) async {
    await pump(tester);
    await openSheet(tester);
    await tester.enterText(find.byKey(const Key('receiveAmountField')), '');
    await tester.pump();
    expect(saveEnabled(tester), isFalse);
    expect(find.text('Digite quanto recebeu.'), findsOneWidget);
  });

  testWidgets('the date row opens a picker without future dates', (
    tester,
  ) async {
    await pump(tester);
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('receiveDateRow')));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(
      find.byKey(const Key('receiveDatePicker')),
    );
    final now = DateTime.now();
    expect(picker.maximumDate, isNotNull);
    expect(
      picker.maximumDate!.isBefore(DateTime(now.year, now.month, now.day + 1)),
      isTrue,
    );
    await tester.tap(find.byKey(const Key('receiveDateConfirm')));
    await tester.pumpAndSettle();
    expect(find.text('Hoje'), findsOneWidget);
  });

  testWidgets('the receipt picked in the sheet goes with the payment', (
    tester,
  ) async {
    final picked = PickedReceiptFile(File('pix.jpg'), 'image/jpeg', 'pix.jpg');
    final service = _FakeService();
    await pump(tester, service: service, pickReceipt: (_) async => picked);
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('receiveAttachReceipt')));
    await tester.pumpAndSettle();
    expect(find.text('pix.jpg'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('new_order_save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(service.requests.single.file, same(picked));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('✓ records the split, toasts and pops with true', (tester) async {
    final popped = <bool>[];
    final service = await pump(tester, popped: popped);
    await receive(tester, amount: 750);

    final request = service.requests.single;
    expect(request.customer?.id, 'c1');
    expect(request.allocations.map((a) => a.orderId), ['a', 'b']);
    expect(request.allocations.map((a) => a.amount), [450, 300]);
    expect(request.file, isNull);
    final now = DateTime.now();
    expect(request.paidAt.year, now.year);
    expect(request.paidAt.day, now.day);

    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(popped, [true]);
  });

  testWidgets(
    'an order paid meanwhile (link, someone else): nothing is recorded, '
    'the screen shows the new amounts',
    (tester) async {
      final popped = <bool>[];
      // Server: OS 182 was paid by the Asaas link after the screen opened.
      final service = _FakeService(
        fresh: {
          'a': _order('a', 182, 450, paid: 450),
          'b': _order('b', 190, 600, paid: 100),
          'c': _order('c', 201, 300),
        },
      );
      await pump(tester, service: service, popped: popped);
      await receive(tester);

      expect(service.freshReads.single, unorderedEquals(['a', 'b', 'c']));
      expect(service.requests, isEmpty);
      expect(find.textContaining('Os valores mudaram'), findsOneWidget);
      expect(amountOnTop(tester), brl(800));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(popped, isEmpty);

      // Confirming again with the fresh amounts records only what is open.
      await receive(tester);
      final request = service.requests.single;
      expect(request.allocations.map((a) => a.orderId), ['b', 'c']);
      expect(request.allocations.map((a) => a.amount), [500, 300]);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    },
  );

  testWidgets('same balances on the server: records right away', (
    tester,
  ) async {
    final service = _FakeService(fresh: {for (final o in _orders()) o.id!: o});
    await pump(tester, service: service);
    await receive(tester);
    expect(service.requests.single.allocations.map((a) => a.amount), [
      450,
      500,
      300,
    ]);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a failure keeps the screen and what was typed', (tester) async {
    final popped = <bool>[];
    await pump(
      tester,
      service: _FakeService(fail: CustomerReceiptFailure.upload),
      popped: popped,
    );
    await receive(tester, amount: 300);
    expect(find.textContaining('comprovante'), findsWidgets);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(popped, isEmpty);
    expect(find.text('João'), findsOneWidget);

    await openSheet(tester);
    final field = tester.widget<CupertinoTextField>(
      find.byKey(const Key('receiveAmountField')),
    );
    expect(field.controller!.text, brl(300));
  });

  testWidgets('long name wraps and text scale 2 does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(2),
          ),
          child: ReceiveCustomerScreen(
            orders: _orders(),
            customerName: 'Maria Aparecida dos Santos Oliveira Transportes',
            service: _FakeService(),
            canAttachReceipt: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final title = tester.widget<Text>(
      find.byKey(const Key('receiveCustomerTitle')),
    );
    expect(title.overflow, isNot(TextOverflow.ellipsis));
    expect(title.maxLines, isNull);
  });

  testWidgets('starts with only the given orders checked and their amount', (
    tester,
  ) async {
    final orders = _orders();
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReceiveCustomerScreen(
          orders: orders,
          checkedOrderIds: {orders.last.id!},
          customerName: 'Maria',
          service: _FakeService(),
          canAttachReceipt: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final amount = tester.widget<Text>(
      find.byKey(const Key('receiveSummaryAmount')),
    );
    expect(amount.data, brl(FinancialSummary.openAmount(orders.last)));
  });

  testWidgets('orders already paid are left out of the sentence', (
    tester,
  ) async {
    await pump(
      tester,
      orders: [
        _order('a', 1, 100, paid: 100),
        _order('b', 2, 80),
        _order('c', 3, 20),
      ],
    );
    expect(summary(tester), 'A receber · 2 OS');
    expect(find.byKey(const Key('receiveCustomerRow_a')), findsNothing);
    expect(find.textContaining('100,00'), findsOneWidget);
  });

  testWidgets('open() pushes above the tab bar (root navigator)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            items: const [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.home),
                label: 'Aba A',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.money_dollar),
                label: 'Aba B',
              ),
            ],
          ),
          tabBuilder: (_, __) => CupertinoTabView(
            builder: (context) => CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  child: const Text('abrir'),
                  onPressed: () => ReceiveCustomerScreen.open(
                    context,
                    orders: _orders(),
                    customer: _customer,
                    canAttachReceipt: false,
                    canReceive: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Aba A'), findsOneWidget);
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(ReceiveCustomerScreen), findsOneWidget);
    // On the root navigator the tab bar is covered, so it is no longer
    // hit-testable under the screen's blue button.
    expect(find.text('Aba A').hitTestable(), findsNothing);
  });
  testWidgets('open() without financial access shows access denied', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                child: const Text('abrir'),
                onPressed: () => ReceiveCustomerScreen.open(
                  context,
                  orders: _orders(),
                  customer: _customer,
                  canAttachReceipt: false,
                  canReceive: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    // A consultant (no viewFinancialReports) gets no "Receber de ...".
    expect(find.byType(ReceiveCustomerScreen), findsNothing);
    expect(find.byType(AccessDeniedScreen), findsOneWidget);
  });

  group('ⓘ opens the order', () {
    testWidgets('the ⓘ pushes /order with that order', (tester) async {
      final opened = <Object?>[];
      await pump(tester, openedOrders: opened);
      final info = find.byKey(const Key('receiveCustomerInfo_b'));
      expect(tester.getSize(info).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(info).height, greaterThanOrEqualTo(44));

      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(find.text('tela da OS'), findsOneWidget);
      final args = opened.single as Map<String, dynamic>;
      expect((args['order'] as Order).id, 'b');
    });

    testWidgets('coming back refreshes the debt', (tester) async {
      await pump(
        tester,
        // Someone received 200 on OS 190 inside the order.
        reloadOrder: (id) async => _order('b', 190, 600, paid: 300),
      );
      await tester.tap(find.byKey(const Key('receiveCustomerInfo_b')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('tela da OS'));
      await tester.pumpAndSettle();

      expect(amountOnTop(tester), brl(1050));
    });
  });

  testWidgets('one open order: no check to toggle', (tester) async {
    await pump(tester, orders: [_order('a', 1, 100)]);
    expect(find.byKey(const Key('receiveCustomerCheck_a')), findsNothing);
    expect(summary(tester), 'A receber · 1 OS');
    await tester.tap(find.byKey(const Key('receiveCustomerToggle_a')));
    await tester.pump();
    expect(summary(tester), 'A receber · 1 OS');
  });
}
