import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/app_notification.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/notifications/notification_list_screen.dart';
import 'package:praticos/screens/notifications/notification_list_tile.dart';

final _now = DateTime(2026, 10, 12, 12);

AppNotification _n(
  String id,
  String title, {
  bool read = false,
  String type = NotificationType.statusChanged,
  String? number = '183',
  Duration ago = const Duration(minutes: 5),
  Map<String, dynamic>? data,
}) {
  return AppNotification()
    ..id = id
    ..title = title
    ..type = type
    ..orderId = 'order-$id'
    ..orderNumber = number
    ..read = read
    ..data = data
    ..createdAt = _now.subtract(ago);
}

Widget _app(Widget home, {List<Object?>? log}) {
  return CupertinoApp(
    locale: const Locale('pt'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
    ],
    home: home,
    onGenerateRoute: (settings) {
      log?.add(settings);
      return CupertinoPageRoute<void>(
        settings: settings,
        builder: (_) => Text('route ${settings.name}'),
      );
    },
  );
}

Widget _view(
  List<AppNotification> list, {
  ValueChanged<AppNotification>? onOpen,
  VoidCallback? onMarkAll,
  bool isLoading = false,
  bool hasError = false,
}) {
  return NotificationListView(
    notifications: list,
    isLoading: isLoading,
    hasError: hasError,
    now: () => _now,
    onOpen: onOpen ?? (_) {},
    onMarkAllRead: onMarkAll ?? () {},
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  test('payment_received matches the backend type', () {
    expect(NotificationType.paymentReceived, 'payment_received');
  });

  testWidgets('shows count, sections, relative time and order number',
      (tester) async {
    await tester.pumpWidget(_app(_view([
      _n('1', 'Ana aprovou o orçamento'),
      _n('2', 'Carlos comentou', ago: const Duration(hours: 1), number: '184'),
      _n('3', 'Cláudia deu nota 5',
          read: true, ago: const Duration(days: 2), number: '170'),
    ])));
    expect(find.text('Avisos'), findsWidgets);
    expect(find.text('2 novos'), findsOneWidget);
    expect(find.text('Marcar todos como lidos'), findsOneWidget);
    expect(find.text('Novos'), findsOneWidget);
    expect(find.text('Antes'), findsOneWidget);
    expect(find.text('OS 183 · há 5 minutos'), findsOneWidget);
    expect(find.text('OS 184 · há 1 hora'), findsOneWidget);
    expect(find.text('OS 170 · há 2 dias'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chevron_forward), findsNWidgets(3));
  });

  testWidgets('strips emoji from titles', (tester) async {
    expect(stripEmoji('✅ Orçamento aprovado 🎉'), 'Orçamento aprovado');
    expect(stripEmoji('💬 Novo comentário'), 'Novo comentário');
    expect(stripEmoji('Pagou R\$ 350'), 'Pagou R\$ 350');
    await tester.pumpWidget(_app(_view([_n('1', '💰 Paulo pagou R\$ 350')])));
    expect(find.text('Paulo pagou R\$ 350'), findsOneWidget);
    expect(find.textContaining('💰'), findsNothing);
  });

  testWidgets('without unread: no count, no mark-all, only "Antes"',
      (tester) async {
    await tester.pumpWidget(_app(_view([_n('1', 'Ana aprovou', read: true)])));
    expect(find.textContaining('novo'), findsNothing);
    expect(find.text('Marcar todos como lidos'), findsNothing);
    expect(find.text('Novos'), findsNothing);
    expect(find.text('Antes'), findsOneWidget);
  });

  testWidgets('mark all as read calls the callback', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(_view(
      [_n('1', 'Ana aprovou')],
      onMarkAll: () => calls++,
    )));
    await tester.tap(find.text('Marcar todos como lidos'));
    expect(calls, 1);
  });

  testWidgets('rows are buttons and report the tapped notification',
      (tester) async {
    final handle = tester.ensureSemantics();
    final opened = <String?>[];
    await tester.pumpWidget(_app(_view(
      [_n('1', 'Ana aprovou'), _n('2', 'Carlos comentou')],
      onOpen: (n) => opened.add(n.id),
    )));
    expect(
      tester.getSemantics(find.text('Ana aprovou')),
      isNotNull,
    );
    await tester.tap(find.text('Carlos comentou'));
    expect(opened, ['2']);
    handle.dispose();
  });

  testWidgets('empty, loading and error states', (tester) async {
    await tester.pumpWidget(_app(_view(const [])));
    expect(find.text('Nenhum aviso por enquanto.'), findsOneWidget);

    await tester.pumpWidget(_app(_view(const [], isLoading: true)));
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    await tester.pumpWidget(_app(_view(const [], hasError: true)));
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('any notification, comments included, opens the order',
      (tester) async {
    final log = <Object?>[];
    late BuildContext ctx;
    await tester.pumpWidget(_app(
      Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
      log: log,
    ));

    openNotificationOrder(ctx, _n('1', 'Ana aprovou'));
    await tester.pumpAndSettle();
    var settings = log.last as RouteSettings;
    expect(settings.name, '/order');
    var args = settings.arguments as Map<String, dynamic>;
    expect((args['order'] as Order).id, 'order-1');
    expect(args.containsKey('scrollToComments'), isFalse);

    openNotificationOrder(
      ctx,
      _n('2', 'Carlos comentou',
          type: NotificationType.newComment, data: {'commentId': 'c9'}),
    );
    await tester.pumpAndSettle();
    settings = log.last as RouteSettings;
    expect(settings.name, '/order');
    args = settings.arguments as Map<String, dynamic>;
    expect((args['order'] as Order).id, 'order-2');
    expect(args['scrollToComments'], isTrue);
    expect(args['commentId'], 'c9');
  });

  testWidgets('renders in dark mode', (tester) async {
    await tester.pumpWidget(CupertinoTheme(
      data: const CupertinoThemeData(brightness: Brightness.dark),
      child: _app(_view([_n('1', 'Ana aprovou')])),
    ));
    expect(find.text('Ana aprovou'), findsOneWidget);
  });
}
