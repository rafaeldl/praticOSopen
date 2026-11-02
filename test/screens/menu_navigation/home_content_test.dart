import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
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
  });

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
    HomeView.open || HomeView.mine || HomeView.quotes =>
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
    // Side by side on one line, like Mail's categories.
    final open = tester.getRect(find.text('Em aberto'));
    final all = tester.getRect(find.text('Todas'));
    expect(all.center.dy, open.center.dy);
    expect(all.left, greaterThan(open.right));

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
