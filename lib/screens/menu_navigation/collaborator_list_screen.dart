import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/collaborator_store.dart';
import 'package:praticos/models/collaborator_exception.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/screens/menu_navigation/team_view.dart';
import 'package:praticos/screens/menu_navigation/collaborator_form_screen.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/invite_share_sheet.dart';

class CollaboratorListScreen extends StatefulWidget {
  @override
  _CollaboratorListScreenState createState() => _CollaboratorListScreenState();
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
  void dispose() {
    super.dispose();
  }






  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) {
      final canManage = _collaboratorStore.canManageCollaborators();
      return TeamView(
        members: _collaboratorStore.collaborators.toList(),
        invites: _collaboratorStore.pendingInvites.toList(),
        currentUserId: Global.currentUser?.uid,
        canManage: canManage,
        loading: _collaboratorStore.isLoading,
        error: _collaboratorStore.errorMessage,
        onRetry: _collaboratorStore.loadCollaborators,
        onTapMember: _showActionSheet,
        onTapInvite: _showInviteActionSheet,
        onResendInvite: _showInviteActionSheet,
        onInvite: _invite,
      );
    });
  }

  Future<void> _invite() async {
    final result = await FormSheet.show<bool>(
        context, (_) => const CollaboratorFormScreen());
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
        context, (_) => CollaboratorFormScreen(prefill: invite));
    // The old invite is gone either way, so refresh the list.
    if (mounted) _collaboratorStore.loadCollaborators();
  }

  void _showInviteActionSheet(Invite invite) {
    final expired = invite.expiresAt != null &&
        invite.expiresAt!.isBefore(DateTime.now());
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('${context.l10n.inviteTo} ${invite.name ?? invite.email}'),
        message: Text(expired
            ? context.l10n.inviteExpiredMessage
            : context.l10n.invitePendingMessage),
        actions: [
          if (expired)
            // Expired: the code no longer works, so cancel and invite again.
            CupertinoActionSheetAction(
              child: Text(context.l10n.cancelAndInviteAgain),
              onPressed: () async {
                Navigator.pop(context);
                await _cancelAndInviteAgain(invite);
              },
            )
          else
            CupertinoActionSheetAction(
              child: Text(context.l10n.shareInviteAction),
              onPressed: () {
                Navigator.pop(context);
                _reshareInvite(invite);
              },
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: Text(context.l10n.cancelInvite),
            onPressed: () {
              Navigator.pop(context);
              _showCancelInviteConfirmation(invite);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _reshareInvite(Invite invite) {
    if (invite.token == null) return;
    InviteShareSheet.show(
      context,
      token: invite.token!,
      whatsappPhone: invite.phone,
      expirationDays: _inviteExpirationDays,
    );
  }

  void _showCancelInviteConfirmation(Invite invite) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.cancelInvite),
        content: Text(
            '${context.l10n.confirmCancelInvite} ${invite.name ?? invite.email}?'),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.no),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _collaboratorStore.cancelInvite(invite.id!);
              } catch (e) {
                _showError(e.toString());
              }
            },
            child: Text(context.l10n.yesCancel),
          ),
        ],
      ),
    );
  }


  String _getRoleLabel(RolesType? role) {
    if (role == null) return context.l10n.roleTechnician;
    return RolePermissions.getRoleLabel(role, context.l10n);
  }

  String _getRoleDescription(RolesType role) {
    return RolePermissions.getRoleDescription(role, context.l10n);
  }

  void _showActionSheet(Membership membership) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('${context.l10n.actionsFor} ${membership.user?.name}'),
        actions: [
          CupertinoActionSheetAction(
            child: Text(context.l10n.editPermission),
            onPressed: () {
              Navigator.pop(context);
              _showEditRoleDialog(membership);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: Text(context.l10n.removeFromCompany),
            onPressed: () {
              Navigator.pop(context);
              _showRemoveConfirmation(membership);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showEditRoleDialog(Membership membership) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(context.l10n.selectProfile),
        message: Text(context.l10n.chooseCollaboratorRole),
        actions: RolePermissions.availableRoles.map((role) {
          final isSelected = membership.role == role;
          return CupertinoActionSheetAction(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getRoleLabel(role),
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      const Icon(CupertinoIcons.checkmark, size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getRoleDescription(role),
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
            onPressed: () async {
              Navigator.pop(context);
              if (role != membership.role) {
                try {
                  await _collaboratorStore.updateCollaboratorRole(
                      membership.userId!, role);
                } on CollaboratorException catch (e) {
                  _showError(_getLocalizedErrorMessage(e.code));
                } catch (e) {
                  _showError(e.toString());
                }
              }
            },
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showRemoveConfirmation(Membership membership) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.removeCollaborator),
        content: Text(
            context.l10n.confirmRemoveFromOrganization(membership.user?.name ?? '')),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.cancel),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _collaboratorStore.removeCollaborator(membership.userId!);
              } on CollaboratorException catch (e) {
                _showError(_getLocalizedErrorMessage(e.code));
              } catch (e) {
                _showError(e.toString());
              }
            },
            child: Text(context.l10n.remove),
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
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.error),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.ok),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
