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
import 'package:praticos/screens/devices/next_maintenance_offer.dart';
import 'package:praticos/services/device_maintenance_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records writes and answers reads from memory.
class _FakeService extends DeviceMaintenanceService {
  _FakeService({this.contracts = const {}, this.dates = const {}});

  final Set<String> contracts;
  final Map<String, String> dates;
  final List<({List<String> ids, DateTime? date, String? customer})> saved = [];
  bool failSave = false;

  @override
  Future<Order?> activeContract(String deviceId) async =>
      contracts.contains(deviceId) ? (Order()..id = 'c') : null;

  @override
  Future<Device?> device(String deviceId) async => Device()
    ..id = deviceId
    ..nextMaintenanceDate = dates[deviceId];

  @override
  void save(
    Iterable<String> deviceIds, {
    required DateTime? date,
    CustomerAggr? customer,
    VoidCallback? onFailed,
  }) {
    saved.add((ids: deviceIds.toList(), date: date, customer: customer?.name));
    if (failSave) onFailed?.call();
  }
}

DeviceAggr _aggr(String id) => DeviceAggr()
  ..id = id
  ..name = 'Split $id';

Order _order({List<String> devices = const ['d1']}) => Order()
  ..id = 'o1'
  ..status = 'done'
  ..customer = (CustomerAggr()
    ..id = 'cu1'
    ..name = 'Padaria')
  ..devices = devices.map(_aggr).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime(2026, 11, 2);

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Global.companyAggr = CompanyAggr()..id = 'c1';
  });

  tearDown(() => Global.companyAggr = null);

  group('shouldOfferNextMaintenance', () {
    bool offer(Order order, {bool can = true, int declined = 0}) =>
        shouldOfferNextMaintenance(
          order: order,
          canManageDevices: can,
          declined: declined,
        );

    test('offers on a saved order with a device', () {
      expect(offer(_order()), isTrue);
    });

    test('not without a device, nor before the order has its id', () {
      expect(offer(_order(devices: const [])), isFalse);
      expect(offer(_order()..id = null), isFalse);
    });

    test('not for who cannot edit devices', () {
      expect(offer(_order(), can: false), isFalse);
    });

    test('not on a contract or an order it generated', () {
      expect(offer(_order()..contract = OrderContract()), isFalse);
    });

    test('stops after being refused too many times', () {
      expect(offer(_order(), declined: kMaintenanceOfferLimit - 1), isTrue);
      expect(offer(_order(), declined: kMaintenanceOfferLimit), isFalse);
    });
  });

  group('offerNextMaintenance', () {
    Future<void> open(
      WidgetTester tester,
      Order order,
      DeviceMaintenanceService service, {
      bool canManage = true,
      Duration delay = Duration.zero,
    }) async {
      await tester.pumpWidget(
        CupertinoApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  onPressed: () => offerNextMaintenance(
                    context,
                    order,
                    service: service,
                    canManageDevices: canManage,
                    now: () => today,
                    delay: delay,
                  ),
                  child: const Text('finish'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();
    }

    testWidgets('6 meses saves the date with the customer, on every device', (
      tester,
    ) async {
      final service = _FakeService();
      await open(tester, _order(devices: const ['d1', 'd2']), service);

      expect(find.text('Quando é a próxima manutenção?'), findsWidgets);
      expect(find.text('maio de 2027'), findsOneWidget);
      await tester.tap(find.text('6 meses'));
      await tester.pumpAndSettle();

      expect(service.saved.single.ids, ['d1', 'd2']);
      expect(service.saved.single.date, DateTime(2027, 5, 2));
      expect(service.saved.single.customer, 'Padaria');
      expect(find.text('finish'), findsOneWidget);
    });

    testWidgets('waits, so a second tap does not land on an answer', (
      tester,
    ) async {
      await open(
        tester,
        _order(),
        _FakeService(),
        delay: kMaintenanceAskDelay,
      );
      expect(find.text('6 meses'), findsNothing);

      await tester.pump(kMaintenanceAskDelay);
      await tester.pumpAndSettle();
      expect(find.text('6 meses'), findsOneWidget);
    });

    testWidgets('a failed write warns the person', (tester) async {
      final service = _FakeService()..failSave = true;
      await open(tester, _order(), service);

      await tester.tap(find.text('1 ano'));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(
        find.text('Não foi possível salvar a data da manutenção'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('leaves out a device under an active contract', (tester) async {
      final service = _FakeService(contracts: {'d1'});
      await open(tester, _order(devices: const ['d1', 'd2']), service);

      await tester.tap(find.text('3 meses'));
      await tester.pumpAndSettle();

      expect(service.saved.single.ids, ['d2']);
    });

    testWidgets('does not ask when every device is under contract', (
      tester,
    ) async {
      await open(tester, _order(), _FakeService(contracts: {'d1'}));

      expect(find.text('3 meses'), findsNothing);
    });

    testWidgets('Não repetir removes a date this order fulfilled', (
      tester,
    ) async {
      final service = _FakeService(dates: {'d1': '2026-11-05'});
      await open(tester, _order(), service);

      await tester.tap(find.text('Não repetir'));
      await tester.pumpAndSettle();

      expect(service.saved.single.ids, ['d1']);
      expect(service.saved.single.date, isNull);
    });

    testWidgets('Não repetir keeps a preventive set for later', (tester) async {
      final service = _FakeService(dates: {'d1': '2027-03-10'});
      await open(tester, _order(), service);

      expect(find.textContaining('Marcada para março de 2027'), findsOneWidget);
      await tester.tap(find.text('Não repetir'));
      await tester.pumpAndSettle();

      expect(service.saved, isEmpty);
    });

    testWidgets('three refusals in a row stop it, and a date starts over', (
      tester,
    ) async {
      final service = _FakeService();
      for (var i = 0; i < kMaintenanceOfferLimit; i++) {
        await open(tester, _order(), service);
        await tester.tap(find.text('Não repetir'));
        await tester.pumpAndSettle();
      }

      await open(tester, _order(), service);
      expect(find.text('Não repetir'), findsNothing);

      await resetMaintenanceDeclines();
      await open(tester, _order(), service);
      expect(find.text('Não repetir'), findsOneWidget);
    });

    testWidgets('going back counts as a refusal and changes nothing', (
      tester,
    ) async {
      final service = _FakeService(dates: {'d1': '2026-11-05'});
      await open(tester, _order(), service);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(service.saved, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('next_maintenance_declined_c1'), 1);
    });

    testWidgets('each company has its own count', (tester) async {
      final service = _FakeService();
      for (var i = 0; i < kMaintenanceOfferLimit; i++) {
        await open(tester, _order(), service);
        await tester.tap(find.text('Não repetir'));
        await tester.pumpAndSettle();
      }

      Global.companyAggr = CompanyAggr()..id = 'c2';
      await open(tester, _order(), service);
      expect(find.text('Não repetir'), findsOneWidget);
    });

    testWidgets('does not ask who cannot edit devices', (tester) async {
      await open(tester, _order(), _FakeService(), canManage: false);

      expect(find.text('3 meses'), findsNothing);
    });
  });
}
