import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/collaborator_store.dart';
import 'package:praticos/models/collaborator_exception.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/screens/menu_navigation/collaborator_form_screen.dart';
import 'package:praticos/screens/menu_navigation/team_view.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/invite_share_sheet.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/widgets/photo_limit_dialog.dart';

/// What the member screen ([showMemberPicker]) returned.
sealed class MemberChoice {
  const MemberChoice();
}

/// A new role for the member.
class MemberRoleChoice extends MemberChoice {
  const MemberRoleChoice(this.role);
  final RolesType role;
}

/// "Tirar da equipe".
class MemberRemoveChoice extends MemberChoice {
  const MemberRemoveChoice();
}

/// "O que {nome} pode fazer?": the roles (✓ on the current one, with a short
/// description) and, at the end, "Tirar da equipe" in red. Picker pattern,
/// never an action sheet.
Future<MemberChoice?> showMemberPicker(
  BuildContext context,
  Membership membership,
) {
  const remove = '__remove__';
  final l10n = context.l10n;
  final name = membership.user?.name ?? '';
  final current = membership.role ?? RolesType.technician;
  return Navigator.of(context)
      .push<String>(
        CupertinoPageRoute<String>(
          builder: (context) {
            final danger = AppColors.danger.resolveFrom(context);
            return PickerScaffold<String>(
              title: l10n.teamMemberRoleQuestion(name),
              itemCount: RolePermissions.availableRoles.length + 1,
              strongTitles: false,
              sections: (_) => [
                PickerSection<String>(
                  items: [
                    for (final role in RolePermissions.availableRoles)
                      PickerItem<String>(
                        key: Key('memberRole_${role.name}'),
                        value: role.name,
                        title: RolePermissions.getRoleLabel(role, l10n),
                        subtitle: roleShortDescription(role, l10n),
                        selected: role == current,
                      ),
                  ],
                ),
                PickerSection<String>(
                  items: [
                    PickerItem<String>(
                      key: const Key('memberRemove'),
                      value: remove,
                      title: l10n.teamRemoveMember,
                      leading: Icon(
                        CupertinoIcons.person_badge_minus,
                        color: danger,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      )
      .then((value) {
        if (value == null) return null;
        if (value == remove) return const MemberRemoveChoice();
        return MemberRoleChoice(RolesType.values.byName(value));
      });
}

class CollaboratorListScreen extends StatefulWidget {
  const CollaboratorListScreen({super.key});

  @override
  State<CollaboratorListScreen> createState() => _CollaboratorListScreenState();
}

class _CollaboratorListScreenState extends State<CollaboratorListScreen> {
  final CollaboratorStore _collaboratorStore = CollaboratorStore.instance;

  // Default invite expiration days (must match collaborator_form_screen)
  static const int _inviteExpirationDays = 7;

  @override
  void initState() {
    super.initState();
    _collaboratorStore.loadCollaborators();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final canManage = _collaboratorStore.canManageCollaborators();
        return TeamView(
          members: _collaboratorStore.collaborators.toList(),
          invites: _collaboratorStore.pendingInvites.toList(),
          currentUserId: Global.currentUser?.uid,
          canManage: canManage,
          loading: _collaboratorStore.isLoading,
          error: _collaboratorStore.errorMessage,
          onRetry: _collaboratorStore.loadCollaborators,
          onTapMember: _openMember,
          onTapInvite: _openInvite,
          onResendInvite: _openInvite,
          onInvite: _invite,
        );
      },
    );
  }

  String _inviteName(Invite invite) =>
      invite.name ?? invite.email ?? invite.phone ?? '';

  Future<void> _invite() async {
    // Team is a paid feature: at the plan limit, offer the plans before
    // asking for the person's details.
    final gate = FeatureGateService.canAddCollaborator(Global.subscription);
    if (!gate.isAllowed) {
      showFeatureLimitDialog(context, gate);
      return;
    }
    final result = await FormSheet.show<bool>(
      context,
      (_) => const CollaboratorFormScreen(),
    );
    if (result == true) _collaboratorStore.loadCollaborators();
  }

  Future<void> _cancelAndInviteAgain(Invite invite) async {
    try {
      await _collaboratorStore.cancelInvite(invite.id!);
    } catch (e) {
      _showError(e.toString());
      return;
    }
    if (!mounted) return;
    await FormSheet.show<bool>(
      context,
      (_) => CollaboratorFormScreen(prefill: invite),
    );
    // The old invite is gone either way, so refresh the list.
    if (mounted) _collaboratorStore.loadCollaborators();
  }

  /// Waiting invite: the share sheet (cancel in its "…"). Expired: the code
  /// no longer works, so the question is whether to invite again.
  void _openInvite(Invite invite) {
    final expired =
        invite.expiresAt != null && invite.expiresAt!.isBefore(DateTime.now());
    if (expired) {
      _showExpiredInvite(invite);
      return;
    }
    if (invite.token == null) {
      _confirmCancelInvite(invite);
      return;
    }
    InviteShareSheet.show(
      context,
      token: invite.token!,
      whatsappPhone: invite.phone,
      expirationDays: _inviteExpirationDays,
      onCancelInvite: () => _confirmCancelInvite(invite),
    );
  }

  void _showExpiredInvite(Invite invite) {
    final l10n = context.l10n;
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.teamInviteExpiredQuestion(_inviteName(invite))),
        content: Text(l10n.teamInviteExpiredMessage),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              _cancelAndInviteAgain(invite);
            },
            child: Text(l10n.teamInviteAgain),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              _cancelInvite(invite);
            },
            child: Text(l10n.teamCancelInvite),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  void _confirmCancelInvite(Invite invite) {
    final l10n = context.l10n;
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.teamCancelInviteQuestion(_inviteName(invite))),
        content: Text(l10n.teamCancelInviteMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.teamKeepInvite),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              _cancelInvite(invite);
            },
            child: Text(l10n.teamCancelInvite),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelInvite(Invite invite) async {
    try {
      await _collaboratorStore.cancelInvite(invite.id!);
      if (mounted) showAppToast(context, context.l10n.teamInviteCanceled);
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _openMember(Membership membership) async {
    final choice = await showMemberPicker(context, membership);
    if (!mounted || choice == null) return;
    switch (choice) {
      case MemberRoleChoice(:final role):
        if (role == membership.role) return;
        try {
          await _collaboratorStore.updateCollaboratorRole(
            membership.userId!,
            role,
          );
          if (mounted) showAppToast(context, context.l10n.teamRoleChanged);
        } on CollaboratorException catch (e) {
          _showError(_getLocalizedErrorMessage(e.code));
        } catch (e) {
          _showError(e.toString());
        }
      case MemberRemoveChoice():
        _confirmRemove(membership);
    }
  }

  void _confirmRemove(Membership membership) {
    final l10n = context.l10n;
    final name = membership.user?.name ?? '';
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.teamRemoveMemberQuestion(name)),
        content: Text(l10n.teamRemoveMemberMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _collaboratorStore.removeCollaborator(membership.userId!);
                if (mounted) {
                  showAppToast(context, l10n.teamMemberRemoved(name));
                }
              } on CollaboratorException catch (e) {
                _showError(_getLocalizedErrorMessage(e.code));
              } catch (e) {
                _showError(e.toString());
              }
            },
            child: Text(l10n.teamRemoveMember),
          ),
        ],
      ),
    );
  }

  /// Maps a [CollaboratorErrorCode] to a localized message.
  String _getLocalizedErrorMessage(CollaboratorErrorCode code) {
    switch (code) {
      case CollaboratorErrorCode.cannotRemoveOnlyAdmin:
        return context.l10n.cannotRemoveOnlyAdmin;
      case CollaboratorErrorCode.cannotChangeOnlyAdminRole:
        return context.l10n.cannotChangeOnlyAdminRole;
      case CollaboratorErrorCode.cannotRemoveSelf:
        return context.l10n.cannotRemoveSelf;
      case CollaboratorErrorCode.invalidInvite:
        return context.l10n.invalidInviteCompanyNotFound;
      case CollaboratorErrorCode.userNotFound:
        return context.l10n.userNotFound;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showAppToast(
      context,
      message,
      icon: CupertinoIcons.exclamationmark_circle_fill,
    );
  }
}
