import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType, Divider, InkWell, DismissDirection;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/collaborator_store.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/repositories/tenant/tenant_membership_repository.dart';

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
    if (_collaboratorStore.collaborators.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('Nenhum colaborador encontrado')),
      );
    }

    final filteredList = _searchQuery.isEmpty
        ? _collaboratorStore.collaborators.toList()
        : _collaboratorStore.collaborators.where((membership) {
            final name = membership.user?.name?.toLowerCase() ?? '';
            return name.contains(_searchQuery);
          }).toList();

    if (filteredList.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('Nenhum resultado encontrado')),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final membership = filteredList[index];
          return _buildMembershipRow(membership, canManage, index == filteredList.length - 1);
        },
        childCount: filteredList.length,
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
                          _getRoleLabel(membership.role),
                          style: TextStyle(
                            fontSize: 14,
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
      key: Key(membership.userId),
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
    if (role == null) return 'Usuário';
    switch (role) {
      case RolesType.admin:
        return 'Administrador';
      case RolesType.manager:
        return 'Gerente';
      case RolesType.user:
        return 'Usuário';
    }
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
        title: const Text('Selecionar Nova Permissão'),
        actions: RolesType.values.map((role) {
          return CupertinoActionSheetAction(
            child: Text(_getRoleLabel(role)),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _collaboratorStore.updateCollaboratorRole(
                    membership.userId, role);
              } catch (e) {
                _showError(e.toString());
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
                await _collaboratorStore.removeCollaborator(membership.userId);
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
