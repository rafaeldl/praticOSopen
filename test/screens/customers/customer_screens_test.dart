import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/screens/device_form_screen.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/customers/customer_detail_screen.dart';
import 'package:praticos/screens/customers/customer_form_screen.dart';
import 'package:praticos/screens/customers/customer_list_screen.dart';
import 'package:praticos/screens/menu_navigation/home_customer_list.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/services/customer_directory.dart';
import 'package:provider/provider.dart';

class FakeDirectory implements CustomerDirectory {
  FakeDirectory({
    this.customers = const [],
    this.devices = const [],
    this.owners = const {},
    this.orders = const {},
    this.open = const {},
  });

  final List<Customer> customers;
  final List<Device> devices;

  /// device id -> customer id
  final Map<String, String> owners;

  /// customer id -> orders
  final Map<String, List<Order>> orders;
  final Map<String, OpenOrdersSummary> open;
  final List<Customer> deleted = [];

  @override
  Stream<List<Customer>> watchCustomers() => Stream.value(customers);

  @override
  Future<List<Device>> loadDevices() async => devices;

  @override
  Future<String?> ownerIdOf(Device device) async => owners[device.id];

  @override
  Future<List<DeviceAggr>> vehiclesOf(String customerId) async {
    final seen = <String>{};
    return [
      for (final o in orders[customerId] ?? <Order>[])
        for (final d in o.devices ?? <DeviceAggr>[])
          if (seen.add(d.id!)) d,
    ];
  }

  @override
  Stream<List<Order>> watchOrdersOf(String customerId) =>
      Stream.value(orders[customerId] ?? const []);

  @override
  Future<Map<String, OpenOrdersSummary>> openOrdersByCustomer() async => open;

  @override
  Future<List<String>> recentCustomerIds() async => const [];

  @override
  Future<void> deleteCustomer(Customer customer) async =>
      deleted.add(customer);
}

Customer customer(String id, String name, {String? phone}) => Customer()
  ..id = id
  ..name = name
  ..phone = phone;

Device device(String id, String name, String serial) => Device()
  ..id = id
  ..name = name
  ..serial = serial;

DeviceAggr aggr(String id, String name) => DeviceAggr()
  ..id = id
  ..name = name;

Order order(int number, String status, double total,
        {List<DeviceAggr> devices = const []}) =>
    Order()
      ..id = 'o$number'
      ..number = number
      ..status = status
      ..total = total
      ..devices = devices;

/// Opens [screen] from a launcher and captures what it pops.
class Harness {
  Object? result = 'unset';
  final List<RouteSettings> pushed = [];

  Future<void> pump(WidgetTester tester, Widget screen,
      {Map<String, dynamic>? args, bool direct = false}) async {
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
                settings: settings,
                builder: (context) => CupertinoPageScaffold(
                  child: direct
                      ? screen
                      : Center(
                          child: CupertinoButton(
                            child: const Text('open'),
                            onPressed: () async {
                              result = await Navigator.of(context).push(
                                CupertinoPageRoute(
                                  settings: RouteSettings(arguments: args),
                                  builder: (_) => screen,
                                ),
                              );
                            },
                          ),
                        ),
                ),
              );
            }
            pushed.add(settings);
            return CupertinoPageRoute(
              settings: settings,
              builder: (_) => const Text('pushed'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (!direct) {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // SegmentConfigProvider reads Firestore in its constructor.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('customer picker "Qual cliente?"', () {
    final ana = customer('c1', 'Ana Ribeiro', phone: '(11) 90000-0001');
    final bruno = customer('c2', 'Bruno Lima');
    final uno = device('d1', 'Fiat Uno', 'ABC1D23');

    // [many] adds fillers so the list passes 10 and the search shows.
    FakeDirectory directory({
      Map<String, List<Order>>? orders,
      bool many = false,
    }) =>
        FakeDirectory(
          customers: [
            ana,
            bruno,
            if (many)
              for (var i = 0; i < 9; i++) customer('f$i', 'Zeca $i'),
          ],
          devices: [uno],
          owners: {'d1': 'c1'},
          orders: orders ?? {},
        );

    testWidgets('titles the screen as a task and offers to add a customer',
        (tester) async {
      await Harness().pump(
          tester, CustomerListScreen(directory: directory()));
      expect(find.text('Qual cliente?'), findsOneWidget);
      expect(find.text('Novo cliente'), findsOneWidget);
      expect(find.text('Ana Ribeiro'), findsOneWidget);
      // Two customers: no search (only above 10).
      expect(find.byType(CupertinoSearchTextField), findsNothing);
    });

    testWidgets('above 10 customers the search shows', (tester) async {
      await Harness().pump(
        tester,
        CustomerListScreen(
          directory: FakeDirectory(
            customers: [
              for (var i = 0; i < 11; i++) customer('x$i', 'Cliente $i'),
            ],
            devices: const [],
            owners: const {},
            orders: const {},
          ),
        ),
      );
      expect(find.byType(CupertinoSearchTextField), findsOneWidget);
    });

    testWidgets('the order customer has the check mark', (tester) async {
      await Harness().pump(
        tester,
        CustomerListScreen(directory: directory()),
        args: {'order': Order()..customer = (CustomerAggr()..id = 'c2')},
      );
      final rows = tester.widgetList<AppListRow>(find.byType(AppListRow));
      expect(
        {for (final r in rows) r.title: r.selected},
        {'Ana Ribeiro': false, 'Bruno Lima': true},
      );
    });

    testWidgets('has no swipe actions and no chevron while choosing',
        (tester) async {
      await Harness().pump(
          tester, CustomerListScreen(directory: directory()));
      expect(find.byType(Dismissible), findsNothing);
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsNothing);
    });

    testWidgets('searching by plate selects the customer and the vehicle',
        (tester) async {
      final h = Harness();
      await h.pump(
          tester, CustomerListScreen(directory: directory(many: true)));
      await tester.enterText(find.byType(CupertinoSearchTextField), 'abc1');
      await tester.pumpAndSettle();
      // Only the plate owner is listed, with the plate on the second line.
      expect(find.text('Bruno Lima'), findsNothing);
      expect(find.textContaining('ABC1D23'), findsOneWidget);
      await tester.tap(find.text('Ana Ribeiro'));
      await tester.pumpAndSettle();
      final pick = h.result as CustomerPick;
      expect(pick.customer.id, 'c1');
      expect(pick.device?.id, 'd1');
    });

    testWidgets('a customer with a single vehicle gets it auto-selected',
        (tester) async {
      final h = Harness();
      await h.pump(
        tester,
        CustomerListScreen(
          directory: directory(orders: {
            'c1': [order(1, 'done', 100, devices: [aggr('d1', 'Fiat Uno')])],
          }),
        ),
      );
      await tester.tap(find.text('Ana Ribeiro'));
      await tester.pumpAndSettle();
      final pick = h.result as CustomerPick;
      expect(pick.customer.id, 'c1');
      expect(pick.device?.id, 'd1');
    });

    testWidgets('a customer with several vehicles gets none auto-selected',
        (tester) async {
      final h = Harness();
      await h.pump(
        tester,
        CustomerListScreen(
          directory: directory(orders: {
            'c1': [
              order(1, 'done', 100, devices: [aggr('d1', 'Fiat Uno')]),
              order(2, 'done', 50, devices: [aggr('d2', 'Gol')]),
            ],
          }),
        ),
      );
      await tester.tap(find.text('Ana Ribeiro'));
      await tester.pumpAndSettle();
      expect((h.result as CustomerPick).device, isNull);
    });

    testWidgets('does not auto-select when the order already has a vehicle',
        (tester) async {
      final h = Harness();
      final existing = Order()..devices = [aggr('d9', 'Moto')];
      await h.pump(
        tester,
        CustomerListScreen(
          directory: directory(orders: {
            'c1': [order(1, 'done', 100, devices: [aggr('d1', 'Fiat Uno')])],
          }),
        ),
        args: {'order': existing},
      );
      await tester.tap(find.text('Ana Ribeiro'));
      await tester.pumpAndSettle();
      expect((h.result as CustomerPick).device, isNull);
    });

    testWidgets('empty search shows the no-match sentence', (tester) async {
      await Harness().pump(
          tester, CustomerListScreen(directory: directory(many: true)));
      await tester.enterText(find.byType(CupertinoSearchTextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('Nenhum cliente com “zzzz”'), findsOneWidget);
      // The add row becomes "Cadastrar “zzzz”".
      expect(find.text('Cadastrar “zzzz”'), findsOneWidget);
      expect(find.text('Novo cliente'), findsNothing);
    });

    testWidgets('"Novo cliente" opens the sheet with Cancelar',
        (tester) async {
      final h = Harness();
      await h.pump(tester, CustomerListScreen(directory: directory()));
      await tester.tap(find.text('Novo cliente'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSheet), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^Salvar')), findsOneWidget);
      // Cancel returns to the picker without choosing anyone.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSheet), findsNothing);
      expect(find.text('Qual cliente?'), findsOneWidget);
      expect(h.result, 'unset');
    });
  });

  group('customer form', () {
    Future<Harness> pumpForm(WidgetTester tester, Widget form) async {
      final h = Harness();
      await h.pump(tester, form);
      return h;
    }

    testWidgets('new customer shows only name and phone', (tester) async {
      await pumpForm(tester, const CustomerFormScreen(asSheet: true));
      expect(find.text('Nome'), findsOneWidget);
      expect(find.text('Telefone ou WhatsApp'), findsOneWidget);
      expect(find.text('E-mail'), findsNothing);
      expect(find.textContaining('Mais dados'), findsOneWidget);
      await tester.tap(find.textContaining('Mais dados'));
      await tester.pumpAndSettle();
      expect(find.text('E-mail'), findsOneWidget);
    });

    testWidgets('editing a customer with an e-mail shows it right away',
        (tester) async {
      final c = customer('c1', 'Ana')..email = 'ana@example.com';
      await pumpForm(tester, CustomerFormScreen(customer: c));
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('Editar cliente'), findsOneWidget);
    });

    testWidgets('empty name shows the hint and does not save',
        (tester) async {
      var saves = 0;
      await pumpForm(
        tester,
        CustomerFormScreen(asSheet: true, onSave: (_) async => saves++),
      );
      await tester.tap(find.textContaining(RegExp(r'^Salvar')));
      await tester.pumpAndSettle();
      expect(find.text('Digite o nome do cliente'), findsOneWidget);
      expect(saves, 0);
    });

    testWidgets('saving the sheet pops the new customer', (tester) async {
      Customer? saved;
      final h = await pumpForm(
        tester,
        CustomerFormScreen(asSheet: true, onSave: (c) async => saved = c),
      );
      await tester.enterText(
          find.byType(CupertinoTextField).first, 'Ana Ribeiro');
      await tester.tap(find.textContaining(RegExp(r'^Salvar')));
      await tester.pumpAndSettle();
      expect(saved?.name, 'Ana Ribeiro');
      expect((h.result as Customer).name, 'Ana Ribeiro');
      expect(find.byType(AppSheet), findsNothing);
    });
  });

  group('customer detail', () {
    final ana = customer('c1', 'Ana Ribeiro', phone: '(11) 90000-0001');

    Future<Harness> pumpDetail(
      WidgetTester tester,
      FakeDirectory dir, {
      bool showPrices = true,
    }) async {
      final h = Harness();
      await h.pump(
        tester,
        CustomerDetailScreen(
          customer: ana,
          directory: dir,
          showPrices: showPrices,
        ),
        direct: true,
      );
      return h;
    }

    testWidgets('header shows the formatted phone with "gastou" and asks '
        'before the Nova OS button', (tester) async {
      final raw = customer('c1', 'Ana Ribeiro', phone: '+5511900000001');
      final h = Harness();
      await h.pump(
        tester,
        CustomerDetailScreen(
          customer: raw,
          directory: FakeDirectory(orders: {
            'c1': [order(1, 'done', 1740)],
          }),
          showPrices: true,
        ),
        direct: true,
      );
      expect(
        find.text('(11) 90000-0001 · gastou R\$ 1.740,00'),
        findsOneWidget,
      );
      expect(find.text('+5511900000001'), findsNothing);
      final question = tester.getTopLeft(find.text('Abrir uma OS para Ana?'));
      final button = tester.getTopLeft(find.text('Nova OS para Ana'));
      expect(question.dy, lessThan(button.dy));
    });

    testWidgets('vehicles show plate and order count, then the add row, '
        'then "Últimas OS" with the order title', (tester) async {
      final gol = aggr('d1', 'VW Gol 2018')..serial = 'ABC1D23';
      final svc = OrderService()..service = (ServiceAggr()..name = 'Revisão');
      await pumpDetail(
        tester,
        FakeDirectory(orders: {
          'c1': [
            order(3, 'progress', 999, devices: [gol])..services = [svc],
            order(2, 'done', 40.5, devices: [gol]),
            order(4, 'canceled', 500),
          ],
        }),
      );
      expect(find.text('Ligar'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Placa ABC1D23 · 2 OS'), findsOneWidget);
      expect(find.textContaining('Cadastrar outro'), findsOneWidget);
      expect(find.text('Últimas OS'), findsOneWidget);
      expect(find.text('OS 3 · Revisão'), findsOneWidget);
      expect(find.text('OS 2'), findsOneWidget);
      expect(find.textContaining('#'), findsNothing);
      final add = tester.getTopLeft(find.textContaining('Cadastrar outro'));
      final latest = tester.getTopLeft(find.text('Últimas OS'));
      expect(add.dy, lessThan(latest.dy));
    });

    testWidgets('"Cadastrar outro dispositivo" opens the new-vehicle sheet',
        (tester) async {
      await pumpDetail(tester, FakeDirectory());
      await tester.tap(find.textContaining('Cadastrar outro'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceFormScreen), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('overdue order shows the status in bold with the order value',
        (tester) async {
      await pumpDetail(
        tester,
        FakeDirectory(orders: {
          'c1': [
            order(1, 'progress', 1250)
              ..dueDate = DateTime.now().subtract(const Duration(days: 1)),
          ],
        }),
      );
      final text = tester.widget<Text>(find.text('Atrasada'));
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(find.text('R\$ 1.250,00'), findsOneWidget);
    });

    testWidgets('"Falta receber" sums the open amount of unpaid orders',
        (tester) async {
      await pumpDetail(
        tester,
        FakeDirectory(orders: {
          'c1': [
            order(1, 'done', 100)..paidAmount = 40,
            order(2, 'progress', 50),
            order(3, 'done', 80)..payment = 'paid',
            order(4, 'canceled', 500),
            order(5, 'quote', 70),
          ],
        }),
      );
      // 60 (100 - 40) + 50
      expect(find.text('Falta receber R\$ 110,00'), findsOneWidget);
    });

    testWidgets('"Falta receber" is hidden when nothing is open',
        (tester) async {
      await pumpDetail(
        tester,
        FakeDirectory(orders: {
          'c1': [order(1, 'done', 50)..payment = 'paid'],
        }),
      );
      expect(find.textContaining('Falta receber'), findsNothing);
      expect(find.textContaining('gastou'), findsOneWidget);
    });

    testWidgets('without values and billing hides totals and values',
        (tester) async {
      await pumpDetail(
        tester,
        FakeDirectory(orders: {
          'c1': [
            order(1, 'done', 100, devices: [aggr('d1', 'Fiat Uno')]),
          ],
        }),
        showPrices: false,
      );
      expect(find.textContaining('gastou'), findsNothing);
      expect(find.textContaining('Falta receber'), findsNothing);
      expect(find.textContaining('100,00'), findsNothing);
      expect(find.text('OS 1'), findsOneWidget);
    });

    testWidgets('customer without orders has no order list', (tester) async {
      await pumpDetail(tester, FakeDirectory());
      expect(find.text('Nova OS para Ana'), findsOneWidget);
      expect(find.text('Últimas OS'), findsNothing);
      expect(find.textContaining('gastou'), findsNothing);
    });

    testWidgets('"Nova OS para Ana" opens the order with the customer',
        (tester) async {
      final h = await pumpDetail(tester, FakeDirectory());
      await tester.tap(find.text('Nova OS para Ana'));
      await tester.pumpAndSettle();
      expect(h.pushed.last.name, '/order');
      final arg = (h.pushed.last.arguments as Map)['order'] as Order;
      expect(arg.id, isNull);
      expect(arg.customer?.id, 'c1');
    });

    testWidgets('delete asks before removing and says orders stay',
        (tester) async {
      final dir = FakeDirectory();
      await pumpDetail(tester, dir);
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apagar'));
      await tester.pumpAndSettle();
      expect(find.text('Apagar Ana Ribeiro?'), findsOneWidget);
      expect(find.text('As OS continuam salvas.'), findsOneWidget);
      expect(dir.deleted, isEmpty);
      await tester.tap(find.text('Apagar'));
      await tester.pumpAndSettle();
      expect(dir.deleted.single.id, 'c1');
    });
  });

  group('Clientes tab', () {
    final ana = customer('c1', 'Ana Ribeiro', phone: '(11) 90000-0001');
    final alice = customer('c3', 'Alice');
    final bruno = customer('c2', 'Bruno Lima');

    testWidgets('groups by initial, counts, and opens the customer',
        (tester) async {
      final h = Harness();
      await h.pump(
        tester,
        HomeCustomerList(
          directory: FakeDirectory(
            customers: [alice, ana, bruno],
            open: {'c1': const OpenOrdersSummary(open: 2, late: 1)},
          ),
        ),
        direct: true,
      );
      expect(find.text('3 clientes'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      // Late order shows as text next to the dot.
      expect(find.textContaining('1 OS atrasada'), findsOneWidget);
      await tester.tap(find.text('Ana Ribeiro'));
      await tester.pumpAndSettle();
      expect(h.pushed.last.name, '/customer_detail');
      expect(((h.pushed.last.arguments as Map)['customer'] as Customer).id, 'c1');
    });

    testWidgets('shows the phone formatted for the country', (tester) async {
      await Harness().pump(
        tester,
        HomeCustomerList(
          directory: FakeDirectory(
            customers: [customer('c9', 'Carla', phone: '+5548984087801')],
          ),
        ),
        direct: true,
      );
      expect(find.text('(48) 98408-7801'), findsOneWidget);
      expect(find.text('+5548984087801'), findsNothing);
    });

    testWidgets('searching by plate lists the owner', (tester) async {
      await Harness().pump(
        tester,
        HomeCustomerList(
          directory: FakeDirectory(
            customers: [ana, bruno],
            devices: [device('d1', 'Fiat Uno', 'ABC1D23')],
            owners: {'d1': 'c2'},
          ),
        ),
        direct: true,
      );
      await tester.enterText(find.byType(CupertinoSearchTextField), 'abc1d');
      await tester.pumpAndSettle();
      expect(find.text('Bruno Lima'), findsOneWidget);
      expect(find.text('Ana Ribeiro'), findsNothing);
      expect(find.textContaining('ABC1D23'), findsOneWidget);
    });

    testWidgets('empty company shows the sentence and the action',
        (tester) async {
      await Harness().pump(
        tester,
        HomeCustomerList(directory: FakeDirectory()),
        direct: true,
      );
      expect(find.text('Você ainda não tem clientes'), findsOneWidget);
      expect(find.text('Cadastrar o primeiro cliente'), findsOneWidget);
    });
  });
}
