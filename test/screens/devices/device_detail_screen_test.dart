import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/routes.dart';
import 'package:praticos/screens/devices/device_detail_screen.dart';
import 'package:provider/provider.dart';

/// Serves a fixed order history instead of querying Firestore.
class _FakeOrderRepository extends TenantOrderRepository {
  _FakeOrderRepository(this.orders);

  final List<Order?> orders;

  @override
  Stream<List<Order?>> streamOrdersByDevice(String companyId, String deviceId) =>
      Stream.value(orders);

  @override
  Stream<List<Order?>> streamContractsByDevice(String companyId, String deviceId) =>
      Stream.value(const []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // TenantOrderRepository reads FirebaseFirestore.instance in its fields.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => Global.companyAggr = CompanyAggr()..id = 'c1');
  tearDown(() => Global.companyAggr = null);

  testWidgets('tapping an order in the history opens it on the order route',
      (tester) async {
    final order = Order()
      ..id = 'o1'
      ..number = 42
      ..status = 'done';
    final device = Device()
      ..id = 'd1'
      ..name = 'Fiat Uno';
    final pushed = <RouteSettings>[];

    await tester.pumpWidget(
      ChangeNotifierProvider<SegmentConfigProvider>(
        create: (_) => SegmentConfigProvider(),
        child: CupertinoApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          initialRoute: '/device_detail',
          onGenerateRoute: (settings) {
            if (settings.name == '/device_detail') {
              return CupertinoPageRoute(
                settings: RouteSettings(
                  name: settings.name,
                  arguments: {'device': device},
                ),
                builder: (_) => DeviceDetailScreen(
                  orderRepository: _FakeOrderRepository([order]),
                  showPrices: true,
                ),
              );
            }
            pushed.add(settings);
            return CupertinoPageRoute(
              settings: settings,
              builder: (_) => const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    // initialRoute also generates '/'; only the tap matters.
    pushed.clear();

    final tile = find.textContaining('#42');
    await tester.scrollUntilVisible(tile, 200);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(pushed, hasLength(1));
    expect(pushed.single.name, '/order');
    expect(appRoutes.containsKey(pushed.single.name), isTrue);
    expect((pushed.single.arguments as Map)['order'], same(order));
  });

  Future<List<RouteSettings>> pumpDetail(
    WidgetTester tester,
    Device device,
    List<Order> orders, {
    Customer? customer,
    bool showPrices = true,
  }) async {
    final pushed = <RouteSettings>[];
    await tester.pumpWidget(
      ChangeNotifierProvider<SegmentConfigProvider>(
        create: (_) => SegmentConfigProvider(),
        child: CupertinoApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          initialRoute: '/device_detail',
          onGenerateRoute: (settings) {
            if (settings.name == '/device_detail') {
              return CupertinoPageRoute(
                settings: RouteSettings(
                  name: settings.name,
                  arguments: {'device': device, 'customer': customer},
                ),
                builder: (_) => DeviceDetailScreen(
                  orderRepository: _FakeOrderRepository(orders),
                  showPrices: showPrices,
                ),
              );
            }
            pushed.add(settings);
            return CupertinoPageRoute(
              settings: settings,
              builder: (_) => const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    pushed.clear();
    return pushed;
  }

  testWidgets('shows plate and owner, history rows and the Nova OS entry',
      (tester) async {
    final owner = Customer()
      ..id = 'c1'
      ..name = 'Ana Ribeiro';
    final device = Device()
      ..id = 'd1'
      ..name = 'Fiat Uno'
      ..serial = 'ABC1D23'
      ..manufacturer = 'Fiat';
    final orders = [
      Order()
        ..id = 'o1'
        ..number = 7
        ..status = 'done'
        ..total = 150,
    ];
    final pushed = await pumpDetail(tester, device, orders, customer: owner);

    expect(find.textContaining('ABC1D23'), findsOneWidget);
    expect(find.text('Ana Ribeiro'), findsWidgets);
    expect(find.text('Nova OS'), findsOneWidget);
    expect(find.textContaining('#7'), findsOneWidget);

    await tester.tap(find.text('Nova OS'));
    await tester.pumpAndSettle();
    expect(pushed.single.name, '/order');
    final order = (pushed.single.arguments as Map)['order'] as Order;
    expect(order.customer?.id, 'c1');
    expect(order.devices?.single.id, 'd1');
  });

  testWidgets('owner falls back to the customer of the latest order and opens '
      'the customer screen', (tester) async {
    final device = Device()
      ..id = 'd1'
      ..name = 'Fiat Uno';
    final orders = [
      Order()
        ..id = 'old'
        ..number = 1
        ..createdAt = DateTime(2024, 1, 1)
        ..customer = (CustomerAggr()
          ..id = 'c-old'
          ..name = 'Antigo'),
      Order()
        ..id = 'new'
        ..number = 2
        ..createdAt = DateTime(2025, 1, 1)
        ..customer = (CustomerAggr()
          ..id = 'c-new'
          ..name = 'Bruno Lima'),
    ];
    final pushed = await pumpDetail(tester, device, orders);

    expect(find.text('Bruno Lima'), findsWidgets);
    expect(find.text('Antigo'), findsNothing);

    await tester.tap(find.text('Bruno Lima').last);
    await tester.pumpAndSettle();
    expect(pushed.single.name, '/customer_detail');
    expect(((pushed.single.arguments as Map)['customer'] as Customer).id,
        'c-new');
  });

  testWidgets('vehicle without orders shows the empty history',
      (tester) async {
    final device = Device()
      ..id = 'd1'
      ..name = 'Fiat Uno';
    await pumpDetail(tester, device, const []);
    expect(find.text('Nenhuma ordem de serviço registrada'), findsOneWidget);
    expect(find.text('Histórico de OS'), findsOneWidget);
    expect(find.text('Nova OS'), findsOneWidget);
  });

  testWidgets('history hides order totals without values and billing',
      (tester) async {
    final device = Device()
      ..id = 'd1'
      ..name = 'Fiat Uno';
    final orders = [
      Order()
        ..id = 'o1'
        ..number = 7
        ..status = 'done'
        ..total = 150,
    ];
    await pumpDetail(tester, device, orders, showPrices: false);
    expect(find.textContaining('#7'), findsOneWidget);
    expect(find.textContaining('150,00'), findsNothing);
  });
}
