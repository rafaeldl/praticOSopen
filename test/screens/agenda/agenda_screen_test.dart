import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/agenda_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/screens/agenda/agenda_screen.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/services/segment_config_service.dart';
import 'package:table_calendar/table_calendar.dart';

// Thursday.
final _now = DateTime(2026, 10, 8, 9);

UserAggr _user(String id, String name) => UserAggr()
  ..id = id
  ..name = name;

Order _order(
  int number,
  String customer,
  DateTime scheduled, {
  String status = 'approved',
  String? device,
  UserAggr? assignedTo,
}) {
  return Order()
    ..id = 'o$number'
    ..number = number
    ..status = status
    ..scheduledDate = scheduled
    ..dueDate = DateTime(2026, 10, 20)
    ..customer = (CustomerAggr()..name = customer)
    ..device = device == null ? null : (DeviceAggr()..name = device)
    ..assignedTo = assignedTo;
}

final _bruno = _user('u1', 'Bruno');
final _carla = _user('u2', 'Carla');

final _members = [
  Membership(userId: 'u1', user: _bruno),
  Membership(userId: 'u2', user: _carla),
];

AgendaStore _store(List<Order> orders) {
  final store = AgendaStore(permissionFilter: (o) => o);
  store.selectedDate = _now;
  store.orders.addAll(orders);
  return store;
}

Future<void> _pump(
  WidgetTester tester,
  AgendaStore store, {
  bool canFilter = true,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    CupertinoApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AgendaScreen(
        store: store,
        collaborators: _members,
        canFilterByTechnician: canFilter,
        statusLabel: (s) => s == 'approved' ? 'Aprovada' : 'Em andamento',
        loadOnStart: false,
        now: () => _now,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(GlassBarButton));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await initializeDateFormatting('pt');
    SegmentConfigService().setCompanyConfig(
      fieldService: true,
      useScheduling: true,
      useDeviceManagement: false,
      useContracts: false,
    );
  });

  final orders = [
    _order(
      12,
      'Ana Ribeiro',
      DateTime(2026, 10, 8, 14, 30),
      device: 'Fiat Uno',
      assignedTo: _bruno,
    ),
    _order(
      13,
      'Paulo Nunes',
      DateTime(2026, 10, 8, 16),
      status: 'progress',
      assignedTo: _carla,
    ),
    _order(14, 'Joana Lima', DateTime(2026, 10, 9)),
  ];

  testWidgets('week strip shows 7 days and marks the days with orders', (
    tester,
  ) async {
    await _pump(tester, _store(orders));

    // Sunday 4 to Saturday 10.
    for (var d = 4; d <= 10; d++) {
      expect(find.byKey(Key('agenda_day_$d')), findsOneWidget);
    }
    expect(find.byKey(const Key('agenda_day_marker')), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byKey(const Key('agenda_day_8')),
        matching: find.byKey(const Key('agenda_day_marker')),
      ),
      findsOneWidget,
    );
    expect(find.text('Outubro de 2026'), findsOneWidget);
    expect(
      find.text('Quinta-feira, 8 de outubro · 2 marcados'),
      findsOneWidget,
    );
  });

  testWidgets('row shows name, time, status · number and device · person', (
    tester,
  ) async {
    await _pump(tester, _store(orders));

    expect(find.text('Ana Ribeiro'), findsOneWidget);
    expect(find.text('14:30'), findsOneWidget);
    expect(find.text('Aprovada · OS 12'), findsOneWidget);
    expect(find.text('Fiat Uno · com Bruno'), findsOneWidget);
    expect(find.text('Em andamento · OS 13'), findsOneWidget);
    expect(find.text('com Carla'), findsOneWidget);
    expect(find.text('Joana Lima'), findsNothing);
  });

  testWidgets('tapping a day selects it and shows its orders', (tester) async {
    final store = _store(orders);
    await _pump(tester, store);

    await tester.tap(find.byKey(const Key('agenda_day_9')));
    await tester.pumpAndSettle();

    expect(store.selectedDate.day, 9);
    expect(find.text('Joana Lima'), findsOneWidget);
    expect(find.text('Dia todo'), findsOneWidget);
    expect(find.text('Ana Ribeiro'), findsNothing);
    expect(find.text('Sexta-feira, 9 de outubro · 1 marcado'), findsOneWidget);
  });

  testWidgets('chevrons move a week', (tester) async {
    final store = _store(orders);
    await _pump(tester, store);

    await tester.tap(find.bySemanticsLabel('Próxima semana'));
    await tester.pumpAndSettle();

    expect(store.selectedDate.day, 15);
    expect(find.byKey(const Key('agenda_day_11')), findsOneWidget);
  });

  testWidgets('empty day shows the empty state', (tester) async {
    await _pump(tester, _store(orders));

    await tester.tap(find.byKey(const Key('agenda_day_5')));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
    expect(find.text(l10n.noScheduledOrders), findsOneWidget);
    expect(find.text('Segunda-feira, 5 de outubro'), findsOneWidget);
  });

  testWidgets('the menu toggles the month view and back', (tester) async {
    final store = _store(orders);
    await _pump(tester, store);
    expect(find.byType(TableCalendar<void>), findsNothing);

    await _openMenu(tester);
    // Today is selected: no "Hoje".
    expect(find.text('Hoje'), findsNothing);
    await tester.tap(find.text('Ver o mês'));
    await tester.pumpAndSettle();

    expect(store.showMonth, isTrue);
    expect(find.byType(TableCalendar<void>), findsOneWidget);
    // Weekday header matches the week strip: no trailing dot.
    expect(find.text('dom'), findsOneWidget);
    expect(find.text('dom.'), findsNothing);
    expect(find.byKey(const Key('agenda_day_4')), findsNothing);

    await _openMenu(tester);
    await tester.tap(find.text('Ver a semana'));
    await tester.pumpAndSettle();
    expect(find.byType(TableCalendar<void>), findsNothing);
  });

  testWidgets('"Hoje" goes back to today', (tester) async {
    final store = _store(orders);
    await _pump(tester, store);
    await tester.tap(find.byKey(const Key('agenda_day_10')));
    await tester.pumpAndSettle();

    await _openMenu(tester);
    await tester.tap(find.text('Hoje'));
    await tester.pumpAndSettle();

    expect(store.selectedDate.day, 8);
  });

  testWidgets('technician filter: picker, "Só de" and "Mostrar todos"', (
    tester,
  ) async {
    final store = _store(orders);
    await _pump(tester, store);

    await _openMenu(tester);
    await tester.tap(find.text('De quem: Toda a equipe'));
    await tester.pumpAndSettle();

    expect(find.text('De quem mostrar?'), findsWidgets);
    await tester.tap(find.text('Bruno'));
    await tester.pumpAndSettle();

    expect(store.selectedTechnicianId, 'u1');
    expect(find.text('Só de Bruno'), findsOneWidget);
    expect(find.text('Ana Ribeiro'), findsOneWidget);
    expect(find.text('Paulo Nunes'), findsNothing);

    await tester.tap(find.text('Mostrar todos'));
    await tester.pumpAndSettle();

    expect(store.selectedTechnicianId, isNull);
    expect(find.text('Só de Bruno'), findsNothing);
    expect(find.text('Paulo Nunes'), findsOneWidget);
  });

  testWidgets('no "De quem" without permission', (tester) async {
    await _pump(tester, _store(orders), canFilter: false);

    await _openMenu(tester);
    expect(find.text('Ver o mês'), findsOneWidget);
    expect(find.textContaining('De quem'), findsNothing);
  });

  testWidgets('overdue order: danger status with the delay', (tester) async {
    final late = _order(20, 'Rui Costa', DateTime(2026, 10, 8, 11))
      ..dueDate = DateTime(2026, 10, 6);
    await _pump(tester, _store([late]));

    expect(find.text('Atrasada 2 dias · OS 20'), findsOneWidget);
  });

  testWidgets('large text: week, month and rows lay out without overflow', (
    tester,
  ) async {
    final store = _store(orders);
    await _pump(tester, store, textScale: 2);
    expect(tester.takeException(), isNull);

    store.toggleMonth();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
