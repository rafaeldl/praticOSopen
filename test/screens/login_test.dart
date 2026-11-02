import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/screens/login.dart';
import 'package:praticos/screens/widgets/login_hero.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class _FakeAuthStore implements AuthStore {
  int appleCalls = 0;
  int googleCalls = 0;
  Object? appleError;

  @override
  Future<dynamic> signInWithApple() async {
    appleCalls++;
    if (appleError != null) throw appleError!;
  }

  @override
  dynamic signInWithGoogle() {
    googleCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(
  _FakeAuthStore auth, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('pt'),
}) {
  return Provider<AuthStore>.value(
    value: auth,
    child: CupertinoApp(
      locale: locale,
      theme: CupertinoThemeData(brightness: brightness),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      home: const LoginPage(),
    ),
  );
}

void main() {
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('light: shows title, Apple, Google, e-mail link and terms', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(_app(_FakeAuthStore()));

    expect(
      find.text('Você fala.\nO PraticOS\nfaz a OS.', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(SignInWithAppleButton), findsOneWidget);
    expect(find.text('Continuar com Google'), findsOneWidget);
    expect(find.text('Entrar com e-mail e senha'), findsOneWidget);
    expect(find.textContaining('Política de Privacidade'), findsOneWidget);

    final bg = tester.widget<CupertinoPageScaffold>(
      find.byType(CupertinoPageScaffold),
    );
    expect(bg.backgroundColor, AppColors.brandNavy);
  });

  testWidgets('shows the photos and the complete order once it settles', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(_app(_FakeAuthStore()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(LoginHero), findsOneWidget);
    expect(find.text('Oficina Mecânica'), findsOneWidget);
    expect(find.text('Refrigeração'), findsOneWidget);
    expect(find.text('Você diz · Oficina Mecânica'), findsOneWidget);
    expect(
      find.text('“Onix da Juliana, troca de óleo e alinhamento”'),
      findsOneWidget,
    );
    expect(find.text('R\$\u00A0200,00'), findsOneWidget);
    expect(find.text('OS pronta para enviar'), findsOneWidget);
  });

  testWidgets('the sample order is a picture: hidden from VoiceOver', (
    tester,
  ) async {
    useTallScreen(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_FakeAuthStore()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.bySemanticsLabel('OS pronta para enviar'), findsNothing);
    semantics.dispose();
  });

  testWidgets('with Reduce Motion the order is already in place', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(_FakeAuthStore()),
      ),
    );

    expect(tester.hasRunningAnimations, isFalse);
    final done = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('OS pronta para enviar'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(done.opacity.value, 1);
  });

  double reelOffset(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).last)
      .position
      .pixels;

  testWidgets('the reel passes to the side and a tap pauses it', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(_app(_FakeAuthStore()));
    await tester.pump();
    final start = reelOffset(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(reelOffset(tester), greaterThan(start));

    await tester.tap(find.text('Oficina Mecânica'));
    await tester.pump();
    final paused = reelOffset(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(reelOffset(tester), paused);
  });

  testWidgets('with Reduce Motion the reel stands still', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(_FakeAuthStore()),
      ),
    );
    final start = reelOffset(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(reelOffset(tester), start);
  });

  testWidgets('the card follows the photo at the center of the reel', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(_FakeAuthStore()),
      ),
    );
    await tester.pump();

    final extent = tester
        .widget<ListView>(find.byType(ListView).last)
        .itemExtent!;
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position;
    final start = position.pixels;

    position.jumpTo(start + extent * 3);
    await tester.pump();
    await tester.pump();
    expect(find.text('Você diz · Assistência de Celular'), findsOneWidget);
    expect(
      find.text('“iPhone do Lucas, troca de tela e bateria”'),
      findsOneWidget,
    );
    expect(find.text('R\$\u00A0650,00'), findsOneWidget);
    expect(
      find.text('“Onix da Juliana, troca de óleo e alinhamento”'),
      findsNothing,
    );

    // The reel never ends: past the last trade comes the first again.
    position.jumpTo(start + extent * 20);
    await tester.pump();
    await tester.pump();
    expect(find.text('Você diz · Oficina Mecânica'), findsOneWidget);
  });

  for (final locale in const ['pt', 'en', 'es']) {
    testWidgets('small screen with large text does not overflow ($locale)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await tester.pumpWidget(_app(_FakeAuthStore(), locale: Locale(locale)));
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
      expect(find.byType(SignInWithAppleButton), findsOneWidget);
    });
  }

  testWidgets('dark: same navy background and dark panel', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      _app(_FakeAuthStore(), brightness: Brightness.dark),
    );

    final scaffold = tester.widget<CupertinoPageScaffold>(
      find.byType(CupertinoPageScaffold),
    );
    expect(scaffold.backgroundColor, AppColors.brandNavy);

    final panel = tester.widget<Container>(
      find.byKey(const Key('login_panel')),
    );
    final panelColor =
        (panel.decoration! as BoxDecoration).color! as CupertinoDynamicColor;
    expect(panelColor.darkColor, const Color(0xFF1C1C1E));
    expect(panelColor.color, const Color(0xFFFFFFFF));

    final apple = tester.widget<SignInWithAppleButton>(
      find.byType(SignInWithAppleButton),
    );
    expect(apple.style, SignInWithAppleButtonStyle.white);
  });

  testWidgets('tapping Google calls the store', (tester) async {
    useTallScreen(tester);
    final auth = _FakeAuthStore();
    await tester.pumpWidget(_app(auth));
    await tester.tap(find.text('Continuar com Google'));
    await tester.pump(const Duration(seconds: 2));
    expect(auth.googleCalls, 1);
  });

  testWidgets('Apple error shows a fixed phrase, cancel shows nothing', (
    tester,
  ) async {
    useTallScreen(tester);
    final auth = _FakeAuthStore()
      ..appleError = Exception('[firebase_auth/network-request-failed] x');
    await tester.pumpWidget(_app(auth));
    await tester.tap(find.byType(SignInWithAppleButton));
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.text('Não deu para entrar com a Apple. Tente de novo.'),
      findsOneWidget,
    );
    expect(find.textContaining('firebase_auth'), findsNothing);

    auth.appleError = const SignInWithAppleAuthorizationException(
      code: AuthorizationErrorCode.canceled,
      message: 'canceled',
    );
    await tester.tap(find.byType(SignInWithAppleButton));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('login_error')), findsNothing);
  });
}
