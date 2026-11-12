import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/share_token.dart';
import 'dart:typed_data';

import 'package:praticos/services/pdf/order_pdf_file.dart';
import 'package:praticos/screens/widgets/share_link_sheet.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/share_link_service.dart';

class _FakeService extends ShareLinkService {
  _FakeService() : super.forTesting();

  final generated = <List<String>>[];
  bool failLink = false;
  final generatedDays = <int>[];
  final whatsapp = <String>[];
  final sheets = <String>[];
  final copied = <String>[];

  @override
  Future<List<ShareToken>> getShareTokens(String orderId) async => [];

  @override
  Future<ShareLinkResult> generateShareLink({
    required String orderId,
    List<String> permissions = const ['view', 'approve', 'comment'],
    int expiresInDays = 7,
  }) async {
    if (failLink) throw ShareLinkException('Order not found');
    generated.add(permissions);
    generatedDays.add(expiresInDays);
    return ShareLinkResult()
      ..token = 'tok${generated.length}'
      ..url = 'https://praticos.app/q/tok${generated.length}'
      ..permissions = permissions
      ..expiresAt = DateTime(2026, 10, 21);
  }

  @override
  Future<void> shareViaWhatsApp({
    required String url,
    required String phone,
    String? message,
  }) async => whatsapp.add(url);

  @override
  Future<void> shareViaSheet({
    required String url,
    String? message,
    String? subject,
    Rect? sharePositionOrigin,
  }) async => sheets.add(url);

  @override
  Future<void> copyToClipboard(String url) async => copied.add(url);

  final pdfs = <String>[];
  final pdfMessages = <String?>[];

  @override
  Future<void> shareViaSheetWithPdf({
    String? url,
    required Uint8List bytes,
    required String filename,
    String? message,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    pdfs.add(url == null ? filename : '$filename $url');
    pdfMessages.add(message);
  }

  final previews = <String>[];

  @override
  Future<void> openPreview(String url) async => previews.add(url);
}

Order _order({String? phone = '11999990000'}) => Order()
  ..id = 'o1'
  ..number = 183
  ..customer = (CustomerAggr()
    ..name = 'Ana'
    ..phone = phone);

Future<void> _pump(
  WidgetTester tester,
  Order order,
  _FakeService service, {
  bool withPdf = false,
  Future<OrderPdfFile> Function(BuildContext context)? buildPdf,
}) {
  return tester.pumpWidget(
    CupertinoApp(
      locale: const Locale('pt', 'BR'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      home: CupertinoPageScaffold(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ShareLinkSheet(
            order: order,
            service: service,
            withPdf: withPdf,
            buildPdf:
                buildPdf ??
                (_) async => OrderPdfFile(
                  bytes: Uint8List.fromList([1, 2, 3]),
                  filename: 'OS-183.pdf',
                ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    FormatService().setLocale('pt_BR');
  });

  testWidgets('says what the customer can do and sends on WhatsApp', (
    tester,
  ) async {
    final service = _FakeService();
    await _pump(tester, _order(), service);
    await tester.pumpAndSettle();

    expect(find.text('Mandar para o cliente'), findsOneWidget);
    final sentence = tester.widget<Text>(
      find.byKey(const Key('shareLinkSentence')),
    );
    expect(
      sentence.data,
      startsWith('Ana abre a OS pelo link, aprova e comenta.'),
    );
    expect(sentence.data, contains('Vale até'));

    expect(find.text('Mandar pelo WhatsApp'), findsOneWidget);
    expect(find.text('Mandar de outro jeito'), findsOneWidget);
    // The old controls are gone: no switches, no visible link.
    expect(find.byType(CupertinoSwitch), findsNothing);
    expect(find.textContaining('praticos.app'), findsNothing);

    await tester.tap(find.byKey(const Key('shareLinkPrimary')));
    await tester.pump();
    expect(service.whatsapp, ['https://praticos.app/q/tok1']);
  });

  testWidgets('without a phone the blue button shares the link', (
    tester,
  ) async {
    final service = _FakeService();
    await _pump(tester, _order(phone: null), service);
    await tester.pumpAndSettle();

    expect(find.text('Mandar o link'), findsOneWidget);
    expect(find.text('Mandar de outro jeito'), findsNothing);
    await tester.tap(find.byKey(const Key('shareLinkPrimary')));
    await tester.pump();
    expect(service.sheets, hasLength(1));
  });

  testWidgets('copy link confirms in place', (tester) async {
    final service = _FakeService();
    await _pump(tester, _order(), service);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copiar o link'));
    await tester.pump();
    expect(service.copied, hasLength(1));
    expect(find.text('Link copiado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Copiar o link'), findsOneWidget);
  });

  testWidgets('"…" changes what the customer can do in the picker', (
    tester,
  ) async {
    final service = _FakeService();
    await _pump(tester, _order(), service);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shareLinkMenu')));
    await tester.pumpAndSettle();
    expect(find.text('Mudar a validade'), findsOneWidget);
    expect(find.text('Desativar o link'), findsOneWidget);

    await tester.tap(find.text('O que o cliente pode fazer'));
    await tester.pumpAndSettle();
    expect(find.text('O que o cliente pode fazer?'), findsOneWidget);
    await tester.tap(find.text('Só ver'));
    await tester.pumpAndSettle();

    expect(service.generated.last, ['view']);
    final sentence = tester.widget<Text>(
      find.byKey(const Key('shareLinkSentence')),
    );
    expect(sentence.data, startsWith('Ana abre a OS pelo link.'));
  });

  testWidgets('"…" changes how long the link lasts', (tester) async {
    final service = _FakeService();
    await _pump(tester, _order(), service);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shareLinkMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mudar a validade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 dias'));
    await tester.pumpAndSettle();

    expect(service.generatedDays.last, 30);
  });

  testWidgets('"Ver como o cliente vê" opens the same link, sends nothing', (
    tester,
  ) async {
    final service = _FakeService();
    await _pump(tester, _order(), service);
    await tester.pumpAndSettle();

    expect(find.text('Ver como o cliente vê'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('shareLinkPreview')));
    await tester.tap(find.byKey(const Key('shareLinkPreview')));
    await tester.pump();

    expect(service.previews, ['https://praticos.app/q/tok1']);
    expect(service.whatsapp, isEmpty);
    expect(service.sheets, isEmpty);
    expect(service.copied, isEmpty);
    // Reuses the link the sheet already made: no extra token.
    expect(service.generated, hasLength(1));
  });

  test('preview url marks the link as a preview', () {
    expect(
      ShareLinkService.previewUrl('https://praticos.app/q/ST_1'),
      'https://praticos.app/q/ST_1?preview=1',
    );
    expect(
      ShareLinkService.previewUrl('https://praticos.app/q/ST_1?lang=en'),
      'https://praticos.app/q/ST_1?lang=en&preview=1',
    );
  });

  group('with the PDF', () {
    testWidgets('the PDF is the main way; the link alone goes on WhatsApp', (
      tester,
    ) async {
      final service = _FakeService();
      await _pump(tester, _order(), service, withPdf: true);
      await tester.pumpAndSettle();

      expect(find.text('Mandar o PDF'), findsOneWidget);
      expect(find.text('Mandar só o link no WhatsApp'), findsOneWidget);
      expect(find.text('Mandar pelo WhatsApp'), findsNothing);

      await tester.tap(find.text('Mandar o PDF'));
      await tester.pumpAndSettle();
      expect(service.pdfs, ['OS-183.pdf https://praticos.app/q/tok1']);
      expect(service.pdfMessages.single, contains('em PDF'));
      expect(service.whatsapp, isEmpty);

      await tester.tap(find.text('Mandar só o link no WhatsApp'));
      await tester.pumpAndSettle();
      expect(service.whatsapp, ['https://praticos.app/q/tok1']);
    });

    testWidgets('without a phone the link alone goes by the share sheet', (
      tester,
    ) async {
      final service = _FakeService();
      await _pump(tester, _order(phone: null), service, withPdf: true);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mandar só o link'));
      await tester.pumpAndSettle();
      expect(service.sheets, ['https://praticos.app/q/tok1']);
      expect(service.pdfs, isEmpty);
    });

    testWidgets('the link fails: the PDF still goes, without the link', (
      tester,
    ) async {
      final service = _FakeService()..failLink = true;
      await _pump(tester, _order(), service, withPdf: true);
      await tester.pumpAndSettle();

      expect(find.text('Não deu para criar o link.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);

      await tester.tap(find.text('Mandar o PDF'));
      await tester.pumpAndSettle();
      expect(service.pdfs, ['OS-183.pdf']);
      expect(service.pdfMessages.single, 'Olá Ana! Segue a sua OS #183 em PDF.');
    });

    testWidgets('without the PDF a failed link only offers to try again', (
      tester,
    ) async {
      final service = _FakeService()..failLink = true;
      await _pump(tester, _order(), service);
      await tester.pumpAndSettle();

      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('Mandar o PDF'), findsNothing);
    });

    testWidgets('a PDF that fails shows an alert and sends nothing', (
      tester,
    ) async {
      final service = _FakeService();
      await _pump(
        tester,
        _order(),
        service,
        withPdf: true,
        buildPdf: (_) async => throw StateError('no pdf'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mandar o PDF'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(service.pdfs, isEmpty);
    });
  });
}
