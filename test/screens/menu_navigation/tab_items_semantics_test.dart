import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/screens/menu_navigation/app_tabs.dart';
import 'package:praticos/screens/menu_navigation/navigation_controller.dart';
import 'package:praticos/screens/menu_navigation/widgets/glass_tab_bar.dart';

void main() {
  testWidgets('every tab, selected or not, is announced as a button',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => CupertinoTabScaffold(
            tabBar: GlassTabBar(
              items: [
                for (final tab in AppTab.values) buildAppTabItem(context, tab),
              ],
            ),
            tabBuilder: (context, index) => const SizedBox(),
          ),
        ),
      ),
    );

    for (final label in ['Início', 'Clientes', 'Agenda', 'Financeiro', 'Mais']) {
      expect(tester.getSemantics(find.text(label)),
          containsSemantics(isButton: true),
          reason: label);
    }
    handle.dispose();
  });
}
