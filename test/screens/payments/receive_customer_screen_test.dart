import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/payments/receive_customer_screen.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/services/customer_receipt_service.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/widgets/permission_widgets.dart';

class _FakeService extends CustomerReceiptService {
  _FakeService({this.fail});

  final CustomerReceiptFailure? fail;
  final requests = <CustomerReceiptRequest>[];

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
    Future<Set<String>?> Function(BuildContext, List<Order>, Set<String>)?
    pickOrders,
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
                        pickOrders: pickOrders,
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

  testWidgets('title, sentence, total prefilled and the full split', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Receber de João'), findsOneWidget);
    expect(find.text('Deve ${brl(1250)} em 3 OS'), findsOneWidget);
    expect(find.textContaining('1.250,00'), findsWidgets);
    expect(find.text('Como fica'), findsOneWidget);
    expect(find.text('OS 182 · quita ${brl(450)}'), findsOneWidget);
    expect(find.text('OS 190 · quita ${brl(500)}'), findsOneWidget);
    expect(find.text('OS 201 · quita ${brl(300)}'), findsOneWidget);
    expect(find.text('Anexar comprovante'), findsOneWidget);
    expect(find.text('Quando'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
    expect(buttonEnabled(tester), isTrue);
    // No payment method.
    expect(find.textContaining('Pix'), findsNothing);
  });

  testWidgets('"Como fica" follows the amount, oldest first', (tester) async {
    await pump(tester);
    await typeAmount(tester, 750);

    expect(find.text('OS 182 · quita ${brl(450)}'), findsOneWidget);
    expect(
      find.text('OS 190 · recebe ${brl(300)}, fica ${brl(200)}'),
      findsOneWidget,
    );
    expect(find.text('OS 201 · continua ${brl(300)}'), findsOneWidget);
    expect(find.textContaining('Recebi'), findsOneWidget);
    expect(find.textContaining('750,00'), findsWidgets);
  });

  testWidgets('more than owed or zero disables the button with a hint', (
    tester,
  ) async {
    await pump(tester);

    await typeAmount(tester, 1300);
    expect(buttonEnabled(tester), isFalse);
    expect(find.text('Passa do que ele deve (${brl(1250)}).'), findsOneWidget);

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

  testWidgets('"Recebi" records the split, toasts and pops with true', (
    tester,
  ) async {
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
    expect(find.text('Deve ${brl(100)} em 2 OS'), findsOneWidget);
    expect(find.textContaining('OS 1 ·'), findsNothing);
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

  group('one card', () {
    testWidgets('the amount is an editable field that drives the button', (
      tester,
    ) async {
      await pump(tester);
      final card = find.byKey(const Key('receiveCustomerCard'));
      // Looks like a field: a pencil next to the amount.
      expect(
        find.descendant(
          of: card,
          matching: find.byKey(const Key('receiveAmountEditIcon')),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Recebeu só uma parte? Toque no valor e digite quanto.'),
        findsOneWidget,
      );

      // Tapping the pencil focuses the field with the numeric keyboard.
      await tester.tap(find.byKey(const Key('receiveAmountEditIcon')));
      await tester.pump();
      final field = tester.widget<CupertinoTextField>(
        find.byKey(const Key('receiveAmountField')),
      );
      expect(field.focusNode?.hasFocus, isTrue);
      expect(field.keyboardType.decimal, isTrue);

      await typeAmount(tester, 320);
      final button = tester.widget<PrimaryButton>(
        find.byKey(const Key('receiveCustomerConfirm')),
      );
      expect(button.label, 'Recebi ${brl(320)}');
    });

    testWidgets('amount, Quando, receipt and the blue button share the card', (
      tester,
    ) async {
      await pump(tester);
      final card = find.byKey(const Key('receiveCustomerCard'));
      for (final key in [
        'receiveAmountField',
        'receiveDateRow',
        'receiveCustomerAttach',
        'receiveCustomerConfirm',
      ]) {
        expect(
          find.descendant(of: card, matching: find.byKey(Key(key))),
          findsOneWidget,
          reason: key,
        );
      }
      // "Como fica" comes after the card.
      final cardBottom = tester.getBottomLeft(card).dy;
      expect(
        tester.getTopLeft(find.text('Como fica')).dy,
        greaterThan(cardBottom),
      );
    });
  });

  group('"Como fica" rows open the order', () {
    testWidgets('tapping a row pushes /order with that order', (tester) async {
      final opened = <Object?>[];
      await pump(tester, openedOrders: opened);
      final row = find.byKey(const Key('receiveCustomerRow_b'));
      expect(
        find.descendant(
          of: row,
          matching: find.byIcon(CupertinoIcons.chevron_forward),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(row).height, greaterThanOrEqualTo(44));

      await tester.tap(row);
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
      await tester.tap(find.byKey(const Key('receiveCustomerRow_b')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('tela da OS'));
      await tester.pumpAndSettle();

      expect(find.text('Receber de João'), findsOneWidget);
      expect(find.text('Deve ${brl(1050)} em 3 OS'), findsOneWidget);
      final button = tester.widget<PrimaryButton>(
        find.byKey(const Key('receiveCustomerConfirm')),
      );
      expect(button.label, 'Recebi ${brl(700)}');
      expect(
        find.text('OS 190 · recebe ${brl(250)}, fica ${brl(50)}'),
        findsOneWidget,
      );
    });
  });

  group('Escolher as OS', () {
    testWidgets('the picker lists open orders, all checked, oldest first', (
      tester,
    ) async {
      await pump(
        tester,
        orders: [
          _order('a', 182, 450)..createdAt = DateTime(2026, 9, 1),
          _order('b', 190, 600, paid: 100)..createdAt = DateTime(2026, 9, 5),
          _order('x', 191, 50, paid: 50),
        ],
      );
      await tester.tap(find.byKey(const Key('receiveCustomerChoose')));
      await tester.pumpAndSettle();

      expect(find.text('Quais OS ele está pagando?'), findsWidgets);
      expect(find.text('OS 182'), findsOneWidget);
      expect(find.text('OS 190'), findsOneWidget);
      // Paid order is not offered.
      expect(find.text('OS 191'), findsNothing);
      expect(find.text('Falta ${brl(450)} · 01/09/2026'), findsOneWidget);
      expect(find.text('Falta ${brl(500)} · 05/09/2026'), findsOneWidget);

      // Uncheck 182 and confirm with the ✓ in the top bar.
      await tester.tap(find.text('OS 182'));
      await tester.pump();
      await tester.tap(find.byType(PickerConfirmButton));
      await tester.pumpAndSettle();

      expect(find.text('Receber de João'), findsOneWidget);
      expect(find.textContaining('OS 182'), findsNothing);
      expect(find.text('OS 190 · quita ${brl(500)}'), findsOneWidget);
      expect(
        find.text(
          'O valor vai só para as OS escolhidas, primeiro a mais antiga.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('chosen orders: max is their open sum and only they get it', (
      tester,
    ) async {
      final service = await pump(
        tester,
        pickOrders: (_, orders, selected) async {
          // Every open order comes in, all selected, oldest first.
          expect(orders.map((o) => o.id), ['a', 'b', 'c']);
          expect(selected, {'a', 'b', 'c'});
          return {'c', 'b'};
        },
      );
      await tester.tap(find.byKey(const Key('receiveCustomerChoose')));
      await tester.pumpAndSettle();

      // Prefilled with what is open on the chosen ones (500 + 300).
      expect(find.textContaining('800,00'), findsWidgets);
      expect(find.text('OS 190 · quita ${brl(500)}'), findsOneWidget);
      expect(find.text('OS 201 · quita ${brl(300)}'), findsOneWidget);
      expect(find.textContaining('OS 182'), findsNothing);

      await typeAmount(tester, 900);
      expect(buttonEnabled(tester), isFalse);
      expect(
        find.text('Passa do que falta nessas OS (${brl(800)}).'),
        findsOneWidget,
      );

      await typeAmount(tester, 600);
      expect(buttonEnabled(tester), isTrue);
      await tester.tap(find.byKey(const Key('receiveCustomerConfirm')));
      await tester.pump();
      final request = service.requests.single;
      // Oldest first among the chosen: 190 before 201.
      expect(request.allocations.map((a) => a.orderId), ['b', 'c']);
      expect(request.allocations.map((a) => a.amount), [500, 100]);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('going back from the picker keeps everything', (tester) async {
      await pump(tester, pickOrders: (_, __, ___) async => null);
      await tester.tap(find.byKey(const Key('receiveCustomerChoose')));
      await tester.pumpAndSettle();
      expect(find.text('OS 182 · quita ${brl(450)}'), findsOneWidget);
      expect(find.textContaining('1.250,00'), findsWidgets);
    });

    testWidgets('one open order: no "Escolher as OS"', (tester) async {
      await pump(tester, orders: [_order('a', 1, 100)]);
      expect(find.byKey(const Key('receiveCustomerChoose')), findsNothing);
    });
  });
}
