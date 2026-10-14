import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/screens/widgets/primary_button.dart';

void main() {
  Widget host(Widget child) => CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      );

  testWidgets('small sheet: Cancelar on the left, the action on the right, '
      'no big button at the bottom (records use FormSheet, rule 9)',
      (tester) async {
    var done = 0;
    await tester.pumpWidget(host(AppSheet(
      title: 'Período',
      actionLabel: 'OK',
      onAction: () => done++,
      child: const SizedBox(),
    )));
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    expect(find.byType(PrimaryButton), findsNothing);

    await tester.tap(find.text('OK'));
    expect(done, 1);
  });

  testWidgets('without an action label nothing shows on the trailing edge',
      (tester) async {
    await tester.pumpWidget(host(const AppSheet(
      title: 'Papel',
      child: SizedBox(),
    )));
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });
}
