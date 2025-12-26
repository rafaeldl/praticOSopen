import 'package:flutter/material.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/theme/app_theme.dart';

class CollaboratorFormScreen extends StatefulWidget {
  @override
  _CollaboratorFormScreenState createState() => _CollaboratorFormScreenState();
}

class _CollaboratorFormScreenState extends State<CollaboratorFormScreen> {
  final CompanyStore _companyStore = CompanyStore();
  final _formKey = GlobalKey<FormState>();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Colaborador adicionado com sucesso!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        title: Text(
          'Novo Colaborador',
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Convide um novo membro para sua equipe',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Digite o email do usuário',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.email_rounded),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira um email';
                  }
                  if (!value.contains('@')) {
                    return 'Insira um email válido';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<RolesType>(
                value: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'Permissão',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.admin_panel_settings_rounded),
                ),
                items: RolesType.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.toString().split('.').last.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'ADICIONAR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
