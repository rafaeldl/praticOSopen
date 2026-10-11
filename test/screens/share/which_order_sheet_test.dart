import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
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
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('tapping an order pops it right away', (tester) async {
    Order? picked;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => CupertinoButton(
        child: const Text('open'),
        onPressed: () async {
          picked = await Navigator.of(context).push<Order>(
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
    expect(picked?.id, '1');
  });

  testWidgets('empty list shows the no-open-orders state', (tester) async {
    await tester.pumpWidget(_app(WhichOrderSheet(batch: _batch, orders: const [])));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma OS em aberto.'), findsOneWidget);
  });
}
