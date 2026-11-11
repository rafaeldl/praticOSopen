import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/custom_field.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/screens/forms/form_fill_screen.dart';
import 'package:praticos/screens/forms/form_question_sheet.dart';
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/utils/checklist_reading.dart';

class _FakeForms implements FormsService {
  _FakeForms({this.fail = false, List<FormResponse>? server})
    : server = server ?? [];

  final bool fail;

  /// The checklist on the server (the web may have answered too).
  List<FormResponse> server;
  final changes = <FormAnswerChange>[];
  final known = <List<FormResponse>>[];
  final statuses = <FormStatus>[];
  final localNotes = <FormItemNote?>[];
  final notes = <(String, FormItemNote?)>[];

  @override
  Future<void> saveNote(
    String companyId,
    String orderId,
    String formId,
    String itemId,
    FormItemNote? note,
  ) async {
    if (fail) throw StateError('permission-denied');
    notes.add((itemId, note));
  }

  /// The response of the question changed, as the screen will show it.
  List<FormResponse> get saved => [
    for (final c in changes) server.lastWhere((r) => r.itemId == c.itemId),
  ];

  @override
  Future<List<FormResponse>?> saveAnswer(
    String companyId,
    String orderId,
    String formId,
    FormAnswerChange change, {
    List<FormResponse> localKnown = const [],
    FormItemNote? localNote,
  }) async {
    if (fail) throw StateError('permission-denied');
    changes.add(change);
    localNotes.add(localNote);
    known.add(localKnown);
    server = applyAnswerChange(server, change);
    return server;
  }

  @override
  Future<void> updateStatus(
    String companyId,
    String orderId,
    String formId,
    FormStatus status,
  ) async {
    statuses.add(status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePhotos implements PhotoService {
  final uploads = <String>[];

  @override
  Future<File?> takePhoto() async => File('a.jpg');

  @override
  Future<String?> uploadImage({
    required File file,
    required String storagePath,
  }) async {
    uploads.add(storagePath);
    return 'https://x/${uploads.length}.jpg';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

OrderForm _form({
  String title = 'Entrada do veículo',
  FormStatus status = FormStatus.pending,
  List<FormResponse> responses = const [],
  Map<String, FormItemNote>? notes,
}) => OrderForm(
  id: 'f1',
  formDefinitionId: 'd1',
  title: title,
  status: status,
  responses: responses,
  notes: notes,
  items: [
    FormItemDefinition(
      id: 'a',
      label: 'Tem estepe?',
      type: FormItemType.boolean,
    ),
    FormItemDefinition(
      id: 'b',
      label: 'Combustível',
      type: FormItemType.select,
      options: ['Cheio', 'Reserva'],
      required: true,
    ),
    FormItemDefinition(
      id: 'c',
      label: 'Foto do painel',
      type: FormItemType.photoOnly,
      allowPhotos: true,
    ),
  ],
);

Widget _app(Widget screen) => CupertinoApp(
  locale: const Locale('pt'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => CupertinoButton(
      child: const Text('abrir'),
      onPressed: () => Navigator.of(
        context,
      ).push(CupertinoPageRoute<void>(builder: (_) => screen)),
    ),
  ),
);

Future<void> _open(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(_app(screen));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

const _mileage = CustomField(
  key: 'device.mileage',
  type: 'number',
  labels: {'pt-BR': 'Quilometragem'},
  suffix: 'km',
  reading: true,
);

/// Vehicle check-in: the km question is the device's reading.
OrderForm _readingForm({List<FormResponse> responses = const []}) => OrderForm(
  id: 'f1',
  formDefinitionId: 'd1',
  title: 'Entrada do veículo',
  responses: responses,
  items: [
    FormItemDefinition(
      id: 'km',
      label: 'Quilometragem Atual',
      type: FormItemType.number,
      reading: true,
    ),
    FormItemDefinition(
      id: 'a',
      label: 'Tem estepe?',
      type: FormItemType.boolean,
    ),
  ],
);

ChecklistReadingLink _link({
  int? order,
  int? lastVisit,
  required List<int> recorded,
}) {
  var current = order;
  return ChecklistReadingLink(
    deviceId: 'd1',
    field: _mileage,
    orderReading: () => current,
    onReading: (value) {
      recorded.add(value);
      current = value;
    },
    lastVisit: Future.value(lastVisit),
  );
}

void main() {
  testWidgets('a checklist with no answer opens on the first question', (
    tester,
  ) async {
    await _open(
      tester,
      FormFillScreen(
        orderId: 'o1',
        companyId: 'c1',
        orderForm: _form(),
        formsService: _FakeForms(),
        photoService: _FakePhotos(),
      ),
    );
    expect(find.byType(FormQuestionSheet), findsOneWidget);
    expect(find.text('Faltam 3'), findsOneWidget);
  });

  testWidgets('overview: status, questions card and "Continuar"', (
    tester,
  ) async {
    await _open(
      tester,
      FormFillScreen(
        orderId: 'o1',
        companyId: 'c1',
        orderForm: _form(responses: [FormResponse(itemId: 'a', value: true)]),
        formsService: _FakeForms(),
        photoService: _FakePhotos(),
      ),
    );

    expect(find.byType(FormQuestionSheet), findsNothing);
    expect(find.text('Faltam 2 perguntas'), findsOneWidget);
    expect(find.text('Perguntas'), findsOneWidget);
    expect(find.text('Tem estepe?'), findsOneWidget);
    expect(find.text('Sim'), findsOneWidget);
    expect(find.text('Sem resposta · Obrigatória'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    // A required one is missing: no "Concluir assim mesmo".
    expect(find.text('Concluir assim mesmo'), findsNothing);
  });

  testWidgets('long name: "Checklist" in the bar, name wraps in the header', (
    tester,
  ) async {
    const name = 'Autorização do Cliente para Serviços (Veículo)';
    await _open(
      tester,
      FormFillScreen(
        orderId: 'o1',
        companyId: 'c1',
        orderForm: _form(
          title: name,
          responses: [FormResponse(itemId: 'a', value: true)],
        ),
        formsService: _FakeForms(),
        photoService: _FakePhotos(),
      ),
    );

    expect(find.text('Checklist'), findsOneWidget);
    final title = find.byKey(const ValueKey('form_fill_title'));
    expect(tester.widget<Text>(title).data, name);
    expect(tester.widget<Text>(title).overflow, isNot(TextOverflow.ellipsis));
    // Wrapped: taller than a single 28pt line.
    expect(tester.getSize(title).height, greaterThan(40));
  });

  testWidgets('answering until the end saves and completes the checklist', (
    tester,
  ) async {
    final forms = _FakeForms(server: [FormResponse(itemId: 'a', value: true)]);
    final photos = _FakePhotos();
    await _open(
      tester,
      FormFillScreen(
        orderId: 'o1',
        companyId: 'c1',
        orderForm: _form(responses: [FormResponse(itemId: 'a', value: true)]),
        formsService: forms,
        photoService: photos,
        canReopen: () => false,
      ),
    );

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Combustível'), findsWidgets);

    await tester.tap(find.text('Reserva'));
    await tester.pumpAndSettle();
    expect(forms.saved.last.itemId, 'b');
    expect(forms.saved.last.value, 'Reserva');

    // Photo question: camera, upload to the same Storage path as before.
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();
    expect(
      photos.uploads.single,
      startsWith('tenants/c1/orders/o1/forms/f1/c_'),
    );
    expect(forms.saved.last.photoUrls, ['https://x/1.jpg']);

    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    expect(forms.statuses, [FormStatus.completed]);
    // Back to where it was opened from.
    expect(find.byType(FormFillScreen), findsNothing);
  });

  testWidgets('an answer changes only its value, not the photos of the web', (
    tester,
  ) async {
    // The web put a photo on "b" after the app opened the checklist.
    final forms = _FakeForms(
      server: [
        FormResponse(itemId: 'a', value: true),
        FormResponse(itemId: 'b', photoUrls: ['web/b.jpg']),
      ],
    );
    await _open(
      tester,
      FormFillScreen(
        orderId: 'o1',
        companyId: 'c1',
        orderForm: _form(responses: [FormResponse(itemId: 'a', value: true)]),
        formsService: forms,
        photoService: _FakePhotos(),
      ),
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reserva'));
    await tester.pumpAndSettle();

    final change = forms.changes.single;
    expect(change, isA<FormValueChange>());
    expect(change.itemId, 'b');
    expect((change as FormValueChange).value, 'Reserva');
    // What the screen had of "b" goes along for the offline queue.
    expect(forms.known.single.map((r) => r.itemId), ['a']);
    expect(forms.server.last.photoUrls, ['web/b.jpg']);
    expect(forms.server.last.value, 'Reserva');
  });

  testWidgets('a photo goes as a photo added, keeping the value', (
    tester,
  ) async {
    final forms = _FakeForms(
      server: [FormResponse(itemId: 'c', value: 'nota', photoUrls: ['web/c.jpg'])],
    );
    await _open(
      tester,
      FormFillScreen(
        orderId: 'o1',
        companyId: 'c1',
        orderForm: _form(
          responses: [
            FormResponse(itemId: 'a', value: true),
            FormResponse(itemId: 'b', value: 'Cheio'),
          ],
        ),
        formsService: forms,
        photoService: _FakePhotos(),
      ),
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    final change = forms.changes.single as FormPhotosAdded;
    expect(change.itemId, 'c');
    expect(change.urls, ['https://x/1.jpg']);
    expect(forms.server.single.photoUrls, ['web/c.jpg', 'https://x/1.jpg']);
    expect(forms.server.single.value, 'nota');
  });

  testWidgets('a refused answer is told, not swallowed', (tester) async {
    final forms = _FakeForms(fail: true);
    await _open(
      tester,
      FormFillScreen(
        orderId: 'o1',
        companyId: 'c1',
        orderForm: _form(responses: [FormResponse(itemId: 'a', value: true)]),
        formsService: forms,
        photoService: _FakePhotos(),
      ),
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reserva'));
    await tester.pump();

    expect(
      find.text('Não deu para guardar a resposta. Tente de novo.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('removing two photos in a row removes the right ones', (
    tester,
  ) async {
    final removed = <String>[];
    await _open(
      tester,
      ChecklistPhotoGallery(
        photos: const ['p1', 'p2', 'p3'],
        initialIndex: 0,
        onDelete: (url) async {
          removed.add(url);
          return true;
        },
      ),
    );

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byIcon(CupertinoIcons.trash));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
    }
    expect(removed, ['p1', 'p2']);
  });

  test('offline errors queue the answer; refusals do not', () {
    expect(FormsService.canQueueOffline(TimeoutException('t')), isTrue);
    expect(
      FormsService.canQueueOffline(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ),
      isTrue,
    );
    for (final code in ['permission-denied', 'aborted', 'not-found']) {
      expect(
        FormsService.canQueueOffline(
          FirebaseException(plugin: 'cloud_firestore', code: code),
        ),
        isFalse,
        reason: code,
      );
    }
    expect(FormsService.canQueueOffline(StateError('x')), isFalse);
  });

  testWidgets('completed: read only, "Reabrir" in sight', (tester) async {
    final forms = _FakeForms();
    await _open(
      tester,
      FormFillScreen(
        orderId: 'o1',
        companyId: 'c1',
        orderForm: _form(
          status: FormStatus.completed,
          responses: [
            FormResponse(itemId: 'a', value: false),
            FormResponse(itemId: 'b', value: 'Cheio'),
            FormResponse(itemId: 'c', photoUrls: ['https://x/1.jpg']),
          ],
        ),
        formsService: forms,
        photoService: _FakePhotos(),
        canReopen: () => true,
      ),
    );

    expect(find.text('Completo'), findsOneWidget);
    expect(find.text('1 foto'), findsOneWidget);
    expect(find.text('Continuar'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('form_fill_reopen')));
    await tester.pumpAndSettle();
    expect(forms.statuses, [FormStatus.inProgress]);
    expect(find.text('Concluir checklist'), findsOneWidget);
  });

  testWidgets('completed with questions left: says so and a tap offers to '
      'reopen', (tester) async {
    final forms = _FakeForms();
    await _open(
      tester,
      FormFillScreen(
        orderId: 'o1',
        companyId: 'c1',
        orderForm: _form(
          status: FormStatus.completed,
          responses: [FormResponse(itemId: 'b', value: 'Cheio')],
        ),
        formsService: forms,
        photoService: _FakePhotos(),
        canReopen: () => true,
      ),
    );

    expect(find.text('Concluído · 2 sem resposta'), findsOneWidget);
    expect(find.text('Completo'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('form_fill_item_a')));
    await tester.pumpAndSettle();
    expect(find.text('Checklist concluído'), findsOneWidget);
    expect(
      find.text('Para mudar uma resposta, reabra o checklist.'),
      findsOneWidget,
    );
    expect(find.byType(FormQuestionSheet), findsNothing);

    await tester.tap(find.byKey(const ValueKey('form_fill_done_reopen')));
    await tester.pumpAndSettle();
    expect(forms.statuses, [FormStatus.inProgress]);
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('completed, without permission to reopen: a tap says who can', (
    tester,
  ) async {
    final forms = _FakeForms();
    await _open(
      tester,
      FormFillScreen(
        orderId: 'o1',
        companyId: 'c1',
        orderForm: _form(
          status: FormStatus.completed,
          responses: [FormResponse(itemId: 'b', value: 'Cheio')],
        ),
        formsService: forms,
        photoService: _FakePhotos(),
        canReopen: () => false,
      ),
    );

    expect(find.byKey(const ValueKey('form_fill_reopen')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('form_fill_item_a')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Para mudar uma resposta, peça a quem gerencia a equipe para reabrir '
        'o checklist.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reabrir'), findsNothing);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(forms.statuses, isEmpty);
  });

  testWidgets('the note shows under the answer, in tertiary text', (
    tester,
  ) async {
    await _open(
      tester,
      FormFillScreen(
        orderId: 'o1',
        companyId: 'c1',
        orderForm: _form(
          responses: [
            FormResponse(itemId: 'a', value: true),
            FormResponse(itemId: 'c', photoUrls: ['https://x/1.jpg']),
          ],
          notes: {
            'a': FormItemNote(text: 'Estepe careca'),
            'c': FormItemNote(
              photos: [FormPhotoNote(url: 'https://x/1.jpg', text: 'Risco')],
            ),
          },
        ),
        formsService: _FakeForms(),
        photoService: _FakePhotos(),
      ),
    );

    final note = tester.widget<Text>(find.text('Estepe careca'));
    expect(
      note.style?.color?.toARGB32(),
      AppColors.textTertiary.color.toARGB32(),
    );
    expect(find.text('Foto 1: Risco'), findsOneWidget);
  });

  testWidgets('"+ Observação" saves only the note, never the answers', (
    tester,
  ) async {
    final forms = _FakeForms();
    await _open(
      tester,
      FormFillScreen(
        orderId: 'o1',
        companyId: 'c1',
        orderForm: _form(responses: [FormResponse(itemId: 'a', value: true)]),
        formsService: forms,
        photoService: _FakePhotos(),
      ),
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('question_note_add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note_text')),
      'Tanque com cheiro de gasolina',
    );
    await tester.tap(find.text('Pronto'));
    await tester.pumpAndSettle();

    expect(forms.changes, isEmpty);
    expect(forms.notes.single.$1, 'b');
    expect(forms.notes.single.$2?.text, 'Tanque com cheiro de gasolina');
    expect(forms.notes.single.$2?.ai, isFalse);
    expect(find.text('Tanque com cheiro de gasolina'), findsWidgets);
  });

  testWidgets('removing a photo takes its note along', (tester) async {
    final forms = _FakeForms(
      server: [FormResponse(itemId: 'c', photoUrls: ['https://x/1.jpg'])],
    );
    await _open(
      tester,
      FormFillScreen(
        orderId: 'o1',
        companyId: 'c1',
        orderForm: _form(
          responses: [FormResponse(itemId: 'c', photoUrls: ['https://x/1.jpg'])],
          notes: {
            'c': FormItemNote(
              photos: [FormPhotoNote(url: 'https://x/1.jpg', text: 'Risco')],
            ),
          },
        ),
        formsService: forms,
        photoService: _FakePhotos(),
      ),
    );
    expect(find.text('Foto 1: Risco'), findsOneWidget);

    await tester.tap(find.byType(FormPhotoThumb));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.trash));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(forms.changes.single, isA<FormPhotoRemoved>());
    expect(forms.localNotes.single?.photos.single.text, 'Risco');
    expect(
      find.text('Foto 1: Risco', skipOffstage: false),
      findsNothing,
    );
  });

  group('question linked to the device reading', () {
    testWidgets("the order's reading answers it on opening", (tester) async {
      final forms = _FakeForms();
      final recorded = <int>[];
      await _open(
        tester,
        FormFillScreen(
          orderId: 'o1',
          companyId: 'c1',
          orderForm: _readingForm(),
          readingLink: _link(order: 98000, recorded: recorded),
          formsService: forms,
          photoService: _FakePhotos(),
        ),
      );

      final change = forms.changes.single as FormValueChange;
      expect(change.itemId, 'km');
      expect(change.value, '98000');
      // Not written back to the order: it came from there.
      expect(recorded, isEmpty);
      // Opens on the first question still without an answer.
      expect(find.byType(FormQuestionSheet), findsOneWidget);
      expect(find.text('Tem estepe?'), findsWidgets);
    });

    testWidgets('the answer is the order reading; below the last visit, a '
        'notice that does not block', (tester) async {
      final forms = _FakeForms();
      final recorded = <int>[];
      await _open(
        tester,
        FormFillScreen(
          orderId: 'o1',
          companyId: 'c1',
          orderForm: _readingForm(),
          readingLink: _link(lastVisit: 102000, recorded: recorded),
          formsService: forms,
          photoService: _FakePhotos(),
        ),
      );
      expect(forms.changes, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('question_field')),
        '98000',
      );
      await tester.tap(find.text('Próxima'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(recorded, [98000]);
      expect(forms.saved.single.value, '98000');
      expect(
        find.text('Menor que os 102.000 km da última visita. Está certo?'),
        findsOneWidget,
      );
      // Moved on to the next question all the same.
      expect(find.text('Tem estepe?'), findsWidgets);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('above the last visit: saved, no notice', (tester) async {
      final recorded = <int>[];
      await _open(
        tester,
        FormFillScreen(
          orderId: 'o1',
          companyId: 'c1',
          orderForm: _readingForm(),
          readingLink: _link(lastVisit: 102000, recorded: recorded),
          formsService: _FakeForms(),
          photoService: _FakePhotos(),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('question_field')),
        '103.500',
      );
      await tester.tap(find.text('Próxima'));
      await tester.pumpAndSettle();

      expect(recorded, [103500]);
      expect(find.textContaining('da última visita'), findsNothing);
    });

    testWidgets('without a link (no device, segment without reading): a '
        'plain number question', (tester) async {
      final forms = _FakeForms();
      await _open(
        tester,
        FormFillScreen(
          orderId: 'o1',
          companyId: 'c1',
          orderForm: _readingForm(),
          formsService: forms,
          photoService: _FakePhotos(),
        ),
      );
      expect(forms.changes, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('question_field')),
        '98000',
      );
      await tester.tap(find.text('Próxima'));
      await tester.pumpAndSettle();
      expect(forms.saved.single.value, '98000');
    });
  });
}
