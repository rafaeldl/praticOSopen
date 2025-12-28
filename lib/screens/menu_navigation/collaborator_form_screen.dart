import 'package:flutter/cupertino.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/models/user_role.dart';

class CollaboratorFormScreen extends StatefulWidget {
  @override
  _CollaboratorFormScreenState createState() => _CollaboratorFormScreenState();
}

class _CollaboratorFormScreenState extends State<CollaboratorFormScreen> {
  final CompanyStore _companyStore = CompanyStore();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  RolesType _selectedRole = RolesType.user;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _companyStore.addCollaborator(
        _emailController.text.trim(),
        _selectedRole,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Error handling
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showRolePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Selecionar Permissão'),
        actions: RolesType.values.map((role) {
          return CupertinoActionSheetAction(
            child: Text(_getRoleLabel(role)),
            onPressed: () {
              setState(() => _selectedRole = role);
              Navigator.pop(context);
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

  String _getRoleLabel(RolesType role) {
    switch (role) {
      case RolesType.admin:
        return 'Administrador';
      case RolesType.manager:
        return 'Gerente';
      case RolesType.user:
        return 'Usuário';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Novo Colaborador'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : const Text("Adicionar", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              
              CupertinoListSection.insetGrouped(
                header: const Text('INFORMAÇÕES DO USUÁRIO'),
                footer: const Text('O usuário receberá um convite por email.'),
                children: [
                  CupertinoTextFormFieldRow(
                    controller: _emailController,
                    prefix: const Text('Email', style: TextStyle(fontSize: 16)),
                    placeholder: 'email@exemplo.com',
                    keyboardType: TextInputType.emailAddress,
                    textAlign: TextAlign.right,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Obrigatório';
                      }
                      if (!value.contains('@')) {
                        return 'Email inválido';
                      }
                      return null;
                    },
                  ),
                  CupertinoListTile(
                    title: const Text('Permissão'),
                    trailing: Row(
                      children: [
                        Text(
                          _getRoleLabel(_selectedRole),
                          style: const TextStyle(color: CupertinoColors.secondaryLabel),
                        ),
                        const SizedBox(width: 6),
                        const Icon(CupertinoIcons.chevron_right, size: 16, color: CupertinoColors.systemGrey3),
                      ],
                    ),
                    onTap: _showRolePicker,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
