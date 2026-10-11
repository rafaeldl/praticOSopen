import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/screens/menu_navigation/team_view.dart';

final _now = DateTime(2026, 10, 11, 12);

Membership _member(String id, String name, RolesType role) => Membership(
      userId: id,
      user: UserAggr()..name = name,
      role: role,
    );

Invite _invite() => Invite()
  ..id = 'i1'
  ..name = 'Lucas'
  ..role = RolesType.technician
  ..expiresAt = _now.add(const Duration(days: 2, hours: 1));

Widget _app(Widget child) => CupertinoApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  final members = [
    _member('u2', 'Marina', RolesType.technician),
    _member('u1', 'Rafael', RolesType.admin),
  ];

  testWidgets('summary, waiting invite block and sections as in app-equipe',
      (tester) async {
    await tester.pumpWidget(_app(TeamView(
      members: members,
      invites: [_invite()],
      currentUserId: 'u1',
      canManage: true,
      now: _now,
      onResendInvite: (_) {},
      onInvite: () {},
    )));

    expect(find.text('Equipe'), findsOneWidget);
    expect(find.text('2 pessoas e 1 convite'), findsOneWidget);
    expect(find.text('Convite esperando'), findsOneWidget);
    expect(find.text('Lucas ainda não entrou. O convite vence em 2 dias.'),
        findsOneWidget);
    expect(find.text('Reenviar convite'), findsOneWidget);
    expect(find.text('Esperando entrar'), findsOneWidget);
    expect(find.text('Convite enviado · vence em 2 dias'), findsOneWidget);
    expect(find.text('Na equipe'), findsOneWidget);
    // The user comes first, then the others.
    final me = tester.getTopLeft(find.text('Rafael (você)')).dy;
    final other = tester.getTopLeft(find.text('Marina')).dy;
    expect(me < other, isTrue);
    expect(find.textContaining('vê e muda tudo'), findsOneWidget);
    expect(find.textContaining('faz os serviços, não vê preços'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Convidar outra pessoa'), 100);
    expect(find.text('Convidar outra pessoa'), findsOneWidget);
  });

  testWidgets('rows open their menus, except the user own row',
      (tester) async {
    final tapped = <String>[];
    var invited = 0;
    await tester.pumpWidget(_app(TeamView(
      members: members,
      invites: [_invite()],
      currentUserId: 'u1',
      canManage: true,
      now: _now,
      onTapMember: (m) => tapped.add(m.userId!),
      onTapInvite: (i) => tapped.add(i.id!),
      onResendInvite: (i) => tapped.add('resend'),
      onInvite: () => invited++,
    )));

    await tester.tap(find.text('Reenviar convite'));
    await tester.tap(find.text('Lucas'));
    await tester.tap(find.text('Rafael (você)'));
    await tester.tap(find.text('Marina'));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team_invite_add')));
    expect(tapped, ['resend', 'i1', 'u2']);
    expect(invited, 1);
  });

  testWidgets('without permission nothing opens and there is no invite row',
      (tester) async {
    await tester.pumpWidget(_app(TeamView(
      members: members,
      invites: const [],
      currentUserId: 'u2',
      now: _now,
      onTapMember: (_) => fail('should not open'),
      onInvite: () => fail('should not invite'),
    )));

    expect(find.text('2 pessoas'), findsOneWidget);
    expect(find.text('Convite esperando'), findsNothing);
    expect(find.text('Convidar outra pessoa'), findsNothing);
    await tester.tap(find.text('Rafael'));
  });
}
