import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/screens/menu_navigation/home_content.dart';
import 'package:praticos/screens/menu_navigation/home_groups.dart';
import 'package:praticos/screens/widgets/order_list_row.dart';
import 'package:praticos/screens/widgets/primary_button.dart';

final _now = DateTime(2026, 10, 12, 10);

Order _order(
  String customer,
  String status, {
  int number = 1,
  DateTime? due,
  DateTime? created,
  String? payment,
  double total = 100,
  double? paid,
}) {
  return Order()
    ..id = 'o$number'
    ..number = number
    ..status = status
    ..dueDate = due
    ..createdAt = created ?? DateTime(2026, 10, 1)
    ..payment = payment
    ..total = total
    ..paidAmount = paid
    ..customer = (CustomerAggr()..name = customer);
}

class _Host extends StatefulWidget {
  const _Host({
    required this.orders,
    this.isLoading = false,
    this.loadFailed = false,
    this.hasAnyOrders,
    this.unread = 0,
    this.onRetry,
    this.onViewReported,
    this.onOpenProfile,
    this.technician = false,
    this.onOpenOrder,
    this.maintenances = const [],
    this.onOpenMaintenance,
  });

  final List<Device> maintenances;
  final ValueChanged<Device>? onOpenMaintenance;
  final bool technician;
  final ValueChanged<Order>? onOpenOrder;
  final List<Order> orders;
  final bool isLoading;
  final bool loadFailed;
  final bool? hasAnyOrders;
  final int unread;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenProfile;
  final ValueChanged<HomeView>? onViewReported;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late HomeView view = widget.technician ? HomeView.mine : HomeView.open;

  /// What the store would load for each view.
  List<Order> get _orders => switch (view) {
    HomeView.open || HomeView.mine || HomeView.quotes || HomeView.onHold =>
      widget.orders.where((o) => !HomeRules.isFinished(o)).toList(),
    HomeView.done => widget.orders.where((o) => o.status == 'done').toList(),
    HomeView.all => widget.orders,
  };

  @override
  Widget build(BuildContext context) {
    return HomeContent(
      orders: _orders,
      view: view,
      onViewChanged: (v) {
        widget.onViewReported?.call(v);
        setState(() => view = v);
      },
      title: 'Ordens de serviço',
      isLoading: widget.isLoading,
      hasMore: false,
      loadFailed: widget.loadFailed,
      hasAnyOrders: widget.hasAnyOrders,
      showPrices: true,
      showDevice: true,
      unreadCount: widget.unread,
      companyName: 'Oficina do Zé',
      statusLabel: (s) => switch (s) {
        'quote' => 'Orçamento',
        'approved' => 'Aprovado',
        'progress' => 'Em andamento',
        'done' => 'Concluído',
        _ => 'Cancelado',
      },
      onOpenOrder: widget.onOpenOrder ?? (_) {},
      technician: widget.technician,
      currentUserId: 'u1',
      deviceLabel: 'Veículo',
      onRetry: widget.onRetry ?? () {},
      onLoadMore: () {},
      onOpenNotifications: () {},
      onOpenProfile: widget.onOpenProfile ?? () {},
      maintenances: widget.maintenances,
      onOpenMaintenance: widget.onOpenMaintenance,
      now: () => _now,
    );
  }
}

Widget _app(Widget home, {Brightness brightness = Brightness.light}) {
  return CupertinoApp(
    locale: const Locale('pt'),
    theme: CupertinoThemeData(brightness: brightness),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
    ],
    home: home,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  final mixed = [
    _order('Bruno', 'progress', number: 2, created: DateTime(2026, 10, 5)),
    _order('Ana', 'approved', number: 1, due: DateTime(2026, 10, 8)),
    _order('Caio', 'quote', number: 3, created: DateTime(2026, 10, 2)),
    _order('Duda', 'done', number: 4, total: 380, paid: 200),
    _order('Elis', 'done', number: 5, total: 640, paid: 640),
  ];

  group('Manutenções chegando', () {
    Device device(String name, String customer, String day) => Device()
      ..id = name
      ..name = name
      ..nextMaintenanceDate = day
      ..nextMaintenanceCustomer = (CustomerAggr()..name = customer);

    testWidgets('shows customer, device and date, and opens the item', (
      tester,
    ) async {
      final tapped = <Device>[];
      await tester.pumpWidget(
        _app(
          _Host(
            orders: mixed,
            maintenances: [device('Split 12000', 'Padaria', '2026-10-15')],
            onOpenMaintenance: tapped.add,
          ),
        ),
      );

      expect(find.text('Manutenções chegando'), findsOneWidget);
      expect(find.text('Padaria'), findsOneWidget);
      expect(find.text('15/10/2026'), findsOneWidget);

      await tester.tap(find.text('Split 12000'));
      expect(tapped.single.name, 'Split 12000');
    });

    testWidgets('does not exist without maintenances', (tester) async {
      await tester.pumpWidget(_app(_Host(orders: mixed)));
      expect(find.text('Manutenções chegando'), findsNothing);
    });

    testWidgets('does not change the order count', (tester) async {
      await tester.pumpWidget(
        _app(
          _Host(
            orders: mixed,
            maintenances: [device('A', 'X', '2026-10-15')],
          ),
        ),
      );
      expect(find.text('3 em aberto · 1 atrasada'), findsOneWidget);
    });

    testWidgets('three rows, then "Ver mais"', (tester) async {
      await tester.pumpWidget(
        _app(
          _Host(
            orders: mixed,
            maintenances: [
              for (final name in ['A', 'B', 'C', 'D', 'E'])
                device(name, 'Cliente', '2026-10-15'),
            ],
          ),
        ),
      );

      expect(find.text('D'), findsNothing);
      await tester.tap(find.text('Ver mais 2'));
      await tester.pump();
      expect(find.text('E'), findsOneWidget);
      expect(find.text('Ver mais 2'), findsNothing);
    });

    testWidgets('stays out of the finished orders', (tester) async {
      await tester.pumpWidget(
        _app(
          _Host(
            orders: mixed,
            maintenances: [device('A', 'X', '2026-10-15')],
          ),
        ),
      );
      await tester.tap(find.text('Concluídas'));
      await tester.pumpAndSettle();
      expect(find.text('Manutenções chegando'), findsNothing);
    });
  });

  testWidgets('Em aberto: summary, overdue first with a red dot, no groups', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_Host(orders: mixed)));

    expect(find.text('3 em aberto · 1 atrasada'), findsOneWidget);
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Ana'), lessThan(y('Bruno')));
    expect(y('Bruno'), lessThan(y('Caio')));
    expect(find.text('Atrasada 4 dias'), findsOneWidget);
    // Only the overdue row gets color: one dot, no group headers.
    expect(find.byKey(const Key('order_row_overdue_dot')), findsOneWidget);
    expect(find.text('Atrasadas'), findsNothing);
    expect(find.text('Duda'), findsNothing);
    // Mail-style rows: value on the right, no photo.
    expect(find.byType(OrderListRow), findsNWidgets(3));
    expect(find.textContaining('100,00'), findsNWidgets(3));
  });

  testWidgets('the row shows the visit date of an open order', (tester) async {
    final visit = _order('Ana', 'approved')
      ..scheduledDate = DateTime(2030, 5, 12, 14);
    final both = _order('Bruno', 'approved', number: 2, due: DateTime(2030, 5, 20))
      ..scheduledDate = DateTime(2030, 5, 12, 14);
    final finished = _order('Caio', 'done', number: 3)
      ..scheduledDate = DateTime(2030, 5, 12, 14);
    await tester.pumpWidget(_app(_Host(orders: [visit, both, finished])));

    final day = FormatService().formatDayMonth(DateTime(2030, 5, 12));
    final due = FormatService().formatDayMonth(DateTime(2030, 5, 20));
    expect(find.textContaining('· visita $day'), findsNWidgets(2));
    expect(find.textContaining('entrega $due · visita $day'), findsOneWidget);

    await tester.tap(find.text('Concluídas'));
    await tester.pumpAndSettle();
    expect(find.text('Caio'), findsOneWidget);
    expect(find.textContaining('visita'), findsNothing);
  });

  testWidgets('filter buttons: Em aberto, Concluídas, Todas', (tester) async {
    final reported = <HomeView>[];
    await tester.pumpWidget(
      _app(_Host(orders: mixed, onViewReported: reported.add)),
    );
    expect(find.text('Em aberto'), findsOneWidget);
    expect(find.text('Concluídas'), findsOneWidget);
    expect(find.text('Todas'), findsOneWidget);
    // Side by side, like Mail's categories (five of them wrap at the end).
    final open = tester.getRect(find.text('Em aberto'));
    final quotes = tester.getRect(find.text('Orçamentos'));
    expect(quotes.center.dy, open.center.dy);
    expect(quotes.left, greaterThan(open.right));

    await tester.tap(find.text('Concluídas'));
    await tester.pumpAndSettle();
    expect(reported, [HomeView.done]);
    expect(find.text('Duda'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
  });

  testWidgets('Concluídas: total stays on the right, only what is left to '
      'receive goes on the status line', (tester) async {
    await tester.pumpWidget(_app(_Host(orders: mixed)));
    await tester.tap(find.text('Concluídas'));
    await tester.pumpAndSettle();

    expect(find.textContaining('380,00'), findsOneWidget);
    expect(
      find.textContaining(
        RegExp(r'falta\sreceber\s.*180,00'),
        findRichText: true,
      ),
      findsOneWidget,
    );
    // Paid order: no payment text at all.
    expect(find.textContaining('paga', findRichText: true), findsNothing);
    expect(
      find.textContaining('falta\u00A0receber', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('Todas shows month sections', (tester) async {
    await tester.pumpWidget(_app(_Host(orders: mixed)));
    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();
    expect(find.text('Outubro de 2026'), findsOneWidget);
    expect(find.text('Elis'), findsOneWidget);
  });

  testWidgets('search is on screen from the start', (tester) async {
    await tester.pumpWidget(_app(_Host(orders: mixed)));
    expect(find.byType(CupertinoSearchTextField), findsOneWidget);
    expect(find.text('Buscar OS, cliente ou veículo'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoSearchTextField), 'caio');
    await tester.pumpAndSettle();
    expect(find.text('Caio'), findsOneWidget);
    expect(find.text('Bruno'), findsNothing);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Bruno'), findsOneWidget);
  });

  testWidgets('search finds orders by status, without the accent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _Host(
          orders: [
            Order()
              ..id = 'q'
              ..status = 'quote'
              ..customer = (CustomerAggr()..name = 'Quitéria'),
            Order()
              ..id = 'a'
              ..status = 'approved'
              ..customer = (CustomerAggr()..name = 'Aprígio'),
          ],
        ),
      ),
    );
    await tester.enterText(find.byType(CupertinoSearchTextField), 'orcamento');
    await tester.pumpAndSettle();
    expect(find.text('Quitéria'), findsOneWidget);
    expect(find.text('Aprígio'), findsNothing);
  });

  testWidgets('Orçamentos shows only quotes, the oldest first', (tester) async {
    await tester.pumpWidget(
      _app(
        _Host(
          orders: [
            Order()
              ..id = 'new'
              ..status = 'quote'
              ..createdAt = DateTime(2026, 10, 20)
              ..customer = (CustomerAggr()..name = 'Nova'),
            Order()
              ..id = 'old'
              ..status = 'quote'
              ..createdAt = DateTime(2026, 9, 1)
              ..customer = (CustomerAggr()..name = 'Antiga'),
            Order()
              ..id = 'a'
              ..status = 'approved'
              ..customer = (CustomerAggr()..name = 'Aprovada'),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Orçamentos'));
    await tester.pumpAndSettle();
    expect(find.text('Aprovada'), findsNothing);
    expect(find.text('2 orçamentos sem resposta'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Antiga')).dy,
      lessThan(tester.getTopLeft(find.text('Nova')).dy),
    );
  });

  group('Paradas', () {
    Order stopped(
      String customer,
      String reason,
      DateTime since, {
      int number = 1,
      String status = 'progress',
    }) => _order(customer, status, number: number)
      ..onHold = (OrderHold()
        ..reason = reason
        ..since = since);

    testWidgets('shows only stopped orders with reason and days, the oldest '
        'first', (tester) async {
      await tester.pumpWidget(
        _app(
          _Host(
            orders: [
              _order('Sem parada', 'progress', number: 1),
              stopped(
                'Parada recente',
                OrderHoldReason.customer,
                DateTime(2026, 10, 11, 18),
                number: 2,
              ),
              stopped(
                'Parada antiga',
                OrderHoldReason.part,
                DateTime(2026, 10, 9),
                number: 3,
                status: 'approved',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Paradas'));
      await tester.pumpAndSettle();

      expect(find.text('2 paradas'), findsOneWidget);
      expect(find.text('Sem parada'), findsNothing);
      expect(find.text('Parada há 3 dias · Esperando peça'), findsOneWidget);
      expect(find.text('Parada há 1 dia · Esperando cliente'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Parada antiga')).dy,
        lessThan(tester.getTopLeft(find.text('Parada recente')).dy),
      );
    });

    testWidgets('the mark shows in the other filters too, beside the dot', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _Host(
            orders: [
              stopped(
                'Carlos',
                OrderHoldReason.authorization,
                DateTime(2026, 10, 12, 8),
              )..dueDate = DateTime(2026, 10, 10),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Em aberto, and overdue on top: the red dot wins, the line stays.
      expect(
        find.text('Parada desde hoje · Esperando autorização'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('order_row_overdue_dot')), findsOneWidget);

      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      expect(
        find.text('Parada desde hoje · Esperando autorização'),
        findsOneWidget,
      );
    });

    testWidgets('a stopped order that is not overdue gets the orange dot', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _Host(
            orders: [
              stopped('Carlos', OrderHoldReason.other, DateTime(2026, 10, 10)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('order_row_hold_dot')), findsOneWidget);
      expect(find.byKey(const Key('order_row_overdue_dot')), findsNothing);
    });

    testWidgets('a leftover mark on a finished order is not shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _Host(
            orders: [
              stopped(
                'Carlos',
                OrderHoldReason.part,
                DateTime(2026, 10, 10),
                status: 'done',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Concluídas'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('order_row_hold')), findsNothing);
    });

    testWidgets('nothing stopped says so', (tester) async {
      await tester.pumpWidget(
        _app(_Host(orders: [_order('Ana', 'progress')])),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paradas'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum serviço parado.'), findsOneWidget);
    });

    testWidgets('technicians have the filter too', (tester) async {
      await tester.pumpWidget(
        _app(_Host(orders: const [], technician: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Paradas'), findsOneWidget);
    });
  });

  testWidgets('Orçamentos without quotes says so', (tester) async {
    await tester.pumpWidget(
      _app(
        _Host(
          orders: [
            Order()
              ..id = 'a'
              ..status = 'approved'
              ..customer = (CustomerAggr()..name = 'Aprovada'),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Orçamentos'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum orçamento sem resposta.'), findsOneWidget);
  });

  testWidgets('top bar: bell with unread count and the company button', (
    tester,
  ) async {
    var profile = 0;
    await tester.pumpWidget(
      _app(_Host(orders: mixed, unread: 3, onOpenProfile: () => profile++)),
    );
    expect(find.bySemanticsLabel('Avisos, 3 novos'), findsOneWidget);
    expect(find.text('OZ'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.ellipsis), findsNothing);

    await tester.tap(find.text('OZ'));
    expect(profile, 1);
  });

  testWidgets('first time: subtitle, label pointing at the + and steps', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const _Host(orders: [], hasAnyOrders: false)));
    expect(find.text('Nenhuma ainda'), findsOneWidget);
    expect(find.text('Comece por aqui'), findsOneWidget);
    expect(
      find.text(
        'Toque no + para criar sua primeira OS. Leva menos de um '
        'minuto.',
      ),
      findsOneWidget,
    );
    expect(find.text('Como funciona'), findsOneWidget);
    expect(find.text('Em aberto'), findsNothing);
    expect(find.byType(PrimaryButton), findsNothing);
  });

  testWidgets('empty Em aberto with orders in the company offers Ver todas', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _Host(orders: [_order('Elis', 'done', number: 5)], hasAnyOrders: true),
      ),
    );
    expect(find.text('Nenhuma OS em aberto.'), findsOneWidget);
    await tester.tap(find.text('Ver todas'));
    await tester.pumpAndSettle();
    expect(find.text('Elis'), findsOneWidget);
  });

  testWidgets('loading and error states', (tester) async {
    await tester.pumpWidget(_app(const _Host(orders: [], isLoading: true)));
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    var retried = 0;
    await tester.pumpWidget(
      _app(_Host(orders: const [], loadFailed: true, onRetry: () => retried++)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tentar novamente'));
    expect(retried, 1);
  });

  testWidgets('large text: filters wrap instead of overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _app(_Host(orders: mixed)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Concluídas'), findsOneWidget);
  });

  testWidgets('renders in dark mode', (tester) async {
    await tester.pumpWidget(
      _app(_Host(orders: mixed), brightness: Brightness.dark),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Ana'), findsOneWidget);
  });

  group('technician', () {
    Order visit(String customer, int number, int hour, {String user = 'u1'}) =>
        _order(customer, 'approved', number: number)
          ..scheduledDate = DateTime(2026, 10, 12, hour, 30)
          ..assignedTo = (UserAggr()..id = user);

    testWidgets('"Agora" block, Minhas | Todas, visit time on the right', (
      tester,
    ) async {
      Order? opened;
      await tester.pumpWidget(
        _app(
          _Host(
            technician: true,
            onOpenOrder: (o) => opened = o,
            orders: [
              visit('Ana Ribeiro', 183, 11),
              visit('Caio', 185, 15),
              visit('Bia', 190, 12, user: 'u2'),
            ],
          ),
        ),
      );
      expect(find.text('Agora'), findsOneWidget);
      expect(find.text('Próximo: Ana, às 11:30.'), findsOneWidget);
      expect(find.text('2 com você hoje'), findsOneWidget);
      expect(find.text('Minhas'), findsOneWidget);
      expect(find.text('Concluídas'), findsNothing);
      expect(find.text('Bia'), findsNothing);
      expect(find.text('15:30'), findsOneWidget);
      await tester.tap(find.text('Abrir OS 183'));
      expect(opened?.number, 183);
    });

    testWidgets('nothing assigned: empty state offers every order', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _Host(technician: true, orders: [visit('Bia', 190, 12, user: 'u2')]),
        ),
      );
      expect(find.text('Nenhuma OS com você.'), findsOneWidget);
      await tester.tap(find.text('Ver todas'));
      await tester.pumpAndSettle();
      expect(find.text('Bia'), findsOneWidget);
    });
  });
}
