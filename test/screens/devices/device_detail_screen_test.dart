import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/company.dart';
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
}
