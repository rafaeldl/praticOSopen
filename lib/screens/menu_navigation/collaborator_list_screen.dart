import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType, Divider, InkWell, DismissDirection;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user_role.dart';

class CollaboratorListScreen extends StatefulWidget {
  @override
  _CollaboratorListScreenState createState() => _CollaboratorListScreenState();
}

class _CollaboratorListScreenState extends State<CollaboratorListScreen> {
  final CompanyStore _companyStore = CompanyStore();
  final UserStore _userStore = UserStore();
  Company? _company;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _userStore.findCurrentUser();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    if (Global.companyAggr?.id != null) {
      _company = await _companyStore.retrieveCompany(Global.companyAggr!.id);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) {
      final isAdmin = _isAdmin();
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        child: Material(
          type: MaterialType.transparency,
          child: CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text('Colaboradores'),
                trailing: isAdmin
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.add),
                        onPressed: () async {
                          final result = await Navigator.pushNamed(
                              context, '/collaborator_form');
                          if (result == true) {
                            _loadData();
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
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else if (_company == null)
                const SliverFillRemaining(
                  child: Center(child: Text('Empresa não encontrada')),
                )
              else
                _buildList(isAdmin),
                
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildList(bool isAdmin) {
    if (_company!.users == null || _company!.users!.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('Nenhum colaborador encontrado')),
      );
    }

    final filteredList = _searchQuery.isEmpty
        ? _company!.users!
        : _company!.users!.where((userRole) {
            final name = userRole.user?.name?.toLowerCase() ?? '';
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
          final userRole = filteredList[index];
          return _buildUserRow(userRole, isAdmin, index == filteredList.length - 1);
        },
        childCount: filteredList.length,
      ),
    );
  }

  Widget _buildUserRow(UserRoleAggr userRole, bool isAdmin, bool isLast) {
    Widget content = Container(
      color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
      child: InkWell(
        onTap: isAdmin ? () => _showActionSheet(userRole) : null,
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
                      userRole.user?.name?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: CupertinoColors.activeBlue,
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
                          userRole.user?.name ?? 'Usuário sem nome',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getRoleLabel(userRole.role),
                          style: const TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    const Icon(CupertinoIcons.chevron_right, size: 16, color: CupertinoColors.systemGrey3),
                ],
              ),
            ),
                          if (!isLast)
                            Divider(
                              height: 1,
                              indent: 72,
                              color: CupertinoColors.systemGrey5.resolveFrom(context),
                            ),          ],
        ),
      ),
    );

    if (!isAdmin) return content;

    return Dismissible(
      key: Key(userRole.user!.id!),
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
          _showEditRoleDialog(userRole);
          return false;
        } else {
          _showRemoveConfirmation(userRole);
          return false; // Wait for dialog confirmation which handles deletion logic
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

  bool _isAdmin() {
    if (_userStore.user?.value == null || Global.companyAggr == null) return false;

    final currentCompanyId = Global.companyAggr!.id;
    final companyRole = _userStore.user!.value!.companies?.firstWhere(
      (c) => c.company?.id == currentCompanyId,
      orElse: () => CompanyRoleAggr(),
    );

    return companyRole?.role == RolesType.admin ||
        companyRole?.role == RolesType.manager;
  }

  void _showActionSheet(UserRoleAggr userRole) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Ações para ${userRole.user?.name}'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Editar Permissão'),
            onPressed: () {
              Navigator.pop(context);
              _showEditRoleDialog(userRole);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Remover da Empresa'),
            onPressed: () {
              Navigator.pop(context);
              _showRemoveConfirmation(userRole);
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

  void _showEditRoleDialog(UserRoleAggr userRole) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Selecionar Nova Permissão'),
        actions: RolesType.values.map((role) {
          return CupertinoActionSheetAction(
            child: Text(_getRoleLabel(role)),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _companyStore.updateCollaboratorRole(
                    userRole.user!.id!, role);
                _loadData();
              } catch (e) {
                // Handle error
                setState(() => _isLoading = false);
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

  void _showRemoveConfirmation(UserRoleAggr userRole) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Remover Colaborador'),
        content: Text(
            'Tem certeza que deseja remover ${userRole.user?.name} da organização?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _companyStore.removeCollaborator(userRole.user!.id!);
                _loadData();
              } catch (e) {
                // Handle error
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}
