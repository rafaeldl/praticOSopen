import 'package:easy_mask/easy_mask.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:flutter/material.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({Key? key}) : super(key: key);

  @override
  _CustomerFormScreenState createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Customer? _customer;
  final CustomerStore _customerStore = CustomerStore();
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['customer'] != null) {
      _customer = args['customer'] as Customer;
    } else {
      _customer = Customer();
    }
  }

  bool get _isEditing => _customer?.id != null;

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      _formKey.currentState!.save();
      await _customerStore.saveCustomer(_customer!);
      setState(() => _isLoading = false);
      Navigator.pop(context, _customer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Editar Cliente" : "Novo Cliente"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header icon
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Form fields
                _buildNameField(),
                const SizedBox(height: 16),
                _buildPhoneField(),
                const SizedBox(height: 16),
                _buildEmailField(),
                const SizedBox(height: 16),
                _buildAddressField(),
                const SizedBox(height: 32),
                // Save button
                FilledButton.icon(
                  onPressed: _isLoading ? null : _saveCustomer,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isLoading ? 'Salvando...' : 'Salvar'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      initialValue: _customer!.name,
      decoration: _inputDecoration(
        label: 'Nome',
        icon: Icons.person_outline,
        hint: 'Nome do cliente',
      ),
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Preencha o nome do cliente';
        }
        return null;
      },
      onSaved: (String? value) {
        _customer!.name = value;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      initialValue: _customer!.phone,
      keyboardType: TextInputType.phone,
      inputFormatters: [TextInputMask(mask: '(99) 99999-9999')],
      decoration: _inputDecoration(
        label: 'Telefone',
        icon: Icons.phone_outlined,
        hint: '(00) 00000-0000',
      ),
      onSaved: (String? value) {
        _customer!.phone = value!.replaceAll(RegExp(r'\D'), '');
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      initialValue: _customer!.email,
      keyboardType: TextInputType.emailAddress,
      decoration: _inputDecoration(
        label: 'Email',
        icon: Icons.email_outlined,
        hint: 'email@exemplo.com',
      ),
      onSaved: (String? value) {
        _customer!.email = value;
      },
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      initialValue: _customer!.address,
      decoration: _inputDecoration(
        label: 'Endereço',
        icon: Icons.location_on_outlined,
        hint: 'Endereço completo',
      ),
      textCapitalization: TextCapitalization.sentences,
      onSaved: (String? value) {
        _customer!.address = value;
      },
    );
  }
}
