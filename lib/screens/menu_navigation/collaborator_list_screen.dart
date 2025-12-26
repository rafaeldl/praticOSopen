import 'package:flutter/material.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/theme/app_theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceColor,
          elevation: 0,
          title: Text(
            'Colaboradores',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.primaryColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        floatingActionButton: isAdmin
            ? FloatingActionButton(
                onPressed: () async {
                  final result =
                      await Navigator.pushNamed(context, '/collaborator_form');
                  if (result == true) {
                    _loadData();
                  }
                },
                backgroundColor: AppTheme.primaryColor,
                child: Icon(Icons.add_rounded, color: Colors.white),
              )
            : null,
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _company == null
                ? Center(child: Text('Empresa não encontrada'))
                : ListView.separated(
                    padding: EdgeInsets.all(16),
                    itemCount: _company!.users?.length ?? 0,
                    separatorBuilder: (context, index) => SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final userRole = _company!.users![index];
                      return _buildUserCard(userRole, isAdmin);
                    },
                  ),
      );
    });
  }

  Widget _buildUserCard(UserRoleAggr userRole, bool isAdmin) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          child: Text(
            userRole.user?.name?.substring(0, 1).toUpperCase() ?? 'U',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          userRole.user?.name ?? 'Usuário sem nome',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          userRole.role.toString().split('.').last.toUpperCase(),
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.textSecondary,
          ),
        ),
        trailing: isAdmin
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditRoleDialog(userRole);
                  } else if (value == 'remove') {
                    _showRemoveConfirmation(userRole);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded,
                            size: 20, color: AppTheme.textSecondary),
                        SizedBox(width: 12),
                        Text('Editar Permissão'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded,
                            size: 20, color: AppTheme.errorColor),
                        SizedBox(width: 12),
                        Text('Remover',
                            style: TextStyle(color: AppTheme.errorColor)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.more_vert_rounded,
                      color: AppTheme.textSecondary),
                ),
              )
            : null,
      ),
    );
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

  void _showEditRoleDialog(UserRoleAggr userRole) {
    RolesType selectedRole = userRole.role ?? RolesType.user;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Permissão'),
        content: DropdownButtonFormField<RolesType>(
          value: selectedRole,
          decoration: InputDecoration(
            labelText: 'Permissão',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: RolesType.values.map((role) {
            return DropdownMenuItem(
              value: role,
              child: Text(role.toString().split('.').last.toUpperCase()),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) selectedRole = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _companyStore.updateCollaboratorRole(
                    userRole.user!.id!, selectedRole);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Permissão atualizada com sucesso!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao atualizar: $e')),
                );
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: Text('SALVAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmation(UserRoleAggr userRole) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remover Colaborador'),
        content: Text(
            'Tem certeza que deseja remover ${userRole.user?.name} da organização?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _companyStore.removeCollaborator(userRole.user!.id!);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Colaborador removido com sucesso!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao remover: $e')),
                );
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text('REMOVER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
