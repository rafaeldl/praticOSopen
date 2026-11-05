import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/catalog/catalog_source.dart';
import 'package:praticos/screens/order/order_item_form.dart';
import 'package:praticos/screens/order_product_screen.dart';
import 'package:praticos/screens/order_service_screen.dart';
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

OrderStore _store({List<DeviceAggr> devices = const []}) {
  final store = OrderStore();
  store.order = Order()
    ..services = [
      OrderService()
        ..service = (ServiceAggr()
          ..id = 's1'
          ..name = 'Troca de óleo do motor com filtro e revisão completa'
          ..value = 120)
        ..value = 120
        ..description = 'Óleo 5W30',
    ]
    ..products = [
      OrderProduct()
        ..product = (ProductAggr()
          ..id = 'p1'
          ..name = 'Filtro de óleo'
          ..value = 35.5)
        ..value = 35.5
        ..quantity = 2
        ..total = 71
        ..description = 'Original',
    ];
  store.updateOrder();
  store.devices.addAll(devices);
  return store;
}

/// Opens [screen] pushed over a host page, with the route [args].
Future<void> _open(
  WidgetTester tester,
  Widget screen,
  Map<String, dynamic> args, {
  double textScale = 1,
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () => Navigator.push(
                  context,
                  CupertinoPageRoute(
                    settings: RouteSettings(arguments: args),
                    builder: (_) => screen,
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(ValueKey(k));

EditableText _editable(WidgetTester tester, String key) =>
    tester.widget<EditableText>(
      find.descendant(of: _key(key), matching: find.byType(EditableText)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  // No company: OrderStore.createItem never reaches Firestore in tests.
  setUp(() => Global.companyAggr = null);

  group('service line', () {
    const screen = OrderServiceScreen(
      canEditMainFields: true,
      canViewPrices: true,
      canManageCatalog: false,
    );

    testWidgets('opens prefilled: name, value, notes, "…" and Salvar', (
      tester,
    ) async {
      final store = _store();
      await _open(tester, screen, {
        'orderStore': store,
        'orderServiceIndex': 0,
      });

      expect(
        find.text('Troca de óleo do motor com filtro e revisão completa'),
        findsOneWidget,
      );
      expect(
        _editable(tester, 'order_item_value').controller.text,
        contains('120,00'),
      );
      expect(
        _editable(tester, 'order_item_notes').controller.text,
        'Óleo 5W30',
      );
      expect(_key('order_item_more'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
      // Sentence case labels.
      expect(find.text('Valor'), findsOneWidget);
      expect(find.text('Observações'), findsOneWidget);
    });

    testWidgets('Salvar writes the new value and notes and closes', (
      tester,
    ) async {
      final store = _store();
      await _open(tester, screen, {
        'orderStore': store,
        'orderServiceIndex': 0,
      });

      await tester.enterText(_key('order_item_value'), '150');
      await tester.enterText(_key('order_item_notes'), 'Óleo 0W20');
      await tester.tap(_key('order_item_save'));
      await tester.pumpAndSettle();

      expect(store.order!.services!.first.value, 150);
      expect(store.order!.services!.first.description, 'Óleo 0W20');
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('blank value asks for it and does not close', (tester) async {
      final store = _store();
      await _open(tester, screen, {
        'orderStore': store,
        'orderServiceIndex': 0,
      });

      await tester.enterText(_key('order_item_value'), '');
      await tester.tap(_key('order_item_save'));
      await tester.pumpAndSettle();

      expect(find.text('abrir'), findsNothing);
      expect(store.order!.services!.first.value, 120);
    });

    testWidgets('"…" > Tirar da OS asks first; cancel keeps the line', (
      tester,
    ) async {
      final store = _store();
      await _open(tester, screen, {
        'orderStore': store,
        'orderServiceIndex': 0,
      });

      await tester.tap(_key('order_item_more'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tirar da OS'));
      await tester.pumpAndSettle();

      expect(find.text('Tirar da OS?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(store.order!.services, hasLength(1));

      await tester.tap(_key('order_item_more'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tirar da OS'));
      await tester.pumpAndSettle();
      await tester.tap(_key('order_item_remove_confirm'));
      await tester.pumpAndSettle();

      expect(store.order!.services, isEmpty);
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('new line from the catalog: no "…", value from catalog', (
      tester,
    ) async {
      final store = _store();
      final service = Service()
        ..id = 's2'
        ..name = 'Alinhamento'
        ..value = 80;
      await _open(tester, screen, {'orderStore': store, 'service': service});

      expect(find.text('Alinhamento'), findsOneWidget);
      expect(_key('order_item_more'), findsNothing);
      expect(
        _editable(tester, 'order_item_value').controller.text,
        contains('80,00'),
      );
    });

    testWidgets('without permission: no value, no "…", notes still edit', (
      tester,
    ) async {
      final store = _store();
      await _open(
        tester,
        const OrderServiceScreen(
          canEditMainFields: false,
          canViewPrices: true,
          canManageCatalog: false,
        ),
        {'orderStore': store, 'orderServiceIndex': 0},
      );

      expect(_key('order_item_value'), findsNothing);
      expect(_key('order_item_more'), findsNothing);
      expect(_key('order_item_notes'), findsOneWidget);
    });

    testWidgets('2+ devices: picker sets the device of the line', (
      tester,
    ) async {
      final store = _store(
        devices: [
          DeviceAggr()
            ..id = 'd1'
            ..name = 'Gol',
          DeviceAggr()
            ..id = 'd2'
            ..name = 'Uno',
        ],
      );
      await _open(tester, screen, {
        'orderStore': store,
        'orderServiceIndex': 0,
      });

      await tester.tap(_key('order_item_device'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uno'));
      await tester.pumpAndSettle();
      expect(store.order!.services!.first.deviceId, 'd2');
    });

    testWidgets('largest text: no overflow', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await _open(tester, screen, {
        'orderStore': _store(),
        'orderServiceIndex': 0,
      }, textScale: 2.2);
      expect(tester.takeException(), isNull);
    });
  });

  group('product line', () {
    const screen = OrderProductScreen(
      canEditMainFields: true,
      canViewPrices: true,
      canManageCatalog: false,
    );

    testWidgets('opens prefilled: quantity, unit value and total', (
      tester,
    ) async {
      await _open(tester, screen, {
        'orderStore': _store(),
        'orderProductIndex': 0,
      });

      expect(find.text('Filtro de óleo'), findsOneWidget);
      expect(_editable(tester, 'order_item_quantity').controller.text, '2');
      expect(
        _editable(tester, 'order_item_value').controller.text,
        contains('35,50'),
      );
      expect(
        tester.widget<Text>(_key('order_item_total')).data,
        contains('71,00'),
      );
      expect(find.text('Quantidade'), findsOneWidget);
      expect(find.text('Valor unitário'), findsOneWidget);
    });

    testWidgets('+ and − change the quantity; total follows; Salvar writes', (
      tester,
    ) async {
      final store = _store();
      await _open(tester, screen, {
        'orderStore': store,
        'orderProductIndex': 0,
      });

      await tester.tap(_key('order_item_more_one'));
      await tester.pump();
      await tester.tap(_key('order_item_more_one'));
      await tester.pump();
      await tester.tap(_key('order_item_less'));
      await tester.pump();
      expect(_editable(tester, 'order_item_quantity').controller.text, '3');
      expect(
        tester.widget<Text>(_key('order_item_total')).data,
        contains('106,50'),
      );

      await tester.enterText(_key('order_item_value'), '40');
      await tester.tap(_key('order_item_save'));
      await tester.pumpAndSettle();

      final line = store.order!.products!.first;
      expect(line.quantity, 3);
      expect(line.value, 40);
      expect(line.total, 120);
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('quantity 0 is refused', (tester) async {
      final store = _store();
      await _open(tester, screen, {
        'orderStore': store,
        'orderProductIndex': 0,
      });

      await tester.enterText(_key('order_item_quantity'), '0');
      await tester.tap(_key('order_item_save'));
      await tester.pumpAndSettle();

      expect(find.text('Coloque pelo menos 1.'), findsOneWidget);
      expect(store.order!.products!.first.quantity, 2);
    });

    testWidgets('"…" > Tirar da OS removes after confirming', (tester) async {
      final store = _store();
      await _open(tester, screen, {
        'orderStore': store,
        'orderProductIndex': 0,
      });

      await tester.tap(_key('order_item_more'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tirar da OS'));
      await tester.pumpAndSettle();
      expect(find.text('Tirar da OS?'), findsOneWidget);
      await tester.tap(_key('order_item_remove_confirm'));
      await tester.pumpAndSettle();

      expect(store.order!.products, isEmpty);
    });

    testWidgets('largest text: no overflow', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await _open(tester, screen, {
        'orderStore': _store(),
        'orderProductIndex': 0,
      }, textScale: 2.2);
      expect(tester.takeException(), isNull);
    });
  });

  group('new price: only here or always (#588)', () {
    late List<(CatalogKind, String, double?)> writes;
    Future<void> writer(CatalogKind kind, String id, double? value) async =>
        writes.add((kind, id, value));
    setUp(() => writes = []);

    OrderServiceScreen serviceScreen({bool canManage = true}) =>
        OrderServiceScreen(
          canEditMainFields: true,
          canViewPrices: true,
          canManageCatalog: canManage,
          catalogPriceWriter: writer,
        );

    testWidgets('"Usar sempre" saves the line and the catalog price', (
      tester,
    ) async {
      final store = _store();
      await _open(tester, serviceScreen(), {
        'orderStore': store,
        'orderServiceIndex': 0,
      });

      await tester.enterText(_key('order_item_value'), '150');
      await tester.tap(_key('order_item_save'));
      await tester.pumpAndSettle();

      expect(find.text('Mudar o preço no Catálogo?'), findsOneWidget);
      expect(find.textContaining('Serviço “Troca de óleo'), findsOneWidget);
      await tester.tap(_key('order_item_catalog_price_always'));
      await tester.pumpAndSettle();

      expect(writes, [(CatalogKind.service, 's1', 150.0)]);
      expect(store.order!.services!.first.value, 150);
      expect(store.order!.services!.first.service!.value, 150);
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('"Só nesta OS" keeps the catalog as it was', (tester) async {
      final store = _store();
      await _open(tester, serviceScreen(), {
        'orderStore': store,
        'orderServiceIndex': 0,
      });

      await tester.enterText(_key('order_item_value'), '150');
      await tester.tap(_key('order_item_save'));
      await tester.pumpAndSettle();
      await tester.tap(_key('order_item_catalog_price_only_here'));
      await tester.pumpAndSettle();

      expect(writes, isEmpty);
      expect(store.order!.services!.first.value, 150);
      expect(store.order!.services!.first.service!.value, 120);
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('same price: no question', (tester) async {
      final store = _store();
      await _open(tester, serviceScreen(), {
        'orderStore': store,
        'orderServiceIndex': 0,
      });

      await tester.enterText(_key('order_item_notes'), 'Outro óleo');
      await tester.tap(_key('order_item_save'));
      await tester.pumpAndSettle();

      expect(find.text('Mudar o preço no Catálogo?'), findsNothing);
      expect(writes, isEmpty);
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('loose item (not from the catalog): no question', (
      tester,
    ) async {
      final store = _store();
      store.order!.services!.first.service!.id = null;
      await _open(tester, serviceScreen(), {
        'orderStore': store,
        'orderServiceIndex': 0,
      });

      await tester.enterText(_key('order_item_value'), '150');
      await tester.tap(_key('order_item_save'));
      await tester.pumpAndSettle();

      expect(find.text('Mudar o preço no Catálogo?'), findsNothing);
      expect(store.order!.services!.first.value, 150);
    });

    testWidgets('cannot edit the catalog: no question', (tester) async {
      final store = _store();
      await _open(tester, serviceScreen(canManage: false), {
        'orderStore': store,
        'orderServiceIndex': 0,
      });

      await tester.enterText(_key('order_item_value'), '150');
      await tester.tap(_key('order_item_save'));
      await tester.pumpAndSettle();

      expect(find.text('Mudar o preço no Catálogo?'), findsNothing);
      expect(writes, isEmpty);
      expect(store.order!.services!.first.value, 150);
    });

    testWidgets('product: asks with the segment name and writes the product', (
      tester,
    ) async {
      final store = _store();
      await _open(
        tester,
        OrderProductScreen(
          canEditMainFields: true,
          canViewPrices: true,
          canManageCatalog: true,
          catalogPriceWriter: writer,
        ),
        {'orderStore': store, 'orderProductIndex': 0},
      );

      await tester.enterText(_key('order_item_value'), '40');
      await tester.tap(_key('order_item_save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Produto “Filtro de óleo”'), findsOneWidget);
      await tester.tap(_key('order_item_catalog_price_always'));
      await tester.pumpAndSettle();

      expect(writes, [(CatalogKind.product, 'p1', 40.0)]);
      expect(store.order!.products!.first.total, 80);
    });

    test('shouldOfferCatalogPrice', () {
      bool offer({
        String? id = 'x',
        double? catalog = 100,
        double? before = 100,
        double? now = 120,
        bool can = true,
      }) => shouldOfferCatalogPrice(
        catalogId: id,
        catalogValue: catalog,
        previousValue: before,
        newValue: now,
        canManageCatalog: can,
      );

      expect(offer(), isTrue);
      expect(offer(id: null), isFalse);
      expect(offer(can: false), isFalse);
      expect(offer(now: 100), isFalse);
      // Changed before ("só nesta OS"), not touched now.
      expect(offer(before: 120, now: 120), isFalse);
      // Back to the catalog price.
      expect(offer(before: 120, now: 100), isFalse);
      // Catalog without price.
      expect(offer(catalog: null, before: null), isTrue);
      expect(offer(now: 100.001), isFalse);
    });
  });
}
