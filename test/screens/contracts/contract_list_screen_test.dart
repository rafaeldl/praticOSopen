import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/contracts/contract_list_screen.dart';
import 'package:praticos/services/contract_directory.dart';

class _FakeDirectory implements ContractDirectory {
  _FakeDirectory(this.stream);
  final Stream<List<Order>> stream;

  @override
  Stream<List<Order>> watchContractOrders() => stream;
}

Order _order(
  String id,
  String customer, {
  required bool active,
  String frequency = 'monthly',
  int interval = 1,
  DateTime? next,
  DateTime? end,
  String? device,
}) {
  return Order()
    ..id = id
    ..number = 1
    ..customer = (CustomerAggr()..name = customer)
    ..device = device == null ? null : (DeviceAggr()..name = device)
    ..contract = (OrderContract()
      ..active = active
      ..frequency = frequency
      ..interval = interval
      ..nextDueDate = next
      ..endDate = end);
}

Widget _app(
  ContractDirectory directory,
  List<Object?> log, {
  VoidCallback? onNew,
}) {
  return CupertinoApp(
    locale: const Locale('pt'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
    ],
    home: ContractListScreen(directory: directory, onNew: onNew),
    onGenerateRoute: (settings) {
      log.add(settings);
      return CupertinoPageRoute<void>(
        settings: settings,
        builder: (_) => Text('route ${settings.name}'),
      );
    },
  );
}

final _orders = [
  _order('a', 'Ana Ribeiro',
      active: true,
      interval: 6,
      device: 'VW Gol 2018',
      next: DateTime(2026, 11, 12)),
  _order('b', 'Transportes Exemplo',
      active: true, next: DateTime(2026, 11, 1)),
  _order('c', 'Carlos Mendes', active: false, end: DateTime(2026, 6, 30)),
];

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('layout: title, subtitle, tabs, active rows and footer',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final log = <Object?>[];
    await tester.pumpWidget(_app(_FakeDirectory(Stream.value(_orders)), log));
    await tester.pump();

    expect(find.text('Contratos'), findsWidgets);
    expect(find.text('OS que se repetem sozinhas'), findsOneWidget);
    expect(find.text('Ativos'), findsOneWidget);
    expect(find.text('Encerrados'), findsOneWidget);
    expect(find.text('Ana Ribeiro'), findsOneWidget);
    expect(find.textContaining('A cada 6 meses · VW Gol 2018'), findsOneWidget);
    expect(find.textContaining('Próxima OS em 12/11/2026'), findsOneWidget);
    expect(find.textContaining('Todo mês'), findsOneWidget);
    expect(find.text('Carlos Mendes'), findsNothing);
    expect(
      find.text('Contratos nascem dentro de uma OS: ligue “Repetir esta OS”.'),
      findsOneWidget,
    );
    expect(find.byIcon(CupertinoIcons.chevron_forward), findsNWidgets(2));
  });

  testWidgets('Encerrados tab lists ended contracts with the end date',
      (tester) async {
    await tester.pumpWidget(_app(_FakeDirectory(Stream.value(_orders)), []));
    await tester.pump();
    await tester.tap(find.text('Encerrados'));
    await tester.pumpAndSettle();
    expect(find.text('Carlos Mendes'), findsOneWidget);
    expect(find.textContaining('Encerrado em 30/06/2026'), findsOneWidget);
    expect(find.text('Ana Ribeiro'), findsNothing);
  });

  testWidgets('tapping a row opens the order', (tester) async {
    final log = <Object?>[];
    await tester.pumpWidget(_app(_FakeDirectory(Stream.value(_orders)), log));
    await tester.pump();
    await tester.tap(find.text('Ana Ribeiro'));
    await tester.pumpAndSettle();
    final settings = log.last as RouteSettings;
    expect(settings.name, '/order');
    final args = settings.arguments as Map<String, dynamic>;
    expect((args['order'] as Order).id, 'a');
  });

  testWidgets('empty states per tab', (tester) async {
    await tester.pumpWidget(_app(_FakeDirectory(Stream.value([])), []));
    await tester.pump();
    expect(find.text('Nenhum contrato'), findsOneWidget);
    // The empty state points at the "+".
    expect(
      find.text('Toque em + para criar uma OS que se repete sozinha.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Encerrados'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum contrato encerrado.'), findsOneWidget);
  });

  testWidgets('"+" at the top starts a new contract', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _app(_FakeDirectory(Stream.value([])), [], onNew: () => opened++),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('contract_new')));
    expect(opened, 1);
  });

  testWidgets('back button says "Ajustes"', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt', 'BR'),
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () => Navigator.push(
              context,
              CupertinoPageRoute<void>(
                builder: (_) => ContractListScreen(
                  directory: _FakeDirectory(Stream.value([])),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('loading state', (tester) async {
    final never = StreamController<List<Order>>();
    addTearDown(never.close);
    await tester.pumpWidget(_app(_FakeDirectory(never.stream), []));
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });

  testWidgets('error state offers retry', (tester) async {
    await tester.pumpWidget(
      _app(_FakeDirectory(Stream.error(Exception('x'))), []),
    );
    await tester.pump();
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}
