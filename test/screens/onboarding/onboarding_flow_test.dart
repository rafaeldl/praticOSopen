import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/screens/onboarding/onboarding_flow.dart';
import 'package:praticos/screens/onboarding/select_subspecialties_screen.dart';
import 'package:praticos/screens/onboarding/your_business_screen.dart';
import 'package:praticos/services/onboarding_service.dart';

final pt = AppLocalizationsPt();

const plain = OnboardingSegment(
  id: 'electronics',
  name: 'Eletrônica',
  icon: '📱',
);

const outsourced = OnboardingSegment(
  id: 'outsourced',
  name: 'Serviço terceirizado',
  useFinancialDefault: false,
);

const automotive = OnboardingSegment(
  id: 'automotive',
  name: 'Automotivo',
  nameI18n: {'pt-BR': 'Mecânica', 'en-US': 'Automotive'},
  icon: '🚗',
  subspecialties: [
    OnboardingSubspecialty(id: 'mechanical', names: {'pt-BR': 'Mecânica geral'}),
    OnboardingSubspecialty(id: 'carwash', names: {'pt-BR': 'Lava-jato'}),
  ],
);

class SaveCall {
  SaveCall(this.data, this.companyId);
  final OnboardingBusiness data;
  final String? companyId;
}

class FakeSetup implements OnboardingSetup {
  final saves = <SaveCall>[];
  final seeds = <({String companyId, bool withSamples, List<String> subs})>[];
  int startedCount = 0;
  int finished = 0;
  int failSeedTimes = 0;
  Completer<void>? holdSave;

  @override
  void started() => startedCount++;

  @override
  Future<String> saveCompany(OnboardingBusiness data, {String? companyId}) async {
    saves.add(SaveCall(data, companyId));
    if (holdSave != null) await holdSave!.future;
    return companyId ?? 'new-company';
  }

  @override
  Future<void> seedCompany(
    String companyId,
    OnboardingBusiness data, {
    required bool withSamples,
  }) async {
    if (failSeedTimes > 0) {
      failSeedTimes--;
      throw Exception('offline');
    }
    seeds.add((
      companyId: companyId,
      withSamples: withSamples,
      subs: data.seedSubspecialties,
    ));
  }

  @override
  Future<void> finish() async => finished++;
}

class Harness {
  Harness({List<OnboardingSegment> segments = const [plain, automotive]})
      : segmentsList = segments;

  final List<OnboardingSegment> segmentsList;
  final setup = FakeSetup();
  int signOuts = 0;
  int inviteCodes = 0;
  int finished = 0;
  int segmentLoads = 0;
  Object? segmentsError;

  OnboardingDeps get deps => OnboardingDeps(
        segments: () {
          segmentLoads++;
          final error = segmentsError;
          return error != null
              ? Stream.error(error)
              : Stream.value(segmentsList);
        },
        setup: setup,
        onSignOut: (_) => signOuts++,
        onInviteCode: (_) => inviteCodes++,
        onFinished: (context) {
          finished++;
          // Like the app: leave the flow for Início.
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(builder: (_) => const Text('Início')),
            (route) => false,
          );
        },
      );
}

Widget app(Widget home) => CupertinoApp(
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

Future<void> pumpFlow(
  WidgetTester tester,
  Harness h, {
  String? companyId,
  String? initialName,
}) async {
  await tester.pumpWidget(app(OnboardingFlow(
    deps: h.deps,
    companyId: companyId,
    initialName: initialName,
  )));
  await tester.pumpAndSettle();
}

Future<void> openBusiness(WidgetTester tester, Harness h,
    {String segment = 'electronics'}) async {
  await pumpFlow(tester, h);
  await tester.tap(find.byKey(ValueKey('segment_$segment')));
  await tester.pumpAndSettle();
}

Future<void> typeName(WidgetTester tester, String name) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey('business_name')),
      matching: find.byType(CupertinoTextField),
    ),
    name,
  );
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

void main() {
  group('Ramo', () {
    testWidgets('lists the segments with the localized name and no button',
        (tester) async {
      final h = Harness();
      await pumpFlow(tester, h);

      expect(find.text(pt.onboardingSegmentTitle), findsWidgets);
      expect(find.text(pt.onboardingSegmentSubtitle), findsOneWidget);
      expect(find.text('Eletrônica'), findsOneWidget);
      expect(find.text('Mecânica'), findsOneWidget); // nameI18n pt-BR
      // every row opens the next step
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsNWidgets(2));
      expect(find.byIcon(CupertinoIcons.checkmark), findsNothing);
      expect(find.text(pt.onboardingCreate), findsNothing);
    });

    testWidgets('tapping a segment marks it with ✓ and goes on',
        (tester) async {
      final h = Harness();
      await openBusiness(tester, h);

      expect(find.byType(YourBusinessScreen), findsOneWidget);
      expect(h.setup.startedCount, 1);

      // back: the picked segment keeps the ✓
      Navigator.of(tester.element(find.byType(YourBusinessScreen))).pop();
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('segment_electronics'));
      expect(
        find.descendant(of: row, matching: find.byIcon(CupertinoIcons.checkmark)),
        findsOneWidget,
      );
    });

    testWidgets('segment with specialties opens Especialidades',
        (tester) async {
      final h = Harness();
      await pumpFlow(tester, h);
      await tester.tap(find.byKey(const ValueKey('segment_automotive')));
      await tester.pumpAndSettle();
      expect(find.byType(SelectSubspecialtiesScreen), findsOneWidget);
    });

    testWidgets('"Sair" and "Recebi um código de convite"', (tester) async {
      final h = Harness();
      await pumpFlow(tester, h);

      await tester.tap(find.text(pt.logout));
      await tapKey(tester, 'onboarding_invite_code');
      expect(h.signOuts, 1);
      expect(h.inviteCodes, 1);
    });

    testWidgets('load error shows a fixed sentence and retries',
        (tester) async {
      final h = Harness()..segmentsError = Exception('[cloud_firestore/unavailable]');
      await pumpFlow(tester, h);

      expect(find.text(pt.onboardingSegmentsError), findsOneWidget);
      expect(find.textContaining('cloud_firestore'), findsNothing);

      h.segmentsError = null;
      await tester.tap(find.text(pt.tryAgain));
      await tester.pumpAndSettle();
      expect(h.segmentLoads, 2);
      expect(find.text('Eletrônica'), findsOneWidget);
    });
  });

  group('Especialidades', () {
    testWidgets('all start checked and Continuar is always enabled',
        (tester) async {
      final h = Harness();
      await openBusiness(tester, h, segment: 'automotive');

      expect(find.text(pt.onboardingSpecialtiesTitle), findsWidgets);
      expect(find.byIcon(CupertinoIcons.checkmark), findsNWidgets(2));

      // uncheck one
      await tester.tap(find.text('Lava-jato'));
      await tester.pump();
      expect(find.byIcon(CupertinoIcons.checkmark), findsNWidgets(1));

      await tapKey(tester, 'subspecialties_continue');
      await tester.pumpAndSettle();
      final business =
          tester.widget<YourBusinessScreen>(find.byType(YourBusinessScreen));
      expect(business.subspecialties, ['mechanical']);
    });

    testWidgets('unchecking all still continues with an empty list',
        (tester) async {
      final h = Harness();
      await openBusiness(tester, h, segment: 'automotive');
      await tester.tap(find.text('Lava-jato'));
      await tester.tap(find.text('Mecânica geral'));
      await tester.pump();
      expect(find.byIcon(CupertinoIcons.checkmark), findsNothing);

      await tapKey(tester, 'subspecialties_continue');
      await tester.pumpAndSettle();
      final business =
          tester.widget<YourBusinessScreen>(find.byType(YourBusinessScreen));
      expect(business.subspecialties, isEmpty);
    });
  });

  group('Seu negócio', () {
    testWidgets('shows name, optional phone, "Valores e cobrança" and samples',
        (tester) async {
      final h = Harness();
      await openBusiness(tester, h);

      expect(find.text(pt.onboardingBusinessTitle), findsWidgets);
      expect(find.text(pt.onboardingBusinessName), findsOneWidget);
      expect(find.text(pt.onboardingPhoneLabel), findsOneWidget);
      expect(find.text(pt.howYouWork), findsOneWidget);
      expect(find.text(pt.valuesAndBilling), findsOneWidget);
      expect(find.text(pt.onboardingSamplesInfo), findsOneWidget);
      expect(find.text(pt.onboardingCreate), findsOneWidget);
      expect(find.text(pt.onboardingStartWithoutSamples), findsOneWidget);
      final toggle = tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
      expect(toggle.value, isTrue);
    });

    testWidgets('name is required; nothing is created without it',
        (tester) async {
      final h = Harness();
      await openBusiness(tester, h);

      await tapKey(tester, 'business_create');
      await tester.pump();
      expect(find.text(pt.onboardingBusinessNameRequired), findsOneWidget);
      expect(h.setup.saves, isEmpty);
    });

    testWidgets('creates with samples, phone left blank, then enters Início',
        (tester) async {
      final h = Harness();
      await openBusiness(tester, h);
      await typeName(tester, '  Oficina do Zé ');
      await tapKey(tester, 'business_create');
      await tester.pumpAndSettle();

      expect(h.setup.saves, hasLength(1));
      final data = h.setup.saves.single.data;
      expect(data.name, 'Oficina do Zé');
      expect(data.phone, isNull);
      expect(data.segment.id, 'electronics');
      expect(data.useFinancial, isTrue);
      expect(h.setup.saves.single.companyId, isNull);
      expect(h.setup.seeds.single.withSamples, isTrue);
      expect(h.setup.seeds.single.companyId, 'new-company');
      expect(h.setup.finished, 1);
      expect(h.finished, 1);
    });

    testWidgets('"Começar sem exemplos" does not create sample data',
        (tester) async {
      final h = Harness();
      await openBusiness(tester, h);
      await typeName(tester, 'Oficina');
      await tapKey(tester, 'business_no_samples');
      await tester.pumpAndSettle();

      expect(h.setup.seeds.single.withSamples, isFalse);
      expect(h.finished, 1);
    });

    testWidgets('"Valores e cobrança" starts from the segment default and '
        'writes the choice', (tester) async {
      final h = Harness(segments: const [outsourced]);
      await openBusiness(tester, h, segment: 'outsourced');

      final toggle = find.byType(CupertinoSwitch);
      expect(tester.widget<CupertinoSwitch>(toggle).value, isFalse);
      await typeName(tester, 'Terceirizada');
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      expect(tester.widget<CupertinoSwitch>(toggle).value, isTrue);

      await tapKey(tester, 'business_create');
      await tester.pumpAndSettle();
      expect(h.setup.saves.single.data.useFinancial, isTrue);
    });

    testWidgets('shows one sentence while preparing', (tester) async {
      final h = Harness();
      h.setup.holdSave = Completer<void>();
      await openBusiness(tester, h);
      await typeName(tester, 'Oficina');
      await tapKey(tester, 'business_create');
      await tester.pump();

      expect(find.text(pt.onboardingPreparing), findsOneWidget);
      expect(find.text(pt.onboardingCreate), findsNothing);

      h.setup.holdSave!.complete();
      await tester.pumpAndSettle();
      expect(h.finished, 1);
    });

    testWidgets('failure shows a fixed sentence; retry reuses the saved '
        'company', (tester) async {
      final h = Harness();
      h.setup.failSeedTimes = 1;
      await openBusiness(tester, h);
      await typeName(tester, 'Oficina');
      await tapKey(tester, 'business_create');
      await tester.pumpAndSettle();

      expect(find.text(pt.onboardingCreateError), findsOneWidget);
      expect(find.textContaining('offline'), findsNothing);
      expect(h.finished, 0);

      await tester.tap(find.text(pt.tryAgain));
      await tester.pumpAndSettle();

      expect(h.setup.saves, hasLength(2));
      expect(h.setup.saves.last.companyId, 'new-company');
      expect(h.setup.seeds.single.withSamples, isTrue);
      expect(h.finished, 1);
    });

    testWidgets('company without segment: prefilled name, completes it',
        (tester) async {
      final h = Harness();
      await pumpFlow(tester, h, companyId: 'old-co', initialName: 'Antiga');
      await tester.tap(find.byKey(const ValueKey('segment_electronics')));
      await tester.pumpAndSettle();

      expect(find.text('Antiga'), findsOneWidget);
      await tapKey(tester, 'business_create');
      await tester.pumpAndSettle();
      expect(h.setup.saves.single.companyId, 'old-co');
      expect(h.setup.seeds.single.companyId, 'old-co');
    });
  });

  testWidgets('full flow: Ramo -> Especialidades -> Seu negócio -> Início',
      (tester) async {
    final h = Harness();
    await pumpFlow(tester, h);

    await tester.tap(find.text('Mecânica'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'subspecialties_continue');
    await tester.pumpAndSettle();

    await typeName(tester, 'Oficina do Zé');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('business_phone_0')),
        matching: find.byType(CupertinoTextField),
      ),
      '11 99999-0000',
    );
    await tapKey(tester, 'business_create');
    await tester.pumpAndSettle();

    final data = h.setup.saves.single.data;
    expect(data.segment.id, 'automotive');
    expect(data.subspecialties, ['mechanical', 'carwash']);
    expect(data.phone, '11 99999-0000');
    expect(h.setup.seeds.single.subs, ['mechanical', 'carwash']);
    expect(h.setup.startedCount, 1);
    expect(h.finished, 1);
  });
}
