import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/screens/menu_navigation/collaborator_form_screen.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';

void main() {
  final pt = AppLocalizationsPt();
  final save = find.byKey(const ValueKey('new_order_save'));

  Future<void> pumpScreen(WidgetTester tester, InviteSender send) async {
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                child: const Text('open'),
                onPressed: () => FormSheet.show<bool>(
                  context,
                  (_) => CollaboratorFormScreen(sendInvite: send),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a failed invite shows a plain notice, not an alert with the server text',
    (tester) async {
      await pumpScreen(
        tester,
        (_, _, _, _) async => throw Exception('Failed to create invite: 404'),
      );
      await tester.enterText(
        find.widgetWithText(CupertinoTextField, pt.emailPlaceholder),
        'lucas@example.com',
      );
      await tester.pump();
      await tester.tap(save);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(pt.inviteGenericError), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.textContaining('404'), findsNothing);
      // The sheet stays open with what was typed, so the person can retry.
      expect(find.byType(FormSheet), findsOneWidget);
      expect(find.text('lucas@example.com'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
    },
  );
}
