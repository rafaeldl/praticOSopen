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
  Company? _company;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/collaborator_form');
          if (result == true) {
            _loadData();
          }
        },
        backgroundColor: AppTheme.primaryColor,
        child: Icon(Icons.add_rounded, color: Colors.white),
      ),
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
                    return _buildUserCard(userRole);
                  },
                ),
    );
  }

  Widget _buildUserCard(UserRoleAggr userRole) {
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
      ),
    );
  }
}
