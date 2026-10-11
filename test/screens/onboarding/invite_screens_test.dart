import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/invite_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/screens/auth_wrapper.dart';
import 'package:praticos/screens/onboarding/accept_invite_screen.dart';
import 'package:praticos/screens/onboarding/pending_invites_screen.dart';

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

Invite _invite(String company, {String? by}) {
  final i = Invite()
    ..token = 'INV_$company'
    ..company = (CompanyAggr()..name = company);
  if (by != null) i.invitedBy = (UserAggr()..name = by);
  return i;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  void setInvites(List<Invite> invites, {String? error}) {
    final store = InviteStore.instance;
    store.isLoading = false;
    store.errorMessage = error;
    store.pendingInvites.clear();
    store.pendingInvites.addAll(invites);
  }

  group('PendingInvitesScreen', () {
    testWidgets('one invite: single primary button, decline is a text link',
        (tester) async {
      tall(tester);
      setInvites([_invite('Oficina Exemplo', by: 'Ana')]);
      await tester.pumpWidget(_app(PendingInvitesScreen(
        loadOnInit: false,
        onCreateCompany: () {},
      )));

      expect(find.text('Oficina Exemplo chamou você para a equipe'),
          findsOneWidget);
      expect(find.text('Entrar na equipe'), findsOneWidget);
      expect(find.text('Recusar convite'), findsOneWidget);
      expect(find.text('Tenho outro código'), findsOneWidget);
      expect(find.text('Criar minha própria empresa'), findsOneWidget);
      // No filled Cupertino buttons anymore.
      expect(find.byType(CupertinoButton), findsWidgets);
      expect(
          find.byWidgetPredicate(
              (w) => w is CupertinoButton && w.color != null),
          findsNothing);
      expect(find.textContaining('Convidado por Ana'), findsOneWidget);
    });

    testWidgets('decline asks for confirmation with Recusar / Voltar',
        (tester) async {
      tall(tester);
      setInvites([_invite('Oficina Exemplo')]);
      await tester.pumpWidget(_app(const PendingInvitesScreen(
        loadOnInit: false,
      )));

      await tester.tap(find.text('Recusar convite'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('Recusar'), findsOneWidget);
      expect(find.text('Voltar'), findsOneWidget);
      expect(find.text('Excluir'), findsNothing);

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    testWidgets('several invites: rows open join/decline options, no buttons',
        (tester) async {
      tall(tester);
      setInvites([_invite('Alfa'), _invite('Beta')]);
      await tester.pumpWidget(
          _app(const PendingInvitesScreen(loadOnInit: false), brightness: Brightness.dark));

      expect(find.text('Convites Pendentes'), findsOneWidget);
      expect(find.text('Entrar na equipe'), findsNothing);

      await tester.tap(find.text('Alfa'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.text('Entrar na equipe'), findsOneWidget);
      expect(find.text('Recusar convite'), findsOneWidget);
    });

    testWidgets('load failure shows a fixed sentence with retry',
        (tester) async {
      tall(tester);
      setInvites([], error: 'FirebaseException: [cloud_firestore/unavailable]');
      await tester.pumpWidget(
          _app(const PendingInvitesScreen(loadOnInit: false)));

      expect(find.text('Não deu para carregar os convites. Confira a internet.'),
          findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.textContaining('cloud_firestore'), findsNothing);
    });
  });

  group('AcceptInviteScreen', () {
    testWidgets('shows example placeholder and one primary button',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(_app(AcceptInviteScreen(onCancel: () {})));

      expect(find.text('Ex.: 7K2P9QXA'), findsOneWidget);
      expect(find.text('Buscar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('empty code shows a friendly error with icon', (tester) async {
      tall(tester);
      await tester.pumpWidget(_app(const AcceptInviteScreen()));

      await tester.tap(find.text('Buscar'));
      await tester.pump();
      expect(find.byKey(const Key('invite_error')), findsOneWidget);
      expect(find.text('Digite o código do convite'), findsWidgets);
      expect(find.byIcon(CupertinoIcons.exclamationmark_circle),
          findsOneWidget);
    });
  });

  group('AuthLoadErrorView', () {
    testWidgets('shows only the fixed sentence and retries', (tester) async {
      tall(tester);
      var retries = 0;
      await tester.pumpWidget(_app(AuthLoadErrorView(
        message: 'Não deu para abrir a sua empresa. Confira a internet e tente de novo.',
        onRetry: () => retries++,
      )));

      expect(find.textContaining('Não deu para abrir a sua empresa'),
          findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      expect(retries, 1);
    });
  });
}
