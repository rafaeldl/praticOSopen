import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserStore _userStore = UserStore();
  final CompanyStore _companyStore = CompanyStore();

  final _userFormKey = GlobalKey<FormState>();
  final _companyFormKey = GlobalKey<FormState>();

  // User Controllers
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _userEmailController = TextEditingController();

  // Company Controllers
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyEmailController = TextEditingController();
  final TextEditingController _companyAddressController = TextEditingController();
  final TextEditingController _companyPhoneController = TextEditingController();
  final TextEditingController _companySiteController = TextEditingController();

  bool _isLoading = false;
  User? _currentUser;
  Company? _currentCompany;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load User
      _currentUser = await _userStore.getSingleUserById();
      if (_currentUser != null) {
        _userNameController.text = _currentUser!.name ?? '';
        _userEmailController.text = _currentUser!.email ?? '';
      }

      // Load Company
      if (Global.companyAggr?.id != null) {
        _currentCompany = await _companyStore.retrieveCompany(Global.companyAggr!.id);
        if (_currentCompany != null) {
          _companyNameController.text = _currentCompany!.name ?? '';
          _companyEmailController.text = _currentCompany!.email ?? '';
          _companyAddressController.text = _currentCompany!.address ?? '';
          _companyPhoneController.text = _currentCompany!.phone ?? '';
          _companySiteController.text = _currentCompany!.site ?? '';
        }
      }
    } catch (e) {
      print("Error loading data: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar dados')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userNameController.dispose();
    _userEmailController.dispose();
    _companyNameController.dispose();
    _companyEmailController.dispose();
    _companyAddressController.dispose();
    _companyPhoneController.dispose();
    _companySiteController.dispose();
    super.dispose();
  }

  Future<void> _saveUser() async {
    if (!_userFormKey.currentState!.validate()) return;
    if (_currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      _currentUser!.name = _userNameController.text;
      // Email is usually not editable here or requires re-auth

      await _userStore.repository.updateItem(_currentUser!);

      // Update Global user if needed
      Global.currentUser = Global.currentUser!..displayName = _currentUser!.name; // Mock update for immediate reflection if using Global

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Usuário atualizado com sucesso!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar usuário')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCompany() async {
    if (!_companyFormKey.currentState!.validate()) return;
    if (_currentCompany == null) return;

    setState(() => _isLoading = true);
    try {
      _currentCompany!.name = _companyNameController.text;
      _currentCompany!.email = _companyEmailController.text;
      _currentCompany!.address = _companyAddressController.text;
      _currentCompany!.phone = _companyPhoneController.text;
      _currentCompany!.site = _companySiteController.text;

      await _companyStore.repository.updateItem(_currentCompany!);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Empresa atualizada com sucesso!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar empresa')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // For glass effect to cover top
      appBar: AppBar(
        title: Text('Editar Perfil', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Theme.of(context).colorScheme.secondary,
          tabs: [
            Tab(text: 'Usuário'),
            Tab(text: 'Empresa'),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Background (Optional: Gradient or Image to show off glass effect)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Theme.of(context).primaryColor, Colors.blue.shade900],
              ),
            ),
          ),

          SafeArea(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.white))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUserTab(),
                      _buildCompanyTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          GlassContainer(
            child: Form(
              key: _userFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Dados do Usuário", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 20),
                  _buildTextField(
                    controller: _userNameController,
                    label: "Nome",
                    icon: Icons.person,
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  SizedBox(height: 15),
                  _buildTextField(
                    controller: _userEmailController,
                    label: "Email",
                    icon: Icons.email,
                    readOnly: true,
                  ),
                  SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _saveUser,
                      child: Text("Salvar Alterações", style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyTab() {
     if (Global.companyAggr?.id == null) {
       return Center(child: Text("Nenhuma empresa associada", style: TextStyle(color: Colors.white)));
     }
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          GlassContainer(
            child: Form(
              key: _companyFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text("Dados da Empresa", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 20),
                  _buildTextField(
                    controller: _companyNameController,
                    label: "Nome da Empresa",
                    icon: Icons.business,
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  SizedBox(height: 15),
                  _buildTextField(
                    controller: _companyEmailController,
                    label: "Email da Empresa",
                    icon: Icons.email_outlined,
                  ),
                  SizedBox(height: 15),
                  _buildTextField(
                    controller: _companyAddressController,
                    label: "Endereço",
                    icon: Icons.location_on,
                  ),
                  SizedBox(height: 15),
                  _buildTextField(
                    controller: _companyPhoneController,
                    label: "Telefone",
                    icon: Icons.phone,
                  ),
                  SizedBox(height: 15),
                  _buildTextField(
                    controller: _companySiteController,
                    label: "Site",
                    icon: Icons.language,
                  ),
                  SizedBox(height: 30),
                   SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _saveCompany,
                      child: Text("Salvar Alterações", style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      validator: validator,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white30),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;

  const GlassContainer({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
