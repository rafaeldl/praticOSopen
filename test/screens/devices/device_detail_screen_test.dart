import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/custom_field.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/repositories/tenant/tenant_device_repository.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/routes.dart';
import 'package:praticos/screens/devices/device_detail_screen.dart';
import 'package:praticos/services/format_service.dart';
import 'package:provider/provider.dart';

/// Serves a fixed order history instead of querying Firestore.
class _FakeOrderRepository extends TenantOrderRepository {
  _FakeOrderRepository(this.orders, {this.contracts = const []});

  final List<Order?> orders;
  final List<Order?> contracts;

  @override
  Stream<List<Order?>> streamOrdersByDevice(
    String companyId,
    String deviceId,
  ) => Stream.value(orders);

  @override
  Stream<List<Order?>> streamContractsByDevice(
    String companyId,
    String deviceId,
  ) => Stream.value(contracts);
}

/// Serves the device as it is saved, which may differ from what the screen
/// received.
class _FakeDeviceRepository extends TenantDeviceRepository {
  _FakeDeviceRepository(this.device);

  final Device device;

  @override
  Stream<Device?> streamSingle(String companyId, String? id) =>
      Stream.value(device);
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

  testWidgets('tapping an order in the history opens it on the order route', (
    tester,
  ) async {
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

    final tile = find.textContaining('OS 42');
    await tester.scrollUntilVisible(tile, 200);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(pushed, hasLength(1));
    expect(pushed.single.name, '/order');
    expect(appRoutes.containsKey(pushed.single.name), isTrue);
    expect((pushed.single.arguments as Map)['order'], same(order));
  });

  group('formatDeviceNumber', () {
    final format = FormatService()..setLocale('pt');

    CustomField field(String key, String type) =>
        CustomField(key: key, type: type, labels: const {});

    test('groups a number field, typed or saved as a number', () {
      final mileage = field('device.mileage', 'number');
      expect(formatDeviceNumber(mileage, '98000', format), '98.000');
      expect(formatDeviceNumber(mileage, 98000, format), '98.000');
      expect(formatDeviceNumber(mileage, 98000.0, format), '98.000');
      expect(formatDeviceNumber(mileage, '1234567', format), '1.234.567');
      expect(formatDeviceNumber(mileage, '-5', format), '-5');
    });

    test('follows the language', () {
      final en = FormatService()..setLocale('en');
      expect(
        formatDeviceNumber(field('device.mileage', 'number'), '98000', en),
        '98,000',
      );
    });

    test('never the year, plate, serial or a text field', () {
      expect(formatDeviceNumber(field('device.year', 'number'), '2015', format), isNull);
      expect(formatDeviceNumber(field('device.serial', 'text'), '98000', format), isNull);
      expect(formatDeviceNumber(field('device.chassis', 'text'), '12345', format), isNull);
      expect(formatDeviceNumber(null, '98000', format), isNull);
    });

    test('leaves what is not a plain whole number as typed', () {
      final mileage = field('device.mileage', 'number');
      expect(formatDeviceNumber(mileage, '0123', format), isNull);
      expect(formatDeviceNumber(mileage, '98.5', format), isNull);
      expect(formatDeviceNumber(mileage, 98.5, format), isNull);
      expect(formatDeviceNumber(mileage, 'abc', format), isNull);
    });
  });

  group('next maintenance', () {
    Device aggregate() => Device()
      ..id = 'd1'
      ..name = 'Split';

    Device withDate(String day) => aggregate()..nextMaintenanceDate = day;

    final saves = <(DateTime?, String?, String?)>[];

    Future<void> pump(
      WidgetTester tester,
      Device saved, {
      bool canManage = true,
      List<Order?> contracts = const [],
      List<Order?> orders = const [],
    }) async {
      saves.clear();
      await tester.pumpWidget(
        ChangeNotifierProvider<SegmentConfigProvider>(
          create: (_) => SegmentConfigProvider(),
          child: CupertinoApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: DeviceDetailScreen(
              // What came from an order: no date, as an aggregate.
              device: aggregate(),
              orderRepository: _FakeOrderRepository(
                orders,
                contracts: contracts,
              ),
              deviceRepository: _FakeDeviceRepository(saved),
              canManageDevices: canManage,
              saveMaintenance: (id, date, customer, service, onFailed) =>
                  saves.add((date, customer?.name, service)),
              showPrices: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('reads the saved date, not the device that came in', (
      tester,
    ) async {
      await pump(tester, withDate('2027-05-12'));

      expect(find.text('Próxima manutenção: maio de 2027'), findsOneWidget);
      expect(find.text('Toque para mudar ou tirar'), findsOneWidget);
    });

    testWidgets('without a date it offers to set one', (tester) async {
      await pump(tester, aggregate());
      expect(find.text('Definir próxima manutenção'), findsOneWidget);
    });

    testWidgets('who cannot edit devices is not offered a date', (
      tester,
    ) async {
      await pump(tester, aggregate(), canManage: false);
      expect(find.text('Definir próxima manutenção'), findsNothing);
    });

    testWidgets('who cannot edit devices only reads it', (tester) async {
      await pump(tester, withDate('2027-05-12'), canManage: false);
      expect(find.text('Próxima manutenção: maio de 2027'), findsOneWidget);
      expect(find.text('Toque para mudar ou tirar'), findsNothing);
    });

    testWidgets('setting saves the date, with the owner from the orders', (
      tester,
    ) async {
      await pump(
        tester,
        aggregate(),
        orders: [
          Order()
            ..id = 'o1'
            ..status = 'done'
            ..services = [
              OrderService()..service = (ServiceAggr()..name = 'Limpeza'),
            ]
            ..customer = (CustomerAggr()..name = 'Padaria'),
        ],
      );

      await tester.tap(find.text('Definir próxima manutenção'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(saves, hasLength(1));
      expect(saves.single.$1, isNotNull);
      expect(saves.single.$2, 'Padaria');
      expect(saves.single.$3, 'Limpeza');
    });

    testWidgets('a double tap on "Salvar" stays on the screen', (tester) async {
      await pump(tester, aggregate());

      await tester.tap(find.text('Definir próxima manutenção'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Salvar'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(saves, hasLength(1));
      expect(find.byType(DeviceDetailScreen), findsOneWidget);
    });

    testWidgets('"Tirar" removes the date', (tester) async {
      await pump(tester, withDate('2027-05-12'));

      await tester.tap(find.text('Próxima manutenção: maio de 2027'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tirar'));
      await tester.pumpAndSettle();

      expect(saves.single.$1, isNull);
    });

    testWidgets('an active contract shows its date and asks for no other', (
      tester,
    ) async {
      final contract = Order()
        ..id = 'c1'
        ..contract = (OrderContract()
          ..active = true
          ..nextDueDate = DateTime(2027, 3, 1));
      await pump(tester, withDate('2027-05-12'), contracts: [contract]);

      expect(find.text('Próxima manutenção: março de 2027'), findsOneWidget);
      expect(find.text('Pelo contrato'), findsOneWidget);
      expect(find.text('Definir próxima manutenção'), findsNothing);
      expect(find.text('Próxima manutenção: maio de 2027'), findsNothing);
    });

    testWidgets('an ended contract gives the row back', (tester) async {
      final ended = Order()
        ..id = 'c1'
        ..contract = (OrderContract()..active = false);
      await pump(tester, aggregate(), contracts: [ended]);

      expect(find.text('Definir próxima manutenção'), findsOneWidget);
    });
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

  testWidgets('shows plate and owner, history rows and the Nova OS entry', (
    tester,
  ) async {
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
    expect(find.textContaining('OS 7'), findsOneWidget);

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
    expect(
      ((pushed.single.arguments as Map)['customer'] as Customer).id,
      'c-new',
    );
  });

  testWidgets('subtitle links the owner, the question precedes Nova OS, '
      'and there is no Cliente or Dados section', (tester) async {
    final owner = Customer()
      ..id = 'c1'
      ..name = 'Ana Ribeiro';
    final device = Device()
      ..id = 'd1'
      ..name = 'VW Gol 2018'
      ..serial = 'QXX1G49'
      ..status = 'active';
    final orders = [
      Order()
        ..id = 'o1'
        ..number = 183
        ..status = 'progress'
        ..total = 1250
        ..dueDate = DateTime.now().subtract(const Duration(days: 1))
        ..services = [
          OrderService()..service = (ServiceAggr()..name = 'Revisão completa'),
        ],
    ];
    final pushed = await pumpDetail(tester, device, orders, customer: owner);

    expect(find.textContaining('QXX1G49 · da '), findsOneWidget);
    expect(find.textContaining('Abrir uma OS para este'), findsOneWidget);
    expect(find.text('Cliente'), findsNothing);
    expect(find.text('Dados'), findsNothing);
    expect(find.text('Ativo'), findsNothing);
    expect(find.text('OS 183 · Revisão completa'), findsOneWidget);
    expect(find.text('Atrasada'), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining('Abrir uma OS para este')).dy,
      lessThan(tester.getTopLeft(find.text('Nova OS')).dy),
    );

    await tester.tap(find.text('Ana Ribeiro'));
    await tester.pumpAndSettle();
    expect(pushed.single.name, '/customer_detail');
    final args = pushed.single.arguments as Map;
    expect((args['customer'] as Customer).id, 'c1');
    expect(args['previousTitle'], 'VW Gol 2018');
  });

  testWidgets('vehicle without orders shows the empty history', (tester) async {
    final device = Device()
      ..id = 'd1'
      ..name = 'Fiat Uno';
    await pumpDetail(tester, device, const []);
    expect(find.text('Nenhuma ordem de serviço registrada'), findsOneWidget);
    expect(find.textContaining('OS deste'), findsOneWidget);
    expect(find.text('Nova OS'), findsOneWidget);
  });

  testWidgets('history hides order totals without values and billing', (
    tester,
  ) async {
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
    expect(find.textContaining('OS 7'), findsOneWidget);
    expect(find.textContaining('150,00'), findsNothing);
  });
}
