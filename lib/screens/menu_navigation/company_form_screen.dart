import 'package:flutter/material.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/theme/app_theme.dart';

class CompanyFormScreen extends StatefulWidget {
  @override
  _CompanyFormScreenState createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends State<CompanyFormScreen> {
  final CompanyStore _companyStore = CompanyStore();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  Company? _company;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _siteController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _siteController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _siteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    if (Global.companyAggr?.id != null) {
      _company = await _companyStore.retrieveCompany(Global.companyAggr!.id);
      if (_company != null) {
        _nameController.text = _company!.name ?? '';
        _emailController.text = _company!.email ?? '';
        _phoneController.text = _company!.phone ?? '';
        _addressController.text = _company!.address ?? '';
        _siteController.text = _company!.site ?? '';
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_company == null) return;

    setState(() => _isLoading = true);
    try {
      _company!
        ..name = _nameController.text.trim()
        ..email = _emailController.text.trim()
        ..phone = _phoneController.text.trim()
        ..address = _addressController.text.trim()
        ..site = _siteController.text.trim()
        ..updatedAt = DateTime.now()
        ..updatedBy = Global.userAggr;

      await _companyStore.updateCompany(_company!);

      // Update global aggregate if name changed
      if (Global.companyAggr != null && _company!.id == Global.companyAggr!.id) {
        Global.companyAggr!.name = _company!.name;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dados atualizados com sucesso!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar: ${e.toString()}')),
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
          'Dados da Empresa',
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _company == null
              ? Center(child: Text('Empresa não encontrada'))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Informações Gerais',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          decoration: _buildInputDecoration('Nome da Empresa', Icons.business_rounded),
                          validator: (value) => value!.isEmpty ? 'Campo obrigatório' : null,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: _buildInputDecoration('Email de Contato', Icons.email_rounded),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: _buildInputDecoration('Telefone', Icons.phone_rounded),
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          decoration: _buildInputDecoration('Endereço', Icons.location_on_rounded),
                          maxLines: 2,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _siteController,
                          decoration: _buildInputDecoration('Site', Icons.language_rounded),
                          keyboardType: TextInputType.url,
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
                          child: Text(
                            'SALVAR ALTERAÇÕES',
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

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      prefixIcon: Icon(icon, color: AppTheme.textSecondary),
    );
  }
}
