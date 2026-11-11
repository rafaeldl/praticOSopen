import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/custom_field.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/screens/forms/form_fill_screen.dart';
import 'package:praticos/screens/forms/form_question_sheet.dart';
import 'package:praticos/services/ai_form_photo_service.dart';
import 'package:praticos/services/ai_order_assist_service.dart';
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

  final aiMarks = <(String, bool)>[];

  @override
  Future<void> markAiFilled(
    String companyId,
    String orderId,
    String formId,
    String itemId, {
    required bool filled,
  }) async {
    aiMarks.add((itemId, filled));
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

class _FakeAi implements AiFormPhotoClient {
  _FakeAi({this.enabled = true, this.result, this.error});

  final bool enabled;
  AiFormPhotoResult? result;
  Object? error;

  /// Holds the reading until completed (to see "Lendo a foto…").
  Completer<void>? gate;
  final questions = <AiFormQuestion>[];
  final lastReadings = <({int value, String? unit})?>[];

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<AiFormPhotoResult> read({
    required AiPhoto photo,
    required AiFormQuestion question,
    String? deviceCategory,
    String? deviceName,
    String? segment,
    String? locale,
    ({int value, String? unit})? lastReading,
  }) async {
    questions.add(question);
    lastReadings.add(lastReading);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return result ?? const AiFormPhotoResult();
  }
}

Future<Uint8List?> _bytes(File _) async => Uint8List.fromList([1, 2, 3]);

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
      server: [
        FormResponse(itemId: 'c', value: 'nota', photoUrls: ['web/c.jpg']),
      ],
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
      server: [
        FormResponse(itemId: 'c', photoUrls: ['https://x/1.jpg']),
      ],
    );
    await _open(
      tester,
      FormFillScreen(
        orderId: 'o1',
        companyId: 'c1',
        orderForm: _form(
          responses: [
            FormResponse(itemId: 'c', photoUrls: ['https://x/1.jpg']),
          ],
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
    expect(find.text('Foto 1: Risco', skipOffstage: false), findsNothing);
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

  group('AI reads the photo', () {
    // Tall enough for the answer, the photos and the note in one screen.
    setUp(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(1170, 2532);
      view.devicePixelRatio = 3;
    });
    tearDown(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    OrderForm fuelForm({
      List<FormResponse> responses = const [],
      Map<String, FormItemNote>? notes,
    }) => OrderForm(
      id: 'f1',
      formDefinitionId: 'd1',
      title: 'Entrada do veículo',
      responses: responses,
      notes: notes,
      items: [
        FormItemDefinition(
          id: 'fuel',
          label: 'Combustível',
          type: FormItemType.select,
          options: ['Reserva', '1/4', 'Cheio'],
        ),
        FormItemDefinition(
          id: 'a',
          label: 'Tem estepe?',
          type: FormItemType.boolean,
        ),
      ],
    );

    FormFillScreen screen(
      _FakeForms forms,
      _FakeAi ai, {
      OrderForm? form,
      ChecklistReadingLink? link,
    }) => FormFillScreen(
      orderId: 'o1',
      companyId: 'c1',
      orderForm: form ?? fuelForm(),
      readingLink: link,
      formsService: forms,
      photoService: _FakePhotos(),
      aiClient: ai,
      aiPhotoBytes: _bytes,
    );

    Future<void> takePhoto(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('question_photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tirar foto'));
      await tester.pump();
      await tester.pump();
    }

    /// Lets the notice's timer run out.
    Future<void> finish(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
    }

    testWidgets('fills the empty answer with ✦; "Desfazer" puts it back', (
      tester,
    ) async {
      final forms = _FakeForms();
      final ai = _FakeAi(
        result: const AiFormPhotoResult(
          answer: '1/4',
          note: 'Ponteiro em um quarto',
          confident: true,
        ),
      )..gate = Completer<void>();
      await _open(tester, screen(forms, ai));

      await takePhoto(tester);
      // In the question and in the list behind it.
      expect(find.text('Lendo a foto…'), findsWidgets);
      expect(ai.questions.single.label, 'Combustível');
      expect(ai.questions.single.options, ['Reserva', '1/4', 'Cheio']);

      ai.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Lendo a foto…'), findsNothing);
      expect(forms.saved.last.value, '1/4');
      expect(forms.aiMarks, [('fuel', true)]);
      expect(forms.notes.single.$2!.text, 'Ponteiro em um quarto');
      expect(forms.notes.single.$2!.ai, isTrue);
      expect(find.byKey(const ValueKey('question_ai_filled')), findsOneWidget);
      expect(find.byKey(const ValueKey('question_note_ai')), findsOneWidget);
      expect(find.text('Preenchi: 1/4'), findsOneWidget);

      await tester.tap(find.text('Desfazer'));
      await tester.pump();
      expect(forms.saved.last.value, isNull);
      expect(forms.aiMarks.last, ('fuel', false));
      expect(forms.notes.last.$2!.isEmpty, isTrue);
      expect(find.byKey(const ValueKey('question_ai_filled')), findsNothing);
      await finish(tester);
    });

    testWidgets('answering it yourself takes the ✦ away', (tester) async {
      final forms = _FakeForms();
      final ai = _FakeAi(
        result: const AiFormPhotoResult(answer: 'Reserva', confident: true),
      );
      await _open(tester, screen(forms, ai));
      await takePhoto(tester);
      await tester.pump();
      expect(find.byKey(const ValueKey('question_ai_filled')), findsOneWidget);

      await tester.tap(find.text('Cheio'));
      await tester.pump();
      expect(forms.saved.last.value, 'Cheio');
      expect(forms.aiMarks, [('fuel', true), ('fuel', false)]);
      await finish(tester);
    });

    testWidgets("an answer already given is never replaced; the person's "
        'note gets "A IA viu também"', (tester) async {
      final forms = _FakeForms(
        server: [FormResponse(itemId: 'fuel', value: 'Reserva')],
      );
      final ai = _FakeAi(
        result: const AiFormPhotoResult(
          answer: 'Reserva',
          note: 'Luz da reserva acesa',
          confident: true,
        ),
      );
      await _open(
        tester,
        screen(
          forms,
          ai,
          form: fuelForm(
            responses: [FormResponse(itemId: 'fuel', value: 'Reserva')],
            notes: {'fuel': FormItemNote(text: 'Cliente pediu para abastecer')},
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('form_fill_item_fuel')));
      await tester.pumpAndSettle();
      await takePhoto(tester);
      await tester.pump();

      expect(forms.aiMarks, isEmpty);
      expect(forms.notes, isEmpty);
      expect(
        find.text('A IA viu também: Luz da reserva acesa'),
        findsOneWidget,
      );
      await tester.tap(find.text('Acrescentar'));
      await tester.pump();
      expect(
        forms.notes.single.$2!.text,
        'Cliente pediu para abastecer. Luz da reserva acesa',
      );
      expect(forms.notes.single.$2!.ai, isFalse);
      await finish(tester);
    });

    testWidgets('a dark photo is a notice with "Tirar de novo", not an '
        'alert', (tester) async {
      final forms = _FakeForms();
      final ai = _FakeAi(
        result: const AiFormPhotoResult(photoIssue: AiPhotoIssue.dark),
      );
      await _open(tester, screen(forms, ai));
      await takePhoto(tester);
      await tester.pump();

      expect(find.text('Foto escura, não deu para ler'), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(forms.aiMarks, isEmpty);
      expect(forms.saved.last.value, isNull);

      await tester.tap(find.text('Tirar de novo'));
      await tester.pump();
      await tester.pump();
      expect(ai.questions.length, 2);
      await finish(tester);
    });

    testWidgets('offline or no quota: a discreet notice, the checklist goes '
        'on', (tester) async {
      final forms = _FakeForms();
      final ai = _FakeAi(
        error: const AiOrderAssistException(AiAssistError.unavailable),
      );
      await _open(tester, screen(forms, ai));
      await takePhoto(tester);
      await tester.pump();
      expect(find.text('Não deu para ler a foto agora'), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      // The photo was saved all the same.
      expect(forms.saved.last.photoUrls, ['https://x/1.jpg']);

      ai.error = const AiOrderAssistException(AiAssistError.quotaExceeded);
      await takePhoto(tester);
      await tester.pump();
      expect(find.text('Acabaram as leituras da IA deste mês'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('AI off: nothing is read, nothing is said', (tester) async {
      final forms = _FakeForms();
      final ai = _FakeAi(enabled: false);
      await _open(tester, screen(forms, ai));
      await takePhoto(tester);
      await tester.pump();
      expect(ai.questions, isEmpty);
      expect(find.text('Lendo a foto…'), findsNothing);
      expect(find.byKey(const ValueKey('checklist_ai_notice')), findsNothing);
      expect(find.text('+ Observação'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('moved on meanwhile: the notice says which question and '
        '"Ver" goes back', (tester) async {
      final forms = _FakeForms();
      final ai = _FakeAi(
        result: const AiFormPhotoResult(answer: '1/4', confident: true),
      )..gate = Completer<void>();
      await _open(tester, screen(forms, ai));
      await takePhoto(tester);
      await tester.tap(find.byKey(const ValueKey('question_skip')));
      await tester.pumpAndSettle();
      expect(find.text('Tem estepe?'), findsWidgets);

      ai.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Combustível: 1/4'), findsOneWidget);
      await tester.tap(find.text('Ver'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('question_label')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('question_label'))).data,
        'Combustível',
      );
      await finish(tester);
    });

    testWidgets('km read from the panel is also the order reading', (
      tester,
    ) async {
      final forms = _FakeForms();
      final recorded = <int>[];
      final ai = _FakeAi(
        result: const AiFormPhotoResult(answer: 98000, confident: true),
      );
      await _open(
        tester,
        screen(
          forms,
          ai,
          form: _readingForm(),
          link: _link(lastVisit: 90000, recorded: recorded),
        ),
      );
      await takePhoto(tester);
      await tester.pump();
      await tester.pump();

      expect(ai.lastReadings.single, (value: 90000, unit: 'km'));
      expect(forms.saved.last.value, '98000');
      expect(recorded, [98000]);
      // The field shows the AI's number.
      expect(find.text('98000'), findsWidgets);
      await finish(tester);
    });
  });
}
