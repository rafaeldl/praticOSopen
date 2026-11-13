import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/services/app_version_service.dart';
import 'package:praticos/widgets/app_version_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Harness {
  AppVersionConfig config = AppVersionConfig.disabled;
  String installed = '1.56.0';
  final opened = <String>[];
  int loads = 0;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  AppVersionConfig config = AppVersionConfig.disabled,
  String installed = '1.56.0',
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  final h = _Harness()
    ..config = config
    ..installed = installed;
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    CupertinoApp(
      navigatorKey: navigatorKey,
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppVersionGate(
        navigatorKey: navigatorKey,
        platform: platform,
        loadConfig: (_) async {
          h.loads++;
          return h.config;
        },
        installedVersion: () async => h.installed,
        openStore: (url) async => h.opened.add(url),
        child: child!,
      ),
      home: const Text('home'),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('config off: the app opens normally', (tester) async {
    await _pump(tester);
    expect(find.text('home'), findsOneWidget);
    expect(find.byKey(const ValueKey('app_update_required_screen')),
        findsNothing);
    expect(find.byKey(const ValueKey('app_update_recommended_dialog')),
        findsNothing);
  });

  testWidgets('below the minimum: blocks with the update screen',
      (tester) async {
    final h = await _pump(tester,
        config: const AppVersionConfig(minimum: '1.110.0'));
    expect(find.text('home'), findsNothing);
    expect(find.text('Atualize o app para continuar'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app_update_button')));
    await tester.pumpAndSettle();
    expect(h.opened, [appStoreUrl]);
  });

  testWidgets('android opens the Play Store', (tester) async {
    final h = await _pump(tester,
        platform: TargetPlatform.android,
        config: const AppVersionConfig(minimum: '1.110.0'));
    await tester.tap(find.byKey(const ValueKey('app_update_button')));
    await tester.pumpAndSettle();
    expect(h.opened, [playStoreUrl]);
  });

  testWidgets('rechecks when the app comes back and unblocks after updating',
      (tester) async {
    final h = await _pump(tester,
        config: const AppVersionConfig(minimum: '1.110.0'));
    expect(find.text('home'), findsNothing);

    h.installed = '1.110.0';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(h.loads, 2);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('raising the minimum while the app is open blocks on return',
      (tester) async {
    final h = await _pump(tester, installed: '1.110.0');
    expect(find.text('home'), findsOneWidget);

    h.config = const AppVersionConfig(minimum: '1.111.0');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app_update_required_screen')),
        findsOneWidget);
  });

  testWidgets('below the recommended: dialog that closes and stays closed',
      (tester) async {
    final h = await _pump(tester,
        installed: '1.110.0',
        config: const AppVersionConfig(recommended: '1.111.0'));
    expect(find.text('home'), findsOneWidget);
    expect(find.byKey(const ValueKey('app_update_recommended_dialog')),
        findsOneWidget);

    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app_update_recommended_dialog')),
        findsNothing);
    expect(h.opened, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app_update_recommended_dialog')),
        findsNothing);
  });

  testWidgets('recommended dialog "Atualizar" opens the store',
      (tester) async {
    final h = await _pump(tester,
        installed: '1.110.0',
        config: const AppVersionConfig(recommended: '1.111.0'));
    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();
    expect(h.opened, [appStoreUrl]);
  });

  testWidgets('a failed read never blocks', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => AppVersionGate(
          navigatorKey: navigatorKey,
          platform: TargetPlatform.iOS,
          loadConfig: (_) async => throw Exception('offline'),
          installedVersion: () async => '1.0.0',
          child: child!,
        ),
        home: const Text('home'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
