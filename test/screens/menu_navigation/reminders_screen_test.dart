import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/engagement_reminder_store.dart';
import 'package:praticos/mobx/reminder_store.dart';
import 'package:praticos/screens/menu_navigation/more/reminders_screen.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pump(WidgetTester tester) async {
    // iOS: no language row (language follows the phone).
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ReminderStore>(create: (_) => ReminderStore()),
          Provider<EngagementReminderStore>(
            create: (_) => EngagementReminderStore(),
          ),
        ],
        child: CupertinoApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RemindersScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('rows and subtitle follow the prototype', (tester) async {
    await pump(tester);

    expect(find.text('Lembretes'), findsWidgets);
    expect(find.text('Valem só neste celular'), findsOneWidget);
    expect(find.text('Antes do horário marcado'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('Resumo do dia às 9h'), findsOneWidget);
    expect(find.text('O que tem para hoje'), findsOneWidget);
    expect(find.text('OS paradas'), findsOneWidget);
    expect(find.text('Orçamentos sem resposta há 7 dias'), findsOneWidget);
    expect(find.text('Se eu ficar dias sem abrir o app'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('"before" row still opens the picker and changes the value',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('reminder_before')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 hora antes'));
    await tester.pumpAndSettle();

    expect(find.text('1 hora'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('"before" opens the choose screen with ✓ on the current value',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('reminder_before')));
    await tester.pumpAndSettle();

    expect(find.byType(PickerScaffold<int>), findsOneWidget);
    expect(find.byType(CupertinoActionSheet), findsNothing);
    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
