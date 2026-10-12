import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/theme/app_glass.dart';

Widget app(Widget home) => CupertinoApp(
      locale: const Locale('pt'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      home: home,
    );

void main() {
  testWidgets('GlassBarButton is a 44pt glass circle with a label',
      (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(app(CupertinoPageScaffold(
      child: Center(
        child: GlassBarButton(
          label: 'Mais opções',
          icon: CupertinoIcons.ellipsis,
          onPressed: () => taps++,
        ),
      ),
    )));
    expect(find.byType(AppGlass), findsOneWidget);
    // Lifted off the page: soft shadow so white glass shows on white.
    expect(tester.widget<AppGlass>(find.byType(AppGlass)).elevated, isTrue);
    final shadow = find.descendant(
      of: find.byType(AppGlass),
      matching: find.byWidgetPredicate((w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          ((w.decoration as BoxDecoration).boxShadow?.isNotEmpty ?? false)),
    );
    expect(shadow, findsOneWidget);
    expect(find.bySemanticsLabel('Mais opções'), findsOneWidget);
    expect(tester.getSize(find.byType(GlassBarButton)), const Size(44, 44));
    await tester.tap(find.byType(GlassBarButton));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('AppNavBar shows glass back with previous title and pops',
      (tester) async {
    await tester.pumpWidget(app(Builder(
      builder: (context) => CupertinoPageScaffold(
        child: Center(
          child: CupertinoButton(
            child: const Text('abrir'),
            onPressed: () => Navigator.of(context).push(CupertinoPageRoute(
              builder: (_) => const CupertinoPageScaffold(
                child: CustomScrollView(slivers: [
                  AppNavBar(
                    largeTitle: Text('Detalhe'),
                    previousTitle: 'Clientes',
                  ),
                ]),
              ),
            )),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(GlassBackButton), findsOneWidget);
    expect(find.text('Clientes'), findsWidgets);
    await tester.tap(find.byType(GlassBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Detalhe'), findsNothing);
  });

  testWidgets('AppNavBar has no back button on a root screen', (tester) async {
    await tester.pumpWidget(app(const CupertinoPageScaffold(
      child: CustomScrollView(slivers: [AppNavBar(largeTitle: Text('Início'))]),
    )));
    expect(find.byType(GlassBackButton), findsNothing);
  });

  testWidgets('GlassBackButton falls back to the previous route title',
      (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(CupertinoApp(
      navigatorKey: nav,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: const SizedBox(),
    ));
    nav.currentState!.push(CupertinoPageRoute<void>(
      title: 'Clientes',
      builder: (_) => const SizedBox(),
    ));
    await tester.pumpAndSettle();
    nav.currentState!.push(CupertinoPageRoute<void>(
      builder: (_) => const CupertinoPageScaffold(
        child: Center(child: GlassBackButton()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Clientes'), findsOneWidget);
  });
}
