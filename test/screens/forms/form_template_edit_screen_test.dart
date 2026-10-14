import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/screens/forms/form_template_form_screen.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/primary_button.dart';

FormDefinition _template({bool active = true}) => FormDefinition(
  id: 't1',
  title: 'Vistoria de entrada',
  isActive: active,
  createdAt: DateTime(2026, 1, 1),
  items: [
    FormItemDefinition(
      id: 'q1',
      label: 'Pneus',
      type: FormItemType.boolean,
      required: true,
    ),
    FormItemDefinition(
      id: 'q2',
      label: 'Quilometragem',
      type: FormItemType.number,
      allowPhotos: false,
    ),
    FormItemDefinition(
      id: 'q3',
      label: 'Foto do painel',
      type: FormItemType.photoOnly,
    ),
  ],
);

class _Harness {
  _Harness({this.active = true, this.textScale = 1});

  final bool active;
  final double textScale;
  late final FormDefinition template = _template(active: active);
  final updated = <FormDefinition>[];
  final deleted = <FormDefinition>[];
  final activeCalls = <bool>[];
  Object? result = 'unset';

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                child: const Text('open'),
                onPressed: () async {
                  result = await Navigator.of(context).push<Object?>(
                    CupertinoPageRoute<Object?>(
                      builder: (_) => FormTemplateFormScreen(
                        template: template,
                        onUpdate: (t) async => updated.add(t),
                        onDelete: (t) async => deleted.add(t),
                        onSetActive: (t, a) async => activeCalls.add(a),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

final _save = find.byKey(const ValueKey('checklist_save'));

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<PrimaryButton>(_save).onPressed != null;

bool _doneEnabled(WidgetTester tester) =>
    tester
        .widget<CupertinoButton>(
          find.ancestor(
            of: find.text('Pronto'),
            matching: find.byType(CupertinoButton),
          ),
        )
        .onPressed !=
    null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('shows the name as title, question count and one blue button', (
    tester,
  ) async {
    final h = _Harness();
    await h.open(tester);

    // Large title (and the name field) carry the checklist name.
    expect(find.text('Vistoria de entrada'), findsWidgets);
    expect(find.text('3 perguntas'), findsOneWidget);
    expect(find.text('Desligado'), findsNothing);
    expect(find.text('Salvar checklist'), findsOneWidget);
    expect(_saveEnabled(tester), isTrue);

    expect(find.text('1. Pneus'), findsOneWidget);
    expect(find.text('Sim ou não · obrigatória · com foto'), findsOneWidget);
    expect(find.text('2. Quilometragem'), findsOneWidget);
    expect(find.text('Número'), findsOneWidget);
    expect(find.text('3. Foto do painel'), findsOneWidget);
    expect(find.text('Só foto'), findsOneWidget);
    expect(find.text('Adicionar pergunta'), findsOneWidget);
    // Old pattern gone.
    expect(find.text('Ativo'), findsNothing);
    expect(find.text('Cancelar'), findsNothing);
    expect(find.text('Arraste para reordenar'), findsNothing);
  });

  testWidgets('saving writes the edits and pops with the checklist', (
    tester,
  ) async {
    final h = _Harness();
    await h.open(tester);

    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Vistoria de entrada'),
      'Vistoria de saída',
    );
    await tester.pump();
    expect(find.text('Vistoria de saída'), findsWidgets);

    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(h.updated, hasLength(1));
    expect(h.updated.single.title, 'Vistoria de saída');
    expect(h.updated.single.items, hasLength(3));
    expect(h.result, same(h.template));
  });

  testWidgets('tapping a question opens the editor with the type checked', (
    tester,
  ) async {
    final h = _Harness();
    await h.open(tester);

    await tester.tap(find.text('1. Pneus'));
    await tester.pumpAndSettle();

    expect(find.text('Pergunta'), findsWidgets);
    expect(find.text('Tipo de resposta'), findsOneWidget);
    expect(find.text('Pronto'), findsOneWidget);
    expect(_doneEnabled(tester), isTrue);
    final boolean = tester.widget<AppListRow>(
      find.byKey(const ValueKey('question_type_boolean')),
    );
    expect(boolean.selected, isTrue);
    final text = tester.widget<AppListRow>(
      find.byKey(const ValueKey('question_type_text')),
    );
    expect(text.selected, isFalse);
    expect(find.text('Obrigatória'), findsOneWidget);
    expect(find.text('Não deixa concluir sem responder'), findsOneWidget);
    expect(find.text('Pode pôr foto'), findsOneWidget);
    expect(find.text('Apagar pergunta'), findsOneWidget);
  });

  testWidgets('a choice type needs 2 options before "Pronto"', (tester) async {
    final h = _Harness();
    await h.open(tester);
    await tester.tap(find.text('1. Pneus'));
    await tester.pumpAndSettle();

    expect(find.text('Opções'), findsNothing);
    await tester.tap(find.text('Escolher uma opção'));
    await tester.pumpAndSettle();

    expect(find.text('Opções'), findsOneWidget);
    expect(_doneEnabled(tester), isFalse);
    expect(
      find.text('Escreva pelo menos 2 opções, uma por linha.'),
      findsOneWidget,
    );

    final options = find.descendant(
      of: find.byKey(const ValueKey('question_options')),
      matching: find.byType(CupertinoTextField),
    );
    await tester.enterText(options, 'Bom');
    await tester.pump();
    expect(_doneEnabled(tester), isFalse);

    await tester.enterText(options, 'Bom\nRuim');
    await tester.pump();
    expect(_doneEnabled(tester), isTrue);

    await tester.tap(find.text('Pronto'));
    await tester.pumpAndSettle();
    expect(
      find.text('Escolher uma opção · obrigatória · com foto'),
      findsOneWidget,
    );

    await tester.tap(_save);
    await tester.pumpAndSettle();
    final item = h.updated.single.items.first;
    expect(item.type, FormItemType.select);
    expect(item.options, ['Bom', 'Ruim']);
  });

  testWidgets('a new question needs its text before "Pronto"', (tester) async {
    final h = _Harness();
    await h.open(tester);
    await tester.tap(find.text('Adicionar pergunta'));
    await tester.pumpAndSettle();

    expect(find.text('Nova pergunta'), findsOneWidget);
    expect(find.text('Apagar pergunta'), findsNothing);
    expect(_doneEnabled(tester), isFalse);
    expect(find.text('Escreva a pergunta para continuar.'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField).last, 'Faróis');
    await tester.pump();
    expect(_doneEnabled(tester), isTrue);
    await tester.tap(find.text('Pronto'));
    await tester.pumpAndSettle();

    expect(find.text('4. Faróis'), findsOneWidget);
    expect(find.text('4 perguntas'), findsOneWidget);
  });

  testWidgets('"Apagar pergunta" removes the row', (tester) async {
    final h = _Harness();
    await h.open(tester);
    await tester.tap(find.text('2. Quilometragem'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apagar pergunta'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Quilometragem'), findsNothing);
    expect(find.text('2 perguntas'), findsOneWidget);
    expect(find.text('2. Foto do painel'), findsOneWidget);
    expect(h.updated, isEmpty);
  });

  testWidgets('leaving with changes asks before discarding', (tester) async {
    final h = _Harness();
    await h.open(tester);
    await tester.tap(find.text('1. Pneus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar pergunta'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Checklists'));
    await tester.pumpAndSettle();
    expect(find.text('Sair sem salvar?'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(h.updated, isEmpty);
  });

  testWidgets('"…" turns it off and deletes it', (tester) async {
    final h = _Harness();
    await h.open(tester);

    await tester.tap(find.byKey(const ValueKey('checklist_more')));
    await tester.pumpAndSettle();
    expect(find.text('Não usar na empresa'), findsOneWidget);
    expect(find.text('Apagar checklist'), findsOneWidget);

    await tester.tap(find.text('Não usar na empresa'));
    await tester.pumpAndSettle();
    expect(h.activeCalls, [false]);
    expect(find.text('Desligado · 3 perguntas'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('checklist_more')));
    await tester.pumpAndSettle();
    expect(find.text('Voltar a usar'), findsOneWidget);
    await tester.tap(find.text('Apagar checklist'));
    await tester.pumpAndSettle();
    expect(find.text('Apagar este checklist?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('checklist_delete_confirm')));
    await tester.pumpAndSettle();

    expect(h.deleted, [same(h.template)]);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('an inactive checklist shows "Desligado" under the title', (
    tester,
  ) async {
    final h = _Harness(active: false);
    await h.open(tester);
    expect(find.text('Desligado · 3 perguntas'), findsOneWidget);
  });

  testWidgets('large text does not overflow', (tester) async {
    final h = _Harness(textScale: 2);
    await h.open(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('1. Pneus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escolher várias opções'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('the editor offers every answer type once, "Sim ou não" first', () {
    expect(questionTypeOrder.first, FormItemType.boolean);
    expect(questionTypeOrder.toSet(), FormItemType.values.toSet());
    expect(questionTypeOrder.length, FormItemType.values.length);
  });
}
