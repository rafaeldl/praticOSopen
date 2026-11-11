import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/pdf/pdf_forms_builder.dart';
import 'package:praticos/services/pdf/pdf_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('the PDF shows the question, marked option and photo notes', (
    tester,
  ) async {
    late PdfLocalizations localizations;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            localizations = PdfLocalizations.fromContext(context);
            return const SizedBox();
          },
        ),
      ),
    );
    final builder = PdfFormsBuilder(
      baseFont: pw.Font.helvetica(),
      boldFont: pw.Font.helveticaBold(),
      config: SegmentConfigProvider(),
      localizations: localizations,
    );
    final item = FormItemDefinition(
      id: 'dano',
      label: 'Onde tem dano?',
      type: FormItemType.checklist,
      options: ['Porta', 'Capô'],
    );
    final response = FormResponse(
      itemId: 'dano',
      value: ['Porta'],
      photoUrls: ['https://x/1.jpg', 'https://x/2.jpg'],
    );
    final note = FormItemNote(
      text: 'Amassado na lateral',
      options: [
        FormOptionNote(option: 'Porta', text: 'perto da maçaneta'),
        FormOptionNote(option: 'Capô', text: 'não marcado'),
      ],
      photos: [
        FormPhotoNote(url: 'https://x/2.jpg', text: 'Risco'),
        FormPhotoNote(url: 'https://x/apagada.jpg', text: 'Some'),
      ],
    );

    expect(builder.pdfNoteLines(item, note, response), [
      'Amassado na lateral',
      'Porta: perto da maçaneta',
      'Foto 2: Risco',
    ]);
    expect(builder.pdfNoteLines(item, null, response), isEmpty);
  });
}
