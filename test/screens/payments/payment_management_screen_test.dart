import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/theme/app_glass.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/screens/payment_management_screen.dart';
import 'package:praticos/services/format_service.dart';

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

  setUp(() {
    Global.companyAggr = CompanyAggr()..id = 'c1';
    FormatService().setLocale('pt-BR');
  });
  tearDown(() => Global.companyAggr = null);

  OrderStore storeWith({
    String status = 'approved',
    double total = 1000,
    double paid = 0,
    List<PaymentTransaction> transactions = const [],
  }) {
    final order = Order()
      ..id = 'o1'
      ..number = 42
      ..status = status
      ..total = total
      ..paidAmount = paid
      ..customer = (CustomerAggr()
        ..id = 'c1'
        ..name = 'Ana Ribeiro');
    final store = OrderStore()
      ..order = order
      ..customer = order.customer
      ..status = status
      ..total = total
      ..paidAmount = paid;
    store.transactions.addAll(transactions);
    return store;
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    OrderStore store, {
    bool canAttach = true,
    bool canView = true,
    List<Uri>? opened,
  }) async {
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PaymentManagementScreen(
          store: store,
          canAttachReceipt: canAttach,
          canViewReceipt: canView,
          onOpenExternalUrl: (uri) async => opened?.add(uri),
        ),
        routes: {
          '/order': (context) => CupertinoPageScaffold(
            child: Text(
              'order route ${(ModalRoute.of(context)!.settings.arguments as Map)['order'].number}',
            ),
          ),
        },
      ),
    );
    await tester.pump();
  }

  testWidgets('manual receive: amount filled, no payment method asked', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      storeWith(
        total: 1250,
        paid: 300,
        transactions: [
          PaymentTransaction(
            id: '1728000000000',
            type: PaymentTransactionType.payment,
            amount: 300,
          ),
        ],
      ),
    );

    expect(find.text('Receber'), findsWidgets);
    expect(find.text('Falta receber'), findsOneWidget);
    expect(find.textContaining('Recebi'), findsOneWidget);
    expect(find.textContaining('950,00'), findsWidgets);
    expect(find.text('Anexar comprovante'), findsOneWidget);
    expect(find.textContaining('Como pagou'), findsNothing);
    // Manual payment: no payment method, receipt state visible.
    expect(find.textContaining('pelo link'), findsNothing);
    expect(find.textContaining('sem comprovante'), findsOneWidget);
    // Old segmented control and shortcut are gone.
    expect(find.byType(CupertinoSlidingSegmentedControl<int>), findsNothing);
    expect(find.textContaining('Pagar valor total'), findsNothing);
  });

  testWidgets('Asaas paid: shows billing type and "Tudo recebido"', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      storeWith(
        total: 950,
        paid: 950,
        transactions: [
          PaymentTransaction(
            id: 'asaas_pay_1',
            type: PaymentTransactionType.payment,
            amount: 950,
            description: 'Asaas • Pix',
          ),
        ],
      ),
    );

    expect(find.text('Tudo recebido'), findsOneWidget);
    expect(find.byKey(const Key('receiveConfirm')), findsNothing);
    expect(find.text('Pix pelo link'), findsOneWidget);
  });

  testWidgets('receipt visible in the payment row and sheet', (tester) async {
    await pumpScreen(
      tester,
      storeWith(
        total: 500,
        paid: 500,
        transactions: [
          PaymentTransaction(
            id: '1728000000000',
            type: PaymentTransactionType.payment,
            amount: 500,
            receiptDocumentId: 'doc1',
          ),
        ],
      ),
    );

    expect(find.textContaining('com comprovante'), findsOneWidget);

    await tester.tap(find.textContaining('com comprovante'));
    await tester.pumpAndSettle();
    expect(find.text('Ver comprovante'), findsOneWidget);
    expect(find.text('Remover este pagamento'), findsOneWidget);
    expect(find.text('Anexar comprovante'), findsNothing);
  });

  testWidgets(
    'payment without receipt offers to attach later; Asaas cannot be removed',
    (tester) async {
      await pumpScreen(
        tester,
        storeWith(
          total: 500,
          paid: 500,
          transactions: [
            PaymentTransaction(
              id: 'asaas_pay_9',
              type: PaymentTransactionType.payment,
              amount: 500,
              description: 'Asaas • Boleto',
            ),
          ],
        ),
      );

      await tester.tap(find.text('Boleto pelo link'));
      await tester.pumpAndSettle();
      expect(find.text('Anexar comprovante'), findsOneWidget);
      expect(find.text('Remover este pagamento'), findsNothing);
    },
  );

  testWidgets('"..." menu offers discount and undo payments', (tester) async {
    await pumpScreen(
      tester,
      storeWith(
        total: 1000,
        paid: 100,
        transactions: [
          PaymentTransaction(
            id: '1728000000000',
            type: PaymentTransactionType.payment,
            amount: 100,
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('receiveMoreButton')));
    await tester.pumpAndSettle();
    expect(find.text('Dar desconto'), findsOneWidget);
    expect(find.text('Desfazer pagamentos'), findsOneWidget);
  });

  testWidgets('top buttons are the shared glass buttons', (tester) async {
    await pumpScreen(tester, storeWith(total: 1000, paid: 100));
    expect(
      find.descendant(
        of: find.byKey(const Key('receiveMoreButton')),
        matching: find.byType(AppGlass),
      ),
      findsOneWidget,
    );
    expect(find.byType(GlassBarButton), findsOneWidget);
  });

  testWidgets('canceled order does not accept payments', (tester) async {
    await pumpScreen(tester, storeWith(status: 'canceled'));
    expect(find.byKey(const Key('receiveBlocked')), findsOneWidget);
    expect(find.byKey(const Key('receiveConfirm')), findsNothing);
    expect(find.byKey(const Key('receiveMoreButton')), findsNothing);
  });

  testWidgets('shows customer and total under the title, and the amount hint', (
    tester,
  ) async {
    await pumpScreen(tester, storeWith(total: 1250));
    expect(
      find.text('Ana Ribeiro · total ${FormatService().formatCurrency(1250)}'),
      findsOneWidget,
    );
    expect(find.text('Recebeu só uma parte? Mude o valor.'), findsOneWidget);
  });

  testWidgets('from Financeiro, "‹ OS 42" replaces Receber with the order', (
    tester,
  ) async {
    await pumpScreen(tester, storeWith());
    expect(find.text('OS 42'), findsOneWidget);
    await tester.tap(find.byKey(const Key('receiveOrderLink')));
    await tester.pumpAndSettle();
    expect(find.text('order route 42'), findsOneWidget);
    // Receber is gone: no stack Receber → OS → Receber.
    expect(find.byType(PaymentManagementScreen), findsNothing);
  });

  testWidgets('from the order, "‹ OS 42" goes back to it', (tester) async {
    final store = storeWith();
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => CupertinoButton(
            child: const Text('order screen'),
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute(
                settings: RouteSettings(
                  arguments: {'orderStore': store, 'fromOrder': true},
                ),
                builder: (_) => PaymentManagementScreen(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('order screen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('receiveOrderLink')));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentManagementScreen), findsNothing);
    expect(find.text('order screen'), findsOneWidget);
  });

  testWidgets(
    'Asaas receipt from the webhook: row says "com comprovante" and sheet opens it',
    (tester) async {
      final opened = <Uri>[];
      await pumpScreen(
        tester,
        storeWith(
          total: 500,
          paid: 500,
          transactions: [
            PaymentTransaction(
              id: 'asaas_pay_7',
              type: PaymentTransactionType.payment,
              amount: 500,
              description: 'Asaas',
              billingType: 'CREDIT_CARD',
              receiptUrl: 'https://www.asaas.com/comprovantes/7',
            ),
          ],
        ),
        opened: opened,
      );

      // Billing type comes from the new field, not the description.
      expect(find.text('Cartão pelo link'), findsOneWidget);
      expect(find.textContaining('com comprovante'), findsOneWidget);

      await tester.tap(find.text('Cartão pelo link'));
      await tester.pumpAndSettle();
      expect(find.text('Ver comprovante'), findsOneWidget);
      expect(find.text('Anexar comprovante'), findsNothing);
      expect(find.text('Remover este pagamento'), findsNothing);

      await tester.tap(find.byKey(const Key('receiveAsaasReceipt')));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://www.asaas.com/comprovantes/7')]);
    },
  );

  testWidgets('Asaas receipt link outside asaas.com is never offered', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      storeWith(
        total: 500,
        paid: 500,
        transactions: [
          PaymentTransaction(
            id: 'asaas_pay_8',
            type: PaymentTransactionType.payment,
            amount: 500,
            description: 'Asaas • Pix',
            receiptUrl: 'https://evil.example.com/asaas',
          ),
        ],
      ),
    );

    expect(find.textContaining('sem comprovante'), findsOneWidget);
    await tester.tap(find.text('Pix pelo link'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('receiveAsaasReceipt')), findsNothing);
    expect(find.text('Anexar comprovante'), findsOneWidget);
  });

  testWidgets('with discount: subtotal, discount, then the net total', (
    tester,
  ) async {
    final store = storeWith(total: 700)..discount = 22.22;
    await pumpScreen(tester, store);
    final format = FormatService();
    expect(find.byKey(const Key('receiveSubtotal')), findsOneWidget);
    expect(find.text(format.formatCurrency(722.22)), findsOneWidget);
    expect(find.text('- ${format.formatCurrency(22.22)}'), findsOneWidget);
    final subtotalY = tester.getTopLeft(find.text('Subtotal')).dy;
    final discountY = tester.getTopLeft(find.text('Desconto')).dy;
    final totalY = tester.getTopLeft(find.text('Total')).dy;
    expect(subtotalY < discountY && discountY < totalY, isTrue);
  });

  testWidgets('without discount: no subtotal row', (tester) async {
    await pumpScreen(tester, storeWith(total: 700));
    expect(find.byKey(const Key('receiveSubtotal')), findsNothing);
    expect(find.text('Desconto'), findsNothing);
  });
}
