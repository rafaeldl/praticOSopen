import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/ratings/ratings_screen.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/services/format_service.dart';

Order _rated(int number, String customer, int score, {String? comment}) {
  return Order()
    ..id = 'o$number'
    ..number = number
    ..rating = (OrderRating()
      ..score = score
      ..comment = comment
      ..customerName = customer);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await initializeDateFormatting('en_US');
  });

  Future<void> pump(
    WidgetTester tester,
    RatedOrdersLoader loader, {
    List<Order>? opened,
    String locale = 'pt',
  }) async {
    FormatService().setLocale(locale);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CupertinoApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RatingsScreen(
          loader: loader,
          onOpenOrder: (_, order) => opened?.add(order),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('title, subtitle, average and rows as in the prototype',
      (tester) async {
    await pump(
      tester,
      () async => [
        _rated(160, 'Ana', 5, comment: 'Serviço rápido.'),
        _rated(170, 'Cláudia', 5),
        _rated(152, 'André', 3, comment: 'Demorou.'),
        _rated(150, 'Bruno', 5),
      ],
    );

    expect(find.text('Avaliações'), findsWidgets);
    expect(find.text('O que os clientes acharam'), findsOneWidget);
    expect(find.text('4,5 de 5'), findsOneWidget);
    expect(find.text('média de 4 avaliações'), findsOneWidget);
    expect(find.text('Últimas'), findsOneWidget);
    expect(find.text('ÚLTIMAS'), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('3 de 5'), findsOneWidget);
    expect(find.text('“Serviço rápido.” · OS 160'), findsOneWidget);
    expect(find.text('Sem comentário · OS 170'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.star_fill), findsNWidgets(18));
  });

  testWidgets('a row opens its order', (tester) async {
    final opened = <Order>[];
    await pump(
      tester,
      () async => [_rated(160, 'Ana', 5), _rated(170, 'Cláudia', 4)],
      opened: opened,
    );

    await tester.tap(find.text('Cláudia'));
    expect(opened.map((o) => o.number), [170]);
  });

  testWidgets('empty state', (tester) async {
    await pump(tester, () async => []);
    expect(find.text('Nenhuma avaliação ainda'), findsOneWidget);
  });

  testWidgets('error state offers retry', (tester) async {
    await pump(tester, () async => throw Exception('x'));
    expect(find.byType(ErrorState), findsOneWidget);
  });

  testWidgets('english and dark without exceptions', (tester) async {
    await pump(
      tester,
      () async => [_rated(1, 'Ana', 4, comment: 'Nice')],
      locale: 'en',
    );
    expect(find.text('4 of 5'), findsWidgets);
    expect(find.text('average of 1 rating'), findsOneWidget);
    expect(find.text('“Nice” · Order 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
