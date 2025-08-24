import 'package:praticos/mobx/product_store.dart';
import 'package:praticos/models/product.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProductFormScreen extends StatelessWidget {
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();
  Map<String, dynamic>? args;

  Product? _product = Product();
  final ProductStore _productStore = ProductStore();

  @override
  Widget build(BuildContext context) {
    args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null && args!.containsKey('product')) {
      _product = args!['product'];
    }

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text("Novo Produto"),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  _productStore.saveProduct(_product!);
                  Navigator.pop(context);
                }
              },
              child: Text("Salvar"),
            ),
          ],
        ),
        body: Container(
          margin: EdgeInsets.fromLTRB(20, 30, 20, 0),
          child: Form(
            key: _formKey,
            child: Column(
              // mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _buildNameField(),
                SizedBox(height: 50.0),
                _buildValueField(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      initialValue: _product!.name,
      decoration: const InputDecoration(
        icon: Icon(Icons.edit),
        labelText: 'Nome',
      ),
      validator: (value) {
        if (value!.isEmpty) {
          return 'Preencha o nome do produto';
        }
        return null;
      },
      onSaved: (String? value) {
        _product!.name = value;
      },
    );
  }

  Widget _buildValueField() {
    return TextFormField(
      initialValue: _convertToCurrency(_product!.value),
      decoration: const InputDecoration(
        icon: Icon(Icons.monetization_on),
        labelText: 'Valor',
      ),
      inputFormatters: [
        CurrencyTextInputFormatter.currency(
          locale: 'pt_BR',
          symbol: 'R\$',
          decimalDigits: 2,
        ),
      ],
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value!.isEmpty) {
          return 'Preencha o valor do produto';
        }
        return null;
      },
      onSaved: (String? value) {
        value = value!
            .replaceAll(RegExp(r'R\$'), '')
            .replaceAll(RegExp(r'\.'), '')
            .replaceAll(RegExp(r','), '.');

        _product!.value = double.parse(value);
      },
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    NumberFormat numberFormat = NumberFormat.currency(
      locale: 'pt-BR',
      symbol: '',
    );
    return numberFormat.format(total);
  }
}
