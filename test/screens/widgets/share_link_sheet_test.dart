import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/share_token.dart';
import 'package:praticos/screens/widgets/share_link_sheet.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/share_link_service.dart';

class _FakeService extends ShareLinkService {
  _FakeService() : super.forTesting();

  final generated = <List<String>>[];
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
    generated.add(permissions);
    generatedDays.add(expiresInDays);
    return ShareLinkResult()
      ..token = 'tok${generated.length}'
      ..url = 'https://praticos.web.app/q/tok${generated.length}'
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
}

Order _order({String? phone = '11999990000'}) => Order()
  ..id = 'o1'
  ..number = 183
  ..customer = (CustomerAggr()
    ..name = 'Ana'
    ..phone = phone);

Future<void> _pump(WidgetTester tester, Order order, _FakeService service) {
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
          child: ShareLinkSheet(order: order, service: service),
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
    expect(sentence.data, startsWith('Ana abre a OS pelo link, aprova e comenta.'));
    expect(sentence.data, contains('Vale até'));

    expect(find.text('Mandar pelo WhatsApp'), findsOneWidget);
    expect(find.text('Mandar de outro jeito'), findsOneWidget);
    // The old controls are gone: no switches, no visible link.
    expect(find.byType(CupertinoSwitch), findsNothing);
    expect(find.textContaining('praticos.web.app'), findsNothing);

    await tester.tap(find.byKey(const Key('shareLinkPrimary')));
    await tester.pump();
    expect(service.whatsapp, ['https://praticos.web.app/q/tok1']);
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
}
