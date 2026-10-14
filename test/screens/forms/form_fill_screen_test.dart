import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/screens/forms/form_fill_screen.dart';
import 'package:praticos/screens/forms/form_question_sheet.dart';
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/services/photo_service.dart';

class _FakeForms implements FormsService {
  final saved = <FormResponse>[];
  final statuses = <FormStatus>[];

  @override
  Future<void> saveResponse(
    String companyId,
    String orderId,
    String formId,
    FormResponse response,
  ) async {
    saved.add(response);
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
  FormStatus status = FormStatus.pending,
  List<FormResponse> responses = const [],
}) => OrderForm(
  id: 'f1',
  formDefinitionId: 'd1',
  title: 'Entrada do veículo',
  status: status,
  responses: responses,
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

  testWidgets('answering until the end saves and completes the checklist', (
    tester,
  ) async {
    final forms = _FakeForms();
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

  testWidgets('completed: read only, "…" reopens', (tester) async {
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

    await tester.tap(find.byKey(const ValueKey('form_fill_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reabrir'));
    await tester.pumpAndSettle();
    expect(forms.statuses, [FormStatus.inProgress]);
    expect(find.text('Concluir checklist'), findsOneWidget);
  });
}
