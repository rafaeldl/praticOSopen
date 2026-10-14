import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/widgets/contract_config_sheet.dart';
import 'package:praticos/services/format_service.dart';

class _Changes {
  String? frequency;
  int? interval;
  DateTime? start;
  DateTime? end = DateTime(1900);
  bool? auto;
  int? reminder;
  bool stopped = false;
}

OrderContract _contract({DateTime? end}) => OrderContract()
  ..frequency = 'monthly'
  ..interval = 1
  ..startDate = DateTime(2026, 10, 1)
  ..endDate = end
  ..autoGenerate = true
  ..reminderDaysBefore = 3;

Future<_Changes> _pump(
  WidgetTester tester, {
  OrderContract? contract,
  double textScale = 1,
  bool withStop = false,
}) async {
  FormatService().setLocale('pt-BR');
  final changes = _Changes();
  await tester.pumpWidget(
    CupertinoApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: ContractConfigScreen(
        contract: contract ?? _contract(),
        onFrequencyChanged: (v) => changes.frequency = v,
        onIntervalChanged: (v) => changes.interval = v,
        onStartDateChanged: (v) => changes.start = v,
        onEndDateChanged: (v) => changes.end = v,
        onAutoGenerateChanged: (v) => changes.auto = v,
        onReminderDaysChanged: (v) => changes.reminder = v,
        onStop: withStop ? () => changes.stopped = true : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return changes;
}

void main() {
  testWidgets('shows the contract in everyday words', (tester) async {
    await _pump(tester);

    expect(find.text('Repetir'), findsWidgets);
    expect(find.text('Repete'), findsOneWidget);
    expect(find.text('Todo mês'), findsOneWidget);
    expect(find.text('01/10/2026'), findsOneWidget);
    expect(find.text('Nunca'), findsOneWidget);
    expect(find.text('3 dias antes'), findsOneWidget);
    expect(find.text('Criar a OS sozinha'), findsOneWidget);
  });

  testWidgets('"Repete" opens the picker and sets frequency and interval', (
    tester,
  ) async {
    final changes = await _pump(tester);

    await tester.tap(find.byKey(const Key('contractRepeatRow')));
    await tester.pumpAndSettle();
    expect(find.text('Com que frequência?'), findsWidgets);
    expect(find.text('Toda semana'), findsOneWidget);

    await tester.tap(find.text('A cada 3 meses'));
    await tester.pumpAndSettle();

    expect(changes.frequency, 'monthly');
    expect(changes.interval, 3);
    expect(find.text('A cada 3 meses'), findsOneWidget);
  });

  testWidgets('"Avisar antes" opens the picker', (tester) async {
    final changes = await _pump(tester);

    await tester.tap(find.byKey(const Key('contractRemindRow')));
    await tester.pumpAndSettle();
    expect(find.text('Avisar quanto tempo antes?'), findsWidgets);

    await tester.tap(find.text('No dia'));
    await tester.pumpAndSettle();

    expect(changes.reminder, 0);
    expect(find.text('No dia'), findsOneWidget);
  });

  testWidgets('"Termina" with a date can go back to never', (tester) async {
    final changes = await _pump(
      tester,
      contract: _contract(end: DateTime(2027, 10, 1)),
    );
    expect(find.text('01/10/2027'), findsOneWidget);

    await tester.tap(find.byKey(const Key('contractEndRow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sem data para terminar'));
    await tester.pumpAndSettle();

    expect(changes.end, isNull);
    expect(find.text('Nunca'), findsOneWidget);
  });

  testWidgets('the switch turns automatic creation off', (tester) async {
    final changes = await _pump(tester);

    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pumpAndSettle();

    expect(changes.auto, isFalse);
  });

  testWidgets('large text does not overflow', (tester) async {
    await _pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Repete'), findsOneWidget);
  });

  testWidgets('"Parar de repetir" asks first and then stops', (tester) async {
    final changes = await _pump(tester, withStop: true);

    await tester.scrollUntilVisible(
      find.byKey(const Key('contractStopRow')),
      200,
    );
    await tester.tap(find.byKey(const Key('contractStopRow')));
    await tester.pumpAndSettle();
    expect(find.text('Parar de repetir?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(changes.stopped, isFalse);

    await tester.tap(find.byKey(const Key('contractStopRow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parar de repetir').last);
    await tester.pumpAndSettle();
    expect(changes.stopped, isTrue);
  });

  testWidgets('no "Parar de repetir" without onStop', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('contractStopRow')), findsNothing);
  });
}
