import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/order_store.dart';
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
import 'package:praticos/screens/widgets/status_dot.dart';
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
          CatalogKind kind, CatalogItem item, PhotoOrigin from) async =>
      null;
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
      create: (_) => SegmentConfigProvider()
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

  OrderScreenV2 screen(OrderStore store,
          {FakeSource? catalog,
          CatalogPermissions catalogPermissions = _allCatalog,
          OrderScreenActions? actions,
          bool prices = true}) =>
      OrderScreenV2(
        store: store,
        permissions: _permissions(prices: prices),
        actions: actions ?? FakeActions(),
        catalogSource: catalog ?? source,
        catalogPermissions: catalogPermissions,
        mostUsed: () async => const [],
      );

  group('new order', () {
    testWidgets('opens the order itself, blank, with nothing saved',
        (tester) async {
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
      final save = tester.widget<CupertinoButton>(find.ancestor(
        of: find.textContaining('Salvar'),
        matching: find.byType(CupertinoButton),
      ));
      expect(save.onPressed, isNull);
    });

    testWidgets('customer picker fills customer and vehicle; Salvar OS saves',
        (tester) async {
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

    testWidgets('status row changes the status with a dot and neutral text',
        (tester) async {
      final store = OrderStore();
      await _pump(tester, screen(store));

      await tester.tap(find.text('Mudar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aprovado').last);
      await tester.pumpAndSettle();
      expect(store.status, 'approved');
    });

    testWidgets('assistant placeholders are disabled when shown',
        (tester) async {
      await _pump(
        tester,
        OrderScreenV2(
          store: OrderStore(),
          permissions: _permissions(),
          actions: FakeActions(),
          showAssistant: true,
        ),
      );
      expect(find.text('Foto'), findsOneWidget);
      expect(find.text('Falar o que fazer'), findsOneWidget);
    });
  });

  group('"O que vai na OS?"', () {
    testWidgets('one search over services and products; tapping adds',
        (tester) async {
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

    testWidgets('"Criar “X” e pôr na OS" creates without price and adds',
        (tester) async {
      final catalog = FakeSource(services: [_item('s1', 'Troca de óleo', 120)]);
      final store = OrderStore();
      await _pump(tester, screen(store, catalog: catalog));

      await tester.tap(find.text('O que vai na OS?'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(CupertinoSearchTextField), 'Troca de embreagem');
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

    testWidgets('no create row without manageServices/manageProducts',
        (tester) async {
      await _pump(
        tester,
        screen(
          OrderStore(),
          catalogPermissions: CatalogPermissions({
            PermissionType.viewServices,
            PermissionType.viewProducts,
          }.contains),
        ),
      );
      await tester.tap(find.text('O que vai na OS?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoSearchTextField), 'Nova');
      await tester.pumpAndSettle();
      expect(find.textContaining('Criar “Nova”'), findsNothing);
    });

    testWidgets('"Mais usados" comes first, from the last orders',
        (tester) async {
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
          find.byType(CupertinoSearchTextField), 'alinhamento');
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

    testWidgets('items without price show "sem valor" and are not summed',
        (tester) async {
      final store = OrderStore();
      await _pump(tester, screen(store), args: {'order': order()});

      expect(find.text('sem valor'), findsNWidgets(2));
      expect(find.text('2 itens sem valor, fora do total'), findsOneWidget);
      expect(find.text(_money(500)), findsOneWidget); // 450 + 2 × 25
      expect(store.total, 500);
    });

    testWidgets('without viewPrices no price, total or "sem valor"',
        (tester) async {
      await _pump(tester, screen(OrderStore(), prices: false),
          args: {'order': order()});
      expect(find.text('sem valor'), findsNothing);
      expect(find.text('Total'), findsNothing);
      expect(find.text('Polimento'), findsOneWidget);
    });

    testWidgets('next step by status is the only blue button', (tester) async {
      await _pump(tester, screen(OrderStore()), args: {'order': order()});
      expect(find.text('Orçamento pronto para o cliente'), findsOneWidget);
      expect(find.text('Cliente aprovou'), findsOneWidget);
      expect(find.textContaining('Salvar'), findsNothing);
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

    testWidgets('"…" has 3 groups: add, send · PDF, cancel / delete',
        (tester) async {
      await _pump(tester, screen(OrderStore()), args: {'order': order()});
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis_circle));
      await tester.pumpAndSettle();

      final labels = tester
          .widgetList<CupertinoActionSheetAction>(
              find.byType(CupertinoActionSheetAction))
          .map((a) => ((a.child as Text).data ?? ''))
          .toList();
      expect(labels, hasLength(6)); // 5 actions + "Cancelar" button
      expect(labels[0], endsWith('›'));
      expect(labels[1], 'Mandar para o cliente');
      expect(labels[2], 'PDF');
      expect(labels[3], startsWith('Cancelar '));
      expect(labels[4], startsWith('Apagar '));
    });
  });
}
