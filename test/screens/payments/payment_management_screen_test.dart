import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('manual receive: amount filled, no payment method asked',
      (tester) async {
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

  testWidgets('Asaas paid: shows billing type and "Tudo recebido"',
      (tester) async {
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

  testWidgets('payment without receipt offers to attach later; Asaas cannot be removed',
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
  });

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

  testWidgets('canceled order does not accept payments', (tester) async {
    await pumpScreen(tester, storeWith(status: 'canceled'));
    expect(find.byKey(const Key('receiveBlocked')), findsOneWidget);
    expect(find.byKey(const Key('receiveConfirm')), findsNothing);
    expect(find.byKey(const Key('receiveMoreButton')), findsNothing);
  });

  testWidgets('shows customer and total under the title, and the amount hint',
      (tester) async {
    await pumpScreen(tester, storeWith(total: 1250));
    expect(find.text('Ana Ribeiro · total ${FormatService().formatCurrency(1250)}'),
        findsOneWidget);
    expect(find.text('Recebeu só uma parte? Mude o valor.'), findsOneWidget);
  });

  testWidgets('"OS 42" link opens the order', (tester) async {
    await pumpScreen(tester, storeWith());
    expect(find.text('OS 42'), findsOneWidget);
    await tester.tap(find.byKey(const Key('receiveOrderLink')));
    await tester.pumpAndSettle();
    expect(find.text('order route 42'), findsOneWidget);
  });
}
