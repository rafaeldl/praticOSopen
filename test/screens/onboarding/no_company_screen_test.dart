import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/mobx/invite_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/screens/menu_navigation/more/account_deletion.dart';
import 'package:praticos/screens/onboarding/no_company_screen.dart';
import 'package:praticos/screens/onboarding/pending_invites_screen.dart';
import 'package:praticos/utils/platform_policy.dart';

final pt = AppLocalizationsPt();

Widget _app(Widget home, {Brightness brightness = Brightness.light}) {
  return CupertinoApp(
    locale: const Locale('pt'),
    theme: CupertinoThemeData(brightness: brightness),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
    ],
    home: home,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  tearDown(() => PlatformPolicy.debugCanCreateCompanyOverride = null);

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('PlatformPolicy', () {
    test('override wins over the platform', () {
      PlatformPolicy.debugCanCreateCompanyOverride = false;
      expect(PlatformPolicy.canCreateCompanyInApp, isFalse);
      PlatformPolicy.debugCanCreateCompanyOverride = true;
      expect(PlatformPolicy.canCreateCompanyInApp, isTrue);
    });

    test('pending invites always go to the invites screen', () {
      for (final canCreate in [true, false]) {
        expect(
          noCompanyDestination(
            hasPendingInvites: true,
            canCreateCompany: canCreate,
          ),
          NoCompanyDestination.pendingInvites,
        );
      }
    });

    test('no invites: onboarding where allowed, NoCompanyScreen on iOS', () {
      expect(
        noCompanyDestination(hasPendingInvites: false, canCreateCompany: true),
        NoCompanyDestination.welcome,
      );
      expect(
        noCompanyDestination(hasPendingInvites: false, canCreateCompany: false),
        NoCompanyDestination.noCompany,
      );
    });
  });

  group('company creation guard', () {
    test('throws where company creation is forbidden', () {
      PlatformPolicy.debugCanCreateCompanyOverride = false;
      expect(
        PlatformPolicy.ensureCanCreateCompany,
        throwsA(isA<CompanyCreationNotAllowedException>()),
      );
    });

    test('passes where company creation is allowed', () {
      PlatformPolicy.debugCanCreateCompanyOverride = true;
      expect(PlatformPolicy.ensureCanCreateCompany, returnsNormally);
    });

    test('UserStore.createCompanyForUser checks the guard first', () {
      // UserStore needs Firebase Storage to be built, so check the source:
      // the guard must run before anything else in createCompanyForUser.
      final source = File('lib/mobx/user_store.dart').readAsStringSync();
      final body = source.split('Future<void> createCompanyForUser(').last;
      final firstStatement = body.split('\n')[1].trim();
      expect(firstStatement, 'PlatformPolicy.ensureCanCreateCompany();');
    });
  });

  group('NoCompanyScreen', () {
    Future<List<String>> pump(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
    }) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _app(
          NoCompanyScreen(
            email: 'ana@example.com',
            onJoinWithCode: () => calls.add('join'),
            onSignOut: () => calls.add('signOut'),
            deletion: AccountDeletionFlow(
              paidPlansEnabled: false,
              deleteAccount: () async => calls.add('delete'),
              reauthenticate: () async => calls.add('reauth'),
            ),
          ),
          brightness: brightness,
        ),
      );
      return calls;
    }

    testWidgets('explains the invite and offers join, sign out and delete', (
      tester,
    ) async {
      tall(tester);
      await pump(tester);

      expect(find.text(pt.noCompanyTitle), findsOneWidget);
      expect(find.text(pt.noCompanyMessage), findsOneWidget);
      expect(
        find.text(pt.noCompanySignedInAs('ana@example.com')),
        findsOneWidget,
      );
      expect(find.text(pt.joinWithInviteCode), findsOneWidget);
      expect(find.text(pt.logout), findsOneWidget);
      expect(find.text(pt.deleteMyAccount), findsOneWidget);
    });

    testWidgets('never offers or mentions creating a company', (tester) async {
      tall(tester);
      await pump(tester, brightness: Brightness.dark);

      expect(find.text(pt.inviteCreateOwnCompany), findsNothing);
      expect(find.text(pt.configureMyBusiness), findsNothing);
      expect(find.text(pt.configureLater), findsNothing);
      expect(
        find.textContaining(RegExp('criar|site|android', caseSensitive: false)),
        findsNothing,
      );
    });

    testWidgets('join and sign out call their callbacks', (tester) async {
      tall(tester);
      final calls = await pump(tester);

      await tester.tap(find.text(pt.joinWithInviteCode));
      await tester.tap(find.text(pt.logout));
      expect(calls, ['join', 'signOut']);
    });

    testWidgets('delete reuses the two-step account deletion', (tester) async {
      tall(tester);
      final calls = await pump(tester);

      await tester.tap(find.text(pt.deleteMyAccount));
      await tester.pumpAndSettle();
      expect(find.text(pt.deleteAccountWarning), findsOneWidget);

      await tester.tap(find.text(pt.continue_));
      await tester.pumpAndSettle();
      expect(find.text(pt.finalConfirmation), findsOneWidget);

      await tester.tap(find.text(pt.permanentlyDelete));
      await tester.pumpAndSettle();
      expect(calls, ['delete']);
    });
  });

  group('PendingInvitesScreen under the policy', () {
    void setInvites() {
      final store = InviteStore.instance;
      store.isLoading = false;
      store.errorMessage = null;
      store.pendingInvites
        ..clear()
        ..add(
          Invite()
            ..token = 'INV_1'
            ..company = (CompanyAggr()..name = 'Oficina Exemplo'),
        );
    }

    testWidgets('hides "create my company" where creation is forbidden', (
      tester,
    ) async {
      tall(tester);
      setInvites();
      PlatformPolicy.debugCanCreateCompanyOverride = false;
      await tester.pumpWidget(
        _app(PendingInvitesScreen(loadOnInit: false, onCreateCompany: () {})),
      );

      expect(find.text(pt.inviteCreateOwnCompany), findsNothing);
      expect(find.text(pt.inviteHaveAnotherCode), findsOneWidget);
    });

    testWidgets('keeps "create my company" where creation is allowed', (
      tester,
    ) async {
      tall(tester);
      setInvites();
      PlatformPolicy.debugCanCreateCompanyOverride = true;
      await tester.pumpWidget(
        _app(PendingInvitesScreen(loadOnInit: false, onCreateCompany: () {})),
      );

      expect(find.text(pt.inviteCreateOwnCompany), findsOneWidget);
    });
  });
}
