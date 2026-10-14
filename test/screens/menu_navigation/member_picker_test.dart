import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/screens/menu_navigation/collaborator_list_screen.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';

void main() {
  final l10n = AppLocalizationsPt();
  final marina = Membership(
    userId: 'u2',
    user: UserAggr()..name = 'Marina',
    role: RolesType.technician,
  );

  Future<List<MemberChoice?>> open(
    WidgetTester tester, {
    double scale = 1,
  }) async {
    final results = <MemberChoice?>[];
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => CupertinoButton(
            child: const Text('abrir'),
            onPressed: () async =>
                results.add(await showMemberPicker(context, marina)),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('tela de escolher com a pergunta, os papéis e Tirar da equipe', (
    tester,
  ) async {
    await open(tester);

    expect(find.byType(PickerScaffold<String>), findsOneWidget);
    expect(find.text(l10n.teamMemberRoleQuestion('Marina')), findsWidgets);
    for (final role in RolePermissions.availableRoles) {
      expect(find.byKey(Key('memberRole_${role.name}')), findsOneWidget);
    }
    expect(find.text(l10n.teamRemoveMember), findsOneWidget);
  });

  testWidgets('escolher outro papel devolve o papel', (tester) async {
    final results = await open(tester);

    await tester.tap(find.byKey(const Key('memberRole_admin')));
    await tester.pumpAndSettle();

    expect(results.single, isA<MemberRoleChoice>());
    expect((results.single! as MemberRoleChoice).role, RolesType.admin);
  });

  testWidgets('Tirar da equipe devolve a remoção', (tester) async {
    final results = await open(tester);

    await tester.tap(find.byKey(const Key('memberRemove')));
    await tester.pumpAndSettle();

    expect(results.single, isA<MemberRemoveChoice>());
  });

  testWidgets('texto grande não estoura', (tester) async {
    await open(tester, scale: 2);

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('memberRemove')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(l10n.teamRemoveMember), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
