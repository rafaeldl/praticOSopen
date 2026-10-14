import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/theme/app_glass.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/screens/payment_management_screen.dart';
import 'package:praticos/screens/payments/create_charge_screen.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/services/asaas_api_service.dart';
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
    bool canCharge = false,
    PaymentSettings? settings,
    List<OrderCharge> charges = const [],
    AsaasApiService? service,
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
          canCharge: canCharge,
          paymentSettingsStream: Stream.value(
            settings ??
                PaymentSettings(asaasEnabled: true, asaasConnected: true),
          ),
          chargesStream: Stream.value(charges),
          chargeService: service,
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
    // Pull-down menu of the "…" button, not an action sheet.
    expect(find.byType(CupertinoActionSheet), findsNothing);
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

  testWidgets('with discount: subtitle tells it, no summary rows', (
    tester,
  ) async {
    final store = storeWith(total: 700)..discount = 50;
    await pumpScreen(tester, store);
    final format = FormatService();
    expect(
      find.text(
        'Ana Ribeiro · total ${format.formatCurrency(700)}'
        ' · desconto ${format.formatCurrency(50)}',
      ),
      findsOneWidget,
    );
    expect(find.text('Subtotal'), findsNothing);
    expect(find.text('Desconto'), findsNothing);
    expect(find.text('Total'), findsNothing);
  });

  testWidgets('without discount: no subtotal nor total rows', (tester) async {
    await pumpScreen(tester, storeWith(total: 700, paid: 100));
    expect(find.text('Subtotal'), findsNothing);
    expect(find.text('Total'), findsNothing);
    expect(find.text('Já recebido'), findsNothing);
  });

  testWidgets('payments are listed under "Já recebido"', (tester) async {
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
    expect(find.text('Já recebido'), findsOneWidget);
    expect(find.text('Pagamentos'), findsNothing);
  });

  group('payment link (Asaas)', () {
    final format = FormatService();

    OrderCharge charge({
      ChargeStatus status = ChargeStatus.pending,
      double value = 1000,
      List<String>? paid,
      ChargeMode mode = ChargeMode.single,
      int? installmentCount,
    }) => OrderCharge(
      id: 'ch1',
      status: status,
      value: value,
      mode: mode,
      installmentCount: installmentCount,
      dueDate: '2026-10-20',
      invoiceUrl: 'https://sandbox.asaas.com/i/abc',
      paidAsaasPaymentIds: paid,
      createdAt: DateTime(2026, 10, 10),
    );

    AsaasApiService service(MockClientHandler handler) =>
        AsaasApiService.withClient(
          MockClient(handler),
          headersProvider: () async => {'Authorization': 'Bearer t'},
        );

    OrderStore countingStore(List<int> reloads, {double paid = 0}) =>
        storeWith(total: 1000, paid: paid)
          ..fetchOrderFromServer = (companyId, orderId) async {
            reloads.add(1);
            return null;
          };

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('receiveMoreButton')));
      await tester.pumpAndSettle();
    }

    group('no open link', () {
      testWidgets('offers "Mandar link para Ana Ribeiro pagar"', (
        tester,
      ) async {
        await pumpScreen(tester, countingStore([]), canCharge: true);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('receiveConfirm')), findsOneWidget);
        expect(find.text('Mandar link para Ana Ribeiro pagar'), findsOneWidget);
        expect(find.text('Link para pagar'), findsNothing);
      });

      testWidgets('opens the create-link sheet once (double tap)', (
        tester,
      ) async {
        final store = countingStore([]);
        // No customer id: the sheet doesn't look up the tax id.
        store.order!.customer!.id = null;
        await pumpScreen(tester, store, canCharge: true);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('chargeSendLink')));
        await tester.tap(
          find.byKey(const Key('chargeSendLink')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        expect(find.byType(CreateChargeScreen), findsOneWidget);
        expect(find.byType(FormSheet), findsOneWidget);
      });

      testWidgets('hidden when disconnected', (tester) async {
        await pumpScreen(
          tester,
          countingStore([]),
          canCharge: true,
          settings: PaymentSettings(asaasEnabled: true, asaasConnected: false),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chargeSendLink')), findsNothing);
      });

      testWidgets('hidden without the chargeOrder permission', (tester) async {
        await pumpScreen(tester, countingStore([]));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chargeSendLink')), findsNothing);
      });

      testWidgets('hidden outside the Asaas pilot', (tester) async {
        await pumpScreen(
          tester,
          countingStore([]),
          canCharge: true,
          settings: PaymentSettings(asaasEnabled: false, asaasConnected: true),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chargeSendLink')), findsNothing);
      });

      testWidgets('hidden when everything was received', (tester) async {
        await pumpScreen(
          tester,
          countingStore([], paid: 1000),
          canCharge: true,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('receiveAllDone')), findsOneWidget);
        expect(find.byKey(const Key('chargeSendLink')), findsNothing);
      });

      testWidgets('hidden for quotes', (tester) async {
        await pumpScreen(tester, storeWith(status: 'quote'), canCharge: true);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chargeSendLink')), findsNothing);
      });

      testWidgets('paid or canceled links are not listed', (tester) async {
        await pumpScreen(
          tester,
          countingStore([]),
          canCharge: true,
          charges: [charge(status: ChargeStatus.canceled)],
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chargeLinkRow')), findsNothing);
        expect(find.byKey(const Key('chargeSendLink')), findsOneWidget);
      });

      testWidgets('reloads the payments once when it shows up', (tester) async {
        final reloads = <int>[];
        await pumpScreen(tester, countingStore(reloads), canCharge: true);
        await tester.pumpAndSettle();
        expect(reloads, hasLength(1));
      });

      testWidgets('does not reload without the permission', (tester) async {
        final reloads = <int>[];
        await pumpScreen(tester, countingStore(reloads));
        await tester.pumpAndSettle();
        expect(reloads, isEmpty);
      });
    });

    group('open link', () {
      testWidgets('block says it was sent; no blue button', (tester) async {
        await pumpScreen(
          tester,
          countingStore([]),
          canCharge: true,
          charges: [charge()],
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chargeLinkBlock')), findsOneWidget);
        expect(find.byKey(const Key('receiveConfirm')), findsNothing);
        expect(find.text('Lembrar pelo WhatsApp também'), findsOneWidget);
        expect(find.text('Link para pagar'), findsOneWidget);
        expect(find.text('Esperando Ana Ribeiro pagar'), findsOneWidget);
        expect(find.byKey(const Key('chargeSendLink')), findsNothing);
      });

      testWidgets('"Recebi de outro jeito" brings back the manual block', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          countingStore([]),
          canCharge: true,
          charges: [charge()],
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Recebi de outro jeito'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chargeLinkBlock')), findsNothing);
        expect(find.byKey(const Key('receiveConfirm')), findsOneWidget);
        // The link row stays.
        expect(find.byKey(const Key('chargeLinkRow')), findsOneWidget);
      });

      testWidgets('the row is not tappable; "…" has the link actions', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          countingStore([]),
          canCharge: true,
          charges: [charge()],
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('chargeLinkRow')));
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoActionSheet), findsNothing);

        await openMenu(tester);
        expect(find.text('Copiar o link'), findsOneWidget);
        expect(find.text('Mandar de novo pelo WhatsApp'), findsOneWidget);
        expect(find.text('Dar desconto'), findsOneWidget);
        expect(find.text('Cancelar o link'), findsOneWidget);
      });

      testWidgets('paid installments: no "Cancelar o link"', (tester) async {
        await pumpScreen(
          tester,
          countingStore([], paid: 333.33),
          canCharge: true,
          charges: [
            charge(
              mode: ChargeMode.cardInstallments,
              installmentCount: 3,
              paid: ['pay_1'],
            ),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.text('1 de 3 parcelas pagas'), findsOneWidget);
        // Locked: no "the order changed" block even if the link is bigger.
        expect(find.byKey(const Key('chargeChangedBlock')), findsNothing);
        expect(find.byKey(const Key('chargeLinkBlock')), findsOneWidget);

        await openMenu(tester);
        expect(find.text('Copiar o link'), findsOneWidget);
        expect(find.text('Cancelar o link'), findsNothing);
      });

      testWidgets('overdue: says when it expired', (tester) async {
        await pumpScreen(
          tester,
          countingStore([]),
          canCharge: true,
          charges: [charge(status: ChargeStatus.overdue)],
        );
        await tester.pumpAndSettle();
        final due = format.formatDayMonthOrDate(DateTime(2026, 10, 20));
        expect(find.text('O link venceu em $due'), findsOneWidget);
        expect(find.text('Venceu em $due'), findsOneWidget);
      });

      testWidgets('copies the link from the "…" menu', (tester) async {
        final copied = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await pumpScreen(
          tester,
          countingStore([]),
          canCharge: true,
          charges: [charge()],
        );
        await tester.pumpAndSettle();
        await openMenu(tester);
        await tester.tap(find.text('Copiar o link'));
        await tester.pumpAndSettle();
        expect(copied, ['https://sandbox.asaas.com/i/abc']);
        // Quick notice, not an alert to dismiss.
        expect(find.text('Link copiado'), findsOneWidget);
        expect(find.byType(CupertinoAlertDialog), findsNothing);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.text('Link copiado'), findsNothing);
      });

      testWidgets('cancels the link after confirming', (tester) async {
        var deleted = false;
        await pumpScreen(
          tester,
          countingStore([]),
          canCharge: true,
          charges: [charge()],
          service: service((request) async {
            expect(request.method, 'DELETE');
            expect(request.url.path, endsWith('/v1/app/orders/o1/charges/ch1'));
            deleted = true;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'id': 'ch1', 'status': 'canceled'},
              }),
              200,
            );
          }),
        );
        await tester.pumpAndSettle();
        await openMenu(tester);
        await tester.tap(find.text('Cancelar o link'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'O cliente não vai mais conseguir pagar por esse link.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('confirmCancelChargeAction')));
        await tester.pumpAndSettle();
        expect(deleted, isTrue);
      });

      testWidgets('cancel error shows the translated text', (tester) async {
        await pumpScreen(
          tester,
          countingStore([]),
          canCharge: true,
          charges: [charge()],
          service: service(
            (_) async => http.Response(
              jsonEncode({
                'success': false,
                'error': {'code': 'CHARGE_NOT_OPEN', 'message': 'raw'},
              }),
              409,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await openMenu(tester);
        await tester.tap(find.text('Cancelar o link'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirmCancelChargeAction')));
        await tester.pumpAndSettle();
        expect(find.text('raw'), findsNothing);
        expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      });

      testWidgets('everything received: "Tudo recebido" and the row', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          countingStore([], paid: 1000),
          canCharge: true,
          charges: [charge()],
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('receiveAllDone')), findsOneWidget);
        expect(find.byKey(const Key('chargeLinkRow')), findsOneWidget);
        await openMenu(tester);
        expect(find.text('Cancelar o link'), findsOneWidget);
      });
    });

    group('order total changed', () {
      testWidgets('offers a new link; "Manter" goes back to the link block', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          countingStore([], paid: 200),
          canCharge: true,
          charges: [charge(value: 1000)],
        );
        await tester.pumpAndSettle();
        final remaining = format.formatCurrency(800);
        final value = format.formatCurrency(1000);
        expect(find.byKey(const Key('chargeChangedBlock')), findsOneWidget);
        expect(find.text('A OS mudou de valor'), findsOneWidget);
        expect(
          find.text('Agora falta $remaining, mas o link ainda cobra $value.'),
          findsOneWidget,
        );
        expect(find.text('Gerar link novo de $remaining'), findsOneWidget);
        expect(find.byKey(const Key('receiveConfirm')), findsNothing);
        final due = format.formatDayMonthOrDate(DateTime(2026, 10, 20));
        expect(
          find.text('até $due · o link novo cancela este'),
          findsOneWidget,
        );

        await tester.tap(find.text('Manter o link de $value'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chargeChangedBlock')), findsNothing);
        expect(find.byKey(const Key('chargeLinkBlock')), findsOneWidget);
      });

      testWidgets('a down payment link (smaller) is just an open link', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          countingStore([]),
          canCharge: true,
          charges: [charge(value: 500)],
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chargeChangedBlock')), findsNothing);
        expect(find.byKey(const Key('chargeLinkBlock')), findsOneWidget);
      });

      testWidgets('disconnected: no "new link" button', (tester) async {
        await pumpScreen(
          tester,
          countingStore([], paid: 200),
          canCharge: true,
          settings: PaymentSettings(asaasEnabled: true, asaasConnected: false),
          charges: [charge(value: 1000)],
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chargeChangedBlock')), findsOneWidget);
        expect(find.byKey(const Key('chargeRegenerateButton')), findsNothing);
      });
    });
  });
}
