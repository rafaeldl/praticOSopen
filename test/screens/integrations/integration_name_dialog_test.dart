import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/screens/integrations/integration_list_screen.dart';

void main() {
  Future<List<String?>> pumpDialogHost(WidgetTester tester) async {
    final results = <String?>[];
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => CupertinoButton(
            child: const Text('open'),
            onPressed: () async {
              results.add(await showCupertinoDialog<String>(
                context: context,
                builder: (_) => const IntegrationNameDialog(),
              ));
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  group('IntegrationNameDialog', () {
    testWidgets('devolve o nome sem espaços e fecha sem erro', (tester) async {
      final results = await pumpDialogHost(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));

      await tester.enterText(find.byType(CupertinoTextField), '  Meu ChatGPT ');
      await tester.tap(find.text(l10n.save));
      await tester.pumpAndSettle();

      expect(results, ['Meu ChatGPT']);
      expect(find.byType(IntegrationNameDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelar devolve null', (tester) async {
      final results = await pumpDialogHost(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));

      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      expect(results, [null]);
      expect(tester.takeException(), isNull);
    });
  });
}
