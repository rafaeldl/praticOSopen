import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/screens/order/assistant/ai_intro.dart';
import 'package:praticos/services/ai_order_assist_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Assistant implements AiOrderAssistClient {
  _Assistant(this.on);

  final bool on;

  @override
  Future<bool> isEnabled() async => on;

  @override
  Future<AiOrderDraft> assist({
    String? text,
    List<AiPhoto> photos = const [],
    String? locale,
    AiOrderSnapshot? order,
  }) => throw UnimplementedError();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('showAiIntroOnce', () {
    Future<bool> run(
      WidgetTester tester, {
      required bool on,
      bool settled = true,
    }) async {
      late BuildContext context;
      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      return tester.runAsync(
        () => showAiIntroOnce(
          context,
          isSettled: () => settled,
          assistant: _Assistant(on),
        ),
      ).then((done) => done ?? false);
    }

    Future<bool?> seen() async =>
        (await SharedPreferences.getInstance()).getBool(kAiIntroSeenKey);

    testWidgets('left Início meanwhile: tries again later, nothing saved', (
      tester,
    ) async {
      expect(await run(tester, on: true, settled: false), isFalse);
      expect(await seen(), isNull);
    });

    testWidgets('assistant off: done for now, nothing saved', (tester) async {
      expect(await run(tester, on: false), isTrue);
      expect(await seen(), isNull);
    });
  });

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
