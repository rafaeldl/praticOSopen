import 'package:flutter/cupertino.dart';
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

  @override
  void initState() {
    super.initState();
    _userStore.findCurrentUser();
    _loadData();
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
            SliverFillRemaining(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _company == null
                      ? const Center(child: Text('Empresa não encontrada'))
                      : _buildList(isAdmin),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildList(bool isAdmin) {
    if (_company!.users == null || _company!.users!.isEmpty) {
      return const Center(child: Text('Nenhum colaborador encontrado'));
    }

    return Column(
      children: [
        CupertinoListSection.insetGrouped(
          children: _company!.users!.map((userRole) {
            return _buildUserRow(userRole, isAdmin);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUserRow(UserRoleAggr userRole, bool isAdmin) {
    return CupertinoListTile(
      leadingSize: 40,
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: CupertinoColors.systemGrey5,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            userRole.user?.name?.substring(0, 1).toUpperCase() ?? 'U',
            style: const TextStyle(
              color: CupertinoColors.activeBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(
        userRole.user?.name ?? 'Usuário sem nome',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _getRoleLabel(userRole.role),
        style: const TextStyle(color: CupertinoColors.secondaryLabel),
      ),
      trailing: isAdmin
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showActionSheet(userRole),
              child: const Icon(CupertinoIcons.ellipsis_circle),
            )
          : null,
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
