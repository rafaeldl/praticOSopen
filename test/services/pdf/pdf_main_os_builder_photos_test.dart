import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/pdf/pdf_localizations.dart';
import 'package:praticos/services/pdf/pdf_main_os_builder.dart';
import 'package:praticos/services/pdf/pdf_styles.dart';

/// PNG 1x1 valido, usado como stand-in de foto baixada
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

pw.MemoryImage _fakePhoto() =>
    pw.MemoryImage(Uint8List.fromList(base64Decode(_pngBase64)));

/// Resultado da renderizacao de um documento de teste
class _RenderResult {
  final Uint8List bytes;
  final int pageCount;

  _RenderResult(this.bytes, this.pageCount);
}

/// Monta um documento MultiPage identico ao usado pelo PdfService e retorna
/// os bytes gerados. Lanca se algum widget nao couber na pagina.
Future<_RenderResult> _renderMainOs(
  PdfMainOsBuilder builder, {
  required Order order,
  required Customer? customer,
  required Company company,
  required List<pw.MemoryImage> osPhotos,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfStyles.pageFormat,
        margin: PdfStyles.pageMargin,
      ),
      header: (context) => builder.buildHeader(company, order),
      footer: (context) => builder.buildFooter(context),
      build: (context) => builder.buildContent(
        order: order,
        customer: customer,
        company: company,
        osPhotos: osPhotos,
      ),
    ),
  );
  final bytes = await doc.save();
  return _RenderResult(bytes, doc.document.pdfPageList.pages.length);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfLocalizations localizations;
  late SegmentConfigProvider config;

  setUpAll(() async {
    // SegmentConfigProvider depende do Firestore no construtor
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    config = SegmentConfigProvider();
  });

  Future<void> loadLocalizations(WidgetTester tester) async {
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
  }

  Order buildOrder() => Order()
    ..id = 'order-1'
    ..number = 42
    ..status = 'approved'
    ..total = 150.0;

  Company buildCompany() => Company()
    ..id = 'company-1'
    ..name = 'Oficina Teste'
    ..termsOfService = 'Garantia de 90 dias sobre os servicos executados.';

  Customer buildCustomer() => Customer()
    ..id = 'customer-1'
    ..name = 'Maria Silva'
    ..phone = '11999999999';

  PdfMainOsBuilder buildBuilder() => PdfMainOsBuilder(
        baseFont: pw.Font.helvetica(),
        boldFont: pw.Font.helveticaBold(),
        config: config,
        localizations: localizations,
      );

  testWidgets('buildPhotosSection retorna vazio quando nao ha fotos',
      (tester) async {
    await loadLocalizations(tester);

    final widgets = buildBuilder().buildPhotosSection([]);

    expect(widgets, isEmpty);
  });

  testWidgets('buildPhotosSection inclui cabecalho com a contagem de fotos',
      (tester) async {
    await loadLocalizations(tester);

    final widgets = buildBuilder().buildPhotosSection(
      List.generate(3, (_) => _fakePhoto()),
    );

    // Cabecalho + grid
    expect(widgets.length, 2);
    expect(localizations.formatAttachedPhotosCount(3), contains('3'));
  });

  testWidgets('gera PDF sem fotos (comportamento atual preservado)',
      (tester) async {
    await loadLocalizations(tester);

    final result = await _renderMainOs(
      buildBuilder(),
      order: buildOrder(),
      customer: buildCustomer(),
      company: buildCompany(),
      osPhotos: const [],
    );

    expect(result.bytes.length, greaterThan(0));
    expect(result.pageCount, 1);
  });

  testWidgets('gera PDF com fotos anexadas a OS', (tester) async {
    await loadLocalizations(tester);

    final withoutPhotos = await _renderMainOs(
      buildBuilder(),
      order: buildOrder(),
      customer: buildCustomer(),
      company: buildCompany(),
      osPhotos: const [],
    );

    final photo = _fakePhoto();
    final withPhotos = await _renderMainOs(
      buildBuilder(),
      order: buildOrder(),
      customer: buildCustomer(),
      company: buildCompany(),
      osPhotos: List.generate(6, (_) => photo),
    );

    // O PDF com fotos precisa conter conteudo adicional
    expect(withPhotos.bytes.length, greaterThan(withoutPhotos.bytes.length));
  });

  testWidgets('grid de fotos quebra entre paginas sem estourar o layout',
      (tester) async {
    await loadLocalizations(tester);

    final photo = _fakePhoto();

    // 30 fotos = default de maxOsPhotos
    final withDefaultLimit = await _renderMainOs(
      buildBuilder(),
      order: buildOrder(),
      customer: buildCustomer(),
      company: buildCompany(),
      osPhotos: List.generate(30, (_) => photo),
    );

    expect(withDefaultLimit.bytes.length, greaterThan(0));

    // Muitas fotos: o grid precisa fluir para paginas extras em vez de
    // estourar o layout (o pdf lanca se um widget nao couber na pagina)
    final withManyPhotos = await _renderMainOs(
      buildBuilder(),
      order: buildOrder(),
      customer: buildCustomer(),
      company: buildCompany(),
      osPhotos: List.generate(120, (_) => photo),
    );

    expect(withManyPhotos.pageCount, greaterThan(1));
  });
}
