import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType, Divider, InkWell, DismissDirection;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/collaborator_store.dart';
import 'package:praticos/models/collaborator_exception.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/invite_share_sheet.dart';

class CollaboratorListScreen extends StatefulWidget {
  @override
  _CollaboratorListScreenState createState() => _CollaboratorListScreenState();
}

class _CollaboratorListScreenState extends State<CollaboratorListScreen> {
  final CollaboratorStore _collaboratorStore = CollaboratorStore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Default invite expiration days (must match collaborator_form_screen)
  static const int _inviteExpirationDays = 7;

  @override
  void initState() {
    super.initState();
    _collaboratorStore.loadCollaborators();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) {
      final canManage = _collaboratorStore.canManageCollaborators();
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        child: Material(
          type: MaterialType.transparency,
          child: CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: Text(context.l10n.collaborators),
                trailing: canManage
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.add),
                        onPressed: () async {
                          final result = await Navigator.pushNamed(
                              context, '/collaborator_form');
                          if (result == true) {
                            _collaboratorStore.loadCollaborators();
                          }
                        },
                      )
                    : null,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: context.l10n.searchCollaborator,
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                  ),
                ),
              ),
              if (_collaboratorStore.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else if (_collaboratorStore.errorMessage != null)
                SliverFillRemaining(
                  child: Center(child: Text(_collaboratorStore.errorMessage!)),
                )
              else
                _buildList(canManage),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildList(bool canManage) {
    final filteredList = _searchQuery.isEmpty
        ? _collaboratorStore.collaborators.toList()
        : _collaboratorStore.collaborators.where((membership) {
            final name = membership.user?.name?.toLowerCase() ?? '';
            final email = membership.user?.email?.toLowerCase() ?? '';
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();

    final filteredInvites = _searchQuery.isEmpty
        ? _collaboratorStore.pendingInvites.toList()
        : _collaboratorStore.pendingInvites.where((invite) {
            final name = invite.name?.toLowerCase() ?? '';
            final email = invite.email?.toLowerCase() ?? '';
            final phone = invite.phone?.toLowerCase() ?? '';
            return name.contains(_searchQuery) ||
                email.contains(_searchQuery) ||
                phone.contains(_searchQuery);
          }).toList();

    if (filteredList.isEmpty && filteredInvites.isEmpty) {
      return SliverFillRemaining(
        child: Center(child: Text(context.l10n.noCollaboratorFound)),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Primeiro mostramos os convites pendentes
          if (filteredInvites.isNotEmpty) {
            if (index == 0) {
              return _buildSectionHeader(context.l10n.pendingInvitations.toUpperCase());
            }
            if (index <= filteredInvites.length) {
              final invite = filteredInvites[index - 1];
              return _buildInviteRow(invite, canManage, index == filteredInvites.length);
            }
            // Depois os colaboradores ativos
            if (index == filteredInvites.length + 1) {
              return _buildSectionHeader(context.l10n.collaborators.toUpperCase());
            }
            final membershipIndex = index - filteredInvites.length - 2;
            if (membershipIndex < filteredList.length) {
              final membership = filteredList[membershipIndex];
              return _buildMembershipRow(membership, canManage, membershipIndex == filteredList.length - 1);
            }
          } else {
            // Sem convites, mostra só os colaboradores
            final membership = filteredList[index];
            return _buildMembershipRow(membership, canManage, index == filteredList.length - 1);
          }
          return const SizedBox.shrink();
        },
        childCount: filteredInvites.isNotEmpty
            ? filteredList.length + filteredInvites.length + 2 // +2 para os headers
            : filteredList.length,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }

  /// Returns the expiration label and color for an invite.
  (String, Color) _getExpirationInfo(Invite invite) {
    if (invite.expiresAt == null) {
      return ('', CupertinoColors.secondaryLabel);
    }

    final now = DateTime.now();
    final diff = invite.expiresAt!.difference(now);

    if (diff.isNegative) {
      return (context.l10n.expired, CupertinoColors.systemRed);
    }

    if (diff.inHours < 1) {
      return (context.l10n.inviteExpiresSoon, CupertinoColors.systemOrange);
    }

    if (diff.inDays < 1) {
      final hours = diff.inHours;
      return (context.l10n.inviteExpiresInHours(hours), CupertinoColors.systemOrange);
    }

    final days = diff.inDays;
    final color = days <= 2 ? CupertinoColors.systemOrange : CupertinoColors.secondaryLabel;
    return (context.l10n.inviteExpiresInDays(days), color);
  }

  Widget _buildInviteRow(Invite invite, bool canManage, bool isLast) {
    final (expirationLabel, expirationColor) = _getExpirationInfo(invite);
    final primaryText = invite.name ?? invite.email ?? context.l10n.emailNotProvided;

    Widget content = Container(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: InkWell(
        onTap: canManage ? () => _showInviteActionSheet(invite) : null,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemOrange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      CupertinoIcons.envelope_badge,
                      size: 22,
                      color: CupertinoColors.systemOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primaryText,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        if (invite.name != null && invite.email != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            invite.email!,
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemOrange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                context.l10n.pending,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.systemOrange,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${RolePermissions.getRoleIcon(invite.role ?? RolesType.technician)} ${_getRoleLabel(invite.role)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            ),
                          ],
                        ),
                        if (expirationLabel.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            expirationLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: expirationColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canManage)
                    Icon(CupertinoIcons.chevron_right, size: 16, color: CupertinoColors.systemGrey3.resolveFrom(context)),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 72,
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
          ],
        ),
      ),
    );

    if (!canManage) return content;

    return Dismissible(
      key: Key('invite_${invite.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: CupertinoColors.systemRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(CupertinoIcons.trash, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        _showCancelInviteConfirmation(invite);
        return false;
      },
      child: content,
    );
  }

  void _showInviteActionSheet(Invite invite) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('${context.l10n.inviteTo} ${invite.name ?? invite.email}'),
        message: Text(context.l10n.invitePendingMessage),
        actions: [
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

  Widget _buildMembershipRow(Membership membership, bool canManage, bool isLast) {
    Widget content = Container(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: InkWell(
        onTap: canManage ? () => _showActionSheet(membership) : null,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5.resolveFrom(context),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      membership.user?.name?.substring(0, 1).toUpperCase() ?? 'U',
                      style: TextStyle(
                        color: CupertinoColors.activeBlue.resolveFrom(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          membership.user?.name ?? context.l10n.userWithoutName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        if (membership.user?.email != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            membership.user!.email!,
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${RolePermissions.getRoleIcon(membership.role ?? RolesType.technician)} ${_getRoleLabel(membership.role)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canManage)
                    Icon(CupertinoIcons.chevron_right, size: 16, color: CupertinoColors.systemGrey3.resolveFrom(context)),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 72,
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
          ],
        ),
      ),
    );

    if (!canManage) return content;

    return Dismissible(
      key: Key(membership.userId!),
      direction: DismissDirection.horizontal,
      background: Container(
        color: CupertinoColors.systemBlue,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(CupertinoIcons.pencil, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: CupertinoColors.systemRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(CupertinoIcons.trash, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _showEditRoleDialog(membership);
          return false;
        } else {
          _showRemoveConfirmation(membership);
          return false;
        }
      },
      child: content,
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
                      '${RolePermissions.getRoleIcon(role)} ${_getRoleLabel(role)}',
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
