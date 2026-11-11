import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/fiscal_emitter.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/menu_navigation/more/my_company_screen.dart';
import 'package:praticos/screens/nfse/nfse_access.dart';
import 'package:praticos/services/segment_config_service.dart';
import 'package:provider/provider.dart';

// "Nota fiscal" in "Sua empresa": the way to the NFS-e direct setup
// (certificate, import, service) that does not depend on having notas yet.

final _pt = AppLocalizationsPt();
final _now = DateTime(2026, 11, 6, 12);

FiscalEmitter _emitter({bool withCertificate = true}) => FiscalEmitter(
  taxId: '00000000000191',
  legalName: 'OFICINA EXEMPLO LTDA',
  regime: FiscalRegime.simples,
  enabledInCity: true,
  service: FiscalEmitterService(nationalCode: '140101', name: 'Revisão'),
  certificate: withCertificate
      ? FiscalEmitterCertificate(
          notAfter: DateTime(2027, 3, 12),
          status: FiscalCertificateStatus.active,
        )
      : null,
)..id = 'e1';

NfseController _nfse({
  bool direct = true,
  List<FiscalEmitter> emitters = const [],
}) => NfseController(
  canIssue: true,
  settingsStream: Stream.value(PaymentSettings(nfseDirectEnabled: direct)),
  emittersStream: Stream.value(emitters),
  invoicesOf: (_) => Stream.value(const []),
);

Future<void> _pump(
  WidgetTester tester, {
  required NfseController nfse,
  bool canSetUp = true,
  void Function(BuildContext context)? open,
}) async {
  tester.view.physicalSize = const Size(1170, 5000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  addTearDown(nfse.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<SegmentConfigProvider>.value(
      value: SegmentConfigProvider(),
      child: CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MyCompanySettings(
          companyId: 'c1',
          writer: (_, _) async {},
          loadCompany: (_) async => Company()..name = 'Oficina Exemplo',
          loadSegments: () async => const [],
          nfse: nfse,
          canSetUpNfse: canSetUp,
          openNfseSetup: open,
          now: _now,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => SegmentConfigService().clear());

  testWidgets('NFS-e direct on: "Nota fiscal" asks for the CNPJ first', (
    tester,
  ) async {
    await _pump(tester, nfse: _nfse());
    expect(find.byKey(const ValueKey('company_nfse')), findsOneWidget);
    expect(find.text(_pt.nfseRowTitle), findsOneWidget);
    expect(find.text(_pt.nfseCompanyRowNoCnpj), findsOneWidget);
  });

  testWidgets('a CNPJ without certificate is not ready yet', (tester) async {
    await _pump(
      tester,
      nfse: _nfse(emitters: [_emitter(withCertificate: false)]),
    );
    expect(find.text(_pt.nfseCompanyRowPending), findsOneWidget);
  });

  testWidgets('a CNPJ that can issue reads "Pronta para emitir"', (
    tester,
  ) async {
    await _pump(tester, nfse: _nfse(emitters: [_emitter()]));
    expect(find.text(_pt.nfseCompanyRowReady), findsOneWidget);
  });

  testWidgets('tapping the row opens the setup', (tester) async {
    var opened = 0;
    await _pump(tester, nfse: _nfse(), open: (_) => opened++);
    await tester.tap(find.byKey(const ValueKey('company_nfse')));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('pilot off: no "Nota fiscal" row', (tester) async {
    await _pump(tester, nfse: _nfse(direct: false));
    expect(find.byKey(const ValueKey('company_nfse')), findsNothing);
  });

  testWidgets('who does not manage the company does not see it', (
    tester,
  ) async {
    await _pump(tester, nfse: _nfse(), canSetUp: false);
    expect(find.byKey(const ValueKey('company_nfse')), findsNothing);
  });
}
