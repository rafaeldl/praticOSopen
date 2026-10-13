import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_photo.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/screens/menu_navigation/home_content.dart';
import 'package:praticos/screens/menu_navigation/home_groups.dart';
import 'package:praticos/screens/widgets/next_step_block.dart';
import 'package:praticos/screens/widgets/order_list_row.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/widgets/cached_image.dart';

final _now = DateTime(2026, 10, 12, 10);

Order _order(
  String customer,
  String status, {
  int number = 1,
  DateTime? due,
  DateTime? created,
  String? payment,
}) {
  return Order()
    ..id = 'o$number'
    ..number = number
    ..status = status
    ..dueDate = due
    ..createdAt = created ?? DateTime(2026, 10, 1)
    ..payment = payment
    ..total = 100
    ..customer = (CustomerAggr()..name = customer);
}

class _Host extends StatefulWidget {
  const _Host({
    required this.orders,
    this.isLoading = false,
    this.loadFailed = false,
    this.hasAnyOrders,
    this.hasMore = false,
    this.useContracts = false,
    this.unread = 0,
    this.onNewOrder,
    this.onRetry,
    this.onLoadMore,
    this.onViewReported,
    this.technician = false,
    this.onOpenOrder,
  });

  final bool technician;
  final ValueChanged<Order>? onOpenOrder;

  final List<Order> orders;
  final bool isLoading;
  final bool loadFailed;
  final bool? hasAnyOrders;
  final bool hasMore;
  final bool useContracts;
  final int unread;
  final VoidCallback? onNewOrder;
  final VoidCallback? onRetry;
  final VoidCallback? onLoadMore;
  final ValueChanged<HomeView>? onViewReported;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late HomeView view = widget.technician ? HomeView.mine : HomeView.open;

  @override
  Widget build(BuildContext context) {
    return HomeContent(
      orders: widget.orders,
      view: view,
      onViewChanged: (v) {
        widget.onViewReported?.call(v);
        setState(() => view = v);
      },
      title: 'Ordens de serviço',
      isLoading: widget.isLoading,
      hasMore: widget.hasMore,
      loadFailed: widget.loadFailed,
      hasAnyOrders: widget.hasAnyOrders,
      showPrices: true,
      showDevice: true,
      useContracts: widget.useContracts,
      unreadCount: widget.unread,
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
      onNewOrder: widget.onNewOrder ?? () {},
      onRetry: widget.onRetry ?? () {},
      onLoadMore: widget.onLoadMore ?? () {},
      onOpenNotifications: () {},
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

  testWidgets('list state: groups, row content, next step and floating button',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var newOrderTaps = 0;
    await tester.pumpWidget(_app(_Host(
      onNewOrder: () => newOrderTaps++,
      orders: [
        _order('Ana Ribeiro', 'progress',
            number: 184, due: DateTime(2026, 10, 10), payment: 'paid'),
        _order('Bruno', 'progress', number: 185, due: DateTime(2026, 10, 15)),
        _order('Carla', 'quote', number: 186),
      ],
    )));

    expect(find.text('Ordens de serviço'), findsWidgets);
    // Next step: late
    expect(find.byType(NextStepBlock), findsOneWidget);
    expect(find.text('1 OS passou do prazo de entrega.'), findsOneWidget);
    expect(find.text('Ver as atrasadas'), findsOneWidget);
    // Sections
    expect(find.text('Atrasadas'), findsOneWidget);
    expect(find.text('Em andamento'), findsOneWidget);
    expect(find.text('Esperando aprovação'), findsOneWidget);
    expect(find.text('Para hoje'), findsNothing);
    expect(find.text('Aprovadas'), findsNothing);
    // Row content
    expect(find.text('Atrasada 2 dias'), findsOneWidget);
    expect(find.text('Em andamento · entrega 15/10'), findsOneWidget);
    expect(find.text('Pago'), findsOneWidget);
    expect(find.byType(OrderListRow), findsNWidgets(3));
    // Subtitle with count
    expect(find.text('3 em aberto'), findsOneWidget);

    // Floating button
    expect(find.byType(PrimaryButton), findsOneWidget);
    await tester.tap(find.text('Nova OS'));
    expect(newOrderTaps, 1);
  });

  testWidgets('segmented switch Em aberto -> Todas shows month sections',
      (tester) async {
    HomeView? reported;
    await tester.pumpWidget(_app(_Host(
      onViewReported: (v) => reported = v,
      orders: [
        _order('Ana', 'done', number: 1, created: DateTime(2026, 10, 5)),
        _order('Bruno', 'canceled', number: 2, created: DateTime(2026, 9, 20)),
      ],
    )));
    expect(find.text('Em aberto'), findsOneWidget);
    expect(find.text('Todas'), findsOneWidget);

    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();
    expect(reported, HomeView.all);
    expect(find.text('Outubro de 2026'), findsOneWidget);
    expect(find.text('Setembro de 2026'), findsOneWidget);
    // No urgency sections nor next step in "Todas".
    expect(find.byType(NextStepBlock), findsNothing);
  });

  testWidgets('empty "Em aberto" with orders in the company offers Ver todas',
      (tester) async {
    HomeView? reported;
    await tester.pumpWidget(_app(_Host(
      orders: const [],
      hasAnyOrders: true,
      onViewReported: (v) => reported = v,
    )));
    expect(find.text('Nenhuma OS em aberto.'), findsOneWidget);
    expect(find.byType(PrimaryButton), findsOneWidget); // floating Nova OS
    await tester.tap(find.text('Ver todas'));
    await tester.pumpAndSettle();
    expect(reported, HomeView.all);
  });

  testWidgets('first time: next step with button, steps, no floating bar',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(_Host(
      orders: const [],
      hasAnyOrders: false,
      onNewOrder: () => taps++,
    )));
    expect(find.byType(NextStepBlock), findsOneWidget);
    expect(find.text('Como funciona'), findsOneWidget);
    expect(find.byType(CupertinoSlidingSegmentedControl<HomeView>), findsNothing);
    expect(find.byType(CupertinoSearchTextField), findsNothing);
    // Exactly one filled button (inside the block), not a floating one.
    expect(find.byType(PrimaryButton), findsOneWidget);
    await tester.tap(find.text('Nova OS'));
    expect(taps, 1);
  });

  testWidgets('loading and error states', (tester) async {
    await tester.pumpWidget(_app(const _Host(orders: [], isLoading: true)));
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    var retries = 0;
    await tester.pumpWidget(_app(_Host(
      orders: const [],
      loadFailed: true,
      onRetry: () => retries++,
    )));
    expect(find.text('Não deu para carregar as OS.'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    expect(retries, 1);
  });

  testWidgets('search without result offers older orders', (tester) async {
    var loadMore = 0;
    await tester.pumpWidget(_app(_Host(
      hasMore: true,
      onLoadMore: () => loadMore++,
      orders: [_order('Ana', 'progress')],
    )));
    expect(find.byType(CupertinoSearchTextField), findsNothing);
    await tester.tap(find.byIcon(CupertinoIcons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoSearchTextField), 'zzz');
    await tester.pump();
    expect(find.text('Não achei nas OS carregadas.'), findsOneWidget);
    await tester.tap(find.text('Buscar nas mais antigas'));
    expect(loadMore, 1);
  });

  testWidgets('"…" menu has only Ver canceladas, plus Contratos when enabled',
      (tester) async {
    HomeView? reported;
    await tester.pumpWidget(_app(_Host(
      orders: [_order('Ana', 'progress')],
      useContracts: false,
      onViewReported: (v) => reported = v,
    )));
    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();
    expect(find.text('Ver canceladas'), findsOneWidget);
    expect(find.text('Contratos'), findsNothing);
    await tester.tap(find.text('Ver canceladas'));
    await tester.pumpAndSettle();
    expect(reported, HomeView.canceled);
    expect(find.text('Voltar para em aberto'), findsOneWidget);
    expect(find.byType(CupertinoSlidingSegmentedControl<HomeView>), findsNothing);

    await tester.pumpWidget(_app(_Host(
      orders: [_order('Ana', 'progress')],
      useContracts: true,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();
    expect(find.text('Contratos'), findsOneWidget);
  });

  testWidgets('bell has an accessible label with the unread count',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_Host(
      orders: [_order('Ana', 'progress')],
      unread: 3,
    )));
    expect(find.bySemanticsLabel('Avisos, 3 novos'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('renders in dark mode', (tester) async {
    await tester.pumpWidget(_app(
      _Host(orders: [
        _order('Ana', 'progress', due: DateTime(2026, 10, 1)),
      ]),
      brightness: Brightness.dark,
    ));
    expect(find.byType(NextStepBlock), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rows never show a photo, so every row starts at the margin',
      (tester) async {
    await tester.pumpWidget(_app(_Host(
      orders: [
        _order('Ana Ribeiro', 'progress', number: 184)
          ..photos = [OrderPhoto()..url = 'https://example.com/a.jpg'],
        _order('Bruno', 'progress', number: 185),
      ],
    )));

    expect(find.byType(OrderListRow), findsNWidgets(2));
    expect(find.byType(CachedImage), findsNothing);
    expect(
      tester.getTopLeft(find.text('Ana Ribeiro')).dx,
      tester.getTopLeft(find.text('Bruno')).dx,
    );
  });

  testWidgets('search closes with Cancelar and clears the query',
      (tester) async {
    await tester.pumpWidget(_app(_Host(
      orders: [_order('Ana', 'progress'), _order('Bia', 'progress', number: 2)],
    )));
    await tester.tap(find.byIcon(CupertinoIcons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoSearchTextField), 'ana');
    await tester.pump();
    expect(find.text('Bia'), findsNothing);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoSearchTextField), findsNothing);
    expect(find.text('Bia'), findsOneWidget);
  });

  testWidgets('"…" menu is titled with the screen name', (tester) async {
    await tester.pumpWidget(_app(_Host(orders: [_order('Ana', 'progress')])));
    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(CupertinoActionSheet),
        matching: find.text('Ordens de serviço'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('floating Nova OS has no icon', (tester) async {
    await tester.pumpWidget(_app(_Host(orders: [_order('Ana', 'progress')])));
    expect(
      find.descendant(
        of: find.byType(PrimaryButton),
        matching: find.byIcon(CupertinoIcons.add),
      ),
      findsNothing,
    );
  });

  testWidgets('first time: label, subtitle and steps with detail',
      (tester) async {
    await tester.pumpWidget(_app(const _Host(
      orders: [],
      hasAnyOrders: false,
    )));
    expect(find.text('Nenhuma ainda'), findsOneWidget);
    expect(find.text('Comece por aqui'), findsOneWidget);
    expect(find.text('1. Anote o que vai ser feito'), findsOneWidget);
    expect(find.text('pelo WhatsApp, com um link'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.search), findsNothing);
  });

  testWidgets('large text: short sentence and no "Hoje" label',
      (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: _app(_Host(orders: [
        _order('Carlos', 'progress', due: DateTime(2026, 10, 10)),
      ])),
    ));
    expect(find.text('1 OS passou do prazo.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NextStepBlock),
        matching: find.text('Hoje'),
      ),
      findsNothing,
    );
  });

  group('technician', () {
    Order visit(String customer, int number, int hour, {String user = 'u1'}) =>
        _order(customer, 'approved', number: number)
          ..scheduledDate = DateTime(2026, 10, 12, hour, 30)
          ..assignedTo = (UserAggr()..id = user);

    testWidgets('"Agora" block opens the next visit, no floating button',
        (tester) async {
      Order? opened;
      await tester.pumpWidget(_app(_Host(
        technician: true,
        onOpenOrder: (o) => opened = o,
        orders: [
          visit('Ana Ribeiro', 183, 11),
          visit('Bia', 190, 12, user: 'u2'),
        ],
      )));
      expect(find.text('Agora'), findsOneWidget);
      expect(find.text('Próximo: Ana, às 11:30.'), findsOneWidget);
      expect(find.text('1 com você hoje'), findsOneWidget);
      expect(find.text('Minhas'), findsOneWidget);
      expect(find.text('Bia'), findsNothing);
      expect(find.byIcon(CupertinoIcons.ellipsis), findsNothing);
      // Only the block's button: no floating "Nova OS".
      expect(find.byType(PrimaryButton), findsOneWidget);
      await tester.tap(find.text('Abrir OS 183'));
      expect(opened?.number, 183);
    });

    testWidgets('nothing assigned: empty state offers every order',
        (tester) async {
      await tester.pumpWidget(_app(_Host(
        technician: true,
        orders: [visit('Bia', 190, 12, user: 'u2')],
      )));
      expect(find.text('Nenhuma OS com você.'), findsOneWidget);
      await tester.tap(find.text('Ver todas'));
      await tester.pumpAndSettle();
      expect(find.text('Bia'), findsOneWidget);
    });
  });
}
