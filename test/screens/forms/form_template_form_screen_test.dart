import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/screens/forms/form_template_form_screen.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';

class _Harness {
  Object? result = 'unset';
  final saved = <FormDefinition>[];

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                child: const Text('open'),
                onPressed: () async {
                  result = await FormSheet.show<FormDefinition>(
                    context,
                    (_) => FormTemplateFormScreen(
                      asSheet: true,
                      onSave: (t) async => saved.add(t),
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

final _save = find.byKey(const ValueKey('new_order_save'));
final _close = find.byKey(const ValueKey('new_order_close'));
final _missing = find.byKey(const ValueKey('form_sheet_missing'));

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<CupertinoButton>(_save).onPressed != null;

/// Adds a question through the item editor.
Future<void> _addQuestion(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('checklist_add_question')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(CupertinoTextField).last, label);
  await tester.pump();
  await tester.tap(find.text('Pronto'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // New ids come from FirebaseFirestore.instance.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('new checklist opens as a sheet; X with nothing typed closes', (
    tester,
  ) async {
    final h = _Harness();
    await h.open(tester);

    expect(find.byType(FormSheet), findsOneWidget);
    expect(find.text('Novo checklist'), findsOneWidget);
    expect(find.text('Perguntas'), findsOneWidget);
    expect(find.text('Mais dados'), findsOneWidget);
    expect(find.text('Salvar'), findsNothing);

    await tester.tap(_close);
    await tester.pumpAndSettle();
    expect(find.text('Sair sem salvar?'), findsNothing);
    expect(find.byType(FormSheet), findsNothing);
    expect(h.result, isNull);
  });

  testWidgets('✓ is gray with what is missing until name and a question', (
    tester,
  ) async {
    final h = _Harness();
    await h.open(tester);

    expect(_saveEnabled(tester), isFalse);
    expect(
      find.text('Escreva o nome e adicione uma pergunta para salvar.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(CupertinoTextField).first, 'Entrada');
    await tester.pump();
    expect(_saveEnabled(tester), isFalse);
    expect(find.text('Adicione uma pergunta para salvar.'), findsOneWidget);

    await _addQuestion(tester, 'Pneus');
    expect(find.text('1. Pneus'), findsOneWidget);
    expect(find.text('Texto · com foto'), findsOneWidget);
    expect(_saveEnabled(tester), isTrue);
    expect(_missing, findsNothing);
  });

  testWidgets('with something typed, X asks before discarding', (tester) async {
    final h = _Harness();
    await h.open(tester);
    await tester.enterText(find.byType(CupertinoTextField).first, 'Entrada');
    await tester.pumpAndSettle();

    await tester.tap(_close);
    await tester.pumpAndSettle();
    expect(find.text('Sair sem salvar?'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.byType(FormSheet), findsNothing);
    expect(h.saved, isEmpty);
  });

  testWidgets('✓ saves the checklist with its questions and closes', (
    tester,
  ) async {
    final h = _Harness();
    await h.open(tester);
    await tester.enterText(find.byType(CupertinoTextField).first, 'Entrada');
    await _addQuestion(tester, 'Pneus');
    await _addQuestion(tester, 'Faróis');

    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(h.saved, hasLength(1));
    final template = h.saved.single;
    expect(template.title, 'Entrada');
    expect(template.items.map((i) => i.label), ['Pneus', 'Faróis']);
    expect(template.isActive, isTrue);
    expect(h.result, same(template));
    expect(find.byType(FormSheet), findsNothing);
  });
}
