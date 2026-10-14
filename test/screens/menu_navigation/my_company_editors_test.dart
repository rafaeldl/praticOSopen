import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/menu_navigation/more/company_editors.dart';
import 'package:praticos/screens/menu_navigation/more/my_company_screen.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/services/onboarding_service.dart';
import 'package:praticos/services/segment_config_service.dart';
import 'package:provider/provider.dart';

final pt = AppLocalizationsPt();

Widget app(Widget home) => CupertinoApp(
  locale: const Locale('pt'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 5000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Home with a button that pushes [screen] and keeps what it pops with.
class _Launcher extends StatelessWidget {
  const _Launcher({required this.screen, required this.onResult});

  final Widget screen;
  final ValueChanged<Object?> onResult;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Center(
        child: CupertinoButton(
          onPressed: () async {
            final result = await Navigator.of(
              context,
            ).push<Object?>(CupertinoPageRoute(builder: (_) => screen));
            onResult(result);
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}

Future<void> pushScreen(
  WidgetTester tester,
  Widget screen, {
  ValueChanged<Object?>? onResult,
}) async {
  tallScreen(tester);
  await tester.pumpWidget(
    app(_Launcher(screen: screen, onResult: onResult ?? (_) {})),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

const _mechanics = OnboardingSegment(
  id: 'automotive',
  name: 'Mecânica',
  icon: '🚗',
  subspecialties: [
    OnboardingSubspecialty(id: 'mechanical', names: {'pt-BR': 'Mecânica'}),
    OnboardingSubspecialty(id: 'bodywork', names: {'pt-BR': 'Funilaria'}),
  ],
);
const _hvac = OnboardingSegment(id: 'hvac', name: 'Refrigeração');

Company company({
  String? email,
  String? site,
  String? country,
  String? terms,
  String segment = 'automotive',
  List<String>? subspecialties = const ['bodywork'],
}) => Company()
  ..id = 'c1'
  ..name = 'Oficina Exemplo'
  ..phone = '11 99999-0000'
  ..address = 'Rua A, 10'
  ..email = email
  ..site = site
  ..country = country
  ..termsOfService = terms
  ..segment = segment
  ..subspecialties = subspecialties;

String fieldText(WidgetTester tester, String key) => tester
    .widget<CupertinoTextField>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(CupertinoTextField),
      ),
    )
    .controller!
    .text;

void main() {
  group('MyCompanyScreen rows', () {
    testWidgets('each row calls its own callback; Ramo shows the segment', (
      tester,
    ) async {
      tallScreen(tester);
      final opened = <String>[];
      await tester.pumpWidget(
        app(
          MyCompanyScreen(
            companyName: 'Oficina Exemplo',
            segmentName: 'Mecânica',
            specialties: const ['Funilaria', 'Elétrica'],
            onOpenCompanyData: () => opened.add('data'),
            onOpenTerms: () => opened.add('terms'),
            onOpenSegment: () => opened.add('segment'),
            onOpenSpecialties: () => opened.add('specialties'),
          ),
        ),
      );

      final segmentRow = tester.widget<AppListRow>(
        find.byKey(const ValueKey('company_segment')),
      );
      expect(segmentRow.trailing, 'Mecânica');
      expect(find.text('Funilaria, Elétrica'), findsOneWidget);

      await tester.tap(find.text('Oficina Exemplo'));
      await tester.tap(find.text(pt.customerTerms));
      await tester.tap(find.text(pt.segmentRow));
      await tester.tap(find.text(pt.specialties));
      expect(opened, ['data', 'terms', 'segment', 'specialties']);
    });

    testWidgets('Especialidades is hidden when the segment has none', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          MyCompanyScreen(
            onOpenCompanyData: () {},
            onOpenTerms: () {},
            onOpenSegment: () {},
          ),
        ),
      );
      expect(find.byKey(const ValueKey('company_specialties')), findsNothing);
    });

    testWidgets('Especialidades without any checked shows the hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          MyCompanyScreen(
            onOpenCompanyData: () {},
            onOpenTerms: () {},
            onOpenSegment: () {},
            onOpenSpecialties: () {},
          ),
        ),
      );
      expect(find.text(pt.specialtiesNone), findsOneWidget);
    });
  });

  group('MyCompanySettings', () {
    late List<Company> saved;

    setUp(() => saved = []);
    tearDown(() => SegmentConfigService().clear());

    Future<void> pumpSettings(WidgetTester tester, Company loaded) async {
      tallScreen(tester);
      await tester.pumpWidget(
        ChangeNotifierProvider<SegmentConfigProvider>.value(
          value: SegmentConfigProvider(),
          child: app(
            MyCompanySettings(
              companyId: 'c1',
              writer: (_, __) async {},
              loadCompany: (_) async => loaded,
              loadSegments: () async => const [_mechanics, _hvac],
              saveCompany: (c) async => saved.add(c),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the segment and its checked specialties', (
      tester,
    ) async {
      await pumpSettings(tester, company());
      final segmentRow = tester.widget<AppListRow>(
        find.byKey(const ValueKey('company_segment')),
      );
      expect(segmentRow.trailing, 'Mecânica');
      expect(find.text('Funilaria'), findsOneWidget);
    });

    testWidgets('segment without specialties hides Especialidades', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        company(segment: 'hvac', subspecialties: null),
      );
      expect(find.byKey(const ValueKey('company_specialties')), findsNothing);
    });

    testWidgets('picking another segment saves it and clears specialties', (
      tester,
    ) async {
      await pumpSettings(tester, company());
      await tester.tap(find.text(pt.segmentRow));
      await tester.pumpAndSettle();
      expect(find.text(pt.pickSegmentTitle), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('segment_hvac')));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved.single.segment, 'hvac');
      expect(saved.single.subspecialties, isNull);
      final segmentRow = tester.widget<AppListRow>(
        find.byKey(const ValueKey('company_segment')),
      );
      expect(segmentRow.trailing, 'Refrigeração');
      expect(find.byKey(const ValueKey('company_specialties')), findsNothing);
    });

    testWidgets('checking specialties saves them in the segment order', (
      tester,
    ) async {
      await pumpSettings(tester, company());
      await tester.tap(find.text(pt.specialties));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('specialty_mechanical')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('picker_confirm')));
      await tester.pumpAndSettle();

      expect(saved.single.subspecialties, ['mechanical', 'bodywork']);
      expect(find.text('Mecânica, Funilaria'), findsOneWidget);
    });

    testWidgets('company row opens Nome, logo e contato and saving renames', (
      tester,
    ) async {
      await pumpSettings(tester, company());
      await tester.tap(find.text('Oficina Exemplo'));
      await tester.pumpAndSettle();
      expect(find.byType(CompanyDataScreen), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('company_name_field')),
          matching: find.byType(CupertinoTextField),
        ),
        'Oficina Nova',
      );
      await tester.tap(find.byKey(const ValueKey('company_editor_save')));
      await tester.pumpAndSettle();

      expect(saved.single.name, 'Oficina Nova');
      expect(saved.single.updatedAt, isNotNull);
      expect(find.byType(CompanyDataScreen), findsNothing);
      expect(find.text('Oficina Nova'), findsOneWidget);
    });

    testWidgets('terms row opens Termos para o cliente', (tester) async {
      await pumpSettings(tester, company(terms: 'Garantia de 90 dias'));
      await tester.tap(find.text(pt.customerTerms));
      await tester.pumpAndSettle();
      expect(find.byType(CompanyTermsScreen), findsOneWidget);
      expect(fieldText(tester, 'company_terms_field'), 'Garantia de 90 dias');
    });
  });

  group('CompanyDataScreen', () {
    testWidgets('fields come from the company; Mais dados starts closed', (
      tester,
    ) async {
      await pushScreen(
        tester,
        CompanyDataScreen(company: company(), onSave: (_) async {}),
      );
      expect(find.text(pt.companyNameLogoContact), findsOneWidget);
      expect(fieldText(tester, 'company_name_field'), 'Oficina Exemplo');
      expect(fieldText(tester, 'company_phone_field'), '11 99999-0000');
      expect(fieldText(tester, 'company_address_field'), 'Rua A, 10');
      expect(find.byKey(const ValueKey('company_email_field')), findsNothing);
      expect(find.text('+ ${pt.moreCompanyData}'), findsOneWidget);
      expect(find.text(pt.addLogo), findsOneWidget);
    });

    testWidgets('Mais dados opens right away with e-mail or site', (
      tester,
    ) async {
      await pushScreen(
        tester,
        CompanyDataScreen(
          company: company(email: 'oi@oficina.com', site: 'oficina.com'),
          onSave: (_) async {},
        ),
      );
      expect(fieldText(tester, 'company_email_field'), 'oi@oficina.com');
      expect(fieldText(tester, 'company_site_field'), 'oficina.com');
      expect(
        find.byKey(const ValueKey('company_country_field')),
        findsOneWidget,
      );
    });

    testWidgets('Salvar sends the edited values and pops with them', (
      tester,
    ) async {
      final original = company(country: 'BR');
      Company? sent;
      Object? popped;
      await pushScreen(
        tester,
        CompanyDataScreen(company: original, onSave: (c) async => sent = c),
        onResult: (r) => popped = r,
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('company_phone_field')),
          matching: find.byType(CupertinoTextField),
        ),
        '11 98888-7777',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('company_email_field')),
          matching: find.byType(CupertinoTextField),
        ),
        'contato@oficina.com',
      );
      await tester.tap(find.byKey(const ValueKey('company_country_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('country_PT')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('company_editor_save')));
      await tester.pumpAndSettle();

      expect(sent, isNotNull);
      expect(sent!.name, 'Oficina Exemplo');
      expect(sent!.phone, '11 98888-7777');
      expect(sent!.email, 'contato@oficina.com');
      expect(sent!.country, 'PT');
      expect(sent!.address, 'Rua A, 10');
      expect(popped, same(sent));
      // The original stays as it was until the caller takes the result.
      expect(original.phone, '11 99999-0000');
    });

    testWidgets('empty name blocks the save', (tester) async {
      var calls = 0;
      await pushScreen(
        tester,
        CompanyDataScreen(company: company(), onSave: (_) async => calls++),
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('company_name_field')),
          matching: find.byType(CupertinoTextField),
        ),
        '',
      );
      await tester.tap(find.byKey(const ValueKey('company_editor_save')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text(pt.companyNameRequired), findsOneWidget);
    });

    testWidgets('a failed save shows an alert and stays', (tester) async {
      await pushScreen(
        tester,
        CompanyDataScreen(
          company: company(),
          onSave: (_) async => throw Exception('offline'),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('company_editor_save')));
      await tester.pumpAndSettle();
      expect(find.text(pt.companySettingSaveError), findsOneWidget);
      await tester.tap(find.text(pt.ok));
      await tester.pumpAndSettle();
      expect(find.byType(CompanyDataScreen), findsOneWidget);
    });

    testWidgets('Trocar logo uploads through the seam', (tester) async {
      final uploaded = <String>[];
      final asked = <bool>[];
      await pushScreen(
        tester,
        CompanyDataScreen(
          company: company(),
          onSave: (_) async {},
          uploadLogo: (c, {required fromCamera}) async {
            asked.add(fromCamera);
            return null;
          },
          onLogoChanged: uploaded.add,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('company_change_logo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(pt.chooseFromGallery));
      await tester.pumpAndSettle();
      // The user gave up picking: nothing changes.
      expect(asked, [false]);
      expect(uploaded, isEmpty);
      expect(find.text(pt.addLogo), findsOneWidget);
    });
  });

  group('CompanyTermsScreen', () {
    testWidgets('shows the terms and saves the edited text', (tester) async {
      Company? sent;
      await pushScreen(
        tester,
        CompanyTermsScreen(
          company: company(terms: 'Garantia de 90 dias'),
          onSave: (c) async => sent = c,
        ),
      );
      expect(find.text(pt.customerTerms), findsOneWidget);
      expect(find.text(pt.companyShownOnOrder), findsOneWidget);
      expect(fieldText(tester, 'company_terms_field'), 'Garantia de 90 dias');

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('company_terms_field')),
          matching: find.byType(CupertinoTextField),
        ),
        'Garantia de 30 dias',
      );
      await tester.tap(find.byKey(const ValueKey('company_editor_save')));
      await tester.pumpAndSettle();
      expect(sent!.termsOfService, 'Garantia de 30 dias');
      expect(find.byType(CompanyTermsScreen), findsNothing);
    });

    testWidgets('empty terms offer the segment default; clearing saves null', (
      tester,
    ) async {
      Company? sent;
      await pushScreen(
        tester,
        CompanyTermsScreen(
          company: company(),
          defaultTerms: 'Texto padrão',
          onSave: (c) async => sent = c,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('company_terms_default')));
      await tester.pump();
      expect(fieldText(tester, 'company_terms_field'), 'Texto padrão');
      expect(find.byKey(const ValueKey('company_terms_default')), findsNothing);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('company_terms_field')),
          matching: find.byType(CupertinoTextField),
        ),
        '   ',
      );
      await tester.tap(find.byKey(const ValueKey('company_editor_save')));
      await tester.pumpAndSettle();
      expect(sent!.termsOfService, isNull);
    });
  });
}
