import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/device_list_screen.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:provider/provider.dart';

Device dev(String id, String name, String plate) => Device()
  ..id = id
  ..name = name
  ..serial = plate
  ..manufacturer = 'Fiat';

DeviceAggr aggr(String id) => DeviceAggr()..id = id;

Future<Object? Function()> pumpList(
  WidgetTester tester, {
  Map<String, dynamic>? args,
  List<Device> devices = const [],
  List<DeviceAggr> customerVehicles = const [],
  bool canManage = true,
  List<RouteSettings>? pushed,
}) async {
  Object? popped = 'unset';
  await tester.pumpWidget(
    ChangeNotifierProvider<SegmentConfigProvider>(
      create: (_) => SegmentConfigProvider(),
      child: CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            return CupertinoPageRoute(
              builder: (context) => CupertinoButton(
                child: const Text('open'),
                onPressed: () async {
                  popped = await Navigator.of(context).push(
                    CupertinoPageRoute(
                      settings: RouteSettings(arguments: args),
                      builder: (_) => DeviceListScreen(
                        devices: () => Stream.value(devices),
                        vehiclesOfCustomer: (_) async => customerVehicles,
                        canManage: () => canManage,
                      ),
                    ),
                  );
                },
              ),
            );
          }
          pushed?.add(settings);
          return CupertinoPageRoute(
            settings: settings,
            builder: (_) => const Text('pushed'),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => popped;
}

Order orderOf(String? customerId) => Order()
  ..customer = customerId == null
      ? null
      : (CustomerAggr()
          ..id = customerId
          ..name = 'Ana Ribeiro');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // SegmentConfigProvider reads FirebaseFirestore.instance.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  final uno = dev('d1', 'Fiat Uno 2015', 'ABC1D23');
  final gol = dev('d2', 'VW Gol', 'XYZ9K88');

  testWidgets('selection mode asks which one, customer section first', (
    tester,
  ) async {
    await pumpList(
      tester,
      args: {'order': orderOf('c1')},
      devices: [uno, gol],
      customerVehicles: [aggr('d2')],
    );
    expect(find.textContaining('Qual '), findsOneWidget);
    // Subtitle with the customer, then the section of the customer.
    expect(find.text('de Ana Ribeiro'), findsOneWidget);
    expect(find.textContaining(RegExp(r' de Ana$')), findsOneWidget);
    expect(find.textContaining('Outros'), findsOneWidget);
    // Customer's vehicle (Gol) is listed before the other one (Uno).
    final gol1 = tester.getTopLeft(find.text('VW Gol')).dy;
    final uno1 = tester.getTopLeft(find.text('Fiat Uno 2015')).dy;
    expect(gol1, lessThan(uno1));
    expect(find.byKey(const ValueKey('picker-add')), findsOneWidget);
    expect(find.byType(AppListRow), findsNWidgets(2));
  });

  testWidgets('selection mode marks the vehicle already on the order', (
    tester,
  ) async {
    await pumpList(
      tester,
      args: {
        'order': orderOf('c1')..devices = [aggr('d1')],
      },
      devices: [uno, gol],
    );
    final rows = tester.widgetList<AppListRow>(find.byType(AppListRow));
    expect(
      {for (final r in rows) r.title: r.selected},
      {'Fiat Uno 2015': true, 'VW Gol': false},
    );
  });

  testWidgets(
    'selection mode has no swipe and no chevron, tap pops the device',
    (tester) async {
      final get = await pumpList(
        tester,
        args: {'order': orderOf(null)},
        devices: [uno],
      );
      expect(find.byType(Dismissible), findsNothing);
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsNothing);
      expect(find.textContaining('de Ana'), findsNothing);
      await tester.tap(find.text('Fiat Uno 2015'));
      await tester.pumpAndSettle();
      expect(get(), uno);
    },
  );

  testWidgets('without vehicles of the customer there is no extra section', (
    tester,
  ) async {
    await pumpList(tester, args: {'order': orderOf('c1')}, devices: [uno, gol]);
    expect(find.textContaining(RegExp(r' de Ana$')), findsNothing);
    expect(find.textContaining('Outros'), findsNothing);
    expect(find.byType(AppListRow), findsNWidgets(2));
  });

  testWidgets('settings mode keeps the chevron and the swipe', (tester) async {
    final pushed = <RouteSettings>[];
    await pumpList(tester, devices: [uno], pushed: pushed);
    expect(find.byType(Dismissible), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chevron_forward), findsOneWidget);
    expect(find.textContaining('Qual é o'), findsNothing);
    await tester.tap(find.text('Fiat Uno 2015'));
    await tester.pumpAndSettle();
    expect(pushed.last.name, '/device_form');
  });

  testWidgets('swipe to delete without permission shows the warning', (
    tester,
  ) async {
    await pumpList(tester, devices: [uno], canManage: false);
    await tester.drag(find.byType(Dismissible), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sem Permissão'), findsOneWidget);
    expect(find.byType(Dismissible), findsOneWidget);
  });

  testWidgets('changing the order vehicle offers "Nenhum veículo" first', (
    tester,
  ) async {
    final get = await pumpList(
      tester,
      args: {
        'order': orderOf('c1'),
        'current': DeviceAggr()
          ..id = 'd1'
          ..name = 'Uno',
      },
      devices: [uno, gol],
    );
    expect(find.textContaining(RegExp(r'^Nenhum ')), findsOneWidget);
    final none = tester.getTopLeft(find.textContaining(RegExp(r'^Nenhum '))).dy;
    expect(none, lessThan(tester.getTopLeft(find.text('Fiat Uno 2015')).dy));
    await tester.tap(find.textContaining(RegExp(r'^Nenhum ')));
    await tester.pumpAndSettle();
    expect(get(), kRemoveDeviceResult);
  });

  testWidgets('adding a vehicle has no "Nenhum veículo" row', (tester) async {
    await pumpList(tester, args: {'order': orderOf('c1')}, devices: [uno]);
    expect(find.textContaining(RegExp(r'^Nenhum ')), findsNothing);
  });
}
