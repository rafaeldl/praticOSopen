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

  testWidgets('record sheet: Cancelar on the left, big button at the bottom, '
      'nothing on the trailing edge (rule 9)', (tester) async {
    var saved = 0;
    await tester.pumpWidget(host(AppSheet(
      title: 'Novo cliente',
      primaryLabel: 'Salvar cliente',
      actionLabel: 'Salvar',
      onAction: () => saved++,
      child: const SizedBox(),
    )));

    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Salvar'), findsNothing);
    expect(find.widgetWithText(PrimaryButton, 'Salvar cliente'), findsOneWidget);
    final screen = tester.getSize(find.byType(AppSheet));
    expect(tester.getCenter(find.text('Salvar cliente')).dy,
        greaterThan(screen.height * 0.8));

    await tester.tap(find.text('Salvar cliente'));
    expect(saved, 1);
  });

  testWidgets('small sheet keeps the trailing action', (tester) async {
    await tester.pumpWidget(host(AppSheet(
      title: 'Período',
      actionLabel: 'OK',
      onAction: () {},
      child: const SizedBox(),
    )));
    expect(find.text('OK'), findsOneWidget);
    expect(find.byType(PrimaryButton), findsNothing);
  });
}
