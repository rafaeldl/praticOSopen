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
import 'package:praticos/models/product.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/pdf/pdf_localizations.dart';
import 'package:praticos/services/pdf/pdf_main_os_builder.dart';
import 'package:praticos/services/pdf/pdf_service.dart';
import 'package:praticos/services/pdf/pdf_styles.dart';

/// Renders the main OS page exactly like PdfService, uncompressed, and
/// returns the text drawn on the page.
Future<String> _renderMainOsText(
  PdfMainOsBuilder builder, {
  required Order order,
  required Customer customer,
  required Company company,
}) async {
  final doc = pw.Document(compress: false);
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
      ),
    ),
  );
  final Uint8List bytes = await doc.save();
  final raw = latin1.decode(bytes, allowInvalid: true);
  // Keep only the words drawn on the page ("[(word)]TJ" operators), so
  // numbers from the PDF structure (coordinates, offsets) never match.
  return RegExp(r'\[\((.*?)\)\]TJ')
      .allMatches(raw)
      .map((m) => m.group(1))
      .join(' ');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfLocalizations localizations;
  late SegmentConfigProvider config;

  setUpAll(() async {
    // SegmentConfigProvider depends on Firestore in its constructor
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

  // Distinctive amounts: their cents never show up in PDF structure numbers.
  Order buildOrder() => Order()
    ..id = 'order-1'
    ..number = 42
    ..status = 'done'
    ..services = [
      OrderService()
        ..service = (ServiceAggr()
          ..id = 'srv-1'
          ..name = 'Troca de oleo')
        ..value = 98765.43,
    ]
    ..products = [
      OrderProduct()
        ..product = (ProductAggr()
          ..id = 'prd-1'
          ..name = 'Filtro de ar')
        ..value = 111.27
        ..quantity = 2
        ..total = 222.54,
    ]
    ..discount = 10.11
    ..paidAmount = 50.29
    ..total = 98977.86;

  Company buildCompany({bool? useFinancial}) => Company()
    ..id = 'company-1'
    ..name = 'Oficina Teste'
    ..useFinancial = useFinancial;

  Customer buildCustomer() => Customer()
    ..id = 'customer-1'
    ..name = 'Maria Silva';

  PdfMainOsBuilder buildBuilder({required bool showValues}) => PdfMainOsBuilder(
        baseFont: pw.Font.helvetica(),
        boldFont: pw.Font.helveticaBold(),
        config: config,
        localizations: localizations,
        showValues: showValues,
      );

  bool containsAmount(String text, String cents) =>
      RegExp('[,.]$cents\\b').hasMatch(text);

  testWidgets('PDF with values keeps prices, totals and the summary',
      (tester) async {
    await loadLocalizations(tester);

    final text = await _renderMainOsText(
      buildBuilder(showValues: true),
      order: buildOrder(),
      customer: buildCustomer(),
      company: buildCompany(),
    );

    expect(text, contains('Troca'));
    expect(containsAmount(text, '43'), isTrue, reason: 'service price');
    expect(containsAmount(text, '27'), isTrue, reason: 'product price');
    expect(containsAmount(text, '86'), isTrue, reason: 'order total');
    expect(text, contains(localizations.summary.toUpperCase()));
  });

  testWidgets('PDF without values has items but no prices, totals or payments',
      (tester) async {
    await loadLocalizations(tester);

    final text = await _renderMainOsText(
      buildBuilder(showValues: false),
      order: buildOrder(),
      customer: buildCustomer(),
      company: buildCompany(useFinancial: false),
    );

    // The service report is still there
    expect(text, contains('Troca'));
    expect(text, contains('Filtro'));
    expect(text, contains('Maria'));

    // No amount of any kind
    for (final cents in ['43', '27', '54', '11', '29', '86']) {
      expect(containsAmount(text, cents), isFalse, reason: 'amount ,$cents');
    }
    expect(text, isNot(contains('R\$')));
    // No financial summary nor price columns
    expect(text, isNot(contains(localizations.summary.toUpperCase())));
    expect(text, isNot(contains(localizations.unitValue)));
  });

  testWidgets('OsPdfData hides values only when the company turned them off',
      (tester) async {
    await loadLocalizations(tester);

    OsPdfData data(Company company, {bool? override}) => OsPdfData(
          order: buildOrder(),
          company: company,
          forms: const [],
          config: config,
          localizations: localizations,
          showValuesOverride: override,
        );

    expect(data(buildCompany(useFinancial: false)).showValues, isFalse);
    expect(data(buildCompany(useFinancial: true)).showValues, isTrue);
    // Absent field: falls back to the resolved value (default true)
    expect(data(buildCompany()).showValues, config.useFinancial);
    expect(
      data(buildCompany(useFinancial: false), override: true).showValues,
      isTrue,
    );
  });

  test('orderPdfShowsValues: company value wins, absent uses resolved', () {
    expect(orderPdfShowsValues(), isTrue);
    expect(orderPdfShowsValues(companyUseFinancial: false), isFalse);
    expect(
      orderPdfShowsValues(
        companyUseFinancial: true,
        resolvedUseFinancial: false,
      ),
      isTrue,
    );
    expect(orderPdfShowsValues(resolvedUseFinancial: false), isFalse);
  });

  test('canShareOrderPdf: PDF comes back for companies without values', () {
    // Today: only who sees prices
    expect(canShareOrderPdf(canViewPrices: true, useFinancial: true), isTrue);
    expect(canShareOrderPdf(canViewPrices: false, useFinancial: true), isFalse);
    // Values off: everybody gets the PDF without values
    expect(canShareOrderPdf(canViewPrices: false, useFinancial: false), isTrue);
  });
}
