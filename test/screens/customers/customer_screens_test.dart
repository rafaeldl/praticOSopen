import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/repositories/v2/customer_repository_v2.dart';
import 'package:praticos/screens/device_form_screen.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/screens/nfse/nfse_access.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/customers/customer_detail_screen.dart';
import 'package:praticos/screens/customers/customer_form_screen.dart';
import 'package:praticos/screens/customers/customer_list_screen.dart';
import 'package:praticos/screens/menu_navigation/home_customer_list.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/customer_directory.dart';
import 'package:praticos/services/format_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Future<void> deleteCustomer(Customer customer) async => deleted.add(customer);
}

/// [FakeDirectory] whose vehicle lookup is [vehicles] (e.g. never answers).
class SlowVehiclesDirectory extends FakeDirectory {
  SlowVehiclesDirectory({super.customers, required this.vehicles});

  final Future<List<DeviceAggr>> Function() vehicles;

  @override
  Future<List<DeviceAggr>> vehiclesOf(String customerId) => vehicles();
}

class FakeCustomerRepository implements CustomerRepositoryV2 {
  final saved = <String, Customer>{};

  @override
  Stream<List<Customer?>> streamCustomers(String companyId) => Stream.value([]);

  @override
  Future<void> createItem(
    String companyId,
    Customer? item, {
    String? id,
  }) async {
    item!.id = 'new-id';
    saved[companyId] = item;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserStore implements UserStore {
  @override
  Future<User?> getSingleUserById() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

Order order(
  int number,
  String status,
  double total, {
  List<DeviceAggr> devices = const [],
}) => Order()
  ..id = 'o$number'
  ..number = number
  ..status = status
  ..total = total
  ..devices = devices;

/// Opens [screen] from a launcher and captures what it pops.
class Harness {
  Object? result = 'unset';
  final List<RouteSettings> pushed = [];

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Map<String, dynamic>? args,
    bool direct = false,
  }) async {
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
    }) => FakeDirectory(
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

    testWidgets('titles the screen as a task and offers to add a customer', (
      tester,
    ) async {
      await Harness().pump(
        tester,
        CustomerListScreen(canAdd: true, directory: directory()),
      );
      expect(find.text('Qual cliente?'), findsOneWidget);
      expect(find.byKey(const ValueKey('picker-add')), findsOneWidget);
      expect(find.text('Ana Ribeiro'), findsOneWidget);
      // Two customers: no search (only above 10).
      expect(find.byType(CupertinoSearchTextField), findsNothing);
    });

    testWidgets('without manageCustomers the picker offers no new customer', (
      tester,
    ) async {
      await Harness().pump(
        tester,
        CustomerListScreen(canAdd: false, directory: directory()),
      );
      expect(find.text('Ana Ribeiro'), findsOneWidget);
      expect(find.byKey(const ValueKey('picker-add')), findsNothing);
    });

    testWidgets('above 10 customers the search shows', (tester) async {
      await Harness().pump(
        tester,
        CustomerListScreen(
          canAdd: true,
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
        CustomerListScreen(canAdd: true, directory: directory()),
        args: {'order': Order()..customer = (CustomerAggr()..id = 'c2')},
      );
      final rows = tester.widgetList<AppListRow>(find.byType(AppListRow));
      expect(
        {for (final r in rows) r.title: r.selected},
        {'Ana Ribeiro': false, 'Bruno Lima': true},
      );
    });

    testWidgets('an order customer without a known id is matched by name', (
      tester,
    ) async {
      await Harness().pump(
        tester,
        CustomerListScreen(canAdd: true, directory: directory()),
        args: {
          'order': Order()
            ..customer = (CustomerAggr()
              ..id = 'migrated-id'
              ..name = 'Bruno Lima'),
        },
      );
      final rows = tester.widgetList<AppListRow>(find.byType(AppListRow));
      expect(
        {for (final r in rows) r.title: r.selected},
        {'Ana Ribeiro': false, 'Bruno Lima': true},
      );
    });

    testWidgets('has no swipe actions and no chevron while choosing', (
      tester,
    ) async {
      await Harness().pump(
        tester,
        CustomerListScreen(canAdd: true, directory: directory()),
      );
      expect(find.byType(Dismissible), findsNothing);
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsNothing);
    });

    testWidgets('searching by plate selects the customer and the vehicle', (
      tester,
    ) async {
      final h = Harness();
      await h.pump(
        tester,
        CustomerListScreen(canAdd: true, directory: directory(many: true)),
      );
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

    testWidgets('a customer with a single vehicle gets it auto-selected', (
      tester,
    ) async {
      final h = Harness();
      await h.pump(
        tester,
        CustomerListScreen(
          canAdd: true,
          directory: directory(
            orders: {
              'c1': [
                order(1, 'done', 100, devices: [aggr('d1', 'Fiat Uno')]),
              ],
            },
          ),
        ),
      );
      await tester.tap(find.text('Ana Ribeiro'));
      await tester.pumpAndSettle();
      final pick = h.result as CustomerPick;
      expect(pick.customer.id, 'c1');
      expect(pick.device?.id, 'd1');
    });

    testWidgets('a vehicle lookup that never answers still chooses the '
        'customer', (tester) async {
      final h = Harness();
      await h.pump(
        tester,
        CustomerListScreen(
          canAdd: true,
          directory: SlowVehiclesDirectory(
            customers: [ana, bruno],
            vehicles: () => Completer<List<DeviceAggr>>().future,
          ),
        ),
      );
      await tester.tap(find.text('Ana Ribeiro'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      final pick = h.result as CustomerPick;
      expect(pick.customer.id, 'c1');
      expect(pick.device, isNull);
    });

    testWidgets('a vehicle lookup that fails still chooses the customer', (
      tester,
    ) async {
      final h = Harness();
      await h.pump(
        tester,
        CustomerListScreen(
          canAdd: true,
          directory: SlowVehiclesDirectory(
            customers: [ana, bruno],
            vehicles: () async => throw StateError('permission-denied'),
          ),
        ),
      );
      await tester.tap(find.text('Bruno Lima'));
      await tester.pumpAndSettle();
      final pick = h.result as CustomerPick;
      expect(pick.customer.id, 'c2');
      expect(pick.device, isNull);
    });

    testWidgets('a customer with several vehicles gets none auto-selected', (
      tester,
    ) async {
      final h = Harness();
      await h.pump(
        tester,
        CustomerListScreen(
          canAdd: true,
          directory: directory(
            orders: {
              'c1': [
                order(1, 'done', 100, devices: [aggr('d1', 'Fiat Uno')]),
                order(2, 'done', 50, devices: [aggr('d2', 'Gol')]),
              ],
            },
          ),
        ),
      );
      await tester.tap(find.text('Ana Ribeiro'));
      await tester.pumpAndSettle();
      expect((h.result as CustomerPick).device, isNull);
    });

    testWidgets('does not auto-select when the order already has a vehicle', (
      tester,
    ) async {
      final h = Harness();
      final existing = Order()..devices = [aggr('d9', 'Moto')];
      await h.pump(
        tester,
        CustomerListScreen(
          canAdd: true,
          directory: directory(
            orders: {
              'c1': [
                order(1, 'done', 100, devices: [aggr('d1', 'Fiat Uno')]),
              ],
            },
          ),
        ),
        args: {'order': existing},
      );
      await tester.tap(find.text('Ana Ribeiro'));
      await tester.pumpAndSettle();
      expect((h.result as CustomerPick).device, isNull);
    });

    testWidgets('empty search shows the no-match sentence', (tester) async {
      await Harness().pump(
        tester,
        CustomerListScreen(canAdd: true, directory: directory(many: true)),
      );
      await tester.enterText(find.byType(CupertinoSearchTextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('Nenhum cliente com “zzzz”'), findsOneWidget);
      // The add row becomes "Cadastrar “zzzz”".
      expect(find.text('Cadastrar “zzzz”'), findsOneWidget);
    });

    testWidgets('"Novo cliente" opens the sheet with X and ✓', (tester) async {
      final h = Harness();
      await h.pump(
        tester,
        CustomerListScreen(canAdd: true, directory: directory()),
      );
      await tester.tap(find.byKey(const ValueKey('picker-add')));
      await tester.pumpAndSettle();
      expect(find.byType(FormSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('new_order_close')), findsOneWidget);
      expect(find.byKey(const ValueKey('new_order_save')), findsOneWidget);
      expect(find.textContaining(RegExp(r'^Salvar')), findsNothing);
      // Nothing typed: "X" returns to the picker without choosing anyone.
      await tester.tap(find.byKey(const ValueKey('new_order_close')));
      await tester.pumpAndSettle();
      expect(find.byType(FormSheet), findsNothing);
      expect(find.text('Qual cliente?'), findsOneWidget);
      expect(h.result, 'unset');
    });

    group('new customer from the picker', () {
      late FakeCustomerRepository repository;

      // Like the form: the store is created at save time, so its company is
      // still being read when the save starts.
      Widget picker({bool many = false}) => CustomerListScreen(
        canAdd: true,
        directory: directory(many: many),
        onSaveCustomer: (c) => CustomerStore(
          repository: repository,
          userStore: FakeUserStore(),
          onCreated: (_) {},
        ).saveCustomer(c),
      );

      Future<void> tapSave(WidgetTester tester) async {
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('new_order_save')));
        await tester.pumpAndSettle();
      }

      setUp(() {
        SharedPreferences.setMockInitialValues({'companyId': 'co1'});
        repository = FakeCustomerRepository();
      });

      testWidgets('"Novo cliente" saves and chooses the customer', (
        tester,
      ) async {
        final h = Harness();
        await h.pump(tester, picker());
        await tester.tap(find.byKey(const ValueKey('picker-add')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(CupertinoTextField).first,
          'Carla Dias',
        );
        await tapSave(tester);

        expect(repository.saved['co1']?.name, 'Carla Dias');
        final pick = h.result as CustomerPick;
        expect(pick.customer, same(repository.saved['co1']));
        expect(pick.customer.id, 'new-id');
        expect(find.text('Qual cliente?'), findsNothing);
      });

      testWidgets('"Cadastrar “x”" saves the typed name and chooses it', (
        tester,
      ) async {
        final h = Harness();
        await h.pump(tester, picker(many: true));
        await tester.enterText(find.byType(CupertinoTextField), 'Carla Dias');
        await tester.pump();
        await tester.tap(find.text('Cadastrar “Carla Dias”'));
        await tester.pumpAndSettle();
        await tapSave(tester);

        expect(repository.saved['co1']?.name, 'Carla Dias');
        expect((h.result as CustomerPick).customer.id, 'new-id');
      });

      testWidgets('a failed save keeps the sheet and chooses no one', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final h = Harness();
        await h.pump(tester, picker());
        await tester.tap(find.byKey(const ValueKey('picker-add')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(CupertinoTextField).first,
          'Carla Dias',
        );
        await tapSave(tester);

        expect(repository.saved, isEmpty);
        expect(find.byType(CupertinoAlertDialog), findsOneWidget);
        expect(find.byType(FormSheet), findsOneWidget);
        expect(h.result, 'unset');
      });
    });
  });

  group('customer form', () {
    Future<Harness> pumpForm(WidgetTester tester, Widget form) async {
      final h = Harness();
      await h.pump(tester, form);
      return h;
    }

    final save = find.byKey(const ValueKey('new_order_save'));
    final close = find.byKey(const ValueKey('new_order_close'));

    bool saveEnabled(WidgetTester tester) =>
        tester.widget<CupertinoButton>(save).onPressed != null;

    testWidgets('new customer shows name and phone in a card and "Mais '
        'dados" opens inside it', (tester) async {
      await pumpForm(tester, const CustomerFormScreen(asSheet: true));
      expect(find.byType(FormFieldsCard), findsOneWidget);
      expect(find.text('Nome'), findsOneWidget);
      expect(find.text('Telefone ou WhatsApp'), findsOneWidget);
      expect(find.text('Mais dados'), findsOneWidget);
      expect(find.text('E-mail, CPF ou CNPJ, endereço'), findsOneWidget);
      expect(find.text('E-mail'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('form_more')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(FormMoreCard),
          matching: find.text('E-mail'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Mais dados" starts open when the customer has an e-mail', (
      tester,
    ) async {
      final draft = Customer()..email = 'ana@example.com';
      await pumpForm(
        tester,
        CustomerFormScreen(asSheet: true, customer: draft),
      );
      expect(find.text('E-mail'), findsOneWidget);
    });

    testWidgets('editing a customer with an e-mail shows it right away', (
      tester,
    ) async {
      final c = customer('c1', 'Ana')..email = 'ana@example.com';
      await pumpForm(tester, CustomerFormScreen(customer: c));
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('Editar cliente'), findsOneWidget);
      expect(find.byType(FormSheet), findsNothing);
    });

    testWidgets('✓ is gray with the hint until the name is filled', (
      tester,
    ) async {
      var saves = 0;
      await pumpForm(
        tester,
        CustomerFormScreen(asSheet: true, onSave: (_) async => saves++),
      );
      expect(saveEnabled(tester), isFalse);
      expect(find.text('Escreva o nome para salvar.'), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saves, 0);

      await tester.enterText(find.byType(CupertinoTextField).first, 'Ana');
      await tester.pump();
      expect(saveEnabled(tester), isTrue);
      expect(find.text('Escreva o nome para salvar.'), findsNothing);
    });

    testWidgets('"X" with nothing typed closes at once', (tester) async {
      final h = await pumpForm(tester, const CustomerFormScreen(asSheet: true));
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.text('Sair sem salvar?'), findsNothing);
      expect(find.byType(FormSheet), findsNothing);
      expect(h.result, isNull);
    });

    testWidgets('"X" with something typed asks before discarding', (
      tester,
    ) async {
      final h = await pumpForm(tester, const CustomerFormScreen(asSheet: true));
      await tester.enterText(find.byType(CupertinoTextField).first, 'Ana');
      await tester.pump();
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.text('Sair sem salvar?'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.byType(FormSheet), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);

      await tester.tap(close);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.byType(FormSheet), findsNothing);
      expect(h.result, isNull);
    });

    testWidgets('✓ saves and pops the new customer', (tester) async {
      Customer? saved;
      final h = await pumpForm(
        tester,
        CustomerFormScreen(asSheet: true, onSave: (c) async => saved = c),
      );
      await tester.enterText(
        find.byType(CupertinoTextField).first,
        'Ana Ribeiro',
      );
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved?.name, 'Ana Ribeiro');
      expect((h.result as Customer).name, 'Ana Ribeiro');
      expect(find.byType(FormSheet), findsNothing);
    });

    testWidgets('a failed save keeps the sheet and says so', (tester) async {
      await pumpForm(
        tester,
        CustomerFormScreen(
          asSheet: true,
          onSave: (_) async => throw StateError('offline'),
        ),
      );
      await tester.enterText(find.byType(CupertinoTextField).first, 'Ana');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(FormSheet), findsOneWidget);
    });

    testWidgets('✓ shows a spinner while saving', (tester) async {
      final done = Completer<void>();
      await pumpForm(
        tester,
        CustomerFormScreen(asSheet: true, onSave: (_) => done.future),
      );
      await tester.enterText(find.byType(CupertinoTextField).first, 'Ana');
      await tester.pump();
      await tester.tap(save);
      await tester.pump();
      expect(find.byKey(const ValueKey('new_order_saving')), findsOneWidget);
      done.complete();
      await tester.pumpAndSettle();
      expect(find.byType(FormSheet), findsNothing);
    });
  });

  group('customer detail', () {
    final ana = customer('c1', 'Ana Ribeiro', phone: '(11) 90000-0001');

    Future<Harness> pumpDetail(
      WidgetTester tester,
      FakeDirectory dir, {
      bool showPrices = true,
      bool Function(PermissionType)? can,
    }) async {
      final h = Harness();
      await h.pump(
        tester,
        CustomerDetailScreen(
          can: can ?? (_) => true,
          customer: ana,
          directory: dir,
          showPrices: showPrices,
          canReceiveOn: (_) => true,
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
          can: (_) => true,
          customer: raw,
          directory: FakeDirectory(
            orders: {
              'c1': [order(1, 'done', 1740)],
            },
          ),
          showPrices: true,
          canReceiveOn: (_) => true,
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
        FakeDirectory(
          orders: {
            'c1': [
              order(3, 'progress', 999, devices: [gol])..services = [svc],
              order(2, 'done', 40.5, devices: [gol]),
              order(4, 'canceled', 500),
            ],
          },
        ),
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

    testWidgets('"Recebimentos" lists the active receipts and opens one', (
      tester,
    ) async {
      final opened = <String>[];
      final h = Harness();
      await h.pump(
        tester,
        CustomerDetailScreen(
          can: (_) => true,
          customer: ana,
          directory: FakeDirectory(
            orders: {
              'c1': [order(1, 'done', 700)],
            },
          ),
          showPrices: true,
          canSeeReceipts: true,
          canReceiveOn: (_) => true,
          receipts: Stream.value([
            Receipt()
              ..id = 'r1'
              ..amount = 700
              ..status = ReceiptStatus.active
              ..paidAt = DateTime(2026, 10, 14)
              ..allocations = [
                ReceiptAllocation(orderId: 'a', amount: 400),
                ReceiptAllocation(orderId: 'b', amount: 300),
              ],
          ]),
          onOpenReceipt: (_, r) => opened.add(r.id!),
        ),
        direct: true,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Recebimentos'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Recebimentos'), findsOneWidget);
      expect(find.text('14/10/2026 · 2 OS'), findsOneWidget);
      final row = find.byKey(const Key('customerReceipt_r1'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(opened, ['r1']);
    });

    testWidgets('no receipts: no "Recebimentos" section', (tester) async {
      final h = Harness();
      await h.pump(
        tester,
        CustomerDetailScreen(
          can: (_) => true,
          customer: ana,
          directory: FakeDirectory(),
          showPrices: true,
          canSeeReceipts: true,
          canReceiveOn: (_) => true,
          receipts: Stream.value(const []),
        ),
        direct: true,
      );
      await tester.pumpAndSettle();
      expect(find.text('Recebimentos'), findsNothing);
    });

    testWidgets('"Cadastrar outro dispositivo" opens the new-vehicle sheet', (
      tester,
    ) async {
      await pumpDetail(tester, FakeDirectory());
      await tester.tap(find.textContaining('Cadastrar outro'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceFormScreen), findsOneWidget);
      expect(find.byType(FormSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('new_order_close')), findsOneWidget);
    });

    testWidgets('overdue order shows the status in bold with the order value', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        FakeDirectory(
          orders: {
            'c1': [
              order(1, 'progress', 1250)
                ..dueDate = DateTime.now().subtract(const Duration(days: 1)),
            ],
          },
        ),
      );
      final text = tester.widget<Text>(find.text('Atrasada'));
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(find.text('R\$ 1.250,00'), findsOneWidget);
    });

    testWidgets('"Falta receber" sums the open amount of unpaid orders', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        FakeDirectory(
          orders: {
            'c1': [
              order(1, 'done', 100)..paidAmount = 40,
              order(2, 'progress', 50),
              order(3, 'done', 80)..payment = 'paid',
              order(4, 'canceled', 500),
              order(5, 'quote', 70),
            ],
          },
        ),
      );
      // 60 (100 - 40) + 50
      expect(find.text('Falta receber R\$ 110,00'), findsOneWidget);
    });

    testWidgets('"Receber" next to "Falta receber" opens with the open '
        'orders, oldest first', (tester) async {
      final received = <List<Order>>[];
      final h = Harness();
      await h.pump(
        tester,
        CustomerDetailScreen(
          can: (_) => true,
          customer: ana,
          directory: FakeDirectory(
            orders: {
              'c1': [
                order(7, 'done', 100)..createdAt = DateTime(2026, 10, 9),
                order(5, 'done', 80)..createdAt = DateTime(2026, 10, 1),
                order(6, 'done', 30)
                  ..createdAt = DateTime(2026, 10, 5)
                  ..payment = 'paid',
                order(8, 'quote', 70)..createdAt = DateTime(2026, 10, 2),
              ],
            },
          ),
          showPrices: true,
          canReceiveOn: (_) => true,
          onReceive: (_, open) => received.add(open),
        ),
        direct: true,
      );

      expect(
        find.text('Falta receber ${FormatService().formatCurrency(180)}'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('customerReceive')));
      await tester.pump();
      expect(received.single.map((o) => o.number), [5, 7]);
    });

    // The real rule for a consultant whose uid is 'me'.
    bool consultantReceives(Order o) =>
        AuthorizationService.canReceiveOnOrderFor(
          role: RolesType.consultant,
          userId: 'me',
          order: o,
        );
    Order mine(Order o) => o..createdBy = (UserAggr()..id = 'me');
    Order theirs(Order o) => o..createdBy = (UserAggr()..id = 'other');

    testWidgets('consultant with no open order of their own sees what is '
        'owed but no "Receber"', (tester) async {
      final received = <List<Order>>[];
      final h = Harness();
      await h.pump(
        tester,
        CustomerDetailScreen(
          can: (_) => true,
          customer: ana,
          directory: FakeDirectory(
            orders: {
              'c1': [theirs(order(5, 'done', 80))],
            },
          ),
          showPrices: true,
          canReceiveOn: consultantReceives,
          onReceive: (_, open) => received.add(open),
        ),
        direct: true,
      );
      expect(
        find.text('Falta receber ${FormatService().formatCurrency(80)}'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('customerReceive')), findsNothing);
      expect(find.text(' · '), findsNothing);
      expect(received, isEmpty);
    });

    testWidgets('consultant "Receber" only takes their own open orders', (
      tester,
    ) async {
      final received = <List<Order>>[];
      final h = Harness();
      await h.pump(
        tester,
        CustomerDetailScreen(
          can: (_) => true,
          customer: ana,
          directory: FakeDirectory(
            orders: {
              'c1': [
                mine(order(7, 'done', 100)..createdAt = DateTime(2026, 10, 9)),
                theirs(order(5, 'done', 80)..createdAt = DateTime(2026, 10, 1)),
                mine(order(6, 'done', 30)..createdAt = DateTime(2026, 10, 5)),
              ],
            },
          ),
          showPrices: true,
          canReceiveOn: consultantReceives,
          onReceive: (_, open) => received.add(open),
        ),
        direct: true,
      );
      await tester.tap(find.byKey(const Key('customerReceive')));
      await tester.pump();
      expect(received.single.map((o) => o.number), [6, 7]);
    });

    testWidgets('supervisor never gets "Receber"', (tester) async {
      final h = Harness();
      await h.pump(
        tester,
        CustomerDetailScreen(
          can: (_) => true,
          customer: ana,
          directory: FakeDirectory(
            orders: {
              'c1': [mine(order(5, 'done', 80))],
            },
          ),
          showPrices: true,
          canReceiveOn: (o) => AuthorizationService.canReceiveOnOrderFor(
            role: RolesType.supervisor,
            userId: 'me',
            order: o,
          ),
        ),
        direct: true,
      );
      expect(find.byKey(const Key('customerReceive')), findsNothing);
    });

    testWidgets('"Falta receber" is hidden when nothing is open', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        FakeDirectory(
          orders: {
            'c1': [order(1, 'done', 50)..payment = 'paid'],
          },
        ),
      );
      expect(find.textContaining('Falta receber'), findsNothing);
      expect(find.textContaining('gastou'), findsOneWidget);
    });

    testWidgets('without values and billing hides totals and values', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        FakeDirectory(
          orders: {
            'c1': [
              order(1, 'done', 100, devices: [aggr('d1', 'Fiat Uno')]),
            ],
          },
        ),
        showPrices: false,
      );
      expect(find.textContaining('gastou'), findsNothing);
      expect(find.textContaining('Falta receber'), findsNothing);
      expect(find.textContaining('100,00'), findsNothing);
      expect(find.byKey(const Key('customerReceive')), findsNothing);
      expect(find.text('OS 1'), findsOneWidget);
    });

    testWidgets('customer without orders has no order list', (tester) async {
      await pumpDetail(tester, FakeDirectory());
      expect(find.text('Nova OS para Ana'), findsOneWidget);
      expect(find.text('Últimas OS'), findsNothing);
      expect(find.textContaining('gastou'), findsNothing);
    });

    testWidgets('"Nova OS para Ana" opens the order with the customer', (
      tester,
    ) async {
      final h = await pumpDetail(tester, FakeDirectory());
      await tester.tap(find.text('Nova OS para Ana'));
      await tester.pumpAndSettle();
      expect(h.pushed.last.name, '/order');
      final arg = (h.pushed.last.arguments as Map)['order'] as Order;
      expect(arg.id, isNull);
      expect(arg.customer?.id, 'c1');
    });

    testWidgets('without manageCustomers there is no edit or delete', (
      tester,
    ) async {
      // Technician: no manageCustomers nor manageDevices (Firestore rules).
      await pumpDetail(tester, FakeDirectory(), can: (_) => false);
      expect(find.byIcon(CupertinoIcons.ellipsis), findsNothing);
      expect(find.textContaining('Cadastrar outro'), findsNothing);
    });

    testWidgets('delete asks before removing and says orders stay', (
      tester,
    ) async {
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

    Future<void> pumpWithNfse(WidgetTester tester, PaymentSettings s) async {
      final h = Harness();
      await h.pump(
        tester,
        CustomerDetailScreen(
          can: (_) => true,
          customer: ana,
          directory: FakeDirectory(),
          showPrices: true,
          canReceiveOn: (_) => true,
          nfse: NfseController(
            canIssue: true,
            settingsStream: Stream.value(s),
            invoicesOf: (_) => Stream.value(const []),
          ),
        ),
        direct: true,
      );
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
      await tester.pumpAndSettle();
    }

    testWidgets('notas of the customer: a row with the count', (tester) async {
      final h = Harness();
      await h.pump(
        tester,
        CustomerDetailScreen(
          can: (_) => true,
          customer: ana,
          directory: FakeDirectory(),
          showPrices: true,
          canReceiveOn: (_) => true,
          nfse: NfseController(
            canIssue: true,
            settingsStream: Stream.value(
              PaymentSettings(
                asaasEnabled: true,
                asaasConnected: true,
                nfseEnabled: true,
              ),
            ),
            invoicesOf: (_) => Stream.value([
              NfseInvoice.fromJson({'status': 'authorized'}, id: 'a'),
              NfseInvoice.fromJson({'status': 'authorized'}, id: 'b'),
              NfseInvoice.fromJson({'status': 'canceled'}, id: 'c'),
            ]),
          ),
        ),
        direct: true,
      );
      expect(find.byKey(const Key('customerNfse')), findsOneWidget);
      expect(find.text('Notas fiscais'), findsOneWidget);
    });

    testWidgets('no notas: no row', (tester) async {
      await pumpWithNfse(
        tester,
        PaymentSettings(
          asaasEnabled: true,
          asaasConnected: true,
          nfseEnabled: true,
        ),
      );
      expect(find.byKey(const Key('customerNfse')), findsNothing);
    });

    testWidgets('"…" has no nota action while notas are off', (tester) async {
      await pumpWithNfse(
        tester,
        PaymentSettings(asaasEnabled: true, asaasConnected: true),
      );
      expect(find.byKey(const Key('customerNfseSeveral')), findsNothing);
    });

    testWidgets('"…" offers one nota with several OS when notas are on', (
      tester,
    ) async {
      await pumpWithNfse(
        tester,
        PaymentSettings(
          asaasEnabled: true,
          asaasConnected: true,
          nfseEnabled: true,
          nfseReady: true,
        ),
      );
      expect(find.byKey(const Key('customerNfseSeveral')), findsOneWidget);
    });
  });

  group('Clientes tab', () {
    final ana = customer('c1', 'Ana Ribeiro', phone: '(11) 90000-0001');
    final alice = customer('c3', 'Alice');
    final bruno = customer('c2', 'Bruno Lima');

    testWidgets('groups by initial, counts, and opens the customer', (
      tester,
    ) async {
      final h = Harness();
      await h.pump(
        tester,
        HomeCustomerList(
          canAdd: true,
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
      expect(
        ((h.pushed.last.arguments as Map)['customer'] as Customer).id,
        'c1',
      );
    });

    testWidgets('shows the phone formatted for the country', (tester) async {
      await Harness().pump(
        tester,
        HomeCustomerList(
          canAdd: true,
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
          canAdd: true,
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

    testWidgets('without manageCustomers there is no way to add one', (
      tester,
    ) async {
      await Harness().pump(
        tester,
        HomeCustomerList(canAdd: false, directory: FakeDirectory()),
        direct: true,
      );
      expect(find.text('Você ainda não tem clientes'), findsOneWidget);
      expect(find.text('Cadastrar o primeiro cliente'), findsNothing);
      expect(find.byIcon(CupertinoIcons.add), findsNothing);
    });

    testWidgets('empty company shows the sentence and the action', (
      tester,
    ) async {
      await Harness().pump(
        tester,
        HomeCustomerList(canAdd: true, directory: FakeDirectory()),
        direct: true,
      );
      expect(find.text('Você ainda não tem clientes'), findsOneWidget);
      expect(find.text('Cadastrar o primeiro cliente'), findsOneWidget);
    });
  });
}
