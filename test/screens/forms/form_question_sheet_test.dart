import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/screens/forms/form_question_sheet.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/theme/app_glass.dart';

FormItemDefinition _item(
  String id,
  FormItemType type, {
  List<String>? options,
  bool required = false,
  bool allowPhotos = false,
}) => FormItemDefinition(
  id: id,
  label: 'Pergunta $id',
  type: type,
  options: options,
  required: required,
  allowPhotos: allowPhotos,
);

/// Hosts the sheet like [FormFillScreen] does: answers update the form and
/// rebuild the sheet.
class _Host extends StatefulWidget {
  const _Host({
    required this.form,
    required this.answers,
    this.photos,
    this.onEnd,
    this.onClose,
    this.initialIndex = 0,
  });

  final OrderForm form;
  final List<(String, dynamic)> answers;
  final List<(String, ImageSource)>? photos;
  final VoidCallback? onEnd;
  final VoidCallback? onClose;
  final int initialIndex;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) {
    return FormQuestionSheet(
      form: widget.form,
      initialIndex: widget.initialIndex,
      localeCode: 'pt',
      onAnswer: (item, value) {
        widget.answers.add((item.id, value));
        setState(() {
          widget.form.responses = [
            ...widget.form.responses.where((r) => r.itemId != item.id),
            FormResponse(itemId: item.id, value: value),
          ];
        });
      },
      onAddPhoto: widget.photos == null
          ? null
          : (item, source) => widget.photos!.add((item.id, source)),
      onEnd: widget.onEnd ?? () {},
      onClose: widget.onClose ?? () {},
    );
  }
}

Widget _app(Widget child) => CupertinoApp(
  locale: const Locale('pt'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

OrderForm _form(
  List<FormItemDefinition> items, [
  List<FormResponse> responses = const [],
]) => OrderForm(
  id: 'f1',
  formDefinitionId: 'd1',
  title: 'Entrada do veículo',
  items: items,
  responses: responses,
);

String _label(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('question_label'))).data!;

void main() {
  testWidgets('header: title, segments, "Faltam N" and big question', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _Host(
          form: _form([
            _item('1', FormItemType.boolean),
            _item('2', FormItemType.boolean, required: true),
            _item('3', FormItemType.boolean),
          ]),
          answers: [],
        ),
      ),
    );

    expect(find.text('Entrada do veículo'), findsOneWidget);
    expect(find.text('Faltam 3'), findsOneWidget);
    expect(find.textContaining(' de '), findsNothing);
    expect(find.byKey(const ValueKey('question_progress')), findsOneWidget);
    expect(_label(tester), 'Pergunta 1');
    expect(find.byKey(const ValueKey('question_skip')), findsOneWidget);
    // First question: nothing to go back to.
    expect(find.byKey(const ValueKey('question_previous')), findsNothing);
  });

  testWidgets('yes/no: 64-high buttons, a tap saves and moves on', (
    tester,
  ) async {
    final answers = <(String, dynamic)>[];
    var ended = false;
    await tester.pumpWidget(
      _app(
        _Host(
          form: _form([
            _item('1', FormItemType.boolean),
            _item('2', FormItemType.boolean),
          ]),
          answers: answers,
          onEnd: () => ended = true,
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('answer_yes'))).height,
      greaterThanOrEqualTo(kAnswerButtonHeight),
    );
    await tester.tap(find.text('Sim'));
    await tester.pump();
    expect(answers, [('1', true)]);
    expect(_label(tester), 'Pergunta 2');
    expect(find.text('Falta 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('question_previous')), findsOneWidget);

    await tester.tap(find.text('Não'));
    await tester.pump();
    expect(answers.last, ('2', false));
    expect(ended, isTrue);
  });

  testWidgets('an answer skips questions already answered and ends after', (
    tester,
  ) async {
    var ended = false;
    await tester.pumpWidget(
      _app(
        _Host(
          form: _form(
            [
              _item('1', FormItemType.boolean),
              _item('2', FormItemType.boolean),
              _item('3', FormItemType.boolean),
              _item('4', FormItemType.text),
            ],
            [
              FormResponse(itemId: '2', value: true),
              FormResponse(itemId: '4', value: 'Já escrito'),
            ],
          ),
          answers: [],
          onEnd: () => ended = true,
        ),
      ),
    );

    await tester.tap(find.text('Sim'));
    await tester.pump();
    expect(_label(tester), 'Pergunta 3');

    await tester.tap(find.text('Sim'));
    await tester.pump();
    expect(ended, isTrue);
  });

  testWidgets('single choice: a tap saves the option and moves on', (
    tester,
  ) async {
    final answers = <(String, dynamic)>[];
    await tester.pumpWidget(
      _app(
        _Host(
          form: _form([
            _item(
              '1',
              FormItemType.select,
              options: ['Cheio', 'Meio', 'Reserva'],
            ),
            _item('2', FormItemType.boolean),
          ]),
          answers: answers,
        ),
      ),
    );

    expect(find.text('Cheio'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('answer_option_1'))).height,
      greaterThanOrEqualTo(kAnswerButtonHeight),
    );
    await tester.tap(find.text('Meio'));
    await tester.pump();
    expect(answers, [('1', 'Meio')]);
    expect(_label(tester), 'Pergunta 2');

    // Back: the saved option shows the ✓.
    await tester.tap(find.byKey(const ValueKey('question_previous')));
    await tester.pump();
    expect(_label(tester), 'Pergunta 1');
    expect(find.byKey(const ValueKey('answer_check')), findsOneWidget);
  });

  testWidgets('multiple choice: ✓ on each, "Pronto" saves and moves on', (
    tester,
  ) async {
    final answers = <(String, dynamic)>[];
    await tester.pumpWidget(
      _app(
        _Host(
          form: _form([
            _item(
              '1',
              FormItemType.checklist,
              options: ['Óleo', 'Filtro', 'Água'],
            ),
            _item('2', FormItemType.boolean),
          ]),
          answers: answers,
        ),
      ),
    );

    await tester.tap(find.text('Óleo'));
    await tester.pump();
    await tester.tap(find.text('Água'));
    await tester.pump();
    // Marking does not save nor move on.
    expect(answers, isEmpty);
    expect(_label(tester), 'Pergunta 1');
    expect(find.byKey(const ValueKey('answer_check')), findsNWidgets(2));

    await tester.tap(find.text('Água'));
    await tester.pump();
    expect(find.byKey(const ValueKey('answer_check')), findsOneWidget);

    await tester.tap(find.text('Pronto'));
    await tester.pump();
    expect(answers.single.$1, '1');
    expect(answers.single.$2, ['Óleo']);
    expect(_label(tester), 'Pergunta 2');
  });

  testWidgets('multiple choice: "Pronto" is off until something is marked', (
    tester,
  ) async {
    final answers = <(String, dynamic)>[];
    await tester.pumpWidget(
      _app(
        _Host(
          form: _form([
            _item(
              '1',
              FormItemType.checklist,
              options: ['Óleo', 'Filtro'],
              required: true,
            ),
            _item('2', FormItemType.boolean),
          ]),
          answers: answers,
        ),
      ),
    );

    PrimaryButton primary() => tester.widget<PrimaryButton>(
      find.byKey(const ValueKey('question_primary')),
    );
    expect(primary().onPressed, isNull);
    await tester.tap(find.text('Pronto'));
    await tester.pump();
    expect(answers, isEmpty);
    expect(_label(tester), 'Pergunta 1');

    await tester.tap(find.text('Filtro'));
    await tester.pump();
    expect(primary().onPressed, isNotNull);
  });

  testWidgets('text: field and "Próxima" saves and moves on', (tester) async {
    final answers = <(String, dynamic)>[];
    await tester.pumpWidget(
      _app(
        _Host(
          form: _form([
            _item('1', FormItemType.text),
            _item('2', FormItemType.boolean),
          ]),
          answers: answers,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('question_field')),
      ' Risco na porta ',
    );
    await tester.tap(find.text('Próxima'));
    await tester.pump();
    expect(answers, [('1', 'Risco na porta')]);
    expect(_label(tester), 'Pergunta 2');
  });

  testWidgets('number: numeric keyboard; going back keeps what was typed', (
    tester,
  ) async {
    final answers = <(String, dynamic)>[];
    await tester.pumpWidget(
      _app(
        _Host(
          form: _form([
            _item('1', FormItemType.boolean),
            _item('2', FormItemType.number),
          ]),
          answers: answers,
          initialIndex: 1,
        ),
      ),
    );

    final field = tester.widget<CupertinoTextField>(
      find.byKey(const ValueKey('question_field')),
    );
    expect(
      field.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );

    await tester.enterText(
      find.byKey(const ValueKey('question_field')),
      '85000',
    );
    await tester.tap(find.byKey(const ValueKey('question_previous')));
    await tester.pump();
    expect(answers, [('2', '85000')]);
    expect(_label(tester), 'Pergunta 1');
  });

  testWidgets('photo: "Tirar foto" opens the camera, gallery is a link', (
    tester,
  ) async {
    final photos = <(String, ImageSource)>[];
    await tester.pumpWidget(
      _app(
        _Host(
          form: _form([_item('1', FormItemType.photoOnly)]),
          answers: [],
          photos: photos,
        ),
      ),
    );

    await tester.tap(find.text('Tirar foto'));
    await tester.tap(find.text('Escolher da galeria'));
    expect(photos, [('1', ImageSource.camera), ('1', ImageSource.gallery)]);
  });

  testWidgets('photo answered: "Próxima" moves on', (tester) async {
    var ended = false;
    await tester.pumpWidget(
      _app(
        _Host(
          form: _form(
            [_item('1', FormItemType.photoOnly)],
            [
              FormResponse(itemId: '1', photoUrls: ['https://x/a.jpg']),
            ],
          ),
          answers: [],
          photos: [],
          onEnd: () => ended = true,
        ),
      ),
    );

    expect(find.text('Tudo respondido'), findsOneWidget);
    expect(find.text('Tirar outra foto'), findsOneWidget);
    await tester.tap(find.text('Próxima'));
    expect(ended, isTrue);
  });

  testWidgets('allowPhotos: glass "Foto" button at the bottom', (tester) async {
    final photos = <(String, ImageSource)>[];
    await tester.pumpWidget(
      _app(
        _Host(
          form: _form([_item('1', FormItemType.boolean, allowPhotos: true)]),
          answers: [],
          photos: photos,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('question_photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escolher da galeria'));
    await tester.pumpAndSettle();
    expect(photos, [('1', ImageSource.gallery)]);
  });

  testWidgets('"Pular por agora" moves on without saving; "Fechar" closes', (
    tester,
  ) async {
    final answers = <(String, dynamic)>[];
    var closed = false;
    await tester.pumpWidget(
      _app(
        _Host(
          form: _form([
            _item('1', FormItemType.boolean, required: true),
            _item('2', FormItemType.boolean),
          ]),
          answers: answers,
          onClose: () => closed = true,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('question_skip')));
    await tester.pump();
    expect(answers, isEmpty);
    expect(_label(tester), 'Pergunta 2');
    // The skipped one still counts.
    expect(find.text('Faltam 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('question_close')));
    expect(closed, isTrue);
  });

  testWidgets('bottom bar: glass "‹ Anterior", "Foto", "Pular ›" on one line', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        _Host(
          form: _form([
            _item('1', FormItemType.boolean, allowPhotos: true),
            _item('2', FormItemType.boolean, allowPhotos: true),
          ]),
          answers: [],
          photos: [],
          initialIndex: 1,
        ),
      ),
    );

    final previous = find.byKey(const ValueKey('question_previous'));
    final photo = find.byKey(const ValueKey('question_photo'));
    final skip = find.byKey(const ValueKey('question_skip'));
    // Short labels; no underlined links left.
    expect(find.text('Anterior'), findsOneWidget);
    expect(find.text('Foto'), findsOneWidget);
    expect(find.text('Pular'), findsOneWidget);
    expect(find.text('Voltar à anterior'), findsNothing);
    expect(find.text('Pular por agora'), findsNothing);
    // Glass capsules at least 44 high, side by side on one line.
    for (final button in [previous, photo, skip]) {
      expect(
        find.descendant(of: button, matching: find.byType(AppGlass)),
        findsOneWidget,
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    }
    expect(tester.getCenter(previous).dy, tester.getCenter(skip).dy);
    expect(tester.getCenter(photo).dy, tester.getCenter(skip).dy);
    expect(tester.getCenter(previous).dx, lessThan(tester.getCenter(photo).dx));
    expect(tester.getCenter(photo).dx, lessThan(tester.getCenter(skip).dx));
    // The screen reader hears the full name.
    expect(find.bySemanticsLabel('Voltar à anterior'), findsOneWidget);
    expect(find.bySemanticsLabel('Pular por agora'), findsOneWidget);
    expect(find.bySemanticsLabel('Foto'), findsOneWidget);
    handle.dispose();
  });

  // The test font draws every letter as wide as it is tall, so the widths
  // that make each case are bigger than on an iPhone.
  for (final (width, scale, labels) in [
    (800.0, 1.0, ['Anterior', 'Foto', 'Pular']),
    // Does not fit: "Foto" becomes just the camera first.
    (500.0, 1.0, ['Anterior', 'Pular']),
    // Biggest text: only icons, still one line.
    (375.0, 3.0, <String>[]),
  ]) {
    testWidgets('bottom bar: one line at width $width, text size $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, 812 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: _Host(
                form: _form([
                  _item('1', FormItemType.boolean, allowPhotos: true),
                  _item('2', FormItemType.boolean, allowPhotos: true),
                ]),
                answers: [],
                photos: [],
                initialIndex: 1,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final keys = ['question_previous', 'question_photo', 'question_skip'];
      final centers = [
        for (final k in keys) tester.getCenter(find.byKey(ValueKey(k))),
      ];
      // One line, left to right, at least 44 high.
      expect(centers.map((c) => c.dy).toSet(), hasLength(1));
      expect(centers[0].dx, lessThan(centers[1].dx));
      expect(centers[1].dx, lessThan(centers[2].dx));
      for (final k in keys) {
        final size = tester.getSize(find.byKey(ValueKey(k)));
        expect(size.height, greaterThanOrEqualTo(44));
        expect(size.width, greaterThanOrEqualTo(44));
      }
      // The labels that fit stay on one line (no word broken in two).
      for (final label in ['Anterior', 'Foto', 'Pular']) {
        expect(
          find.text(label),
          labels.contains(label) ? findsOneWidget : findsNothing,
        );
      }
      final line = tester.getSize(find.text('Faltam 2')).height;
      for (final label in labels) {
        expect(
          tester.getSize(find.text(label)).height,
          lessThanOrEqualTo(line + 1),
        );
      }
      // Icon or not, the screen reader hears the full name.
      expect(find.bySemanticsLabel('Voltar à anterior'), findsOneWidget);
      expect(find.bySemanticsLabel('Pular por agora'), findsOneWidget);
      handle.dispose();
    });
  }

  test('counting helpers', () {
    final form = _form(
      [
        _item('1', FormItemType.boolean),
        _item('2', FormItemType.checklist, options: ['a']),
        _item('3', FormItemType.photoOnly),
        _item('4', FormItemType.text),
      ],
      [
        FormResponse(itemId: '1', value: false),
        FormResponse(itemId: '2', value: <String>[]),
        FormResponse(itemId: '3', photoUrls: ['u']),
        FormResponse(itemId: '4', value: '  '),
      ],
    );
    expect(formItemsMissing(form), 2);
    expect(firstUnansweredIndex(form), 1);
  });

  group('note', () {
    setUp(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(800, 2000);
      view.devicePixelRatio = 1;
    });
    tearDown(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    OrderForm multiForm(Map<String, FormItemNote> notes) => OrderForm(
      id: 'f1',
      formDefinitionId: 'd1',
      title: 'Entrada do veículo',
      items: [
        FormItemDefinition(
          id: 'dano',
          label: 'Onde tem dano?',
          type: FormItemType.checklist,
          options: ['Porta', 'Para-choque', 'Capô'],
          optionsI18n: {
            'en': ['Door', 'Bumper', 'Hood'],
          },
          allowPhotos: true,
        ),
      ],
      responses: [
        FormResponse(
          itemId: 'dano',
          value: ['Porta', 'Capô'],
          photoUrls: ['https://x/1.jpg'],
        ),
      ],
      notes: notes,
    );

    Widget sheet(OrderForm form, List<(String, FormItemNote)> saved) =>
        _app(
          FormQuestionSheet(
            form: form,
            localeCode: 'pt',
            onAnswer: (_, _) {},
            onEnd: () {},
            onClose: () {},
            onNote: (item, note) => saved.add((item.id, note)),
          ),
        );

    testWidgets('"+ Observação" link when there is none', (tester) async {
      await tester.pumpWidget(sheet(multiForm({}), []));
      expect(find.text('+ Observação'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('question_note_add'))).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('without onNote the link is not there', (tester) async {
      await tester.pumpWidget(
        _app(
          FormQuestionSheet(
            form: multiForm({}),
            onAnswer: (_, _) {},
            onEnd: () {},
            onClose: () {},
          ),
        ),
      );
      expect(find.text('+ Observação'), findsNothing);
    });

    testWidgets(
      'shows the question, marked option and photo notes; edited text loses ✦',
      (tester) async {
        final saved = <(String, FormItemNote)>[];
        await tester.pumpWidget(
          sheet(
            multiForm({
              'dano': FormItemNote(
                text: 'Amassado na lateral',
                ai: true,
                options: [
                  FormOptionNote(option: 'Porta', text: 'perto da maçaneta'),
                  // Not marked: kept, not shown.
                  FormOptionNote(option: 'Para-choque', text: 'risco'),
                ],
                photos: [
                  FormPhotoNote(
                    url: 'https://x/1.jpg',
                    text: 'Risco no para-lama',
                    ai: true,
                  ),
                ],
              ),
            }),
            saved,
          ),
        );

        expect(find.text('Observação'), findsOneWidget);
        expect(find.text('Amassado na lateral'), findsOneWidget);
        expect(find.text('Porta: perto da maçaneta'), findsOneWidget);
        expect(find.text('Para-choque: risco'), findsNothing);
        expect(find.text('Foto 1: Risco no para-lama'), findsOneWidget);
        expect(find.text('+ Observação'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('question_note')));
        await tester.pumpAndSettle();
        // Question, the two marked options and the photo.
        expect(find.byKey(const ValueKey('note_option_0')), findsOneWidget);
        expect(find.byKey(const ValueKey('note_option_1')), findsOneWidget);
        expect(find.byKey(const ValueKey('note_photo_0')), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('note_text')),
          'Amassado na porta traseira esquerda',
        );
        await tester.enterText(
          find.byKey(const ValueKey('note_option_1')),
          'trinca',
        );
        await tester.tap(find.text('Pronto').last);
        await tester.pumpAndSettle();

        final (itemId, note) = saved.single;
        expect(itemId, 'dano');
        expect(note.text, 'Amassado na porta traseira esquerda');
        expect(note.ai, isFalse);
        // Option key = the saved value, not the translated text.
        expect(note.optionText('Capô'), 'trinca');
        expect(note.optionText('Porta'), 'perto da maçaneta');
        expect(note.optionText('Para-choque'), 'risco');
        // Untouched AI text keeps its mark.
        expect(note.photos.single.ai, isTrue);
      },
    );
  });
}
