import 'package:praticos/mobx/service_store.dart';
import 'package:praticos/models/service.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ServiceFormScreen extends StatelessWidget {
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();
  Map<String, dynamic>? args;

  NumberFormat numberFormat = NumberFormat.currency(
    locale: 'pt-BR',
    symbol: 'R\$',
  );

  Service? _service = Service();
  final ServiceStore _serviceStore = ServiceStore();

  @override
  Widget build(BuildContext context) {
    args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null && args!.containsKey('service')) {
      _service = args!['service'];
    }

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text("Novo Serviço"),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  _serviceStore.saveService(_service!);
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
      initialValue: _service!.name,
      decoration: const InputDecoration(
        icon: Icon(Icons.edit),
        labelText: 'Nome',
      ),
      validator: (value) {
        if (value!.isEmpty) {
          return 'Preencha o nome do serviço';
        }
        return null;
      },
      onSaved: (String? value) {
        _service!.name = value;
      },
    );
  }

  Widget _buildValueField() {
    return TextFormField(
      initialValue: _convertToCurrency(_service!.value),
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
          return 'Preencha o valor do serviço';
        }
        return null;
      },
      onSaved: (String? value) {
        value = value!
            .replaceAll(RegExp(r'R\$'), '')
            .replaceAll(RegExp(r'\.'), '')
            .replaceAll(RegExp(r','), '.');

        _service!.value = double.parse(value);
      },
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    return numberFormat.format(total);
  }
}
