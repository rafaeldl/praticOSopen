import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/payments/receive_customer_screen.dart';
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
}
