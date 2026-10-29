import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/screens/user_profile_edit_screen.dart';

void main() {
  User user() => User()
    ..id = 'u1'
    ..name = 'Ana Souza'
    ..email = 'ana@exemplo.com';

  Future<List<User>> pump(WidgetTester tester, User u) async {
    final saved = <User>[];
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: UserProfileEditScreen(
          loadUser: () async => u,
          saveUser: (x) async => saved.add(x),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return saved;
  }

  testWidgets('shows the new title, the name and the e-mail as a sentence', (
    tester,
  ) async {
    await pump(tester, user());

    expect(find.text('Seu perfil'), findsOneWidget);
    expect(find.text('Editar Perfil'), findsNothing);
    expect(find.text('INFORMAÇÕES PESSOAIS'), findsNothing);
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Você entra com ana@exemplo.com'), findsOneWidget);
    expect(find.text('Trocar foto'), findsOneWidget);
  });

  testWidgets('Salvar writes the edited name', (tester) async {
    final saved = await pump(tester, user());

    await tester.enterText(find.byType(CupertinoTextField), 'Ana Lima');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(saved.single.name, 'Ana Lima');
  });

  testWidgets('empty name blocks saving', (tester) async {
    final saved = await pump(tester, user());

    await tester.enterText(find.byType(CupertinoTextField), '  ');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(saved, isEmpty);
    expect(find.text('Digite seu nome'), findsOneWidget);
  });
}
