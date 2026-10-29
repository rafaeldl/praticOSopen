import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/screens/email_login_screen.dart';
import 'package:praticos/screens/loading_screen.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:provider/provider.dart';

class _FakeAuthStore implements AuthStore {
  final calls = <(String, String)>[];
  Object? error;

  @override
  Future<dynamic> signInWithEmailPassword(String email, String password) async {
    calls.add((email, password));
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget home, {AuthStore? auth, Brightness? brightness}) {
  final app = CupertinoApp(
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
  return auth == null
      ? app
      : Provider<AuthStore>.value(value: auth, child: app);
}

Finder _field(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(CupertinoTextField),
);

void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('EmailLoginScreen', () {
    testWidgets('sentence-case title, one primary button, forgot link', (
      tester,
    ) async {
      tall(tester);
      await tester.pumpWidget(
        _app(const EmailLoginScreen(), auth: _FakeAuthStore()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Entrar com e-mail'), findsWidgets);
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.text('Esqueceu a senha?'), findsOneWidget);
      // No old all-caps section header.
      expect(find.text('CREDENCIAIS'), findsNothing);
    });

    testWidgets('empty fields show plain errors and do not sign in', (
      tester,
    ) async {
      tall(tester);
      final auth = _FakeAuthStore();
      await tester.pumpWidget(_app(const EmailLoginScreen(), auth: auth));

      await tester.tap(find.byKey(const ValueKey('email_login_submit')));
      await tester.pump();

      expect(find.text('Escreva o seu e-mail.'), findsOneWidget);
      expect(find.text('Escreva a sua senha.'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('a field error goes away as soon as the field is filled', (
      tester,
    ) async {
      tall(tester);
      await tester.pumpWidget(
        _app(const EmailLoginScreen(), auth: _FakeAuthStore()),
      );

      await tester.tap(find.byKey(const ValueKey('email_login_submit')));
      await tester.pump();
      await tester.enterText(_field('email_login_email'), 'ana@exemplo.com');
      await tester.enterText(_field('email_login_password'), 'segredo');
      await tester.pump();

      expect(find.text('Escreva o seu e-mail.'), findsNothing);
      expect(find.text('Escreva a sua senha.'), findsNothing);
    });

    testWidgets('wrong password shows a fixed sentence and keeps the form', (
      tester,
    ) async {
      tall(tester);
      final auth = _FakeAuthStore()
        ..error = Exception('[firebase_auth/invalid-credential] raw message');
      await tester.pumpWidget(_app(const EmailLoginScreen(), auth: auth));

      await tester.enterText(_field('email_login_email'), 'ana@exemplo.com');
      await tester.enterText(_field('email_login_password'), 'segredo');
      await tester.tap(find.byKey(const ValueKey('email_login_submit')));
      await tester.pumpAndSettle();

      expect(auth.calls.single, ('ana@exemplo.com', 'segredo'));
      expect(find.byKey(const Key('email_login_error')), findsOneWidget);
      expect(
        find.text('E-mail ou senha não conferem. Confira e tente de novo.'),
        findsOneWidget,
      );
      expect(find.textContaining('firebase_auth'), findsNothing);
      // Way out: still on the form, can retry or reset the password.
      expect(find.text('ana@exemplo.com'), findsOneWidget);
      expect(find.byKey(const ValueKey('email_login_forgot')), findsOneWidget);
      final button = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('email_login_submit')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('network error has its own sentence', (tester) async {
      tall(tester);
      final auth = _FakeAuthStore()
        ..error = Exception('[firebase_auth/network-request-failed]');
      await tester.pumpWidget(_app(const EmailLoginScreen(), auth: auth));

      await tester.enterText(_field('email_login_email'), 'ana@exemplo.com');
      await tester.enterText(_field('email_login_password'), 'segredo');
      await tester.tap(find.byKey(const ValueKey('email_login_submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('Sem internet. Confira a conexão e tente de novo.'),
        findsOneWidget,
      );
    });

    testWidgets('eye button has a spoken label and a 44pt target', (
      tester,
    ) async {
      tall(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const EmailLoginScreen(), auth: _FakeAuthStore()),
      );

      final eye = find.byKey(const ValueKey('email_login_toggle_password'));
      final size = tester.getSize(eye);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(find.bySemanticsLabel('Mostrar senha'), findsOneWidget);

      await tester.tap(eye);
      await tester.pump();
      expect(find.bySemanticsLabel('Ocultar senha'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('large text and dark mode: no overflow', (tester) async {
      tall(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = _FakeAuthStore()..error = Exception('unknown');
      await tester.pumpWidget(
        _app(const EmailLoginScreen(), auth: auth, brightness: Brightness.dark),
      );

      await tester.enterText(_field('email_login_email'), 'ana@exemplo.com');
      await tester.enterText(_field('email_login_password'), 'segredo');
      await tester.tap(find.byKey(const ValueKey('email_login_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Não deu para entrar. Tente de novo.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('LoadingScreen', () {
    testWidgets('spinner announced as "Carregando"', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(const LoadingScreen()));

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Carregando')), findsOneWidget);
      semantics.dispose();
    });
  });
}
