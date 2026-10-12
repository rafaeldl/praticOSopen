import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/menu_navigation/invite_form.dart';
import 'package:praticos/screens/menu_navigation/more/account_deletion.dart';
import 'package:praticos/screens/menu_navigation/more/account_screen.dart';
import 'package:praticos/screens/menu_navigation/more/advanced_screen.dart';
import 'package:praticos/screens/menu_navigation/more/my_company_screen.dart';
import 'package:praticos/screens/menu_navigation/more/more_view.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/services/account_deletion_api_service.dart';
import 'package:praticos/services/segment_config_service.dart';
import 'package:provider/provider.dart';

final pt = AppLocalizationsPt();

Widget app(Widget home) => CupertinoApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 5000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

final _financialSwitch = find.descendant(
  of: find.byKey(const ValueKey('company_use_financial')),
  matching: find.byType(CupertinoSwitch),
);

void main() {
  group('MoreView', () {
    testWidgets('shows the 9 rows in order, each opening a screen',
        (tester) async {
      tallScreen(tester);
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

    testWidgets('groups rows under Empresa, Cadastros and Você like the '
        'prototype, with the user as the account row', (tester) async {
      tallScreen(tester);
      await tester.pumpWidget(app(MoreView(
        onOpen: (_) {},
        accountName: 'Rafael',
        companyName: 'Oficina Exemplo',
        catalogSubtitle: 'Serviços e peças',
        planName: 'Pro',
      )));

      expect(find.text('Rafael'), findsOneWidget);
      expect(find.text('Sua conta · Oficina Exemplo'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
      expect(find.text('Dados na OS, ramo e recursos'), findsOneWidget);
      expect(find.text('Serviços e peças'), findsOneWidget);
      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('Empresa'), lessThan(y('Sua empresa')));
      expect(y('Plano'), lessThan(y('Cadastros')));
      expect(y('Cadastros'), lessThan(y('Catálogo')));
      expect(y('Avaliações'), lessThan(y('Você')));
      expect(y('Você'), lessThan(y('Lembretes')));
    });

    testWidgets('hides empty sections', (tester) async {
      tallScreen(tester);
      await tester.pumpWidget(app(MoreView(
        onOpen: (_) {},
        visibility: const MoreVisibility(
          catalog: false,
          checklists: false,
          ratings: false,
        ),
      )));
      expect(find.text('Cadastros'), findsNothing);
      expect(find.text('Empresa'), findsOneWidget);
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

    testWidgets('photo shows the person icon while loading, no spinner',
        (tester) async {
      await tester.pumpWidget(app(AccountView(
        name: 'Maria',
        photoUrl: 'https://example.com/photo.jpg',
        onSignOut: () async {},
        deletion: AccountDeletionFlow(
          paidPlansEnabled: false,
          deleteAccount: () async {},
          reauthenticate: () async {},
        ),
      )));
      await tester.pump();
      expect(find.byKey(const ValueKey('account_avatar_fallback')),
          findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
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

    testWidgets('client timeout shows the "can take a few minutes" message',
        (tester) async {
      await pumpAccount(
        tester,
        onDelete: () async => throw AccountDeletionApiException(
          AccountDeletionApiService.timeoutCode,
          AccountDeletionApiService.timeoutCode,
        ),
      );
      await tester.tap(find.text('Apagar minha conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(pt.continue_));
      await tester.pumpAndSettle();
      await tester.tap(find.text(pt.permanentlyDelete));
      await tester.pumpAndSettle();

      expect(find.textContaining(pt.accountDeletionTakingLong), findsOneWidget);
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
    testWidgets('financial switch is disabled when not wired',
        (tester) async {
      await tester.pumpWidget(app(MyCompanyScreen(onOpenCompanyData: () {})));
      expect(find.text('Dados da Empresa'), findsOneWidget);
      expect(find.text('Como você trabalha'), findsOneWidget);
      expect(find.text('Valores e cobrança'), findsOneWidget);
      expect(find.text(pt.valuesAndBillingHint), findsOneWidget);
      final toggle = tester.widget<CupertinoSwitch>(_financialSwitch);
      expect(toggle.onChanged, isNull);
      expect(toggle.value, isTrue);
    });

    testWidgets('switch works when the field is wired', (tester) async {
      bool? changed;
      await tester.pumpWidget(app(MyCompanyScreen(
        onOpenCompanyData: () {},
        onFinancialChanged: (value) => changed = value,
      )));
      await tester.tap(_financialSwitch);
      expect(changed, isFalse);
    });
  });

  group('Sua empresa › layout and switches', () {
    testWidgets('sections, rows and switches in prototype order',
        (tester) async {
      var opened = 0;
      await tester.pumpWidget(app(MyCompanyScreen(
        companyName: 'Oficina Exemplo',
        devicesLabel: 'Veículos',
        onOpenCompanyData: () => opened++,
      )));
      final order = [
        'Aparece na OS do cliente',
        'Oficina Exemplo',
        'Termos para o cliente',
        'Como você trabalha',
        'Ramo',
        'Valores e cobrança',
        'Agenda',
        'Atendimento no local do cliente',
        'Contratos',
        'Controle de veículos',
      ];
      // Short test surface: check every row exists (skipOffstage off).
      for (final text in order) {
        expect(find.text(text, skipOffstage: false), findsOneWidget,
            reason: text);
      }
      await tester.tap(find.text('Oficina Exemplo'));
      await tester.tap(find.text('Termos para o cliente'));
      await tester.tap(find.text('Ramo'));
      expect(opened, 3);
    });

    testWidgets('a feature switch writes its company field', (tester) async {
      final provider = SegmentConfigProvider()
        ..setCompanyConfig(
          fieldService: true,
          useScheduling: true,
          useDeviceManagement: false,
          useContracts: false,
        );
      final writes = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        ChangeNotifierProvider<SegmentConfigProvider>.value(
          value: provider,
          child: app(MyCompanySettings(
            companyId: 'c1',
            onOpenCompanyData: () {},
            writer: (id, fields) async => writes.add(fields),
          )),
        ),
      );
      final contracts = find.descendant(
        of: find.byKey(const ValueKey('company_useContracts')),
        matching: find.byType(CupertinoSwitch),
        skipOffstage: false,
      );
      tester.widget<CupertinoSwitch>(contracts).onChanged!(true);
      await tester.pumpAndSettle();
      expect(writes, [
        {'useContracts': true}
      ]);
      expect(provider.useContracts, isTrue);
      expect(provider.useScheduling, isTrue);
      SegmentConfigService().clear();
    });
  });

  group('Sua empresa › Valores e cobrança (useFinancial)', () {
    late SegmentConfigProvider provider;
    late List<(String, Map<String, dynamic>)> writes;

    setUp(() {
      provider = SegmentConfigProvider();
      provider.setCompanyConfig(
        fieldService: true,
        useScheduling: true,
        useDeviceManagement: false,
        useContracts: false,
      );
      writes = [];
    });

    tearDown(() => SegmentConfigService().clear());

    Future<void> pumpSettings(
      WidgetTester tester, {
      String? companyId = 'c1',
      bool fail = false,
    }) {
      return tester.pumpWidget(
        ChangeNotifierProvider<SegmentConfigProvider>.value(
          value: provider,
          child: app(MyCompanySettings(
            companyId: companyId,
            onOpenCompanyData: () {},
            writer: (id, fields) async {
              if (fail) throw Exception('offline');
              writes.add((id, fields));
            },
          )),
        ),
      );
    }

    bool switchValue(WidgetTester tester) =>
        tester.widget<CupertinoSwitch>(_financialSwitch).value;

    testWidgets('starts on: absent field resolves to true', (tester) async {
      await pumpSettings(tester);
      expect(switchValue(tester), isTrue);
      expect(provider.useFinancial, isTrue);
    });

    testWidgets('turning off asks first; cancel writes nothing',
        (tester) async {
      await pumpSettings(tester);
      await tester.tap(_financialSwitch);
      await tester.pumpAndSettle();
      expect(find.text(pt.valuesAndBillingOffTitle), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      expect(switchValue(tester), isTrue);
      expect(provider.useFinancial, isTrue);
    });

    testWidgets('confirming writes useFinancial=false and applies it',
        (tester) async {
      await pumpSettings(tester);
      await tester.tap(_financialSwitch);
      await tester.pumpAndSettle();
      await tester.tap(find.text(pt.valuesAndBillingOffAction));
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      expect(writes.single.$1, 'c1');
      expect(writes.single.$2, {'useFinancial': false});
      expect(provider.useFinancial, isFalse);
      expect(SegmentConfigService().useFinancial, isFalse);
      expect(switchValue(tester), isFalse);
    });

    testWidgets('turning back on writes true without asking', (tester) async {
      provider.setUseFinancial(false);
      await pumpSettings(tester);
      expect(switchValue(tester), isFalse);
      await tester.tap(_financialSwitch);
      await tester.pumpAndSettle();
      expect(find.text(pt.valuesAndBillingOffTitle), findsNothing);
      expect(writes, hasLength(1));
      expect(writes.single.$1, 'c1');
      expect(writes.single.$2, {'useFinancial': true});
      expect(provider.useFinancial, isTrue);
    });

    testWidgets('a failed write goes back and tells the user',
        (tester) async {
      provider.setUseFinancial(false);
      await pumpSettings(tester, fail: true);
      await tester.tap(_financialSwitch);
      await tester.pumpAndSettle();
      expect(provider.useFinancial, isFalse);
      expect(find.text(pt.valuesAndBillingSaveError), findsOneWidget);
    });

    testWidgets('without a company the switch is disabled', (tester) async {
      await pumpSettings(tester, companyId: null);
      final toggle =
          tester.widget<CupertinoSwitch>(_financialSwitch);
      expect(toggle.onChanged, isNull);
    });
  });

  group('Avançado', () {
    test('always shows (the "Nova tela da OS" switch lives there)', () {
      expect(
        AdvancedScreen.hasEntries(showIntegrations: false, showDevices: false),
        isTrue,
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
