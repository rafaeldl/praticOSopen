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
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();
  Customer? _customer;
  final CustomerStore _customerStore = CustomerStore();

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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _customer?.id == null ? "Novo Cliente" : "Editar Cliente",
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  await _customerStore.saveCustomer(_customer!);
                  Navigator.pop(context, _customer);
                }
              },
              child: Text("Salvar"),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Container(
            margin: EdgeInsets.fromLTRB(20, 30, 20, 0),
            child: Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  _buildNameField(),
                  SizedBox(height: 50.0),
                  _buildPhoneField(),
                  SizedBox(height: 50.0),
                  _buildEmailField(),
                  SizedBox(height: 50.0),
                  _buildAddressField(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      initialValue: _customer!.name,
      decoration: const InputDecoration(
        icon: Icon(Icons.edit),
        labelText: 'Nome',
      ),
      validator: (value) {
        if (value!.isEmpty) {
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
      keyboardType: TextInputType.number,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [TextInputMask(mask: '(99) 99999-9999')],
      decoration: const InputDecoration(
        icon: Icon(Icons.phone_iphone),
        labelText: 'Telefone',
      ),
      onSaved: (String? value) {
        _customer!.phone = value!.replaceAll(RegExp(r'\D'), '');
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      initialValue: _customer!.email,
      decoration: const InputDecoration(
        icon: Icon(Icons.email),
        labelText: 'Email',
      ),
      onSaved: (String? value) {
        _customer!.email = value;
      },
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      initialValue: _customer!.address,
      decoration: const InputDecoration(
        icon: Icon(Icons.location_on),
        labelText: 'Endereço',
      ),
      onSaved: (String? value) {
        _customer!.address = value;
      },
    );
  }
}
