import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/share/which_order_sheet.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/received_share.dart';

Order _order(String id, int number, String status, String customer) =>
    Order()
      ..id = id
      ..number = number
      ..status = status
      ..customer = (CustomerAggr()..name = customer);

Widget _app(Widget child) => CupertinoApp(
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      home: child,
    );

final _batch = ReceivedBatch(const [
  ReceivedFile(path: '/c/1.jpg', mimeType: 'image/jpeg'),
  ReceivedFile(path: '/c/2.pdf', mimeType: 'application/pdf'),
]);

void main() {
  test('recentOpenOrders drops done/canceled and sorts newest first', () {
    final list = recentOpenOrders([
      _order('1', 1, 'approved', 'A'),
      _order('2', 2, 'done', 'B'),
      _order('3', 3, 'quote', 'C'),
      _order('4', 4, 'canceled', 'D'),
      null,
    ]);
    expect(list.map((o) => o.id), ['3', '1']);
  });

  testWidgets('shows title, summary and rows with status dot', (tester) async {
    await tester.pumpWidget(_app(WhichOrderSheet(
      batch: _batch,
      orders: [
        _order('1', 12, 'progress', 'Maria'),
        _order('2', 11, 'approved', 'João'),
      ],
    )));
    await tester.pumpAndSettle();
    expect(find.text('Em qual OS?'), findsOneWidget);
    expect(find.text('1 foto e 1 PDF'), findsOneWidget);
    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('#12'), findsOneWidget);
    expect(find.byType(StatusDot), findsNWidgets(2));
    expect(find.bySemanticsLabel('Cancelar'), findsOneWidget);
  });

  testWidgets('tapping an order pops it right away', (tester) async {
    WhichOrderChoice? picked;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => CupertinoButton(
        child: const Text('open'),
        onPressed: () async {
          picked = await Navigator.of(context).push<WhichOrderChoice>(
            CupertinoPageRoute(
              builder: (_) => WhichOrderSheet(
                batch: _batch,
                orders: [_order('1', 12, 'progress', 'Maria')],
              ),
            ),
          );
        },
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maria'));
    await tester.pumpAndSettle();
    expect(picked?.isNewOrder, isFalse);
    expect(picked?.order?.id, '1');
  });

  testWidgets('empty list shows the no-open-orders state', (tester) async {
    await tester.pumpWidget(_app(WhichOrderSheet(batch: _batch, orders: const [])));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma OS em aberto.'), findsOneWidget);
  });

  group('search', () {
    Order withDevice(Order o, String name, String serial) => o
      ..devices = [
        DeviceAggr()
          ..name = name
          ..serial = serial,
      ];

    test('matches number, customer (no accents/case) and vehicle or plate',
        () {
      final o = withDevice(
          _order('1', 193, 'progress', 'João Pereira'), 'Gol 2018', 'ABC-1D23');
      expect(orderMatchesSearch(o, '193'), isTrue);
      expect(orderMatchesSearch(o, '#193'), isTrue);
      expect(orderMatchesSearch(o, '# 19'), isTrue);
      expect(orderMatchesSearch(o, '194'), isFalse);
      expect(orderMatchesSearch(o, 'joao'), isTrue);
      expect(orderMatchesSearch(o, 'PEREIRA'), isTrue);
      expect(orderMatchesSearch(o, 'gol'), isTrue);
      expect(orderMatchesSearch(o, 'abc1d23'), isTrue);
      expect(orderMatchesSearch(o, 'abc-1d'), isTrue);
      expect(orderMatchesSearch(o, 'maria'), isFalse);
    });

    test('searchOrders finds done orders, drops canceled, one row per order',
        () {
      final found = searchOrders([
        _order('1', 10, 'done', 'Ana'),
        _order('2', 12, 'canceled', 'Ana'),
        _order('3', 11, 'progress', 'Ana'),
        _order('3', 11, 'progress', 'Ana'),
        null,
      ], 'ana');
      expect(found.map((o) => o.id), ['3', '1']);
    });

    testWidgets('typing searches the latest orders, not only the open ones',
        (tester) async {
      final queries = <String>[];
      await tester.pumpWidget(_app(WhichOrderSheet(
        batch: _batch,
        orders: [_order('1', 12, 'progress', 'Maria')],
        searchPool: [
          _order('9', 5, 'done', 'Paulo Antônio'),
          _order('8', 4, 'canceled', 'Paulo Antônio'),
        ],
        onQueryChanged: queries.add,
      )));
      await tester.pumpAndSettle();
      // The search shows even with a short list: it reaches older orders.
      expect(find.byType(CupertinoSearchTextField), findsOneWidget);

      await tester.enterText(find.byType(CupertinoSearchTextField), 'antonio');
      await tester.pumpAndSettle();
      expect(queries.last, 'antonio');
      expect(find.text('Maria'), findsNothing);
      expect(find.text('Paulo Antônio'), findsOneWidget);
      expect(find.text('#5'), findsOneWidget);
      expect(find.text('#4'), findsNothing);
    });

    testWidgets('shows loading while the latest orders load', (tester) async {
      await tester.pumpWidget(_app(WhichOrderSheet(
        batch: _batch,
        orders: [_order('1', 12, 'progress', 'Maria')],
        searching: true,
      )));
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });
  });

  group('"+" Nova OS', () {
    Future<WhichOrderChoice?> openAndTapAdd(WidgetTester tester) async {
      WhichOrderChoice? picked;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => CupertinoButton(
          child: const Text('open'),
          onPressed: () async {
            picked = await Navigator.of(context).push<WhichOrderChoice>(
              CupertinoPageRoute(
                builder: (_) => WhichOrderSheet(
                  batch: _batch,
                  orders: [_order('1', 12, 'progress', 'Maria')],
                  canCreate: true,
                ),
              ),
            );
          },
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('picker-add')));
      await tester.pumpAndSettle();
      return picked;
    }

    testWidgets('pops "new order"', (tester) async {
      final picked = await openAndTapAdd(tester);
      expect(picked?.isNewOrder, isTrue);
      expect(picked?.order, isNull);
    });

    testWidgets('hidden for who cannot create orders', (tester) async {
      await tester.pumpWidget(_app(WhichOrderSheet(
        batch: _batch,
        orders: [_order('1', 12, 'progress', 'Maria')],
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('picker-add')), findsNothing);
    });

    testWidgets('no open orders: the empty state offers "Nova OS"',
        (tester) async {
      await tester.pumpWidget(_app(WhichOrderSheet(
        batch: _batch,
        orders: const [],
        canCreate: true,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma OS em aberto.'), findsOneWidget);
      expect(find.text('Nova OS'), findsOneWidget);
    });
  });
}
