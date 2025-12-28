import 'package:easy_mask/easy_mask.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/models/customer.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({Key? key}) : super(key: key);

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Customer? _customer;
  final CustomerStore _customerStore = CustomerStore();
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['customer'] != null) {
        _customer = args['customer'] as Customer;
      } else {
        _customer = Customer();
      }
      _initialized = true;
    }
  }

  bool get _isEditing => _customer?.id != null;

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      _formKey.currentState!.save();
      await _customerStore.saveCustomer(_customer!);
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.pop(context, _customer);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? "Editar Cliente" : "Novo Cliente"),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _saveCustomer,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : const Text("Salvar", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              
              // Header Icon (Placeholder since no photo)
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: CupertinoColors.systemGrey5,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.person,
                    size: 50,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Form Fields
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoTextFormFieldRow(
                    prefix: const Text("Nome", style: TextStyle(fontSize: 16)),
                    initialValue: _customer?.name,
                    placeholder: "Nome do cliente",
                    textCapitalization: TextCapitalization.words,
                    textAlign: TextAlign.right,
                    onSaved: (val) => _customer?.name = val,
                    validator: (val) => val == null || val.isEmpty ? "Obrigatório" : null,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: const Text("Telefone", style: TextStyle(fontSize: 16)),
                    initialValue: _customer?.phone, // Note: Mask might need controller logic if buggy, but trying standard first
                    placeholder: "(00) 00000-0000",
                    keyboardType: TextInputType.phone,
                    textAlign: TextAlign.right,
                    inputFormatters: [TextInputMask(mask: '(99) 99999-9999')],
                    onSaved: (val) => _customer?.phone = val?.replaceAll(RegExp(r'\D'), ''),
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: const Text("Email", style: TextStyle(fontSize: 16)),
                    initialValue: _customer?.email,
                    placeholder: "email@exemplo.com",
                    keyboardType: TextInputType.emailAddress,
                    textAlign: TextAlign.right,
                    onSaved: (val) => _customer?.email = val,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: const Text("Endereço", style: TextStyle(fontSize: 16)),
                    initialValue: _customer?.address,
                    placeholder: "Endereço completo",
                    textCapitalization: TextCapitalization.sentences,
                    textAlign: TextAlign.right,
                    onSaved: (val) => _customer?.address = val,
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
