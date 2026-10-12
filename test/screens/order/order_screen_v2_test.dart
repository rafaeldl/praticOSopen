import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/config/feature_flags.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/custom_field.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/catalog/catalog_source.dart';
import 'package:praticos/screens/customers/customer_list_screen.dart'
    show CustomerPick;
import 'package:praticos/screens/order/order_screen_services.dart';
import 'package:praticos/screens/order/order_screen_v2.dart';
import 'package:praticos/screens/widgets/device_picker_sheet.dart';
import 'package:praticos/services/segment_config_service.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/services/ai_order_assist_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:provider/provider.dart';

/// Firebase core mock whose default app has a storage bucket (OrderStore
/// creates Firestore/Storage services in its fields).
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

class FakeSource implements CatalogSource {
  FakeSource({this.services = const [], this.products = const []});

  final List<CatalogItem> services;
  final List<CatalogItem> products;
  final List<(CatalogKind, CatalogItem)> saved = [];

  @override
  Stream<List<CatalogItem>> watch(CatalogKind kind) =>
      Stream.value(kind == CatalogKind.service ? services : products);

  @override
  Future<void> save(CatalogKind kind, CatalogItem item) async {
    item.id ??= 'new-${saved.length}';
    saved.add((kind, item));
  }

  @override
  Future<void> delete(CatalogKind kind, CatalogItem item) async {}

  @override
  Future<String?> uploadPhoto(
    CatalogKind kind,
    CatalogItem item,
    PhotoOrigin from,
  ) async => null;
}

class FakeActions extends OrderScreenActions {
  final List<String> calls = [];

  @override
  Future<void> openPayments(BuildContext context, OrderStore store) async =>
      calls.add('payments');

  @override
  Future<void> shareWithCustomer(BuildContext context, Order order) async =>
      calls.add('send');
}

class FakeAssistant implements AiOrderAssistClient {
  FakeAssistant(this.draft, {this.error});

  final AiOrderDraft draft;
  final AiOrderAssistException? error;
  final List<String?> texts = [];
  final List<int> photoCounts = [];

  @override
  Future<AiOrderDraft> assist({
    String? text,
    List<AiPhoto> photos = const [],
    String? locale,
  }) async {
    texts.add(text);
    photoCounts.add(photos.length);
    if (error != null) throw error!;
    return draft;
  }
}

String _money(double v) => (FormatService()..setLocale('pt')).formatCurrency(v);

CatalogItem _item(String id, String name, [double? value]) =>
    CatalogItem(id: id, name: name, value: value, origin: Object());

OrderPermissions _permissions({bool prices = true}) => OrderPermissions(
  canViewPrices: () => prices,
  availableStatuses: (_) => const ['approved', 'progress', 'canceled'],
  canChangeStatus: (_, _) => true,
  canDelete: (_) => true,
);

const _allCatalog = CatalogPermissions(_all);
bool _all(PermissionType p) => true;

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Map<String, dynamic>? args,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SegmentConfigProvider>(
      create: (_) =>
          SegmentConfigProvider()
            ..injectL10n(lookupAppLocalizations(const Locale('pt'))),
      child: CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            return CupertinoPageRoute(
              settings: RouteSettings(name: '/', arguments: args),
              builder: (_) => screen,
            );
          }
          if (settings.name == '/customer_list') {
            // Fake "Quem é o cliente?": a plate hit returns customer + vehicle.
            return CupertinoPageRoute(
              settings: settings,
              builder: (context) => CupertinoPageScaffold(
                child: Center(
                  child: CupertinoButton(
                    onPressed: () => Navigator.pop(
                      context,
                      CustomerPick(
                        Customer()
                          ..id = 'c1'
                          ..name = 'Ana Souza',
                        Device()
                          ..id = 'd1'
                          ..name = 'Gol 2018'
                          ..serial = 'ABC1D23',
                      ),
                    ),
                    child: const Text('pick ABC1D23'),
                  ),
                ),
              ),
            );
          }
          return CupertinoPageRoute(
            settings: settings,
            builder: (_) => const Text('pushed'),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  // No company: OrderStore.createItem never reaches Firestore in tests.
  setUp(() => Global.companyAggr = null);

  final source = FakeSource(
    services: [_item('s1', 'Troca de óleo', 120), _item('s2', 'Alinhamento')],
    products: [_item('p1', 'Filtro de óleo', 35.5)],
  );

  OrderScreenV2 screen(
    OrderStore store, {
    FakeSource? catalog,
    CatalogPermissions catalogPermissions = _allCatalog,
    OrderScreenActions? actions,
    bool prices = true,
  }) => OrderScreenV2(
    store: store,
    permissions: _permissions(prices: prices),
    actions: actions ?? FakeActions(),
    catalogSource: catalog ?? source,
    catalogPermissions: catalogPermissions,
    mostUsed: () async => const [],
  );

  group('new order', () {
    testWidgets('opens the order itself, blank, with nothing saved', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(tester, screen(store));

      expect(find.text('Quem é o cliente?'), findsOneWidget);
      expect(find.text('O que vai na OS?'), findsOneWidget);
      expect(find.text('Escolha o cliente para salvar.'), findsOneWidget);
      expect(find.byType(StatusDot), findsOneWidget);
      expect(find.text('Orçamento'), findsOneWidget);
      // No "…" before saving, no cover photo, no assistant yet.
      expect(find.byIcon(CupertinoIcons.ellipsis_circle), findsNothing);
      expect(find.text('Falar o que fazer'), findsNothing);
      expect(store.deferSave, isTrue);
      expect(store.order!.id, isNull);
      expect(store.status, 'quote');

      // "Salvar OS" is disabled until there is a customer.
      final save = tester.widget<CupertinoButton>(
        find.ancestor(
          of: find.textContaining('Salvar'),
          matching: find.byType(CupertinoButton),
        ),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('customer picker fills customer and vehicle; Salvar OS saves', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(tester, screen(store));

      await tester.tap(find.text('Quem é o cliente?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pick ABC1D23'));
      await tester.pumpAndSettle();

      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.text('Gol 2018'), findsOneWidget);
      expect(store.devices.single.id, 'd1');
      expect(find.text('Escolha o cliente para salvar.'), findsNothing);

      await tester.tap(find.textContaining('Salvar'));
      await tester.pumpAndSettle();
      expect(store.deferSave, isFalse);
      expect(find.textContaining('Salvar'), findsNothing);
      expect(find.byIcon(CupertinoIcons.ellipsis_circle), findsOneWidget);
    });

    testWidgets('status row changes the status with a dot and neutral text', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(tester, screen(store));

      await tester.tap(find.text('Mudar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aprovado').last);
      await tester.pumpAndSettle();
      expect(store.status, 'approved');
    });
  });

  group('assistant (aiOrderAssist)', () {
    // 1x1 transparent PNG.
    final png = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      ),
    );

    const draft = AiOrderDraft(
      customer: AiCustomerHit(id: 'c9', name: 'Revenda Sul'),
      deviceGuessName: 'Classic',
      deviceGuessSerial: 'NXS8620',
      items: [
        AiDraftItem(
          kind: 'service',
          name: 'Troca de óleo',
          value: 120,
          catalogId: 's1',
        ),
        AiDraftItem(kind: 'service', name: 'Polimento'),
        AiDraftItem(
          kind: 'product',
          name: 'Filtro de óleo',
          value: 35.5,
          quantity: 2,
          catalogId: 'p1',
        ),
      ],
      used: 1,
      limit: 10,
    );

    OrderScreenV2 assistantScreen(
      OrderStore store,
      FakeAssistant assistant, {
      Future<AiPhoto?> Function()? capture,
    }) => OrderScreenV2(
      store: store,
      permissions: _permissions(),
      actions: FakeActions(),
      catalogSource: source,
      catalogPermissions: _allCatalog,
      mostUsed: () async => const [],
      showAssistant: true,
      assistant: assistant,
      capturePhoto: capture ?? () async => AiPhoto(png),
    );

    AppListRow rowOf(WidgetTester tester, String text) =>
        tester.widget<AppListRow>(
          find.ancestor(of: find.text(text), matching: find.byType(AppListRow)),
        );

    testWidgets('flag is off by default and hides Foto / Falar', (
      tester,
    ) async {
      expect(kAiOrderAssistEnabled, isFalse);
      await _pump(
        tester,
        OrderScreenV2(
          store: OrderStore(),
          permissions: _permissions(),
          actions: FakeActions(),
        ),
      );
      expect(find.text('Foto'), findsNothing);
      expect(find.text('Falar o que fazer'), findsNothing);
      expect(find.text('Tire foto da placa e fale o serviço'), findsNothing);
    });

    testWidgets('with the flag: shown on the blank new order only', (
      tester,
    ) async {
      await _pump(tester, assistantScreen(OrderStore(), FakeAssistant(draft)));
      expect(find.text('Foto'), findsOneWidget);
      expect(find.text('Falar o que fazer'), findsOneWidget);
      expect(find.text('Tire foto da placa e fale o serviço'), findsOneWidget);
    });

    testWidgets(
      'Falar fills the same blank order and highlights what the AI put',
      (tester) async {
        final store = OrderStore();
        final assistant = FakeAssistant(draft);
        await _pump(tester, assistantScreen(store, assistant));

        await tester.tap(find.text('Falar o que fazer'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(CupertinoTextField),
          'Revenda Sul, troca de óleo',
        );
        await tester.pump();
        await tester.tap(find.text('Pronto'));
        await tester.pumpAndSettle();

        expect(assistant.texts, ['Revenda Sul, troca de óleo']);
        expect(assistant.photoCounts, [0]);

        // Same screen, still not saved.
        expect(store.deferSave, isTrue);
        expect(store.order!.id, isNull);
        expect(
          find.text('Confira o que está marcado em amarelo antes de salvar.'),
          findsOneWidget,
        );

        expect(rowOf(tester, 'Revenda Sul').marked, isTrue);
        expect(rowOf(tester, 'Troca de óleo').marked, isTrue);
        expect(rowOf(tester, 'Polimento').marked, isTrue);
        expect(rowOf(tester, 'Filtro de óleo').marked, isTrue);
        expect(
          rowOf(tester, '“Classic · NXS8620” não está no cadastro').marked,
          isTrue,
        );
        expect(store.services!.map((s) => s.service?.id), ['s1', null]);
        expect(store.services![1].value, isNull); // "sem valor"
        expect(store.products!.single.quantity, 2);
        expect(find.text('sem valor'), findsOneWidget);

        // Button stays "Salvar OS"; saving clears the highlighter.
        await tester.tap(find.textContaining('Salvar'));
        await tester.pumpAndSettle();
        expect(store.deferSave, isFalse);
        expect(rowOf(tester, 'Polimento').marked, isFalse);
      },
    );

    testWidgets('the camera opens only when Foto is tapped', (tester) async {
      var cameraOpened = 0;
      final assistant = FakeAssistant(draft);
      await _pump(
        tester,
        assistantScreen(
          OrderStore(),
          assistant,
          capture: () async {
            cameraOpened++;
            return AiPhoto(png);
          },
        ),
      );
      expect(cameraOpened, 0);

      await tester.tap(find.text('Foto'));
      await tester.pumpAndSettle();
      expect(cameraOpened, 1);
      expect(find.text('1 foto'), findsOneWidget);

      await tester.tap(find.text('Pronto'));
      await tester.pumpAndSettle();
      expect(assistant.photoCounts, [1]);
      expect(rowOf(tester, 'Polimento').marked, isTrue);
    });

    testWidgets('quota exceeded shows a clear message and keeps manual flow', (
      tester,
    ) async {
      final store = OrderStore();
      final assistant = FakeAssistant(
        draft,
        error: const AiOrderAssistException(
          AiAssistError.quotaExceeded,
          used: 10,
          limit: 10,
        ),
      );
      await _pump(tester, assistantScreen(store, assistant));

      await tester.tap(find.text('Falar o que fazer'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), 'polimento');
      await tester.pump();
      await tester.tap(find.text('Pronto'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Você já usou os 10 pedidos do assistente deste mês. '
          'Dá para continuar preenchendo à mão.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(store.services, isEmpty);
      expect(find.text('Quem é o cliente?'), findsOneWidget);
    });
  });

  group('"O que vai na OS?"', () {
    testWidgets('one search over services and products; tapping adds', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(tester, screen(store));

      await tester.tap(find.text('O que vai na OS?'));
      await tester.pumpAndSettle();
      expect(find.text('Troca de óleo'), findsOneWidget);
      expect(find.text('Filtro de óleo'), findsOneWidget);
      expect(find.text('serviço'), findsNWidgets(2));
      expect(find.text('produto'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoSearchTextField), 'oleo');
      await tester.pumpAndSettle();
      expect(find.text('Alinhamento'), findsNothing);
      await tester.tap(find.text('Filtro de óleo'));
      await tester.pumpAndSettle();

      expect(store.products!.single.product!.name, 'Filtro de óleo');
      expect(store.products!.single.quantity, 1);
      expect(find.text('Filtro de óleo'), findsOneWidget);
      expect(find.text(_money(35.5)), findsNWidgets(2)); // row + total
    });

    testWidgets('"Criar “X” e pôr na OS" creates without price and adds', (
      tester,
    ) async {
      final catalog = FakeSource(services: [_item('s1', 'Troca de óleo', 120)]);
      final store = OrderStore();
      await _pump(tester, screen(store, catalog: catalog));

      await tester.tap(find.text('O que vai na OS?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(CupertinoSearchTextField),
        'Troca de embreagem',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Criar “Troca de embreagem” e pôr na OS'));
      await tester.pumpAndSettle();

      expect(catalog.saved.single.$1, CatalogKind.service);
      expect(catalog.saved.single.$2.name, 'Troca de embreagem');
      expect(catalog.saved.single.$2.value, isNull);
      expect(store.services!.single.value, isNull);
      expect(find.text('Troca de embreagem'), findsOneWidget);
      expect(find.text('sem valor'), findsOneWidget);
      expect(find.text('1 item sem valor, fora do total'), findsOneWidget);
    });

    testWidgets('no create row without manageServices/manageProducts', (
      tester,
    ) async {
      await _pump(
        tester,
        screen(
          OrderStore(),
          catalogPermissions: CatalogPermissions(
            {PermissionType.viewServices, PermissionType.viewProducts}.contains,
          ),
        ),
      );
      await tester.tap(find.text('O que vai na OS?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoSearchTextField), 'Nova');
      await tester.pumpAndSettle();
      expect(find.textContaining('Criar “Nova”'), findsNothing);
    });

    testWidgets('"Mais usados" comes first, from the last orders', (
      tester,
    ) async {
      await _pump(
        tester,
        OrderScreenV2(
          store: OrderStore(),
          permissions: _permissions(),
          actions: FakeActions(),
          catalogSource: source,
          catalogPermissions: _allCatalog,
          mostUsed: () async => const ['product:p1'],
        ),
      );
      await tester.tap(find.text('O que vai na OS?'));
      await tester.pumpAndSettle();
      expect(find.text('Mais usados'), findsOneWidget);
      expect(find.text('Filtro de óleo'), findsNWidgets(2));
      final top = tester.getTopLeft(find.text('Filtro de óleo').first);
      expect(top.dy, lessThan(tester.getTopLeft(find.text('Alinhamento')).dy));
    });

    testWidgets('an item without price gets one in its sheet', (tester) async {
      final store = OrderStore();
      await _pump(tester, screen(store));
      await tester.tap(find.text('O que vai na OS?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alinhamento'));
      await tester.pumpAndSettle();
      expect(find.text('sem valor'), findsOneWidget);

      await tester.tap(find.text('Alinhamento'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), '8000');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(store.services!.single.value, 80);
      expect(find.text('sem valor'), findsNothing);
      expect(store.total, 80);
    });

    testWidgets('"Tirar da OS" removes the item', (tester) async {
      final store = OrderStore();
      await _pump(tester, screen(store));
      await tester.tap(find.text('O que vai na OS?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Troca de óleo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Troca de óleo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tirar da OS'));
      await tester.pumpAndSettle();
      expect(store.services, isEmpty);
      expect(find.text('Troca de óleo'), findsNothing);
    });

    testWidgets('exact name match hides the create row', (tester) async {
      await _pump(tester, screen(OrderStore()));
      await tester.tap(find.text('O que vai na OS?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(CupertinoSearchTextField),
        'alinhamento',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Criar “'), findsNothing);
      expect(find.text('Alinhamento'), findsOneWidget);
    });
  });

  group('existing order', () {
    Order order() => Order()
      ..id = 'o1'
      ..number = 186
      ..status = 'quote'
      ..customer = (CustomerAggr()
        ..id = 'c1'
        ..name = 'Ana Souza')
      ..services = [
        OrderService()
          ..service = (ServiceAggr()..name = 'Polimento')
          ..value = 450,
        OrderService()..service = (ServiceAggr()..name = 'Porta traseira'),
      ]
      ..products = [
        OrderProduct()
          ..product = (ProductAggr()..name = 'Cera')
          ..value = 25
          ..quantity = 2
          ..total = 50,
        OrderProduct()
          ..product = (ProductAggr()..name = 'Lixa')
          ..quantity = 1,
      ]
      ..discount = 0
      ..paidAmount = 0
      ..transactions = [];

    testWidgets('items without price show "sem valor" and are not summed', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(tester, screen(store), args: {'order': order()});

      expect(find.text('sem valor'), findsNWidgets(2));
      expect(find.text('2 itens sem valor, fora do total'), findsOneWidget);
      expect(find.text(_money(500)), findsOneWidget); // 450 + 2 × 25
      expect(store.total, 500);
    });

    testWidgets('without viewPrices no price, total or "sem valor"', (
      tester,
    ) async {
      await _pump(
        tester,
        screen(OrderStore(), prices: false),
        args: {'order': order()},
      );
      expect(find.text('sem valor'), findsNothing);
      expect(find.text('Total'), findsNothing);
      expect(find.text('Polimento'), findsOneWidget);
    });

    testWidgets('without values and billing a done order has no "Receber" nor '
        '"Falta receber"', (tester) async {
      final actions = FakeActions();
      await _pump(
        tester,
        screen(OrderStore(), actions: actions, prices: false),
        args: {'order': order()..status = 'done'},
      );
      expect(find.textContaining('Receber'), findsNothing);
      expect(find.textContaining('Falta receber'), findsNothing);
      expect(find.text(_money(500)), findsNothing);
    });

    testWidgets('next step by status is the only blue button', (tester) async {
      await _pump(tester, screen(OrderStore()), args: {'order': order()});
      expect(find.text('Orçamento pronto para o cliente'), findsOneWidget);
      expect(find.text('Cliente aprovou'), findsOneWidget);
      expect(find.textContaining('Salvar'), findsNothing);
    });

    testWidgets('status sits in the top block; no customer section (app-os)', (
      tester,
    ) async {
      await _pump(tester, screen(OrderStore()), args: {'order': order()});

      final block = find
          .ancestor(
            of: find.text('Orçamento pronto para o cliente'),
            matching: find.byType(Container),
          )
          .first;
      expect(
        find.descendant(of: block, matching: find.text('Orçamento')),
        findsOneWidget,
      );
      // Customer only in the header, not as its own row.
      expect(find.widgetWithText(AppListRow, 'Ana Souza'), findsNothing);
      // Total closes the list of items.
      expect(
        tester.getTopLeft(find.text('Total')).dy,
        greaterThan(tester.getTopLeft(find.text('Lixa')).dy),
      );

      await tester.tap(find.byKey(const ValueKey('order_header_subtitle')));
      await tester.pumpAndSettle();
      expect(find.text('Trocar cliente'), findsOneWidget);
    });

    testWidgets('done with balance: "Receber" opens payments', (tester) async {
      final actions = FakeActions();
      await _pump(
        tester,
        screen(OrderStore(), actions: actions),
        args: {'order': order()..status = 'done'},
      );
      expect(find.text('Pronto. Falta receber ${_money(500)}'), findsOneWidget);
      await tester.tap(find.text('Receber ${_money(500)}'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['payments']);
    });

    testWidgets('"Adicionar à OS" > "Serviço ou peça" opens the item picker', (
      tester,
    ) async {
      await _pump(tester, screen(OrderStore()), args: {'order': order()});
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis_circle));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar à OS ›'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Serviço ou peça'));
      await tester.pumpAndSettle();
      expect(find.text('Troca de óleo'), findsOneWidget);
    });

    testWidgets('"…" has 3 groups: add, send · PDF, cancel / delete', (
      tester,
    ) async {
      await _pump(tester, screen(OrderStore()), args: {'order': order()});
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis_circle));
      await tester.pumpAndSettle();

      final labels = tester
          .widgetList<CupertinoActionSheetAction>(
            find.byType(CupertinoActionSheetAction),
          )
          .map((a) => ((a.child as Text).data ?? ''))
          .toList();
      expect(labels, hasLength(6)); // 5 actions + "Cancelar" button
      expect(labels[0], 'Adicionar à OS ›');
      expect(labels[1], 'Mandar para o cliente');
      expect(labels[2], 'PDF da OS');
      expect(labels[3], 'Cancelar OS');
      expect(labels[4], 'Apagar OS');
    });
  });

  group('segment custom fields', () {
    const brand = CustomField(
      key: 'service_order.brand',
      type: 'text',
      labels: {'pt-BR': 'Marca do lacre'},
      section: 'Lacre',
      sectionI18n: {'pt-BR': 'Lacre'},
    );
    const builtIn = CustomField(
      key: 'service_order.status',
      type: 'text',
      labels: {'pt-BR': 'Status custom'},
    );

    setUp(
      () => SegmentConfigService().debugSetCustomFields(const [brand, builtIn]),
    );
    tearDown(() => SegmentConfigService().debugSetCustomFields(const []));

    Order saved() => Order()
      ..id = 'o1'
      ..number = 7
      ..status = 'quote'
      ..customer = (CustomerAggr()
        ..id = 'c1'
        ..name = 'Ana Souza')
      ..customData = {'brand': 'ABC-123'}
      ..services = []
      ..products = []
      ..discount = 0
      ..paidAmount = 0
      ..transactions = [];

    testWidgets('shows the segment fields with the saved value; built-ins '
        'are not duplicated', (tester) async {
      await _pump(tester, screen(OrderStore()), args: {'order': saved()});
      expect(find.text('Marca do lacre'), findsOneWidget);
      expect(find.text('ABC-123'), findsOneWidget);
      expect(find.text('Status custom'), findsNothing);
    });

    testWidgets('editing saves into order.customData; clearing removes it', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(tester, screen(store), args: {'order': saved()});

      await tester.enterText(find.byType(EditableText).first, 'XYZ-9');
      await tester.pump();
      expect(store.order!.customData, {'brand': 'XYZ-9'});

      await tester.enterText(find.byType(EditableText).first, '');
      await tester.pump();
      expect(store.order!.customData, isNull);
    });

    testWidgets('no fields configured, no section', (tester) async {
      SegmentConfigService().debugSetCustomFields(const []);
      await _pump(tester, screen(OrderStore()), args: {'order': saved()});
      expect(find.text('Marca do lacre'), findsNothing);
      expect(find.byType(EditableText), findsNothing);
    });
  });

  group('two or more vehicles', () {
    Order twoCars() => Order()
      ..id = 'o2'
      ..number = 9
      ..status = 'quote'
      ..customer = (CustomerAggr()
        ..id = 'c1'
        ..name = 'Ana Souza')
      ..devices = [
        DeviceAggr()
          ..id = 'd1'
          ..name = 'Gol'
          ..serial = 'AAA1A11',
        DeviceAggr()
          ..id = 'd2'
          ..name = 'Uno',
      ]
      ..services = [
        OrderService()
          ..service = (ServiceAggr()..name = 'Polimento')
          ..value = 100
          ..deviceId = 'd1',
        OrderService()
          ..service = (ServiceAggr()..name = 'Revisão')
          ..value = 300
          ..deviceId = 'd2',
        OrderService()
          ..service = (ServiceAggr()..name = 'Taxa de busca')
          ..value = 20,
      ]
      ..products = [
        OrderProduct()
          ..product = (ProductAggr()..name = 'Cera')
          ..value = 25
          ..quantity = 2
          ..total = 50
          ..deviceId = 'd1',
      ]
      ..discount = 0
      ..paidAmount = 0
      ..transactions = [];

    testWidgets('items are grouped per vehicle with a subtotal each', (
      tester,
    ) async {
      await _pump(tester, screen(OrderStore()), args: {'order': twoCars()});

      expect(find.text('Gol - AAA1A11'), findsWidgets);
      expect(find.text('Geral'), findsOneWidget);
      expect(find.text('Subtotal'), findsNWidgets(3));
      expect(find.text(_money(150)), findsOneWidget); // Gol: 100 + 2 × 25
      expect(find.text(_money(300)), findsNWidgets(2)); // Uno + its row
      expect(find.text(_money(20)), findsNWidgets(2)); // Geral + its row
      expect(find.text(_money(470)), findsOneWidget); // Total
      // Order of the blocks: Gol, Uno, Geral.
      final gol = tester.getTopLeft(find.text('Polimento')).dy;
      final uno = tester.getTopLeft(find.text('Revisão')).dy;
      final general = tester.getTopLeft(find.text('Taxa de busca')).dy;
      expect(gol, lessThan(uno));
      expect(uno, lessThan(general));
    });

    testWidgets('without viewPrices no subtotals', (tester) async {
      await _pump(
        tester,
        screen(OrderStore(), prices: false),
        args: {'order': twoCars()},
      );
      expect(find.text('Subtotal'), findsNothing);
      expect(find.text('Revisão'), findsOneWidget);
    });

    testWidgets('one vehicle keeps the flat list', (tester) async {
      final order = twoCars()..devices = [twoCars().devices!.first];
      await _pump(tester, screen(OrderStore()), args: {'order': order});
      expect(find.text('Subtotal'), findsNothing);
      expect(find.text('Geral'), findsNothing);
    });

    testWidgets('adding an item asks which vehicle and files it there', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(
        tester,
        OrderScreenV2(
          store: store,
          permissions: _permissions(),
          actions: FakeActions(),
          catalogSource: source,
          catalogPermissions: _allCatalog,
          mostUsed: () async => const [],
          devicePicker: (_, devices) async =>
              DevicePickerResult(DevicePickerAction.specific, devices.last),
        ),
        args: {'order': twoCars()},
      );

      await tester.ensureVisible(find.text('O que vai na OS?'));
      await tester.pump();
      await tester.tap(find.text('O que vai na OS?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alinhamento'));
      await tester.pumpAndSettle();

      final added = store.services!.last;
      expect(added.service!.name, 'Alinhamento');
      expect(added.deviceId, 'd2');
      expect(store.pendingDeviceId, isNull);
    });

    testWidgets('cancelling the vehicle question adds nothing', (tester) async {
      final store = OrderStore();
      await _pump(
        tester,
        OrderScreenV2(
          store: store,
          permissions: _permissions(),
          actions: FakeActions(),
          catalogSource: source,
          catalogPermissions: _allCatalog,
          mostUsed: () async => const [],
          devicePicker: (_, _) async => null,
        ),
        args: {'order': twoCars()},
      );
      await tester.ensureVisible(find.text('O que vai na OS?'));
      await tester.pump();
      await tester.tap(find.text('O que vai na OS?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alinhamento'));
      await tester.pumpAndSettle();
      expect(store.services, hasLength(3));
    });

    test('applyDevicePick maps each answer to the store', () {
      final store = OrderStore();
      applyDevicePick(store, DevicePickerResult.multi(['d1', 'd2']));
      expect(store.pendingDeviceIds, ['d1', 'd2']);
      applyDevicePick(store, DevicePickerResult(DevicePickerAction.all));
      expect(store.pendingDuplicateAll, isTrue);
      expect(store.pendingDeviceIds, isNull);
      applyDevicePick(store, DevicePickerResult(DevicePickerAction.general));
      expect(store.pendingDuplicateAll, isFalse);
      expect(store.pendingDeviceId, isNull);
    });
  });
}
