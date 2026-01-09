import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType, Divider, InkWell, DismissDirection;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/collaborator_store.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';

class CollaboratorListScreen extends StatefulWidget {
  @override
  _CollaboratorListScreenState createState() => _CollaboratorListScreenState();
}

class _CollaboratorListScreenState extends State<CollaboratorListScreen> {
  final CollaboratorStore _collaboratorStore = CollaboratorStore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
                largeTitle: const Text('Colaboradores'),
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
                    placeholder: 'Buscar colaborador',
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
            return name.contains(_searchQuery);
          }).toList();

    final filteredInvites = _searchQuery.isEmpty
        ? _collaboratorStore.pendingInvites.toList()
        : _collaboratorStore.pendingInvites.where((invite) {
            final email = invite.email?.toLowerCase() ?? '';
            return email.contains(_searchQuery);
          }).toList();

    if (filteredList.isEmpty && filteredInvites.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('Nenhum colaborador encontrado')),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Primeiro mostramos os convites pendentes
          if (filteredInvites.isNotEmpty) {
            if (index == 0) {
              return _buildSectionHeader('CONVITES PENDENTES');
            }
            if (index <= filteredInvites.length) {
              final invite = filteredInvites[index - 1];
              return _buildInviteRow(invite, canManage, index == filteredInvites.length);
            }
            // Depois os colaboradores ativos
            if (index == filteredInvites.length + 1) {
              return _buildSectionHeader('COLABORADORES');
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

  Widget _buildInviteRow(Invite invite, bool canManage, bool isLast) {
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
                          invite.email ?? 'Email não informado',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemOrange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Pendente',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.systemOrange,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${RolePermissions.getRoleIcon(invite.role ?? RolesType.tecnico)} ${_getRoleLabel(invite.role)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _getRoleDescription(invite.role ?? RolesType.tecnico),
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
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
        title: Text('Convite para ${invite.email}'),
        message: const Text('Este convite está pendente. O usuário verá o convite quando se cadastrar no sistema.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Cancelar Convite'),
            onPressed: () {
              Navigator.pop(context);
              _showCancelInviteConfirmation(invite);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Fechar'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showCancelInviteConfirmation(Invite invite) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Cancelar Convite'),
        content: Text(
            'Tem certeza que deseja cancelar o convite para ${invite.email}?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Não'),
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
            child: const Text('Sim, Cancelar'),
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
                          membership.user?.name ?? 'Usuário sem nome',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${RolePermissions.getRoleIcon(membership.role ?? RolesType.tecnico)} ${_getRoleLabel(membership.role)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          ),
                        ),
                        Text(
                          _getRoleDescription(membership.role ?? RolesType.tecnico),
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
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
    if (role == null) return 'Técnico';
    return RolePermissions.getRoleLabel(role);
  }

  String _getRoleDescription(RolesType role) {
    return RolePermissions.getRoleDescription(role);
  }

  void _showActionSheet(Membership membership) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Ações para ${membership.user?.name}'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Editar Permissão'),
            onPressed: () {
              Navigator.pop(context);
              _showEditRoleDialog(membership);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Remover da Empresa'),
            onPressed: () {
              Navigator.pop(context);
              _showRemoveConfirmation(membership);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showEditRoleDialog(Membership membership) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Selecionar Perfil'),
        message: const Text('Escolha o perfil de acesso do colaborador'),
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
                } catch (e) {
                  _showError(e.toString());
                }
              }
            },
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showRemoveConfirmation(Membership membership) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Remover Colaborador'),
        content: Text(
            'Tem certeza que deseja remover ${membership.user?.name} da organização?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _collaboratorStore.removeCollaborator(membership.userId!);
              } catch (e) {
                _showError(e.toString());
              }
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Erro'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
