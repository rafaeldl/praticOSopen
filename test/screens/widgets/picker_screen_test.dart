import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/device_picker_sheet.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';

/// Opens [build] from a launcher; returns what the pushed screen popped.
Future<Object? Function()> open(
  WidgetTester tester,
  Future<Object?> Function(BuildContext context) push,
) async {
  Object? popped = 'unset';
  await tester.pumpWidget(
    CupertinoApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => CupertinoButton(
          child: const Text('open'),
          onPressed: () async => popped = await push(context),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => popped;
}

List<String> names(int n) => [for (var i = 0; i < n; i++) 'Item $i'];

Future<Object? Function()> openPicker(
  WidgetTester tester, {
  required List<String> items,
  String? selected,
  void Function(String query)? onCreate,
}) {
  return open(
    tester,
    (context) => Navigator.of(context).push<String>(
      CupertinoPageRoute(
        builder: (_) => PickerScaffold<String>(
          title: 'Qual item?',
          itemCount: items.length,
          addLabel: 'Novo item',
          onAdd: () {},
          onCreate: onCreate,
          sections: (query) => [
            PickerSection(
              items: [
                for (final i in items)
                  if (pickerMatches(i, query))
                    PickerItem(value: i, title: i, selected: i == selected),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

CupertinoButton confirmButton(WidgetTester tester) => tester
    .widget<CupertinoButton>(find.byKey(const ValueKey('picker_confirm')));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('long question shrinks to fit, never ends in "…"', (
    tester,
  ) async {
    const question = 'Quais OS ele está pagando? Escolha uma ou mais';
    await open(
      tester,
      (context) => Navigator.of(context).push<String>(
        CupertinoPageRoute(
          builder: (_) => PickerScaffold<String>(
            title: question,
            itemCount: 1,
            sections: (_) => [
              PickerSection(items: [PickerItem(value: 'a', title: 'a')]),
            ],
          ),
        ),
      ),
    );
    final title = find.text(question).first;
    expect(
      find.ancestor(of: title, matching: find.byType(FittedBox)),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no search with 10 items', (tester) async {
    await openPicker(tester, items: names(10));
    expect(find.text('Qual item?'), findsOneWidget);
    expect(find.byType(CupertinoSearchTextField), findsNothing);
    expect(find.byKey(const ValueKey('picker-add')), findsOneWidget);
  });

  testWidgets('search shows with 11 items and stays while typed', (
    tester,
  ) async {
    await openPicker(tester, items: names(11));
    expect(find.byType(CupertinoSearchTextField), findsOneWidget);
    await tester.enterText(find.byType(CupertinoSearchTextField), 'Item 1');
    await tester.pumpAndSettle();
    // "Item 1" and "Item 10": two left, the search is still there.
    expect(find.byType(AppListRow), findsNWidgets(2));
    expect(find.byType(CupertinoSearchTextField), findsOneWidget);
  });

  testWidgets('no match turns the add row into "Cadastrar “x”"', (
    tester,
  ) async {
    String? created;
    await openPicker(
      tester,
      items: names(11),
      onCreate: (q) => created = q,
    );
    await tester.enterText(find.byType(CupertinoSearchTextField), 'cambagem');
    await tester.pumpAndSettle();
    expect(find.text('Novo item'), findsNothing);
    expect(find.text('Cadastrar “cambagem”'), findsOneWidget);
    expect(find.text('Nada com “cambagem”.'), findsOneWidget);
    await tester.tap(find.text('Cadastrar “cambagem”'));
    expect(created, 'cambagem');
  });

  testWidgets('selected row has the ✓ and no chevron; tap pops the value', (
    tester,
  ) async {
    final get = await openPicker(tester, items: names(3), selected: 'Item 1');
    final rows = tester.widgetList<AppListRow>(find.byType(AppListRow));
    expect([for (final r in rows) r.selected], [false, true, false]);
    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chevron_forward), findsNothing);
    await tester.tap(find.text('Item 2'));
    await tester.pumpAndSettle();
    expect(get(), 'Item 2');
  });

  testWidgets('empty list shows the empty state with the add action', (
    tester,
  ) async {
    await open(
      tester,
      (context) => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => PickerScaffold<String>(
            title: 'Qual item?',
            itemCount: 0,
            addLabel: 'Novo item',
            onAdd: () {},
            emptyTitle: 'Nenhum item ainda',
            sections: (_) => const [],
          ),
        ),
      ),
    );
    expect(find.text('Nenhum item ainda'), findsOneWidget);
    expect(find.text('Novo item'), findsOneWidget);
  });

  testWidgets('pickOne returns the tapped option, ✓ on the current one', (
    tester,
  ) async {
    final get = await open(
      tester,
      (context) => pickOne<String>(
        context,
        title: 'Qual a situação?',
        selected: 'approved',
        options: const [
          PickerItem(value: 'quote', title: 'Orçamento'),
          PickerItem(value: 'approved', title: 'Aprovada'),
          PickerItem(value: 'done', title: 'Concluída'),
        ],
      ),
    );
    expect(find.text('Qual a situação?'), findsOneWidget);
    final rows = tester.widgetList<AppListRow>(find.byType(AppListRow));
    expect([for (final r in rows) r.selected], [false, true, false]);
    await tester.tap(find.text('Concluída'));
    await tester.pumpAndSettle();
    expect(get(), 'done');
  });

  testWidgets('pickOne back returns null', (tester) async {
    final get = await open(
      tester,
      (context) => pickOne<String>(
        context,
        title: 'Quem é o responsável?',
        options: const [PickerItem(value: 'u1', title: 'Ana')],
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    expect(get(), isNull);
  });

  group('multiple choice (vehicles of the item)', () {
    DeviceAggr car(String id, String name) => DeviceAggr()
      ..id = id
      ..name = name;
    final cars = [car('d1', 'Classic'), car('d2', 'Strada'), car('d3', 'Saveiro')];

    testWidgets('✓ on top goes gray → blue and returns the list', (
      tester,
    ) async {
      final get = await open(
        tester,
        (context) => DevicePickerSheet.show(context, cars),
      );
      expect(confirmButton(tester).onPressed, isNull);
      // No "Confirmar" button at the bottom.
      expect(find.text('Confirmar'), findsNothing);

      await tester.tap(find.text('Classic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saveiro'));
      await tester.pumpAndSettle();
      expect(confirmButton(tester).onPressed, isNotNull);
      final rows = tester.widgetList<AppListRow>(find.byType(AppListRow));
      expect(
        {for (final r in rows) r.title: r.selected},
        containsPair('Classic', true),
      );

      await tester.tap(find.byKey(const ValueKey('picker_confirm')));
      await tester.pumpAndSettle();
      final result = get() as DevicePickerResult;
      expect(result.action, DevicePickerAction.multiSpecific);
      expect(result.deviceIds!.toSet(), {'d1', 'd3'});
    });

    testWidgets('one vehicle returns specific; tapping again unmarks', (
      tester,
    ) async {
      final get = await open(
        tester,
        (context) => DevicePickerSheet.show(context, cars),
      );
      await tester.tap(find.text('Strada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Strada'));
      await tester.pumpAndSettle();
      expect(confirmButton(tester).onPressed, isNull);
      await tester.tap(find.text('Strada'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('picker_confirm')));
      await tester.pumpAndSettle();
      final result = get() as DevicePickerResult;
      expect(result.action, DevicePickerAction.specific);
      expect(result.device!.id, 'd2');
    });
  });
}
