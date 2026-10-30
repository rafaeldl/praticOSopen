import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/payments/receive_customer_screen.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/services/customer_receipt_service.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/services/format_service.dart';
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

  Future<void> typeAmount(WidgetTester tester, double value) async {
    await tester.enterText(find.byType(CupertinoTextField).first, brl(value));
    await tester.pump();
  }

  bool buttonEnabled(WidgetTester tester) {
    final button = tester.widget<PrimaryButton>(
      find.byKey(const Key('receiveCustomerConfirm')),
    );
    return button.onPressed != null;
  }

  String? line(WidgetTester tester, String id) {
    final f = find.byKey(Key('receiveCustomerLine_$id'));
    if (f.evaluate().isEmpty) return null;
    return tester.widget<Text>(f).data;
  }

  testWidgets('title, sentence, amount once and every order settled', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Receber de João'), findsOneWidget);
    expect(
      find.text('3 OS em aberto. Marque as OS que foram pagas.'),
      findsOneWidget,
    );
    // The total shows once: only in the field.
    expect(find.textContaining('1.250,00'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('receiveAmountField')),
        matching: find.textContaining('1.250,00'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Se recebeu só uma parte, digite quanto.'),
      findsOneWidget,
    );
    expect(find.text('Está pagando'), findsOneWidget);
    expect(
      find.text(
        'Se o valor não der para tudo, as mais antigas são pagas primeiro.',
      ),
      findsOneWidget,
    );
    expect(line(tester, 'a'), 'Quita');
    expect(line(tester, 'b'), 'Quita');
    expect(line(tester, 'c'), 'Quita');
    expect(find.text('Comprovante'), findsOneWidget);
    expect(find.text('Anexar'), findsOneWidget);
    expect(find.text('Quando'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
    expect(buttonEnabled(tester), isTrue);
    // Gone: "Como fica", "Escolher as OS", the separate picker.
    expect(find.text('Como fica'), findsNothing);
    expect(find.text('Escolher as OS'), findsNothing);
    expect(find.textContaining('Pix'), findsNothing);
  });

  testWidgets('button says "Confirmar recebimento", without the amount', (
    tester,
  ) async {
    await pump(tester);
    await typeAmount(tester, 320);
    final button = tester.widget<PrimaryButton>(
      find.byKey(const Key('receiveCustomerConfirm')),
    );
    expect(button.label, 'Confirmar recebimento');
    expect(find.textContaining('Recebi'), findsNothing);
  });

  testWidgets('standard field: numeric keyboard, clear button, no autofocus', (
    tester,
  ) async {
    await pump(tester);
    final field = tester.widget<CupertinoTextField>(
      find.byKey(const Key('receiveAmountField')),
    );
    expect(field.keyboardType.decimal, isTrue);
    expect(field.clearButtonMode, OverlayVisibilityMode.editing);
    expect(field.focusNode?.hasFocus, isFalse);
    expect(field.autofocus, isFalse);
    expect(find.byKey(const Key('receiveAmountEditIcon')), findsNothing);
    expect(find.byKey(const Key('receiveKeyboardDone')), findsNothing);

    // Focused: an "OK" bar dismisses the numeric keyboard.
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

  testWidgets('a partial payment tells what each order gets, oldest first', (
    tester,
  ) async {
    await pump(tester);
    await typeAmount(tester, 750);

    expect(line(tester, 'a'), 'Quita');
    expect(line(tester, 'b'), 'Recebe ${brl(300)} · fica ${brl(200)}');
    expect(line(tester, 'c'), 'Fica para depois');
  });

  testWidgets('tapping a row toggles the check and the amount follows', (
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
    // 1250 - 450.
    expect(find.textContaining('800,00'), findsOneWidget);
    expect(line(tester, 'a'), isNull);

    await typeAmount(tester, 900);
    expect(buttonEnabled(tester), isFalse);
    expect(
      find.text('Passa do que falta nessas OS (${brl(800)}).'),
      findsOneWidget,
    );

    await typeAmount(tester, 600);
    // Once typed, checking again does not rewrite the amount.
    await tester.tap(find.byKey(const Key('receiveCustomerToggle_a')));
    await tester.pump();
    expect(find.textContaining('600,00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('receiveCustomerConfirm')));
    await tester.pump();
    final request = service.requests.single;
    expect(request.allocations.map((a) => a.orderId), ['a', 'b']);
    expect(request.allocations.map((a) => a.amount), [450, 150]);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('nothing checked: button off with a hint', (tester) async {
    await pump(tester, orders: [_order('a', 1, 100), _order('b', 2, 50)]);
    await tester.tap(find.byKey(const Key('receiveCustomerToggle_a')));
    await tester.tap(find.byKey(const Key('receiveCustomerToggle_b')));
    await tester.pump();
    expect(buttonEnabled(tester), isFalse);
    expect(find.text('Marque pelo menos uma OS.'), findsOneWidget);
  });

  testWidgets('more than owed or zero disables the button with a hint', (
    tester,
  ) async {
    await pump(tester);

    await typeAmount(tester, 1300);
    expect(buttonEnabled(tester), isFalse);
    expect(
      find.text('Passa do que falta nessas OS (${brl(1250)}).'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(CupertinoTextField).first, '');
    await tester.pump();
    expect(buttonEnabled(tester), isFalse);
    expect(find.text('Digite quanto recebeu.'), findsOneWidget);
  });

  testWidgets('the date row opens a picker without future dates', (
    tester,
  ) async {
    await pump(tester);
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

  testWidgets(
    '"Confirmar recebimento" records the split, toasts and pops with true',
    (tester) async {
      final popped = <bool>[];
      final service = await pump(tester, popped: popped);
      await typeAmount(tester, 750);
      await tester.tap(find.byKey(const Key('receiveCustomerConfirm')));
      await tester.pump();

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
    },
  );

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
      await tester.tap(find.byKey(const Key('receiveCustomerConfirm')));
      await tester.pump();

      expect(service.freshReads.single, unorderedEquals(['a', 'b', 'c']));
      expect(service.requests, isEmpty);
      expect(find.textContaining('Os valores mudaram'), findsOneWidget);
      expect(find.textContaining('800,00'), findsWidgets);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(popped, isEmpty);

      // Confirming again with the fresh amounts records only what is open.
      await tester.tap(find.byKey(const Key('receiveCustomerConfirm')));
      await tester.pump();
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
    await tester.tap(find.byKey(const Key('receiveCustomerConfirm')));
    await tester.pump();
    expect(service.requests.single.allocations.map((a) => a.amount), [
      450,
      500,
      300,
    ]);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a failure keeps the screen open', (tester) async {
    final popped = <bool>[];
    await pump(
      tester,
      service: _FakeService(fail: CustomerReceiptFailure.upload),
      popped: popped,
    );
    await tester.tap(find.byKey(const Key('receiveCustomerConfirm')));
    await tester.pump();
    expect(find.textContaining('comprovante'), findsWidgets);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(popped, isEmpty);
    expect(find.text('Receber de João'), findsOneWidget);
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
    expect(
      find.text('2 OS em aberto. Marque as OS que foram pagas.'),
      findsOneWidget,
    );
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

    testWidgets('coming back keeps the typed amount and refreshes the debt', (
      tester,
    ) async {
      await pump(
        tester,
        // Someone received 200 on OS 190 inside the order.
        reloadOrder: (id) async => _order('b', 190, 600, paid: 300),
      );
      await typeAmount(tester, 700);
      await tester.tap(find.byKey(const Key('receiveCustomerInfo_b')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('tela da OS'));
      await tester.pumpAndSettle();

      expect(find.text('Receber de João'), findsOneWidget);
      expect(find.textContaining('700,00'), findsOneWidget);
      expect(find.textContaining(brl(300)), findsWidgets);
      expect(line(tester, 'b'), 'Recebe ${brl(250)} · fica ${brl(50)}');
    });
  });

  testWidgets('one open order: no check to toggle', (tester) async {
    await pump(tester, orders: [_order('a', 1, 100)]);
    expect(find.byKey(const Key('receiveCustomerCheck_a')), findsNothing);
    expect(find.text('1 OS em aberto.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('receiveCustomerToggle_a')));
    await tester.pump();
    expect(buttonEnabled(tester), isTrue);
  });
}
