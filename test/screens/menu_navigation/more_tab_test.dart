import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/screens/menu_navigation/invite_form.dart';
import 'package:praticos/screens/menu_navigation/more/account_deletion.dart';
import 'package:praticos/screens/menu_navigation/more/account_screen.dart';
import 'package:praticos/screens/menu_navigation/more/advanced_screen.dart';
import 'package:praticos/screens/menu_navigation/more/my_company_screen.dart';
import 'package:praticos/screens/menu_navigation/more/more_view.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';

final pt = AppLocalizationsPt();

Widget app(Widget home) => CupertinoApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  group('MoreView', () {
    testWidgets('shows the 9 rows in order, each opening a screen',
        (tester) async {
      final opened = <MoreDestination>[];
      await tester.pumpWidget(app(MoreView(
        onOpen: opened.add,
        planName: 'Starter',
        version: '1.0.0',
      )));

      final titles = tester
          .widgetList<AppListRow>(find.byType(AppListRow))
          .map((row) => row.title)
          .toList();
      expect(titles, [
        'Sua conta',
        'Sua empresa',
        'Equipe',
        'Plano',
        'Catálogo',
        'Checklists',
        'Avaliações',
        'Lembretes',
        'Avançado',
      ]);
      // every row opens another screen, so every row has a chevron
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsNWidgets(9));
      expect(find.text('Starter'), findsOneWidget);
      expect(find.text('PraticOS 1.0.0'), findsOneWidget);

      await tester.tap(find.text('Equipe'));
      expect(opened, [MoreDestination.team]);
    });

    testWidgets('hides rows the role cannot see', (tester) async {
      await tester.pumpWidget(app(MoreView(
        onOpen: (_) {},
        visibility: const MoreVisibility(
          company: false,
          team: false,
          checklists: false,
          ratings: false,
          advanced: false,
        ),
      )));
      final titles = tester
          .widgetList<AppListRow>(find.byType(AppListRow))
          .map((row) => row.title)
          .toList();
      expect(titles, ['Sua conta', 'Plano', 'Catálogo', 'Lembretes']);
    });
  });

  group('Sua conta', () {
    Future<List<String>> pumpAccount(
      WidgetTester tester, {
      Future<void> Function()? onDelete,
      Future<void> Function()? onReauth,
    }) async {
      final calls = <String>[];
      await tester.pumpWidget(app(AccountView(
        name: 'Maria',
        email: 'maria@example.com',
        companyName: 'Oficina',
        roleLabel: 'Administrador',
        onSignOut: () async => calls.add('signOut'),
        deletion: AccountDeletionFlow(
          paidPlansEnabled: false,
          deleteAccount: () async {
            calls.add('delete');
            await onDelete?.call();
          },
          reauthenticate: () async {
            calls.add('reauth');
            await onReauth?.call();
          },
        ),
      )));
      return calls;
    }

    testWidgets('has profile, sign out and delete rows', (tester) async {
      await pumpAccount(tester);
      expect(find.text('Maria'), findsOneWidget);
      expect(find.text('Entrar com código de convite'), findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);
      expect(find.text('Apagar minha conta'), findsOneWidget);
      // switcher only shows with more than one company
      expect(find.text(pt.switchCompany), findsNothing);
    });

    testWidgets('delete asks twice before deleting', (tester) async {
      final calls = await pumpAccount(tester);

      await tester.tap(find.text('Apagar minha conta'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text(pt.deleteAccountWarning), findsOneWidget);
      expect(calls, isEmpty);

      await tester.tap(find.text(pt.continue_));
      await tester.pumpAndSettle();
      expect(find.text(pt.finalConfirmation), findsOneWidget);
      expect(calls, isEmpty);

      await tester.tap(find.text(pt.permanentlyDelete));
      await tester.pumpAndSettle();
      expect(calls, ['delete']);
    });

    testWidgets('cancelling the first confirmation deletes nothing',
        (tester) async {
      final calls = await pumpAccount(tester);
      await tester.tap(find.text('Apagar minha conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(pt.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(calls, isEmpty);
    });

    testWidgets('recent login required asks to sign in again and retries',
        (tester) async {
      var attempts = 0;
      final calls = await pumpAccount(
        tester,
        onDelete: () async {
          attempts++;
          if (attempts == 1) throw Exception('REQUIRES_RECENT_LOGIN');
        },
      );
      await tester.tap(find.text('Apagar minha conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(pt.continue_));
      await tester.pumpAndSettle();
      await tester.tap(find.text(pt.permanentlyDelete));
      await tester.pumpAndSettle();

      expect(find.text(pt.reauthenticationRequired), findsOneWidget);
      await tester.tap(find.text(pt.signInAgain));
      await tester.pumpAndSettle();
      // after re-authenticating the final confirmation comes back
      expect(calls, ['delete', 'reauth']);
      expect(find.text(pt.finalConfirmation), findsOneWidget);
    });

    testWidgets('sign out confirms first', (tester) async {
      final calls = await pumpAccount(tester);
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Sair'));
      await tester.pumpAndSettle();
      expect(calls, ['signOut']);
    });
  });

  group('Sua empresa', () {
    testWidgets('financial switch is disabled until useFinancial exists',
        (tester) async {
      await tester.pumpWidget(app(MyCompanyScreen(onOpenCompanyData: () {})));
      expect(find.text('Dados da Empresa'), findsOneWidget);
      expect(find.text('Como você trabalha'), findsOneWidget);
      expect(find.text('Valores e cobrança'), findsOneWidget);
      final toggle = tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
      expect(toggle.onChanged, isNull);
      expect(toggle.value, isTrue);
    });

    testWidgets('switch works when the field is wired', (tester) async {
      bool? changed;
      await tester.pumpWidget(app(MyCompanyScreen(
        onOpenCompanyData: () {},
        onFinancialChanged: (value) => changed = value,
      )));
      await tester.tap(find.byType(CupertinoSwitch));
      expect(changed, isFalse);
    });
  });

  group('Avançado', () {
    test('shows when at least one entry is allowed', () {
      expect(
        AdvancedScreen.hasEntries(showIntegrations: false, showDevices: false),
        isFalse,
      );
      expect(
        AdvancedScreen.hasEntries(showIntegrations: false, showDevices: true),
        isTrue,
      );
    });
  });

  group('Convidar pessoa', () {
    Future<List<InviteFormData>> pumpForm(WidgetTester tester) async {
      final submitted = <InviteFormData>[];
      await tester.pumpWidget(app(InviteForm(
        onSubmit: (data) async => submitted.add(data),
      )));
      return submitted;
    }

    testWidgets('name is optional: only the e-mail is enough', (tester) async {
      final submitted = await pumpForm(tester);
      await tester.enterText(
          find.widgetWithText(CupertinoTextField, pt.emailPlaceholder),
          'lucas@example.com');
      await tester.tap(find.text('Criar convite'));
      await tester.pump();

      expect(submitted, hasLength(1));
      expect(submitted.single.name, isNull);
      expect(submitted.single.email, 'lucas@example.com');
      expect(submitted.single.role, RolesType.technician);
    });

    testWidgets('asks for e-mail or WhatsApp when both are empty',
        (tester) async {
      final submitted = await pumpForm(tester);
      await tester.tap(find.text('Criar convite'));
      await tester.pump();
      expect(submitted, isEmpty);
      expect(find.text(pt.emailOrPhone), findsOneWidget);
    });

    testWidgets('rejects an e-mail without @', (tester) async {
      final submitted = await pumpForm(tester);
      await tester.enterText(
          find.widgetWithText(CupertinoTextField, pt.emailPlaceholder),
          'lucas');
      await tester.tap(find.text('Criar convite'));
      await tester.pump();
      expect(submitted, isEmpty);
      expect(find.text(pt.invalidEmail), findsOneWidget);
    });

    testWidgets('role picker offers Supervisor and marks the choice with a check',
        (tester) async {
      final submitted = await pumpForm(tester);
      await tester.tap(find.byKey(const ValueKey('invite_role')));
      await tester.pumpAndSettle();

      for (final role in RolePermissions5.all) {
        expect(find.byKey(ValueKey('role_${role.name}')), findsOneWidget);
      }
      expect(find.text(pt.roleSupervisor), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.checkmark), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('role_supervisor')));
      await tester.pumpAndSettle();
      expect(find.text(pt.roleDescSupervisor), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(CupertinoTextField, pt.phonePlaceholder),
          '11 99999-9999');
      await tester.tap(find.text('Criar convite'));
      await tester.pump();
      expect(submitted.single.role, RolesType.supervisor);
      expect(submitted.single.phone, '11 99999-9999');
    });
  });
}

/// The five roles an admin can invite.
class RolePermissions5 {
  static const all = [
    RolesType.admin,
    RolesType.supervisor,
    RolesType.manager,
    RolesType.consultant,
    RolesType.technician,
  ];
}
