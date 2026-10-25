import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/screens/forms/form_selection_screen.dart';

Future<void> pumpSelection(WidgetTester tester, {required bool canCreate}) {
  return tester.pumpWidget(
    CupertinoApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: FormSelectionScreen(
        companyId: 'c1',
        loadTemplates: () async =>
            (const <FormDefinition>[], const <FormDefinition>[]),
        canCreateTemplate: () => canCreate,
      ),
    ),
  );
}

void main() {
  // The Firestore rules let only manageForms create a checklist template.
  testWidgets('without manageForms there is no "Novo checklist"', (
    tester,
  ) async {
    await pumpSelection(tester, canCreate: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('picker-add')), findsNothing);
  });

  testWidgets('with manageForms "Novo checklist" shows', (tester) async {
    await pumpSelection(tester, canCreate: true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('picker-add')), findsOneWidget);
  });
}
