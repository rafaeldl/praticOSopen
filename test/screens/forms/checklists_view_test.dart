import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/screens/forms/checklists_view.dart';
import 'package:praticos/screens/widgets/primary_button.dart';

List<FormItemDefinition> _items(int n, {bool photo = false}) => [
  for (var i = 0; i < n; i++)
    FormItemDefinition(
      id: 'q$i',
      label: 'Pergunta $i',
      type: photo && i == 0 ? FormItemType.photoOnly : FormItemType.boolean,
    ),
];

final _entry = FormDefinition(
  id: 'a',
  title: 'Entrada do veículo',
  items: _items(12, photo: true),
);
final _off = FormDefinition(
  id: 'b',
  title: 'Revisão completa',
  isActive: false,
  items: _items(20),
);
final _ready = FormDefinition(
  id: 'g1',
  title: 'Inspeção de freios',
  items: _items(10),
);

Widget _app(Widget child) => CupertinoApp(
  locale: const Locale('pt'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  testWidgets('layout follows app-checklists', (tester) async {
    await tester.pumpWidget(
      _app(
        ChecklistsView(
          templates: [_entry, _off],
          readyTemplates: [_ready],
          onUseReady: (_) {},
          onNew: () {},
        ),
      ),
    );

    expect(find.text('Checklists'), findsOneWidget);
    expect(find.text('Perguntas que o técnico responde na OS'), findsOneWidget);
    expect(find.text('Seus checklists'), findsOneWidget);
    expect(find.text('12 perguntas · com fotos'), findsOneWidget);
    expect(find.text('Desligado · 20 perguntas'), findsOneWidget);
    expect(find.text('Prontos para usar'), findsOneWidget);
    expect(find.text('10 perguntas'), findsOneWidget);
    expect(find.text('Usar'), findsOneWidget);
    // "+" at the top, not a big blue button over the list.
    expect(find.text('Novo checklist'), findsNothing);
    expect(find.bySemanticsLabel('Novo checklist'), findsOneWidget);
    expect(find.byType(PrimaryButton), findsNothing);
    expect(find.textContaining('PROCEDIMENTOS'), findsNothing);
  });

  testWidgets('taps: edit, use a ready one, preview and new', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      _app(
        ChecklistsView(
          templates: [_entry],
          readyTemplates: [_ready],
          onOpen: (t) => calls.add('open ${t.id}'),
          onUseReady: (t) => calls.add('use ${t.id}'),
          onPreviewReady: (t) => calls.add('preview ${t.id}'),
          onNew: () => calls.add('new'),
        ),
      ),
    );

    await tester.tap(find.text('Entrada do veículo'));
    await tester.tap(find.text('Usar'));
    await tester.tap(find.text('Inspeção de freios'));
    await tester.tap(find.byKey(const ValueKey('checklist_new')));
    expect(calls, ['open a', 'use g1', 'preview g1', 'new']);
  });

  testWidgets('swipe asks before deleting', (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(
      _app(
        ChecklistsView(
          templates: [_entry],
          onDelete: (t) async {
            asked.add(t.id!);
            return false;
          },
        ),
      ),
    );

    await tester.drag(find.text('Entrada do veículo'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(asked, ['a']);
    expect(find.text('Entrada do veículo'), findsOneWidget);
  });

  testWidgets('empty state when there is nothing', (tester) async {
    await tester.pumpWidget(_app(const ChecklistsView(templates: [])));
    expect(
      find.text('Nenhum checklist ainda. Crie um ou use um pronto.'),
      findsOneWidget,
    );
  });
}
