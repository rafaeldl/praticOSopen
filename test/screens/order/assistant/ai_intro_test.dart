import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/screens/order/assistant/ai_intro.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onTry,
    VoidCallback? onLater,
  }) async {
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AiIntroSheet(
              order: 'OS',
              onTry: onTry ?? () {},
              onLater: onLater ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('invites with the segment word for a work order', (tester) async {
    await pump(tester);
    expect(find.text('Crie sua próxima OS falando'), findsOneWidget);
  });

  testWidgets('each button answers once', (tester) async {
    var tried = 0;
    var later = 0;
    await pump(tester, onTry: () => tried++, onLater: () => later++);
    await tester.tap(find.byKey(const ValueKey('ai_intro_try')));
    await tester.tap(find.byKey(const ValueKey('ai_intro_later')));
    expect((tried, later), (1, 1));
  });
}
