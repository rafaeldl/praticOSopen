import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/widgets/add_row.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/next_step_block.dart';
import 'package:praticos/screens/widgets/section_label.dart';

/// Short description of what a role can do ("vê e muda tudo").
String roleShortDescription(RolesType role, AppLocalizations l10n) {
  return switch (role) {
    RolesType.admin => l10n.roleShortAdmin,
    RolesType.supervisor => l10n.roleShortSupervisor,
    RolesType.manager => l10n.roleShortManager,
    RolesType.consultant => l10n.roleShortConsultant,
    RolesType.technician => l10n.roleShortTechnician,
  };
}

/// "Equipe" (app-equipe): "2 pessoas e 1 convite", a block for the invite
/// still waiting ("Reenviar convite"), "Esperando entrar" and "Na equipe",
/// and "Convidar outra pessoa" at the end.
///
/// Presentational: [CollaboratorListScreen] wires the store and the action
/// sheets. Rows only open something when [canManage]; the user's own row
/// never does.
class TeamView extends StatelessWidget {
  const TeamView({
    super.key,
    required this.members,
    required this.invites,
    this.currentUserId,
    this.canManage = false,
    this.loading = false,
    this.error,
    this.onRetry,
    this.onTapMember,
    this.onTapInvite,
    this.onResendInvite,
    this.onInvite,
    this.now,
  });

  final List<Membership> members;
  final List<Invite> invites;
  final String? currentUserId;
  final bool canManage;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final ValueChanged<Membership>? onTapMember;
  final ValueChanged<Invite>? onTapInvite;
  final ValueChanged<Invite>? onResendInvite;
  final VoidCallback? onInvite;

  /// Clock for the invite expiry (tests).
  final DateTime? now;

  /// Whole days left until [expiresAt]: null when unknown, negative when
  /// expired, 0 when it ends today.
  int? _daysLeft(DateTime? expiresAt) {
    if (expiresAt == null) return null;
    final diff = expiresAt.difference(now ?? DateTime.now());
    if (diff.isNegative) return -1;
    return diff.inDays;
  }

  String _inviteName(BuildContext context, Invite invite) =>
      invite.name ?? invite.email ?? invite.phone ?? context.l10n.emailNotProvided;

  String _roleLabel(BuildContext context, RolesType? role) =>
      RolePermissions.getRoleLabel(role ?? RolesType.technician, context.l10n);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = invites.isEmpty
        ? l10n.teamPeopleCount(members.length)
        : l10n.teamSummary(
            l10n.teamPeopleCount(members.length),
            l10n.teamInvitesCount(invites.length),
          );

    if (loading || error != null) {
      return MorePage(
        title: l10n.teamTitle,
        children: [
          SizedBox(
            height: 320,
            child: loading
                ? const LoadingState()
                : ErrorState(message: error, onRetry: onRetry ?? () {}),
          ),
        ],
      );
    }

    final waiting = invites.isEmpty ? null : invites.first;
    final waitingDays = _daysLeft(waiting?.expiresAt);
    final sortedMembers = [...members]
      ..sort((a, b) => (a.userId == currentUserId ? 0 : 1)
          .compareTo(b.userId == currentUserId ? 0 : 1));

    return MorePage(
      title: l10n.teamTitle,
      subtitle: summary,
      children: [
        if (waiting != null) ...[
          const SizedBox(height: 8),
          NextStepBlock(
            key: const ValueKey('team_invite_block'),
            label: l10n.teamInviteWaitingLabel,
            text: l10n.teamInviteWaitingText(
              _inviteName(context, waiting),
              switch (waitingDays) {
                null => '',
                < 0 => l10n.teamInviteExpired,
                0 => l10n.teamInviteExpiresToday,
                final days => l10n.teamInviteExpiresInDays(days),
              },
            ).trim(),
            linkLabel: canManage && onResendInvite != null
                ? l10n.teamResendInvite
                : null,
            onLink: canManage && onResendInvite != null
                ? () => onResendInvite!(waiting)
                : null,
          ),
          SectionLabel(l10n.teamWaitingSection),
          MoreRows(rows: [
            for (final invite in invites)
              AppListRow(
                key: ValueKey('team_invite_${invite.id}'),
                title: _inviteName(context, invite),
                subtitle: l10n.teamInviteSent(
                  switch (_daysLeft(invite.expiresAt)) {
                    null || 0 => l10n.teamInviteDueToday,
                    < 0 => l10n.teamInviteDueExpired,
                    final days => l10n.teamInviteDueInDays(days),
                  },
                ),
                trailing: _roleLabel(context, invite.role),
                onTap: canManage && onTapInvite != null
                    ? () => onTapInvite!(invite)
                    : null,
              ),
          ]),
        ],
        SectionLabel(l10n.teamMembersSection),
        MoreRows(rows: [
          for (final member in sortedMembers)
            AppListRow(
              key: ValueKey('team_member_${member.userId}'),
              title: () {
                final name = member.user?.name ?? l10n.userWithoutName;
                return member.userId == currentUserId
                    ? l10n.teamYou(name)
                    : name;
              }(),
              subtitle:
                  '${_roleLabel(context, member.role)} · ${roleShortDescription(member.role ?? RolesType.technician, l10n)}',
              onTap: canManage &&
                      onTapMember != null &&
                      member.userId != currentUserId
                  ? () => onTapMember!(member)
                  : null,
            ),
        ]),
        if (canManage && onInvite != null)
          AddRow(
            key: const ValueKey('team_invite_add'),
            label: members.length <= 1 && invites.isEmpty
                ? l10n.teamInviteFirst
                : l10n.teamInviteAnother,
            onTap: onInvite!,
          ),
      ],
    );
  }
}
