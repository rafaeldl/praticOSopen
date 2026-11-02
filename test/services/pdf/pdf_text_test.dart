import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/services/pdf/pdf_localizations.dart';
import 'package:praticos/services/pdf/pdf_service.dart';

Future<String> _pdfOf(String text, {pw.ThemeData? theme}) async {
  final doc = pw.Document(compress: false);
  doc.addPage(
    pw.Page(
      pageTheme: pw.PageTheme(theme: theme),
      build: (_) => pw.Text(text),
    ),
  );
  return latin1.decode(await doc.save());
}

class _BrokenBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => throw Exception('no asset');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fixed texts keep their accents', () {
    Future<PdfLocalizations> strings(WidgetTester tester, Locale locale) async {
      late PdfLocalizations result;
      await tester.pumpWidget(
        CupertinoApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              result = PdfLocalizations.fromContext(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('pt', (tester) async {
      final pt = await strings(tester, const Locale('pt'));
      expect(pt.descriptionColumn, 'DESCRIÇÃO');
      expect(pt.serviceDescriptionColumn, 'DESCRIÇÃO DO SERVIÇO');
      expect(pt.termsAndConditions.toUpperCase(), 'TERMOS E CONDIÇÕES');
      expect(pt.serviceType, 'Serviço');
      expect(pt.productType, 'Peça');
      expect(pt.companySignature, 'Responsável');
      expect(pt.formatPageOf(1, 2), 'Página 1 de 2');
      expect(pt.statusCompleted.toUpperCase(), 'CONCLUÍDO');
      expect(pt.notAnswered, 'Não Respondido');
    });

    testWidgets('es', (tester) async {
      final es = await strings(tester, const Locale('es'));
      expect(es.descriptionColumn, 'DESCRIPCIÓN');
      expect(es.formatPageOf(1, 2), 'Página 1 de 2');
    });
  });

  group('typed text outside Latin-1', () {
    test('the Greek mu needs the fallback font, which gets embedded', () async {
      final theme = await pdfFallbackTheme();
      expect(theme, isNotNull);
      expect(await _pdfOf('Capacitor 35μF'), isNot(contains('/FontFile2')));
      expect(
        await _pdfOf('Capacitor 35μF', theme: theme),
        contains('/FontFile2'),
      );
    });

    test(
      'Latin-1 text stays on Helvetica: the layout does not change',
      () async {
        final theme = await pdfFallbackTheme();
        expect(
          await _pdfOf('Capacitor 35µF · Higienização', theme: theme),
          isNot(contains('/FontFile2')),
        );
      },
    );

    test('without the font the PDF still works', () async {
      expect(await pdfFallbackTheme(bundle: _BrokenBundle()), isNull);
    });
  });
}
