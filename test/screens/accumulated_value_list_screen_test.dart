import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/accumulated_value.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/repositories/accumulated_value_repository.dart';
import 'package:praticos/screens/accumulated_value_list_screen.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';

class FakeRepo extends AccumulatedValueRepository {
  FakeRepo(this.values);

  final List<AccumulatedValue> values;
  final List<String> removed = [];
  final List<String> used = [];

  @override
  Future<List<AccumulatedValue>> getAll(String companyId, String fieldType,
          {String? group}) async =>
      [...values];

  @override
  Future<void> remove(String companyId, String fieldType, String id) async {
    removed.add(id);
    values.removeWhere((x) => x.id == id);
  }

  @override
  Future<String> use(String companyId, String fieldType, String value,
      {String? group}) async {
    used.add(value);
    return 'id-$value';
  }
}

AccumulatedValue v(String id, String value, {int usage = 3}) =>
    AccumulatedValue(id: id, value: value, usageCount: usage);

Future<Object? Function()> pumpScreen(
  WidgetTester tester,
  FakeRepo repo, {
  bool canDelete = true,
  Map<String, dynamic>? args,
}) async {
  Object? popped = 'unset';
  await tester.pumpWidget(
    CupertinoApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => CupertinoButton(
          child: const Text('open'),
          onPressed: () async {
            popped = await Navigator.of(context).push(
              CupertinoPageRoute(
                settings: RouteSettings(arguments: {
                  'fieldType': 'deviceBrand',
                  'title': 'Marca',
                  ...?args,
                }),
                builder: (_) => AccumulatedValueListScreen(
                  repository: repo,
                  canDelete: (_) => canDelete,
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => popped;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(() => Global.companyAggr = CompanyAggr()..id = 'c1');
  tearDown(() => Global.companyAggr = null);

  testWidgets('rows are AppListRow with a check on the current choice and no count',
      (tester) async {
    await pumpScreen(
      tester,
      FakeRepo([v('1', 'Fiat', usage: 9), v('2', 'Honda')]),
      args: {'currentValue': 'Honda'},
    );
    expect(find.byType(AppListRow), findsNWidgets(2));
    expect(find.text('✓'), findsOneWidget);
    expect(find.text('9'), findsNothing);
  });

  testWidgets('typing a new value puts "Usar “X”" on top and returns it',
      (tester) async {
    final repo = FakeRepo([v('1', 'Fiat'), v('2', 'Ford')]);
    final get = await pumpScreen(tester, repo);
    await tester.enterText(find.byType(CupertinoSearchTextField), 'Fo');
    await tester.pumpAndSettle();
    expect(find.text('Usar “Fo”'), findsOneWidget);
    final add = tester.getTopLeft(find.text('Usar “Fo”')).dy;
    final ford = tester.getTopLeft(find.text('Ford')).dy;
    expect(add, lessThan(ford));
    await tester.tap(find.text('Usar “Fo”'));
    await tester.pumpAndSettle();
    expect(repo.used, ['Fo']);
    expect(get(), 'Fo');
  });

  testWidgets('"Deixar em branco" replaces the red Limpar and returns clear',
      (tester) async {
    final get = await pumpScreen(
      tester,
      FakeRepo([v('1', 'Fiat')]),
      args: {'currentValue': 'Fiat', 'allowClear': true},
    );
    expect(find.text('Limpar'), findsNothing);
    await tester.tap(find.text('Deixar em branco'));
    await tester.pumpAndSettle();
    expect(get(), 'clear');
  });

  testWidgets('swipe deletes after a translated confirmation', (tester) async {
    final repo = FakeRepo([v('1', 'Fiat')]);
    await pumpScreen(tester, repo);
    await tester.drag(find.byType(Dismissible), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Apagar “Fiat”?'), findsOneWidget);
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(repo.removed, ['1']);
    expect(find.text('Fiat'), findsNothing);
  });

  testWidgets('without permission there is no swipe to delete', (tester) async {
    await pumpScreen(tester, FakeRepo([v('1', 'Fiat')]), canDelete: false);
    expect(find.byType(Dismissible), findsNothing);
    expect(find.text('Fiat'), findsOneWidget);
  });
}
