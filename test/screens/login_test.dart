import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/screens/login.dart';
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

Widget _app(_FakeAuthStore auth, {Brightness brightness = Brightness.light}) {
  return Provider<AuthStore>.value(
    value: auth,
    child: CupertinoApp(
      locale: const Locale('pt'),
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

    expect(find.text('Entre para começar'), findsOneWidget);
    expect(find.byType(SignInWithAppleButton), findsOneWidget);
    expect(find.text('Continuar com Google'), findsOneWidget);
    expect(find.text('Entrar com e-mail e senha'), findsOneWidget);
    expect(find.textContaining('Política de Privacidade'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    final bg = tester.widget<CupertinoPageScaffold>(
      find.byType(CupertinoPageScaffold),
    );
    expect(
      (bg.backgroundColor! as CupertinoDynamicColor).color,
      const Color(0xFFE0F1FF),
    );
  });

  testWidgets('dark: dark blue background and dark panel', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      _app(_FakeAuthStore(), brightness: Brightness.dark),
    );

    final scaffold = tester.widget<CupertinoPageScaffold>(
      find.byType(CupertinoPageScaffold),
    );
    final bg = scaffold.backgroundColor! as CupertinoDynamicColor;
    expect(bg.darkColor, const Color(0xFF142F4B));

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
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_error')), findsNothing);
  });
}
